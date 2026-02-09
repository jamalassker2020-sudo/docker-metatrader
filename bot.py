import os
import time
import json
from mt5linux import MetaTrader5
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# --- CONFIGURATION ---
# Fixed: Accessing the key correctly from Railway Variables
API_KEY = os.getenv("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") 
MAGIC_NUMBER = 123456
SYMBOL_MAP = {
    "EUR/USD": "EURUSD",
    "GBP/USD": "GBPUSD",
    "USD/JPY": "USDJPY",
    "XAU/USD": "XAUUSD"
}

# Initialize MT5 Bridge
mt5 = MetaTrader5(host='localhost', port=18812)

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=API_KEY,
)

def check_mt5_health():
    """Checks if MT5 is actually logged in and connected to broker."""
    if not mt5.initialize():
        print("❌ CRITICAL: MT5 Bridge Offline")
        return False
    
    account_info = mt5.account_info()
    if account_info is None:
        print("❌ CRITICAL: Could not get account info. Is MT5 logged in?")
        return False
    
    print(f"✅ MT5 Online | Broker: {account_info.company} | Balance: {account_info.balance}")
    return True

def get_sentiment(pair):
    """Asks AI for sentiment and logs the headlines clearly."""
    prompt = f"""You are a forex news analyst. Generate 5 realistic current news headlines about {pair} 
    and rate each one's likely impact on {pair} price direction.
    Return ONLY a JSON array:
    [{"headline":"...","sentiment":"BUY"},{"headline":"...","sentiment":"SELL"},{"headline":"...","sentiment":"NEUTRAL"}]"""

    try:
        response = client.chat.completions.create(
            model="google/gemini-2.0-flash-001",
            messages=[{"role": "user", "content": prompt}],
            response_format={ "type": "json_object" }
        )
        data = json.loads(response.choices[0].message.content)
        headlines = data.get('headlines', data) if isinstance(data, dict) else data
        
        print(f"--- AI Sentiment for {pair} ---")
        for h in headlines:
            print(f"  [{h.get('sentiment')}] {h.get('headline')}")
        return headlines
    except Exception as e:
        print(f"❌ AI Error: {e}")
        return []

def execute_trade(symbol, direction, lot):
    """Executes trade with detailed result logging."""
    if not mt5.initialize():
        return None

    mt5.symbol_select(symbol, True)
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
        "comment": "Railway AI Bot",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    print(f"🚀 Sending {direction} order for {symbol} at {price}...")
    result = mt5.order_send(request)
    
    if result is None:
        print(f"❌ Trade Failed: Internal Bridge Error")
    elif result.retcode != mt5.TRADE_RETCODE_DONE:
        print(f"❌ Trade Failed! Error Code: {result.retcode} | Msg: {result.comment}")
    else:
        print(f"✅ Trade Success! Ticket: {result.order}")
    
    return result

def main_cycle(pair, lot):
    """Full cycle with logic verification."""
    if not check_mt5_health():
        return
    
    print(f"\n🔍 Starting analysis for {pair}...")
    headlines = get_sentiment(pair)
    
    if not headlines:
        print("⚠️ No headlines received. Skipping cycle.")
        return

    bulls = sum(1 for h in headlines if h.get('sentiment') == 'BUY')
    bears = sum(1 for h in headlines if h.get('sentiment') == 'SELL')
    
    print(f"📊 Stats: {bulls} Bulls vs {bears} Bears")

    direction = None
    if bulls >= 3: direction = "BUY"  # Requiring at least 3 out of 5 for confidence
    elif bears >= 3: direction = "SELL"
    
    if direction:
        mt5_symbol = SYMBOL_MAP.get(pair, pair.replace("/", ""))
        execute_trade(mt5_symbol, direction, lot)
    else:
        print("⚖️ Sentiment is Neutral/Mixed. No trade placed.")

if __name__ == "__main__":
    print("🤖 AI Trading Bot Initializing...")
    # Wait for MT5 and Bridge to settle
    time.sleep(10)
    
    while True:
        try:
            main_cycle("EUR/USD", 0.01)
            # Sleep for 1 hour between checks to avoid spamming
            print("\n😴 Cycle finished. Sleeping for 60 minutes...")
            time.sleep(3600)
        except Exception as e:
            print(f"⚠️ Unexpected Loop Error: {e}")
            time.sleep(60)
