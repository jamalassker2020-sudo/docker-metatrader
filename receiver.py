import os
from flask import Flask, request, jsonify
from mt5linux import MetaTrader5
import logging

# --- CREDENTIALS FROM YOUR SPEC ---
MT5_LOGIN = 641086382
MT5_PASS = "EJam123!@"
MT5_SERVER = "ValetaxIntI-Live3" # Valetax Alive

app = Flask(__name__)
mt5 = MetaTrader5(host="localhost", port=18812)

# --- YOUR SYMBOL MAPPING (From your JSON) ---
SYMBOL_MAP = {
    "EUR/USD": "EURUSD", "GBP/USD": "GBPUSD", "USD/JPY": "USDJPY",
    "USD/CHF": "USDCHF", "AUD/USD": "AUDUSD", "USD/CAD": "USDCAD",
    "NZD/USD": "NZDUSD", "XAU/USD": "XAUUSD" 
    # The code below handles the rest automatically by removing the "/"
}

@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.json
    
    # 1. Initialize & Login
    if not mt5.initialize():
        mt5.login(login=MT5_LOGIN, password=MT5_PASS, server=MT5_SERVER)

    # 2. Extract Data based on your JSON Spec
    action = data.get("action") # OPEN, CLOSE, etc.
    source_sym = data.get("symbol")
    mt5_sym = data.get("symbol_mt5") or SYMBOL_MAP.get(source_sym, source_sym.replace("/", ""))
    
    # 3. Logic for OPEN
    if action == "OPEN":
        direction = data.get("direction")
        order_type = mt5.ORDER_TYPE_BUY if direction == "BUY" else mt5.ORDER_TYPE_SELL
        
        # Get current price
        tick = mt5.symbol_info_tick(mt5_sym)
        price = tick.ask if direction == "BUY" else tick.bid

        request_dict = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": mt5_sym,
            "volume": float(data.get("lot_size", 0.01)),
            "type": order_type,
            "price": price,
            "sl": float(data.get("stop_loss", 0)),
            "tp": float(data.get("take_profit", 0)),
            "magic": 202602, # Your Magic Number
            "comment": f"HFTFX:{data.get('trade_id', 'MANUAL')}",
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        
        result = mt5.order_send(request_dict)
        return jsonify({"status": "success", "retcode": result.retcode})

    return jsonify({"status": "ignored", "action": action})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)
