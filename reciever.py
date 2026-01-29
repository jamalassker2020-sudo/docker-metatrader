
"""
MT5 Webhook Receiver for HFT Ultra FX Smart Lock 2026
======================================================
Receives FOREX trading signals via HTTP webhook and executes trades on MetaTrader 5

SUPPORTED PAIRS (28 Total):
- Major Pairs: EUR/USD, GBP/USD, USD/JPY, USD/CHF, AUD/USD, USD/CAD, NZD/USD
- Euro Crosses: EUR/GBP, EUR/JPY, EUR/CHF, EUR/AUD, EUR/CAD, EUR/NZD
- GBP Crosses: GBP/JPY, GBP/CHF, GBP/AUD, GBP/CAD, GBP/NZD
- Other Crosses: AUD/JPY, AUD/NZD, AUD/CAD, AUD/CHF, NZD/JPY, NZD/CAD, NZD/CHF, CAD/JPY, CAD/CHF
- Metals: XAU/USD

SETUP FOR RAILWAY + noVNC:
1. Install dependencies: pip install flask flask-cors metatrader5 pytz
2. Update MT5_CONFIG credentials below
3. Set PORT environment variable in Railway (default: 8080)
4. Run: python mt5_webhook_receiver.py
5. Configure webhook URL in HFT Ultra FX: https://YOUR-APP.railway.app/webhook

Author: HFT Ultra FX Smart Lock 2026
Version: 2.0
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
# CONFIGURATION - UPDATE THESE VALUES
# ============================================

MT5_CONFIG = {
    "server": "YourBroker-Server",      # e.g., "ICMarkets-Demo", "Exness-MT5Real"
    "login": 12345678,                   # Your MT5 account number
    "password": "YourPassword",          # Your MT5 password
    "timeout": 10000,
    "portable": False
}

# Use environment variable for port (Railway sets this automatically)
# Default to 8080 to avoid collision with other services
WEBHOOK_CONFIG = {
    "host": "0.0.0.0",
    "port": int(os.environ.get("PORT", 8080)),  # Railway uses PORT env var
    "secret_key": os.environ.get("WEBHOOK_SECRET", ""),  # Optional: set in Railway env
    "enable_trading": True,
    "max_slippage": 20,
}

# Symbol mapping: HFT Ultra FX symbol -> Your broker's symbol
# Adjust these based on your broker's naming convention
SYMBOL_MAP = {
    # Major Pairs
    "EURUSD": "EURUSD",
    "GBPUSD": "GBPUSD",
    "USDJPY": "USDJPY",
    "USDCHF": "USDCHF",
    "AUDUSD": "AUDUSD",
    "USDCAD": "USDCAD",
    "NZDUSD": "NZDUSD",
    # Euro Crosses
    "EURGBP": "EURGBP",
    "EURJPY": "EURJPY",
    "EURCHF": "EURCHF",
    "EURAUD": "EURAUD",
    "EURCAD": "EURCAD",
    "EURNZD": "EURNZD",
    # GBP Crosses
    "GBPJPY": "GBPJPY",
    "GBPCHF": "GBPCHF",
    "GBPAUD": "GBPAUD",
    "GBPCAD": "GBPCAD",
    "GBPNZD": "GBPNZD",
    # Other Crosses
    "AUDJPY": "AUDJPY",
    "AUDNZD": "AUDNZD",
    "AUDCAD": "AUDCAD",
    "AUDCHF": "AUDCHF",
    "NZDJPY": "NZDJPY",
    "NZDCAD": "NZDCAD",
    "NZDCHF": "NZDCHF",
    "CADJPY": "CADJPY",
    "CADCHF": "CADCHF",
    # Metals
    "XAUUSD": "XAUUSD",
}

# Pip sizes for different pair types
PIP_SIZES = {
    # JPY pairs use 0.01
    "USDJPY": 0.01,
    "EURJPY": 0.01,
    "GBPJPY": 0.01,
    "AUDJPY": 0.01,
    "NZDJPY": 0.01,
    "CADJPY": 0.01,
    # Gold
    "XAUUSD": 0.01,
    # All other pairs default to 0.0001
}

DEFAULT_PIP_SIZE = 0.0001

# ============================================
# LOGGING SETUP
# ============================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s',
    handlers=[
        logging.FileHandler('mt5_webhook_fx.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ============================================
# FLASK APP
# ============================================

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# Track active trades by trade_id
active_trades = {}
mt5_connected = False

# ============================================
# MT5 CONNECTION
# ============================================

def connect_mt5():
    """Initialize and connect to MetaTrader 5"""
    global mt5_connected
    
    logger.info("Connecting to MetaTrader 5...")
    
    if not mt5.initialize():
        logger.error(f"MT5 initialize() failed: {mt5.last_error()}")
        return False
    
    authorized = mt5.login(
        login=MT5_CONFIG["login"],
        password=MT5_CONFIG["password"],
        server=MT5_CONFIG["server"],
        timeout=MT5_CONFIG["timeout"]
    )
    
    if not authorized:
        logger.error(f"MT5 login failed: {mt5.last_error()}")
        mt5.shutdown()
        return False
    
    account_info = mt5.account_info()
    if account_info:
        logger.info(f"Connected to MT5")
        logger.info(f"   Account: {account_info.login}")
        logger.info(f"   Server: {account_info.server}")
        logger.info(f"   Balance: ${account_info.balance:.2f}")
        logger.info(f"   Equity: ${account_info.equity:.2f}")
        logger.info(f"   Leverage: 1:{account_info.leverage}")
        mt5_connected = True
        return True
    
    return False

def disconnect_mt5():
    """Disconnect from MetaTrader 5"""
    global mt5_connected
    mt5.shutdown()
    mt5_connected = False
    logger.info("Disconnected from MT5")

def ensure_mt5_connection():
    """Ensure MT5 is connected, reconnect if needed"""
    global mt5_connected
    
    if not mt5_connected:
        return connect_mt5()
    
    account = mt5.account_info()
    if account is None:
        logger.warning("MT5 connection lost, reconnecting...")
        return connect_mt5()
    
    return True

# ============================================
# SYMBOL UTILITIES
# ============================================

def get_pip_size(symbol):
    """Get pip size for a symbol"""
    return PIP_SIZES.get(symbol, DEFAULT_PIP_SIZE)

def get_broker_symbol(hft_symbol):
    """Map HFT Ultra FX symbol to broker symbol"""
    if hft_symbol in SYMBOL_MAP:
        broker_sym = SYMBOL_MAP[hft_symbol]
    else:
        broker_sym = hft_symbol
    
    symbol_info = mt5.symbol_info(broker_sym)
    if symbol_info is None:
        # Try common variations
        variations = [
            broker_sym,
            broker_sym + ".i",
            broker_sym + "m",
            broker_sym + ".raw",
            broker_sym + ".ecn",
            broker_sym + ".pro",
            broker_sym + "_",
            broker_sym.lower(),
        ]
        for var in variations:
            info = mt5.symbol_info(var)
            if info is not None:
                logger.info(f"Symbol mapped: {hft_symbol} -> {var}")
                return var
        
        logger.error(f"Symbol not found: {hft_symbol}")
        return None
    
    return broker_sym

def get_symbol_info(symbol):
    """Get symbol trading info"""
    info = mt5.symbol_info(symbol)
    if info is None:
        return None
    
    if not info.visible:
        mt5.symbol_select(symbol, True)
    
    return info

# ============================================
# TRADE EXECUTION
# ============================================

def execute_open(payload):
    """Execute OPEN trade from webhook signal"""
    
    if not WEBHOOK_CONFIG["enable_trading"]:
        logger.info("Trading disabled - simulating OPEN")
        return {"success": True, "simulated": True, "trade_id": payload.get("trade_id")}
    
    if not ensure_mt5_connection():
        return {"success": False, "error": "MT5 not connected"}
    
    trade_id = payload.get("trade_id")
    symbol_mt5 = payload.get("symbol_mt5")
    direction = payload.get("direction")
    lot_size = payload.get("lot_size", 0.01)
    tp = payload.get("take_profit")
    sl = payload.get("stop_loss")
    
    broker_symbol = get_broker_symbol(symbol_mt5)
    if not broker_symbol:
        return {"success": False, "error": f"Symbol not found: {symbol_mt5}"}
    
    symbol_info = get_symbol_info(broker_symbol)
    if not symbol_info:
        return {"success": False, "error": f"Cannot get symbol info: {broker_symbol}"}
    
    # Normalize lot size
    lot_min = symbol_info.volume_min
    lot_max = symbol_info.volume_max
    lot_step = symbol_info.volume_step
    
    lot_size = max(lot_min, min(lot_max, round(lot_size / lot_step) * lot_step))
    
    tick = mt5.symbol_info_tick(broker_symbol)
    if not tick:
        return {"success": False, "error": "Cannot get price"}
    
    if direction == "BUY":
        order_type = mt5.ORDER_TYPE_BUY
        price = tick.ask
    else:
        order_type = mt5.ORDER_TYPE_SELL
        price = tick.bid
    
    digits = symbol_info.digits
    
    if tp:
        tp = round(tp, digits)
    if sl:
        sl = round(sl, digits)
    
    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": broker_symbol,
        "volume": lot_size,
        "type": order_type,
        "price": price,
        "deviation": WEBHOOK_CONFIG["max_slippage"],
        "magic": 202602,  # Magic number for Smart Lock version
        "comment": f"HFTFX:{trade_id[:10] if trade_id else 'SIGNAL'}",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }
    
    if tp and tp > 0:
        request["tp"] = tp
    if sl and sl > 0:
        request["sl"] = sl
    
    logger.info(f"Sending order: {direction} {lot_size} {broker_symbol} @ {price}")
    
    result = mt5.order_send(request)
    
    if result is None:
        error = mt5.last_error()
        logger.error(f"Order failed: {error}")
        return {"success": False, "error": str(error)}
    
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        logger.error(f"Order rejected: {result.retcode} - {result.comment}")
        return {"success": False, "error": result.comment, "retcode": result.retcode}
    
    active_trades[trade_id] = {
        "ticket": result.order,
        "position": result.order,
        "symbol": broker_symbol,
        "direction": direction,
        "volume": lot_size,
        "open_price": result.price,
        "time": datetime.now().isoformat()
    }
    
    logger.info(f"Order filled: Ticket #{result.order} @ {result.price}")
    
    return {
        "success": True,
        "ticket": result.order,
        "price": result.price,
        "volume": result.volume,
        "trade_id": trade_id
    }

def execute_close(payload):
    """Execute CLOSE trade from webhook signal"""
    
    if not WEBHOOK_CONFIG["enable_trading"]:
        logger.info("Trading disabled - simulating CLOSE")
        return {"success": True, "simulated": True, "trade_id": payload.get("trade_id")}
    
    if not ensure_mt5_connection():
        return {"success": False, "error": "MT5 not connected"}
    
    trade_id = payload.get("trade_id")
    symbol_mt5 = payload.get("symbol_mt5")
    direction = payload.get("direction")
    exit_reason = payload.get("exit_reason", "SIGNAL")
    
    if trade_id in active_trades:
        trade_info = active_trades[trade_id]
        broker_symbol = trade_info["symbol"]
    else:
        broker_symbol = get_broker_symbol(symbol_mt5)
        if not broker_symbol:
            return {"success": False, "error": f"Symbol not found: {symbol_mt5}"}
    
    positions = mt5.positions_get(symbol=broker_symbol)
    
    if not positions:
        logger.warning(f"No open positions found for {broker_symbol}")
        return {"success": False, "error": "No position to close"}
    
    target_type = mt5.POSITION_TYPE_BUY if direction == "BUY" else mt5.POSITION_TYPE_SELL
    position = None
    
    # First try to find our own trades by magic number
    for pos in positions:
        if pos.type == target_type:
            if pos.magic == 202602 or "HFTFX" in (pos.comment or ""):
                position = pos
                break
    
    # Fallback to any matching position
    if not position:
        for pos in positions:
            if pos.type == target_type:
                position = pos
                break
    
    if not position:
        logger.warning(f"No matching {direction} position for {broker_symbol}")
        return {"success": False, "error": "No matching position"}
    
    tick = mt5.symbol_info_tick(broker_symbol)
    
    if not tick:
        return {"success": False, "error": "Cannot get price"}
    
    if position.type == mt5.POSITION_TYPE_BUY:
        close_type = mt5.ORDER_TYPE_SELL
        close_price = tick.bid
    else:
        close_type = mt5.ORDER_TYPE_BUY
        close_price = tick.ask
    
    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": broker_symbol,
        "volume": position.volume,
        "type": close_type,
        "position": position.ticket,
        "price": close_price,
        "deviation": WEBHOOK_CONFIG["max_slippage"],
        "magic": 202602,
        "comment": f"CLOSE:{exit_reason}",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }
    
    logger.info(f"Closing position #{position.ticket}: {position.volume} {broker_symbol} ({exit_reason})")
    
    result = mt5.order_send(request)
    
    if result is None:
        error = mt5.last_error()
        logger.error(f"Close failed: {error}")
        return {"success": False, "error": str(error)}
    
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        logger.error(f"Close rejected: {result.retcode} - {result.comment}")
        return {"success": False, "error": result.comment, "retcode": result.retcode}
    
    pnl = position.profit
    
    if trade_id in active_trades:
        del active_trades[trade_id]
    
    logger.info(f"Position closed: #{position.ticket} P&L: ${pnl:.2f} Reason: {exit_reason}")
    
    return {
        "success": True,
        "ticket": result.order,
        "closed_ticket": position.ticket,
        "price": result.price,
        "pnl": pnl,
        "reason": exit_reason,
        "trade_id": trade_id
    }

def modify_position(payload):
    """Modify SL/TP of existing position (for trailing stops)"""
    
    if not WEBHOOK_CONFIG["enable_trading"]:
        return {"success": True, "simulated": True}
    
    if not ensure_mt5_connection():
        return {"success": False, "error": "MT5 not connected"}
    
    trade_id = payload.get("trade_id")
    symbol_mt5 = payload.get("symbol_mt5")
    new_sl = payload.get("stop_loss")
    new_tp = payload.get("take_profit")
    
    broker_symbol = get_broker_symbol(symbol_mt5)
    if not broker_symbol:
        return {"success": False, "error": f"Symbol not found: {symbol_mt5}"}
    
    positions = mt5.positions_get(symbol=broker_symbol)
    if not positions:
        return {"success": False, "error": "No position to modify"}
    
    # Find the position
    position = None
    for pos in positions:
        if pos.magic == 202602 or "HFTFX" in (pos.comment or ""):
            position = pos
            break
    
    if not position:
        position = positions[0]
    
    symbol_info = get_symbol_info(broker_symbol)
    digits = symbol_info.digits if symbol_info else 5
    
    request = {
        "action": mt5.TRADE_ACTION_SLTP,
        "symbol": broker_symbol,
        "position": position.ticket,
        "sl": round(new_sl, digits) if new_sl else position.sl,
        "tp": round(new_tp, digits) if new_tp else position.tp,
    }
    
    result = mt5.order_send(request)
    
    if result and result.retcode == mt5.TRADE_RETCODE_DONE:
        logger.info(f"Position modified: #{position.ticket} SL={new_sl} TP={new_tp}")
        return {"success": True, "ticket": position.ticket}
    
    return {"success": False, "error": "Modify failed"}

# ============================================
# WEBHOOK ENDPOINTS
# ============================================

@app.route('/webhook', methods=['POST', 'OPTIONS'])
def webhook():
    """Main webhook endpoint for trading signals"""
    
    if request.method == 'OPTIONS':
        response = jsonify({"status": "ok"})
        response.headers.add('Access-Control-Allow-Origin', '*')
        response.headers.add('Access-Control-Allow-Headers', '*')
        response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS')
        return response, 204
    
    try:
        payload = request.get_json()
        
        if not payload:
            return jsonify({"success": False, "error": "No JSON payload"}), 400
        
        action = payload.get("action")
        source = payload.get("source")
        
        logger.info(f"Received {action} signal from {source}")
        logger.debug(f"Payload: {json.dumps(payload, indent=2)}")
        
        # Accept both old and new source identifiers
        valid_sources = ["HFT-ULTRA-FX-SMARTLOCK-2026", "HFT-ULTRA-FX-2026", "HFT-ULTRA-2026"]
        if source not in valid_sources:
            logger.warning(f"Unknown source: {source}")
            return jsonify({"success": False, "error": "Unknown source"}), 403
        
        # Authentication check
        if WEBHOOK_CONFIG["secret_key"]:
            auth = payload.get("auth", {})
            if auth.get("secret") != WEBHOOK_CONFIG["secret_key"]:
                logger.warning("Invalid authentication")
                return jsonify({"success": False, "error": "Auth failed"}), 403
        
        if action == "TEST":
            logger.info("Test connection successful")
            return jsonify({
                "success": True,
                "message": "MT5 FX Webhook receiver is running (Smart Lock 2026)",
                "mt5_connected": mt5_connected,
                "supported_pairs": list(SYMBOL_MAP.keys()),
                "port": WEBHOOK_CONFIG["port"],
                "timestamp": datetime.now().isoformat()
            })
        
        elif action == "OPEN":
            result = execute_open(payload)
            return jsonify(result)
        
        elif action == "CLOSE":
            result = execute_close(payload)
            return jsonify(result)
        
        elif action == "MODIFY":
            result = modify_position(payload)
            return jsonify(result)
        
        else:
            return jsonify({"success": False, "error": f"Unknown action: {action}"}), 400
    
    except Exception as e:
        logger.error(f"Webhook error: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/status', methods=['GET'])
def status():
    """Health check endpoint"""
    account = None
    if mt5_connected:
        acc = mt5.account_info()
        if acc:
            account = {
                "login": acc.login,
                "server": acc.server,
                "balance": acc.balance,
                "equity": acc.equity,
                "margin": acc.margin,
                "free_margin": acc.margin_free,
                "positions": len(mt5.positions_get() or [])
            }
    
    return jsonify({
        "status": "running",
        "version": "2.0",
        "name": "HFT Ultra FX Smart Lock 2026",
        "mt5_connected": mt5_connected,
        "account": account,
        "active_trades": len(active_trades),
        "trading_enabled": WEBHOOK_CONFIG["enable_trading"],
        "port": WEBHOOK_CONFIG["port"],
        "supported_pairs": list(SYMBOL_MAP.keys()),
        "timestamp": datetime.now().isoformat()
    })

@app.route('/positions', methods=['GET'])
def positions():
    """Get current open positions"""
    if not ensure_mt5_connection():
        return jsonify({"success": False, "error": "MT5 not connected"})
    
    positions = mt5.positions_get()
    if not positions:
        return jsonify({"success": True, "positions": []})
    
    pos_list = []
    for pos in positions:
        pos_list.append({
            "ticket": pos.ticket,
            "symbol": pos.symbol,
            "type": "BUY" if pos.type == 0 else "SELL",
            "volume": pos.volume,
            "price_open": pos.price_open,
            "price_current": pos.price_current,
            "sl": pos.sl,
            "tp": pos.tp,
            "profit": pos.profit,
            "magic": pos.magic,
            "comment": pos.comment,
            "is_hft": pos.magic == 202602 or "HFTFX" in (pos.comment or "")
        })
    
    return jsonify({"success": True, "positions": pos_list})

@app.route('/symbols', methods=['GET'])
def symbols():
    """Get supported forex symbols"""
    return jsonify({
        "success": True,
        "symbols": SYMBOL_MAP,
        "pip_sizes": PIP_SIZES,
        "default_pip_size": DEFAULT_PIP_SIZE,
        "total_pairs": len(SYMBOL_MAP)
    })

@app.route('/account', methods=['GET'])
def account():
    """Get account information"""
    if not ensure_mt5_connection():
        return jsonify({"success": False, "error": "MT5 not connected"})
    
    acc = mt5.account_info()
    if not acc:
        return jsonify({"success": False, "error": "Cannot get account info"})
    
    return jsonify({
        "success": True,
        "account": {
            "login": acc.login,
            "server": acc.server,
            "name": acc.name,
            "currency": acc.currency,
            "balance": acc.balance,
            "equity": acc.equity,
            "margin": acc.margin,
            "free_margin": acc.margin_free,
            "margin_level": acc.margin_level,
            "leverage": acc.leverage,
            "profit": acc.profit
        }
    })

@app.route('/health', methods=['GET'])
def health():
    """Simple health check for Railway"""
    return jsonify({"status": "healthy", "port": WEBHOOK_CONFIG["port"]}), 200

@app.route('/', methods=['GET'])
def home():
    """Home page"""
    port = WEBHOOK_CONFIG["port"]
    return f"""
    <html>
    <head>
        <title>MT5 FX Webhook - Smart Lock 2026</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body style="font-family: monospace; background: #0a0e14; color: #0f6; padding: 20px;">
        <h1>⚡ MT5 FX Webhook Receiver</h1>
        <h2 style="color: #ffd700;">HFT Ultra FX Smart Lock 2026</h2>
        <hr style="border-color: #1a2030;">
        <p>🔌 Port: <span style="color: #0af;">{port}</span></p>
        <p>📡 Status: <a href="/status" style="color: #0af;">/status</a></p>
        <p>📊 Positions: <a href="/positions" style="color: #0af;">/positions</a></p>
        <p>💹 Symbols: <a href="/symbols" style="color: #0af;">/symbols</a></p>
        <p>💰 Account: <a href="/account" style="color: #0af;">/account</a></p>
        <p>❤️ Health: <a href="/health" style="color: #0af;">/health</a></p>
        <p>📨 Webhook: <span style="color: #fc0;">POST /webhook</span></p>
        <hr style="border-color: #1a2030;">
        <h3>🎯 Supported Forex Pairs (28):</h3>
        <p style="color: #0af;"><b>Majors:</b> EUR/USD, GBP/USD, USD/JPY, USD/CHF, AUD/USD, USD/CAD, NZD/USD</p>
        <p style="color: #fc0;"><b>EUR Crosses:</b> EUR/GBP, EUR/JPY, EUR/CHF, EUR/AUD, EUR/CAD, EUR/NZD</p>
        <p style="color: #fc0;"><b>GBP Crosses:</b> GBP/JPY, GBP/CHF, GBP/AUD, GBP/CAD, GBP/NZD</p>
        <p style="color: #888;"><b>Other Crosses:</b> AUD/JPY, AUD/NZD, AUD/CAD, AUD/CHF, NZD/JPY, NZD/CAD, NZD/CHF, CAD/JPY, CAD/CHF</p>
        <p style="color: #ffd700;"><b>Metals:</b> XAU/USD (Gold)</p>
        <hr style="border-color: #1a2030;">
        <h3 style="color: #ffd700;">🛡️ Smart Lock Features:</h3>
        <ul style="color: #888;">
            <li>Break-Even Lock at 3 pips</li>
            <li>Tiered Trailing: 5p → 8p → 12p</li>
            <li>Partial Profit: 50% at 6 pips</li>
            <li>Profit Ratchet: Lock 50% of peak gains</li>
        </ul>
    </body>
    </html>
    """

# ============================================
# MAIN
# ============================================

def heartbeat():
    """Keep MT5 connection alive"""
    while True:
        time.sleep(30)
        if mt5_connected:
            ensure_mt5_connection()

if __name__ == '__main__':
    port = WEBHOOK_CONFIG["port"]
    print(f"""
    ╔══════════════════════════════════════════════════════════╗
    ║   MT5 WEBHOOK RECEIVER - HFT Ultra FX Smart Lock 2026    ║
    ╠══════════════════════════════════════════════════════════╣
    ║  🎯 28 FOREX PAIRS: Majors, Crosses, XAU/USD             ║
    ║  🛡️ FEATURES: Break-Even, Tiered Trail, Profit Lock      ║
    ║  📡 PORT: {port:<47}║
    ║                                                          ║
    ║  Configure webhook URL in HFT Ultra FX:                  ║
    ║  http://YOUR_IP:{port}/webhook{' ' * (35 - len(str(port)))}║
    ╚══════════════════════════════════════════════════════════╝
    """)
    
    if connect_mt5():
        heartbeat_thread = threading.Thread(target=heartbeat, daemon=True)
        heartbeat_thread.start()
        
        logger.info(f"Starting webhook server on port {port}")
        app.run(
            host=WEBHOOK_CONFIG["host"],
            port=port,
            debug=False,
            threaded=True
        )
    else:
        logger.error("Failed to connect to MT5. Please check credentials.")
        print("\n⚠️ Troubleshooting:")
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

