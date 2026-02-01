import os, logging, time, threading
from flask import Flask, request, jsonify
from flask_cors import CORS
from mt5linux import MetaTrader5

# --- ACCOUNT CONFIG ---
MT5_CONFIG = {
    "server": "ValetaxIntI-Live1", # Fixed based on your requirement
    "login": 641086382,
    "password": "EJam123!@",
}

app = Flask(__name__)
CORS(app)
mt5 = MetaTrader5(host="localhost", port=18812)

# --- HFT STRATEGY CONSTANTS (Mimicking your HTML) ---
C = {
    "tp_pips": 15,
    "sl_pips": 5,
    "be_trigger": 3,      # Move to Break-even at 3 pips
    "trail_start": 5,     # Start trailing at 5 pips
    "magic": 202602,
    "lot": 0.01           # Default lot size
}

@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.json
    if not mt5.initialize(): 
        mt5.login(**MT5_CONFIG)
    
    symbol = data.get("symbol_mt5", "EURUSD")
    action = data.get("action") # "OPEN" or "CLOSE"
    direction = data.get("direction") # "BUY" or "SELL"

    # 1. HANDLE CLOSING
    if action == "CLOSE":
        # Logic to find and close all positions for this symbol
        positions = mt5.positions_get(symbol=symbol)
        for p in positions:
            tick = mt5.symbol_info_tick(symbol)
            mt5.order_send({
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "position": p.ticket,
                "type": mt5.ORDER_TYPE_SELL if p.type == 0 else mt5.ORDER_TYPE_BUY,
                "volume": p.volume,
                "price": tick.bid if p.type == 0 else tick.ask,
                "magic": C["magic"],
                "type_filling": mt5.ORDER_FILLING_IOC,
            })
        return jsonify({"status": "closed"})

    # 2. HANDLE OPENING (With Smart SL/TP)
    mt5.symbol_select(symbol, True)
    tick = mt5.symbol_info_tick(symbol)
    point = mt5.symbol_info(symbol).point
    
    order_type = mt5.ORDER_TYPE_BUY if direction == "BUY" else mt5.ORDER_TYPE_SELL
    price = tick.ask if order_type == mt5.ORDER_TYPE_BUY else tick.bid
    
    # Calculate SL and TP based on Pips
    sl = price - (C["sl_pips"] * 10 * point) if direction == "BUY" else price + (C["sl_pips"] * 10 * point)
    tp = price + (C["tp_pips"] * 10 * point) if direction == "BUY" else price - (C["tp_pips"] * 10 * point)

    request_dict = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": C["lot"],
        "type": order_type,
        "price": price,
        "sl": sl,
        "tp": tp,
        "magic": C["magic"],
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    result = mt5.order_send(request_dict)
    return jsonify({"retcode": result.retcode, "id": getattr(result, 'order', 0)})

# --- BACKGROUND MONITOR (The Smart Profit Lock) ---
def profit_protector():
    """Mimics the HTML Break-even and Trailing Logic every 1 second"""
    while True:
        try:
            if mt5.initialize():
                positions = mt5.positions_get()
                for p in positions:
                    symbol = p.symbol
                    point = mt5.symbol_info(symbol).point
                    current_price = mt5.symbol_info_tick(symbol).bid if p.type == 0 else mt5.symbol_info_tick(symbol).ask
                    
                    # Calculate Profit in Pips
                    pips = (current_price - p.price_open) / (point * 10) if p.type == 0 else (p.price_open - current_price) / (point * 10)

                    # A. BREAK-EVEN LOCK (Trigger at 3 pips)
                    if pips >= C["be_trigger"] and p.sl != p.price_open:
                        mt5.order_modify(p.ticket, sl=p.price_open, tp=p.tp)
                        logging.info(f"Break-even locked for {symbol}")

                    # B. TIERED TRAILING (Start at 5 pips)
                    if pips >= C["trail_start"]:
                        new_sl = current_price - (2 * 10 * point) if p.type == 0 else current_price + (2 * 10 * point)
                        # Only move SL up, never down
                        if (p.type == 0 and new_sl > p.sl) or (p.type == 1 and new_sl < p.sl):
                            mt5.order_modify(p.ticket, sl=new_sl, tp=p.tp)
        except Exception as e:
            print(f"Protector error: {e}")
        time.sleep(1)

threading.Thread(target=profit_protector, daemon=True).start()
app.run(host="0.0.0.0", port=8081)
