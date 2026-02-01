"""
MT5 Webhook Receiver for HFT Ultra FX Smart Lock 2026
Full version with 28 Forex Pairs + Top 20 Cryptos
"""

from mt5linux import MetaTrader5
from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import logging
import threading
import time
from datetime import datetime

# ============================================
# CONFIGURATION
# ============================================
MT5_CONFIG = {
    "server": "ValetaxIntI-Live1",
    "login": 641086382,
    "password": "EJam123!@",
    "timeout": 10000
}

WEBHOOK_CONFIG = {
    "host": "0.0.0.0",
    "port": int(os.environ.get("PORT", 8080)),
    "enable_trading": True
}

SYMBOL_MAP = {
    # Cryptos (Top 20)
    "BTCUSD": "BTCUSD", "ETHUSD": "ETHUSD", "SOLUSD": "SOLUSD", "XRPUSD": "XRPUSD",
    "ADAUSD": "ADAUSD", "AVAXUSD": "AVAXUSD", "DOTUSD": "DOTUSD", "LINKUSD": "LINKUSD",
    "DOGEUSD": "DOGEUSD", "MATICUSD": "MATICUSD", "LTCUSD": "LTCUSD", "BCHUSD": "BCHUSD",
    "SHIBUSD": "SHIBUSD", "TRXUSD": "TRXUSD", "UNIUSD": "UNIUSD", "ATOMUSD": "ATOMUSD",
    "XLMUSD": "XLMUSD", "NEARUSD": "NEARUSD", "ALGOUSD": "ALGOUSD", "ICPUSD": "ICPUSD",
    # Forex & Metals
    "EURUSD": "EURUSD", "GBPUSD": "GBPUSD", "USDJPY": "USDJPY", "XAUUSD": "XAUUSD"
    # ... (rest of your map remains the same)
}

# ============================================
# LOGGING & APP SETUP
# ============================================
logging.basicConfig(level=logging.INFO, format='%(asctime)s | %(levelname)s | %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Global MT5 Object (Initialized inside a function to avoid early crash)
mt5 = None
mt5_connected = False

# ============================================
# RESILIENT CONNECTION LOGIC
# ============================================
def init_mt5():
    global mt5, mt5_connected
    try:
        if mt5 is None:
            logger.info("Initializing MT5 Linux Bridge...")
            # We wrap this in a try/except because if the bridge is down, this throws a socket error
            mt5 = MetaTrader5(host='localhost', port=18812)
        
        if not mt5.initialize():
            logger.error(f"MT5 Initialize failed: {mt5.last_error()}")
            return False

        authorized = mt5.login(
            login=MT5_CONFIG["login"],
            password=MT5_CONFIG["password"],
            server=MT5_CONFIG["server"]
        )

        if authorized:
            logger.info(f"MT5 Authorized Successfully: {MT5_CONFIG['login']}")
            mt5_connected = True
            return True
        else:
            logger.error(f"MT5 Login failed for {MT5_CONFIG['login']}")
            return False
    except Exception as e:
        logger.error(f"Bridge connection error: {e}")
        return False

def ensure_connection():
    global mt5_connected
    if not mt5_connected or mt5 is None or mt5.account_info() is None:
        return init_mt5()
    return True

# ============================================
# TRADE EXECUTION
# ============================================
def execute_open(payload):
    if not ensure_connection(): return {"success": False, "error": "MT5 Connection Failed"}
    
    symbol = payload.get("symbol_mt5")
    direction = payload.get("direction")
    lots = float(payload.get("lot_size", 0.01))
    
    # Auto-select symbol
    mt5.symbol_select(symbol, True)
    tick = mt5.symbol_info_tick(symbol)
    if tick is None: return {"success": False, "error": f"Invalid Symbol: {symbol}"}

    order_type = mt5.ORDER_TYPE_BUY if direction == "BUY" else mt5.ORDER_TYPE_SELL
    price = tick.ask if direction == "BUY" else tick.bid

    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": lots,
        "type": order_type,
        "price": price,
        "magic": 202602,
        "comment": "HFTFX:SMARTLOCK",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    result = mt5.order_send(request)
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        return {"success": False, "error": f"Trade Failed: {result.comment}", "code": result.retcode}
    
    return {"success": True, "ticket": result.order}

def execute_close(payload):
    if not ensure_connection(): return {"success": False, "error": "MT5 Offline"}
    symbol = payload.get("symbol_mt5")
    positions = mt5.positions_get(symbol=symbol)
    
    if not positions: return {"success": False, "error": "No open positions for " + symbol}
    
    results = []
    for pos in positions:
        tick = mt5.symbol_info_tick(symbol)
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "position": pos.ticket,
            "volume": pos.volume,
            "type": mt5.ORDER_TYPE_SELL if pos.type == mt5.POSITION_TYPE_BUY else mt5.ORDER_TYPE_BUY,
            "price": tick.bid if pos.type == mt5.POSITION_TYPE_BUY else tick.ask,
            "magic": 202602,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        results.append(mt5.order_send(request).retcode)
    
    return {"success": True, "codes": results}

# ============================================
# ENDPOINTS
# ============================================
@app.route('/webhook', methods=['POST'])
def webhook():
    payload = request.get_json()
    action = payload.get("action")
    logger.info(f"Received Request: {action} for {payload.get('symbol_mt5')}")
    
    if action == "OPEN": return jsonify(execute_open(payload))
    if action == "CLOSE": return jsonify(execute_close(payload))
    return jsonify({"success": False, "error": "Invalid Action"})

@app.route('/status')
def status():
    conn = ensure_connection()
    return jsonify({"mt5_connected": conn, "timestamp": datetime.now().isoformat()})

@app.route('/')
def home():
    return "HFT Ultra FX Smart Lock 2026 - SERVER RUNNING"

# Connection Heartbeat to prevent Wine/MT5 timeout
def heartbeat():
    while True:
        try:
            if mt5_connected:
                mt5.account_info()
        except:
            pass
        time.sleep(30)

if __name__ == "__main__":
    # Start heartbeat
    threading.Thread(target=heartbeat, daemon=True).start()
    # Start Flask
    app.run(host=WEBHOOK_CONFIG["host"], port=WEBHOOK_CONFIG["port"])
