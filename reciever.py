"""
MT5 Webhook Receiver for HFT Ultra 2026
========================================
Receives trading signals via HTTP webhook and executes trades on MetaTrader 5

SETUP:
1. Install dependencies: pip install flask metatrader5 pytz
2. Update credentials below
3. Run: python mt5_webhook_receiver.py
4. Configure webhook URL in HFT Ultra: http://YOUR_VPS_IP:8080/webhook

Author: HFT Ultra 2026
Version: 1.0
"""

from mt5linux import MetaTrader5
from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import logging
from datetime import datetime
import threading
import time
mt5 = MetaTrader5()
# ============================================
# CONFIGURATION - UPDATE THESE VALUES
# ============================================

MT5_CONFIG = {
     "server": "ValetaxGlobal-Live3",
     "login": 641086382,
     "password": "EJam123!@",  # ⚠️ CHANGE THIS AFTER SETUP!
     "timeout": 10000,
     "portable": False
}

WEBHOOK_CONFIG = {
     "host": "0.0.0.0",      # Listen on all interfaces
     "port": 5000,            # Webhook port
     "secret_key": "",        # Optional: match with HFT Ultra secret
     "enable_trading": True,  # Set to False for testing without trades
     "max_slippage": 20,      # Max slippage in points
}

# Symbol mapping: HFT Ultra symbol -> Your broker's symbol
# Adjust these based on your broker's naming convention
SYMBOL_MAP = {
     "BTCUSD": "BTCUSD",      # Adjust if broker uses BTCUSD.i, BTCUSDm, etc.
     "ETHUSD": "ETHUSD",
     "BNBUSD": "BNBUSD",
     "XRPUSD": "XRPUSD",
     "SOLUSD": "SOLUSD",
     "DOGEUSD": "DOGEUSD",
     "ADAUSD": "ADAUSD",
     "AVAXUSD": "AVAXUSD",
     "LINKUSD": "LINKUSD",
     "DOTUSD": "DOTUSD",
     "MATICUSD": "MATICUSD",
     "SHIBUSD": "SHIBUSD",
     "LTCUSD": "LTCUSD",
     "TRXUSD": "TRXUSD",
     "ATOMUSD": "ATOMUSD",
     "UNIUSD": "UNIUSD",
     "ETCUSD": "ETCUSD",
     "XLMUSD": "XLMUSD",
     "NEARUSD": "NEARUSD",
     "APTUSD": "APTUSD",
     "FILUSD": "FILUSD",
     "ARBUSD": "ARBUSD",
     "OPUSD": "OPUSD",
     "INJUSD": "INJUSD",
     "SUIUSD": "SUIUSD",
     "PEPEUSD": "PEPEUSD",
     "WIFUSD": "WIFUSD",
     "RENDERUSD": "RENDERUSD",
     "FETUSD": "FETUSD",
}

# ============================================
# LOGGING SETUP
# ============================================

logging.basicConfig(
     level=logging.INFO,
     format='%(asctime)s | %(levelname)s | %(message)s',
     handlers=[
         logging.FileHandler('mt5_webhook.log'),
         logging.StreamHandler()
     ]
)
logger = logging.getLogger(__name__)

# ============================================
# FLASK APP
# ============================================

app = Flask(__name__)
CORS(app)  # Enable CORS for browser requests

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
     
     # Initialize MT5
     if not mt5.initialize():
         logger.error(f"MT5 initialize() failed: {mt5.last_error()}")
         return False
     
     # Login to account
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
     
     # Get account info
     account_info = mt5.account_info()
     if account_info:
         logger.info(f"✅ Connected to MT5")
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
     
     # Check if still connected
     account = mt5.account_info()
     if account is None:
         logger.warning("MT5 connection lost, reconnecting...")
         return connect_mt5()
     
     return True

# ============================================
# SYMBOL UTILITIES
# ============================================

def get_broker_symbol(hft_symbol):
     """Map HFT Ultra symbol to broker symbol"""
     # First try direct mapping
     if hft_symbol in SYMBOL_MAP:
         broker_sym = SYMBOL_MAP[hft_symbol]
     else:
         broker_sym = hft_symbol
     
     # Verify symbol exists
     symbol_info = mt5.symbol_info(broker_sym)
     if symbol_info is None:
         # Try common variations
         variations = [
             broker_sym,
             broker_sym + ".i",
             broker_sym + "m",
             broker_sym + ".raw",
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
     
     # Ensure symbol is visible in Market Watch
     if not info.visible:
         mt5.symbol_select(symbol, True)
     
     return info

# ============================================
# TRADE EXECUTION
# ============================================

def execute_open(payload):
     """Execute OPEN trade from webhook signal"""
     
     if not WEBHOOK_CONFIG["enable_trading"]:
         logger.info("🔒 Trading disabled - simulating OPEN")
         return {"success": True, "simulated": True, "trade_id": payload.get("trade_id")}
     
     if not ensure_mt5_connection():
         return {"success": False, "error": "MT5 not connected"}
     
     # Extract trade details
     trade_id = payload.get("trade_id")
     symbol_mt5 = payload.get("symbol_mt5")
     direction = payload.get("direction")
     lot_size = payload.get("lot_size", 0.01)
     tp = payload.get("take_profit")
     sl = payload.get("stop_loss")
     
     # Map to broker symbol
     broker_symbol = get_broker_symbol(symbol_mt5)
     if not broker_symbol:
         return {"success": False, "error": f"Symbol not found: {symbol_mt5}"}
     
     # Get symbol info
     symbol_info = get_symbol_info(broker_symbol)
     if not symbol_info:
         return {"success": False, "error": f"Cannot get symbol info: {broker_symbol}"}
     
     # Normalize lot size
     lot_min = symbol_info.volume_min
     lot_max = symbol_info.volume_max
     lot_step = symbol_info.volume_step
     
     # Round to nearest step
     lot_size = max(lot_min, min(lot_max, round(lot_size / lot_step) * lot_step))
     
     # Get current price
     tick = mt5.symbol_info_tick(broker_symbol)
     if not tick:
         return {"success": False, "error": "Cannot get price"}
     
     # Determine order type and price
     if direction == "BUY":
         order_type = mt5.ORDER_TYPE_BUY
         price = tick.ask
     else:
         order_type = mt5.ORDER_TYPE_SELL
         price = tick.bid
     
     # Normalize TP/SL to broker's digit precision
     digits = symbol_info.digits
     point = symbol_info.point
     
     if tp:
         tp = round(tp, digits)
     if sl:
         sl = round(sl, digits)
     
     # Build trade request
     request = {
         "action": mt5.TRADE_ACTION_DEAL,
         "symbol": broker_symbol,
         "volume": lot_size,
         "type": order_type,
         "price": price,
         "deviation": WEBHOOK_CONFIG["max_slippage"],
         "magic": 202601,  # Magic number for HFT Ultra
         "comment": f"HFT:{trade_id[:15]}",
         "type_time": mt5.ORDER_TIME_GTC,
         "type_filling": mt5.ORDER_FILLING_IOC,
     }
     
     # Add TP/SL if provided
     if tp and tp > 0:
         request["tp"] = tp
     if sl and sl > 0:
         request["sl"] = sl
     
     logger.info(f"📤 Sending order: {direction} {lot_size} {broker_symbol} @ {price}")
     
     # Send order
     result = mt5.order_send(request)
     
     if result is None:
         error = mt5.last_error()
         logger.error(f"❌ Order failed: {error}")
         return {"success": False, "error": str(error)}
     
     if result.retcode != mt5.TRADE_RETCODE_DONE:
         logger.error(f"❌ Order rejected: {result.retcode} - {result.comment}")
         return {"success": False, "error": result.comment, "retcode": result.retcode}
     
     # Store position for tracking
     active_trades[trade_id] = {
         "ticket": result.order,
         "position": result.order,
         "symbol": broker_symbol,
         "direction": direction,
         "volume": lot_size,
         "open_price": result.price,
         "time": datetime.now().isoformat()
     }
     
     logger.info(f"✅ Order filled: Ticket #{result.order} @ {result.price}")
     
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
         logger.info("🔒 Trading disabled - simulating CLOSE")
         return {"success": True, "simulated": True, "trade_id": payload.get("trade_id")}
     
     if not ensure_mt5_connection():
         return {"success": False, "error": "MT5 not connected"}
     
     trade_id = payload.get("trade_id")
     symbol_mt5 = payload.get("symbol_mt5")
     direction = payload.get("direction")
     exit_reason = payload.get("exit_reason", "SIGNAL")
     
     # Check if we have this trade tracked
     if trade_id in active_trades:
         trade_info = active_trades[trade_id]
         broker_symbol = trade_info["symbol"]
         # Find position by ticket
     else:
         # Find position by symbol
         broker_symbol = get_broker_symbol(symbol_mt5)
         if not broker_symbol:
             return {"success": False, "error": f"Symbol not found: {symbol_mt5}"}
     
     # Get all positions for this symbol
     positions = mt5.positions_get(symbol=broker_symbol)
     
     if not positions:
         logger.warning(f"No open positions found for {broker_symbol}")
         return {"success": False, "error": "No position to close"}
     
     # Find matching position (same direction)
     target_type = mt5.POSITION_TYPE_BUY if direction == "BUY" else mt5.POSITION_TYPE_SELL
     position = None
     
     for pos in positions:
         if pos.type == target_type:
             # Check magic number or comment for HFT trades
             if pos.magic == 202601 or "HFT" in (pos.comment or ""):
                 position = pos
                 break
     
     if not position:
         # Just take first matching position
         for pos in positions:
             if pos.type == target_type:
                 position = pos
                 break
     
     if not position:
         logger.warning(f"No matching {direction} position for {broker_symbol}")
         return {"success": False, "error": "No matching position"}
     
     # Get symbol info
     symbol_info = get_symbol_info(broker_symbol)
     tick = mt5.symbol_info_tick(broker_symbol)
     
     if not tick:
         return {"success": False, "error": "Cannot get price"}
     
     # Opposite order to close
     if position.type == mt5.POSITION_TYPE_BUY:
         close_type = mt5.ORDER_TYPE_SELL
         close_price = tick.bid
     else:
         close_type = mt5.ORDER_TYPE_BUY
         close_price = tick.ask
     
     # Build close request
     request = {
         "action": mt5.TRADE_ACTION_DEAL,
         "symbol": broker_symbol,
         "volume": position.volume,
         "type": close_type,
         "position": position.ticket,
         "price": close_price,
         "deviation": WEBHOOK_CONFIG["max_slippage"],
         "magic": 202601,
         "comment": f"CLOSE:{exit_reason}",
         "type_time": mt5.ORDER_TIME_GTC,
         "type_filling": mt5.ORDER_FILLING_IOC,
     }
     
     logger.info(f"📤 Closing position #{position.ticket}: {position.volume} {broker_symbol}")
     
     # Send close order
     result = mt5.order_send(request)
     
     if result is None:
         error = mt5.last_error()
         logger.error(f"❌ Close failed: {error}")
         return {"success": False, "error": str(error)}
     
     if result.retcode != mt5.TRADE_RETCODE_DONE:
         logger.error(f"❌ Close rejected: {result.retcode} - {result.comment}")
         return {"success": False, "error": result.comment, "retcode": result.retcode}
     
     # Calculate P&L
     pnl = position.profit
     
     # Remove from tracking
     if trade_id in active_trades:
         del active_trades[trade_id]
     
     logger.info(f"✅ Position closed: #{position.ticket} P&L: ${pnl:.2f}")
     
     return {
         "success": True,
         "ticket": result.order,
         "closed_ticket": position.ticket,
         "price": result.price,
         "pnl": pnl,
         "reason": exit_reason,
         "trade_id": trade_id
     }

# ============================================
# WEBHOOK ENDPOINTS
# ============================================

@app.route('/webhook', methods=['POST', 'OPTIONS'])
def webhook():
     """Main webhook endpoint for trading signals"""
     
     # Handle CORS preflight
     if request.method == 'OPTIONS':
         return '', 204
     
     try:
         payload = request.get_json()
         
         if not payload:
             return jsonify({"success": False, "error": "No JSON payload"}), 400
         
         action = payload.get("action")
         source = payload.get("source")
         
         logger.info(f"📨 Received {action} signal from {source}")
         logger.debug(f"Payload: {json.dumps(payload, indent=2)}")
         
         # Verify source
         if source != "HFT-ULTRA-2026":
             logger.warning(f"Unknown source: {source}")
             return jsonify({"success": False, "error": "Unknown source"}), 403
         
         # Verify secret if configured
         if WEBHOOK_CONFIG["secret_key"]:
             auth = payload.get("auth", {})
             if auth.get("secret") != WEBHOOK_CONFIG["secret_key"]:
                 logger.warning("Invalid authentication")
                 return jsonify({"success": False, "error": "Auth failed"}), 403
         
         # Handle actions
         if action == "TEST":
             logger.info("✅ Test connection successful")
             return jsonify({
                 "success": True,
                 "message": "MT5 Webhook receiver is running",
                 "mt5_connected": mt5_connected,
                 "timestamp": datetime.now().isoformat()
             })
         
         elif action == "OPEN":
             result = execute_open(payload)
             return jsonify(result)
         
         elif action == "CLOSE":
             result = execute_close(payload)
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
         "mt5_connected": mt5_connected,
         "account": account,
         "active_trades": len(active_trades),
         "trading_enabled": WEBHOOK_CONFIG["enable_trading"],
         "timestamp": datetime.now().isoformat()
     })

@app.route('/positions', methods=['GET'])
def positions():
     """Get current open positions"""
     if not mt5_connected:
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
             "comment": pos.comment
         })
     
     return jsonify({"success": True, "positions": pos_list})

@app.route('/', methods=['GET'])
def home():
     """Home page"""
     return """
     <html>
     <head><title>MT5 Webhook Receiver</title></head>
     <body style="font-family: monospace; background: #1a1a2e; color: #0f6; padding: 20px;">
         <h1>⚡ MT5 Webhook Receiver</h1>
         <p>Status: <a href="/status" style="color: #0af;">/status</a></p>
         <p>Positions: <a href="/positions" style="color: #0af;">/positions</a></p>
         <p>Webhook endpoint: POST /webhook</p>
         <hr>
         <p>HFT Ultra 2026 Integration</p>
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
         ensure_mt5_connection()

if __name__ == '__main__':
     print("""
     ╔══════════════════════════════════════════════════════╗
     ║        MT5 WEBHOOK RECEIVER for HFT Ultra 2026       ║
     ╠══════════════════════════════════════════════════════╣
     ║  Configure webhook URL in HFT Ultra:                 ║
     ║  http://YOUR_IP:8080/webhook                         ║
     ╚══════════════════════════════════════════════════════╝
     """)
     
     # Connect to MT5
     if connect_mt5():
         # Start heartbeat thread
         heartbeat_thread = threading.Thread(target=heartbeat, daemon=True)
         heartbeat_thread.start()
         
         # Start Flask server
         logger.info(f"🚀 Starting webhook server on port {WEBHOOK_CONFIG['port']}")
         app.run(
             host=WEBHOOK_CONFIG["host"],
             port=WEBHOOK_CONFIG["port"],
             debug=False,
             threaded=True
         )
     else:
         logger.error("❌ Failed to connect to MT5. Please check credentials.")
         print("\nTroubleshooting:")
         print("1. Make sure MetaTrader 5 is installed and running")
         print("2. Enable 'Allow algorithmic trading' in MT5 settings")
         print("3. Verify your login credentials")
         print("4. Check if the server name is correct")
