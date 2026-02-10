import os
import time
import json
from mt5linux import MetaTrader5
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# --- CONFIGURATION ---
# Pulls from Railway Variables (Ensure you added OPENROUTER_API_KEY there)
API_KEY = os.getenv("OPENROUTER_API_KEY") 
MAGIC_NUMBER = 123456

# Updated Symbol Map with .vx suffix for Valetex
SYMBOL_MAP = {
    # Forex
    "EUR/USD": "EURUSD.vx", 
    "GBP/USD": "GBPUSD.vx", 
    "USD/JPY": "USDJPY.vx", 
    "XAU/USD": "XAUUSD.vx",
    # Top 20 Crypto Symbols with .vx suffix
    "BTC/USD": "BTCUSD.vx", "ETH/USD": "ETHUSD.vx", "BNB/USD": "BNBUSD.vx", 
    "SOL/USD": "SOLUSD.vx", "XRP/USD": "XRPUSD.vx", "ADA/USD": "ADAUSD.vx",
    "DOGE/USD": "DOGEUSD.vx", "AVAX/USD": "AVAXUSD.vx", "DOT/USD": "DOTUSD.vx",
    "TRX/USD": "TRXUSD.vx", "LINK/USD": "LINKUSD.vx", "MATIC/USD": "MATICUSD.vx",
    "BCH/USD": "BCHUSD.vx", "LTC/USD": "LTCUSD.vx", "SHIB/USD": "SHIBUSD.vx",
    "ICP/USD": "ICPUSD.vx", "NEAR/USD": "NEARUSD.vx", "UNI/USD": "UNIUSD.vx",
    "DAI/USD": "DAIUSD.vx", "STX/USD": "STXUSD.vx"
}

# Initialize MT5 Bridge (Connects to the bridge started in Docker)
mt5 = MetaTrader5(host='localhost', port=18812)

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=API_KEY,
)

def check_mt5_health():
    """Checks if MT5 is actually logged in and connected."""
    if not mt5.initialize():
        print("❌ CRITICAL: MT5 Bridge Offline")
        return False
    
    account_info = mt5.account_info()
    if account_info is None:
        print("❌ CRITICAL: Could not get account info. Make sure you are logged into Valetex via VNC.")
        return False
    
    print(f"✅ MT5 Online | Account: {account_info.login} | Balance: {account_info.balance}")
    return True

def get_sentiment(pair):
    """Asks Gemini for news sentiment."""
    prompt = f"""You are a financial analyst. Generate 5 current news headlines for {pair}.
    Return ONLY a JSON object with this exact structure:
    {{ "headlines": [ {{"headline":"text","sentiment":"BUY/SELL/NEUTRAL"}}, ... ] }}"""

    try:
        response = client.chat.completions.create(
            model="google/gemini-2.0-flash-001",
            messages=[{"role": "user", "content": prompt}],
            response_format={ "type": "json_object" }
        )
        data = json.loads(response.choices[0].message.content)
        headlines = data.get('headlines', [])
        
        print(f"\n--- AI Sentiment for {pair} ---")
        for h in headlines:
            print(f"  [{h.get('sentiment')}] {h.get('headline')}")
        return headlines
    except Exception as e:
        print(f"❌ AI Error: {e}")
        return []

def execute_trade(symbol, direction, lot):
    """Executes trade on MT5 with .vx symbols."""
    if not mt5.initialize():
        return None

    # Sync symbol with Market Watch
    if not mt5.symbol_select(symbol, True):
        print(f"❌ Error: Symbol {symbol} not found on Valetex. Check suffix.")
        return None

    tick = mt5.symbol_info_tick(symbol)
    if tick is None:
        print(f"❌ Error: Could not get price for {symbol}")
        return None

    order_type = mt5.ORDER_TYPE_BUY if direction == "BUY" else mt5.ORDER_TYPE_SELL
    price = tick.ask if direction == "BUY" else tick.bid

    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": float(lot),
        "type": order_type,
        "price": price,
        "magic": MAGIC_NUMBER,
        "comment": "AI Bot .vx",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    print(f"🚀 Sending {direction} order for {symbol} at {price}...")
    result = mt5.order_send(request)
    
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        print(f"❌ Trade Failed! Code: {result.retcode} | Msg: {result.comment}")
    else:
        print(f"✅ Trade Success! Ticket: {result.order}")
    
    return result

def main_cycle(pair, lot):
    """Execution Logic."""
    if not check_mt5_health():
        return
    
    headlines = get_sentiment(pair)
    if not headlines: return

    bulls = sum(1 for h in headlines if h.get('sentiment') == 'BUY')
    bears = sum(1 for h in headlines if h.get('sentiment') == 'SELL')
    
    print(f"📊 Stats: {bulls} Bulls vs {bears} Bears")

    direction = None
    if bulls >= 3: direction = "BUY"
    elif bears >= 3: direction = "SELL"
    
    if direction:
        broker_symbol = SYMBOL_MAP.get(pair)
        execute_trade(broker_symbol, direction, lot)
    else:
        print("⚖️ Mixed sentiment. No trade.")

if __name__ == "__main__":
    print("🤖 AI Bot Starting...")
    # Wait for Docker bridge to be fully ready
    time.sleep(20)
    
    # List of pairs to monitor (using the keys from SYMBOL_MAP)
    watch_list = ["EUR/USD", "BTC/USD", "ETH/USD", "XAU/USD", "SOL/USD"]
    
    while True:
        try:
            for pair in watch_list:
                main_cycle(pair, 0.01)
                time.sleep(10)
            
            print("\n😴 Cycle Complete. Sleeping 1 hour...")
            time.sleep(3600)
        except Exception as e:
            print(f"⚠️ Loop Error: {e}")
            time.sleep(60)

