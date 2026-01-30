"""
MT5 Webhook Receiver for HFT Ultra FX Smart Lock 2026
Full version with 28 Forex Pairs + Top 20 Cryptos
"""

from mt5linux import MetaTrader5
from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import logging
import os
from datetime import datetime
import threading
import time

# Initialize Bridge
mt5 = MetaTrader5()

# ============================================
# CONFIGURATION
# ============================================
MT5_CONFIG = {
    "server": "ValetaxIntI-Live1",
    "login": 641086382,
    "password": "EJam123!@",
    "timeout": 10000,
    "portable": False
}

WEBHOOK_CONFIG = {
    "host": "0.0.0.0",
    "port": int(os.environ.get("PORT", 8080)),
    "secret_key": os.environ.get("WEBHOOK_SECRET", ""),
    "enable_trading": True,
    "max_slippage": 20,
}

# Added Top 20 Cryptos to your original 28 Forex Pairs
SYMBOL_MAP = {
    # Cryptos (Top 20)
    "BTCUSD": "BTCUSD", "ETHUSD": "ETHUSD", "SOLUSD": "SOLUSD", "XRPUSD": "XRPUSD",
    "ADAUSD": "ADAUSD", "AVAXUSD": "AVAXUSD", "DOTUSD": "DOTUSD", "LINKUSD": "LINKUSD",
    "DOGEUSD": "DOGEUSD", "MATICUSD": "MATICUSD", "LTCUSD": "LTCUSD", "BCHUSD": "BCHUSD",
    "SHIBUSD": "SHIBUSD", "TRXUSD": "TRXUSD", "UNIUSD": "UNIUSD", "ATOMUSD": "ATOMUSD",
    "XLMUSD": "XLMUSD", "NEARUSD": "NEARUSD", "ALGOUSD": "ALGOUSD", "ICPUSD": "ICPUSD",
    # Original Major Pairs
    "EURUSD": "EURUSD", "GBPUSD": "GBPUSD", "USDJPY": "USDJPY", "USDCHF": "USDCHF", 
    "AUDUSD": "AUDUSD", "USDCAD": "USDCAD", "NZDUSD": "NZDUSD",
    # Euro Crosses
    "EURGBP": "EURGBP", "EURJPY": "EURJPY", "EURCHF": "EURCHF", "EURAUD": "EURAUD", 
    "EURCAD": "EURCAD", "EURNZD": "EURNZD",
    # GBP Crosses
    "GBPJPY": "GBPJPY", "GBPCHF": "GBPCHF", "GBPAUD": "GBPAUD", "GBPCAD": "GBPCAD", "GBPNZD": "GBPNZD",
    # Other Crosses
    "AUDJPY": "AUDJPY", "AUDNZD": "AUDNZD", "AUDCAD": "AUDCAD", "AUDCHF": "AUDCHF", 
    "NZDJPY": "NZDJPY", "NZDCAD": "NZDCAD", "NZDCHF": "NZDCHF", "CADJPY": "CADJPY", "CADCHF": "CADCHF",
    # Metals
    "XAUUSD": "XAUUSD",
}

PIP_SIZES = {
    "USDJPY": 0.01, "EURJPY": 0.01, "GBPJPY": 0.01, "AUDJPY": 0.01, 
    "NZDJPY": 0.01, "CADJPY": 0.01, "XAUUSD": 0.01
}
DEFAULT_PIP_SIZE = 0.0001

# ============================================
# LOGGING SETUP
# ============================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

active_trades = {}
mt5_connected = False

# ============================================
# MT5 CONNECTION UTILITIES
# ============================================
def connect_mt5():
    global mt5_connected
    logger.info("Connecting to MetaTrader 5 via Bridge...")
    if not mt5.initialize():
        logger.error(f"MT5 initialize failed: {mt5.last_error()}")
        return False
    
    authorized = mt5.login(
        login=MT5_CONFIG["login"],
        password=MT5_CONFIG["password"],
        server=MT5_CONFIG["server"],
        timeout=MT5_CONFIG["timeout"]
    )
    
    if authorized:
        account_info = mt5.account_info()
        logger.info(f"Connected to Account: {account_info.login}")
        mt5_connected = True
        return True
    return False

def ensure_mt5_connection():
    global mt5_connected
    if not mt5_connected: return connect_mt5()
    if mt5.account_info() is None:
        return connect_mt5()
    return True

def get_broker_symbol(hft_symbol):
    broker_sym = SYMBOL_MAP.get(hft_symbol, hft_symbol)
    info = mt5.symbol_info(broker_sym)
    if info is None:
        # Check for suffixes like .i or .raw
        for suffix in [".i", "m", ".raw", ".ecn"]:
            if mt5.symbol_info(broker_sym + suffix):
                return broker_sym + suffix
    return broker_sym

# ============================================
# TRADE EXECUTION
# ============================================
def execute_open(payload):
    if not ensure_mt5_connection(): return {"success": False, "error": "MT5 Offline"}
    
    symbol = get_broker_symbol(payload.get("symbol_mt5"))
    direction = payload.get("direction")
    lots = payload.get("lot_size", 0.01)
    
    mt5.symbol_select(symbol, True)
    tick = mt5.symbol_info_tick(symbol)
    
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
        "type_filling": mt5.ORDER_FILLING_IOC,
    }
    
    result = mt5.order_send(request)
    return {"success": True, "ticket": result.order} if result.retcode == mt5.TRADE_RETCODE_DONE else {"success": False, "error": result.comment}

def execute_close(payload):
    if not ensure_mt5_connection(): return {"success": False, "error": "MT5 Offline"}
    symbol = get_broker_symbol(payload.get("symbol_mt5"))
    positions = mt5.positions_get(symbol=symbol)
    
    if not positions: return {"success": False, "error": "No position"}
    
    for pos in positions:
        tick = mt5.symbol_info_tick(symbol)
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "position": pos.ticket,
            "volume": pos.volume,
            "type": mt5.ORDER_TYPE_SELL if pos.type == 0 else mt5.ORDER_TYPE_BUY,
            "price": tick.bid if pos.type == 0 else tick.ask,
            "magic": 202602,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        mt5.order_send(request)
    return {"success": True}

# ============================================
# ENDPOINTS
# ============================================
@app.route('/webhook', methods=['POST'])
def webhook():
    try:
        payload = request.get_json()
        action = payload.get("action")
        if action == "OPEN": return jsonify(execute_open(payload))
        if action == "CLOSE": return jsonify(execute_close(payload))
        return jsonify({"success": True, "msg": "Action received"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/status')
def status():
    return jsonify({"mt5_connected": mt5_connected, "time": datetime.now().isoformat()})

@app.route('/')
def home():
    return "HFT Ultra FX Smart Lock 2026 - Active"

def heartbeat():
    while True:
        time.sleep(30)
        if mt5_connected: mt5.account_info()

if __name__ == "__main__":
    if connect_mt5():
        threading.Thread(target=heartbeat, daemon=True).start()
    app.run(host=WEBHOOK_CONFIG["host"], port=WEBHOOK_CONFIG["port"])

