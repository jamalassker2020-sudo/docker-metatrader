from mt5linux import MetaTrader5
from flask import Flask, request, jsonify
from flask_cors import CORS
import os, logging, time, threading
from datetime import datetime

MT5_CONFIG = {
    "server": "ValetaxIntI-Live1",
    "login": 641086382,
    "password": "EJam123!@",
}

FLASK_PORT = int(os.environ.get("FLASK_PORT", 8081))

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("MT5-WEBHOOK")

app = Flask(__name__)
CORS(app)

mt5 = None
connected = False

def connect_mt5():
    global mt5, connected
    try:
        if mt5 is None:
            mt5 = MetaTrader5(host="localhost", port=18812)

        if not mt5.initialize():
            return False

        if mt5.login(**MT5_CONFIG):
            connected = True
            logger.info("MT5 LOGIN OK")
            return True
    except Exception as e:
        logger.error(e)
    return False

def ensure():
    if not connected:
        return connect_mt5()
    return True

@app.route("/")
def home():
    return "WEBHOOK OK"

@app.route("/status")
def status():
    return jsonify({
        "mt5": ensure(),
        "time": datetime.utcnow().isoformat()
    })

@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.json
    if not ensure():
        return jsonify({"error": "MT5 offline"}), 500

    symbol = data["symbol_mt5"]
    action = data["action"]
    lot = float(data.get("lot_size", 0.01))

    mt5.symbol_select(symbol, True)
    tick = mt5.symbol_info_tick(symbol)

    if action == "OPEN":
        order_type = mt5.ORDER_TYPE_BUY if data["direction"] == "BUY" else mt5.ORDER_TYPE_SELL
        price = tick.ask if order_type == mt5.ORDER_TYPE_BUY else tick.bid

        result = mt5.order_send({
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": lot,
            "type": order_type,
            "price": price,
            "magic": 202602,
            "type_filling": mt5.ORDER_FILLING_IOC
        })

        return jsonify({"retcode": result.retcode})

    return jsonify({"error": "Invalid action"})

def heartbeat():
    while True:
        try:
            if connected:
                mt5.account_info()
        except:
            pass
        time.sleep(30)

if __name__ == "__main__":
    threading.Thread(target=heartbeat, daemon=True).start()
    app.run(host="0.0.0.0", port=FLASK_PORT)
