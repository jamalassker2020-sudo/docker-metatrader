"""
MT5 Webhook Receiver for HFT Ultra FX Smart Lock 2026
======================================================
Receives FOREX trading signals via HTTP webhook and executes trades on MetaTrader 5
"""

from mt5linux import MetaTrader5
mt5 = MetaTrader5()

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import logging
import os
from datetime import datetime
import threading
import time

# ============================================
# CONFIGURATION
# ============================================

MT5_CONFIG = {
    "server": os.environ.get("MT5_SERVER", "ValetaxIntI-Live1"),
    "login": int(os.environ.get("MT5_LOGIN", "641086382")),
    "password": os.environ.get("MT5_PASSWORD", "EJam123!@"),
    "timeout": 10000,
    "portable": True   # ✅ REQUIRED FOR /portable MT5
}

WEBHOOK_CONFIG = {
    "host": "0.0.0.0",
    "port": int(os.environ.get("PORT", 8080)),
    "secret_key": os.environ.get("WEBHOOK_SECRET", ""),
    "enable_trading": True,
    "max_slippage": 20,
}

SYMBOL_MAP = {
    "EURUSD": "EURUSD",
    "GBPUSD": "GBPUSD",
    "USDJPY": "USDJPY",
    "USDCHF": "USDCHF",
    "AUDUSD": "AUDUSD",
    "USDCAD": "USDCAD",
    "NZDUSD": "NZDUSD",
    "EURGBP": "EURGBP",
    "EURJPY": "EURJPY",
    "EURCHF": "EURCHF",
    "EURAUD": "EURAUD",
    "EURCAD": "EURCAD",
    "EURNZD": "EURNZD",
    "GBPJPY": "GBPJPY",
    "GBPCHF": "GBPCHF",
    "GBPAUD": "GBPAUD",
    "GBPCAD": "GBPCAD",
    "GBPNZD": "GBPNZD",
    "AUDJPY": "AUDJPY",
    "AUDNZD": "AUDNZD",
    "AUDCAD": "AUDCAD",
    "AUDCHF": "AUDCHF",
    "NZDJPY": "NZDJPY",
    "NZDCAD": "NZDCAD",
    "NZDCHF": "NZDCHF",
    "CADJPY": "CADJPY",
    "CADCHF": "CADCHF",
    "XAUUSD": "XAUUSD",
}

PIP_SIZES = {
    "USDJPY": 0.01,
    "EURJPY": 0.01,
    "GBPJPY": 0.01,
    "AUDJPY": 0.01,
    "NZDJPY": 0.01,
    "CADJPY": 0.01,
    "XAUUSD": 0.01,
}

DEFAULT_PIP_SIZE = 0.0001

# ============================================
# LOGGING (STDOUT SAFE FOR RAILWAY)
# ============================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================
# FLASK APP
# ============================================

app = Flask(__name__)
CORS(app)

active_trades = {}
mt5_connected = False

# ============================================
# MT5 CONNECTION (mt5linux-CORRECT)
# ============================================

def connect_mt5():
    global mt5_connected

    logger.info("Connecting to MT5 terminal...")

    if not mt5.initialize():
        logger.error(f"MT5 initialize failed: {mt5.last_error()}")
        return False

    # ⚠️ mt5linux DOES NOT LOGIN VIA API
    # Terminal MUST already be logged in via GUI

    if not wait_for_terminal():
        logger.error("MT5 terminal not ready")
        return False

    mt5_connected = True
    acc = mt5.account_info()

    if acc:
        logger.info(f"Connected: {acc.login} | Balance: {acc.balance}")

    return True

def wait_for_terminal():
    for _ in range(90):
        acc = mt5.account_info()
        if acc:
            return True
        time.sleep(2)
    return False

def ensure_mt5_connection():
    global mt5_connected
    if not mt5_connected:
        return connect_mt5()
    if mt5.account_info() is None:
        mt5_connected = False
        return connect_mt5()
    return True

# ============================================
# SYMBOL UTILITIES
# ============================================

def get_broker_symbol(symbol):
    variations = [
        symbol, symbol + ".i", symbol + "m",
        symbol + ".raw", symbol + ".ecn",
        symbol.lower()
    ]
    for s in variations:
        info = mt5.symbol_info(s)
        if info:
            mt5.symbol_select(s, True)
            time.sleep(0.3)
            return s
    return None

def get_symbol_info(symbol):
    info = mt5.symbol_info(symbol)
    if info and not info.visible:
        mt5.symbol_select(symbol, True)
        time.sleep(0.3)
    return info

# ============================================
# TRADE EXECUTION
# ============================================

def execute_open(payload):
    if not WEBHOOK_CONFIG["enable_trading"]:
        return {"success": True, "simulated": True}

    if not ensure_mt5_connection():
        return {"success": False, "error": "MT5 not connected"}

    trade_id = payload.get("trade_id")
    symbol = get_broker_symbol(payload.get("symbol_mt5"))
    direction = payload.get("direction")
    lot = payload.get("lot_size", 0.01)
    sl = payload.get("stop_loss")
    tp = payload.get("take_profit")

    if not symbol:
        return {"success": False, "error": "Symbol not found"}

    info = get_symbol_info(symbol)
    tick = mt5.symbol_info_tick(symbol)

    if not tick:
        return {"success": False, "error": "No price feed"}

    order_type = mt5.ORDER_TYPE_BUY if direction == "BUY" else mt5.ORDER_TYPE_SELL
    price = tick.ask if direction == "BUY" else tick.bid

    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": lot,
        "type": order_type,
        "price": price,
        "deviation": WEBHOOK_CONFIG["max_slippage"],
        "magic": 202602,
        "comment": f"HFTFX:{trade_id}",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_RETURN,  # ✅ FIXED
    }

    if sl: request["sl"] = round(sl, info.digits)
    if tp: request["tp"] = round(tp, info.digits)

    result = mt5.order_send(request)

    if not result or result.retcode != mt5.TRADE_RETCODE_DONE:
        return {"success": False, "error": str(result.retcode if result else "SEND_FAIL")}

    active_trades[trade_id] = result.order

    return {"success": True, "ticket": result.order}

def execute_close(payload):
    if not ensure_mt5_connection():
        return {"success": False, "error": "MT5 not connected"}

    trade_id = payload.get("trade_id")
    symbol = get_broker_symbol(payload.get("symbol_mt5"))
    direction = payload.get("direction")

    positions = mt5.positions_get(symbol=symbol)
    if not positions:
        return {"success": False, "error": "No position"}

    position = None
    for p in positions:
        if p.magic == 202602 and trade_id in (p.comment or ""):
            position = p
            break

    if not position:
        return {"success": False, "error": "Matching trade not found"}

    tick = mt5.symbol_info_tick(symbol)
    close_type = mt5.ORDER_TYPE_SELL if position.type == mt5.POSITION_TYPE_BUY else mt5.ORDER_TYPE_BUY
    close_price = tick.bid if close_type == mt5.ORDER_TYPE_SELL else tick.ask

    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "position": position.ticket,
        "volume": position.volume,
        "type": close_type,
        "price": close_price,
        "deviation": WEBHOOK_CONFIG["max_slippage"],
        "magic": 202602,
        "comment": "CLOSE"
    }

    result = mt5.order_send(request)

    if not result or result.retcode != mt5.TRADE_RETCODE_DONE:
        return {"success": False, "error": "Close failed"}

    active_trades.pop(trade_id, None)
    return {"success": True}

# ============================================
# WEBHOOK ROUTES (UNCHANGED)
# ============================================

@app.route('/webhook', methods=['POST'])
def webhook():
    payload = request.get_json()
    action = payload.get("action")

    if action == "OPEN":
        return jsonify(execute_open(payload))
    if action == "CLOSE":
        return jsonify(execute_close(payload))

    return jsonify({"success": False, "error": "Unknown action"})

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

# ============================================
# MAIN
# ============================================

def heartbeat():
    while True:
        time.sleep(30)
        ensure_mt5_connection()

if __name__ == '__main__':
    connect_mt5()
    threading.Thread(target=heartbeat, daemon=True).start()

    app.run(
        host=WEBHOOK_CONFIG["host"],
        port=WEBHOOK_CONFIG["port"],
        debug=False,
        threaded=True
    )
        print("1. Make sure MetaTrader 5 is installed and running")
        print("2. Enable 'Allow algorithmic trading' in MT5 settings")
        print("3. Verify your login credentials in MT5_CONFIG")
        print("4. Check if the server name is correct")
        print("\n💡 Starting webhook server anyway for testing...")
        
        # Start server even without MT5 for testing
        app.run(
            host=WEBHOOK_CONFIG["host"],
            port=port,
            debug=False,
            threaded=True
        )

