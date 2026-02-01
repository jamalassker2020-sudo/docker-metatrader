"""
MT5 Webhook Receiver for HFT Ultra FX Smart Lock 2026
Fixed Port version to avoid Railway Conflict
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

# We force Port 5000 here
WEBHOOK_PORT = 5000

SYMBOL_MAP = {
    "BTCUSD": "BTCUSD", "ETHUSD": "ETHUSD", "SOLUSD": "SOLUSD", "XRPUSD": "XRPUSD",
    "EURUSD": "EURUSD", "GBPUSD": "GBPUSD", "USDJPY": "USDJPY", "XAUUSD": "XAUUSD"
}

logging.basicConfig(level=logging.INFO, format='%(asctime)s | %(levelname)s | %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

mt5 = None
mt5_connected = False

def init_mt5():
    global mt5, mt5_connected
    try:
        if mt5 is None:
            mt5 = MetaTrader5(host='localhost', port=18812)
        if not mt5.initialize():
            return False
        authorized = mt5.login(login=MT5_CONFIG["login"], password=MT5_CONFIG["password"], server=MT5_CONFIG["server"])
        if authorized:
            mt5_connected = True
            return True
        return False
    except Exception as e:
        logger.error(f"Bridge error: {e}")
        return False

def ensure_connection():
    global mt5_connected
    if not mt5_connected or mt5 is None or mt5.account_info() is None:
        return init_mt5()
    return True

@app.route('/webhook', methods=['POST'])
def webhook():
    payload = request.get_json()
    action = payload.get("action")
    if action == "OPEN":
        if not ensure_connection(): return jsonify({"success": False, "error": "MT5 Offline"})
        # ... (rest of your trade logic remains the same)
    return jsonify({"success": True})

@app.route('/status')
def status():
    conn = ensure_connection()
    return jsonify({"mt5_connected": conn, "timestamp": datetime.now().isoformat()})

@app.route('/')
def home():
    return "HFT Webhook Active on Port 5000"

if __name__ == "__main__":
    # Internal port 5000
    app.run(host="0.0.0.0", port=WEBHOOK_PORT)
