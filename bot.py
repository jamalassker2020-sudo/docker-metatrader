import os
import time
import json
from mt5linux import MetaTrader5
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# --- CONFIGURATION ---
OPENROUTER_API_KEY = os.getenv("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")
MAGIC_NUMBER = 123456
# You can expand this dict for more symbols
SYMBOL_MAP = {
    "EUR/USD": "EURUSD",
    "GBP/USD": "GBPUSD",
    "USD/JPY": "USDJPY",
    "XAU/USD": "XAUUSD"
}

# Initialize MT5 Bridge
mt5 = MetaTrader5()

client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=OPENROUTER_API_KEY,
)

def get_sentiment(pair):
    """Asks OpenRouter for sentiment analysis."""
    prompt = f"""You are a forex news analyst. Generate 5 realistic current news headlines about {pair} 
    and rate each one's likely impact on {pair} price direction.
    Return ONLY a JSON array, no explanation:
    [{"headline":"...","sentiment":"BUY"},{"headline":"...","sentiment":"SELL"},{"headline":"...","sentiment":"NEUTRAL"}]"""

    try:
        response = client.chat.completions.create(
            model="google/gemini-2.0-flash-001", # High speed for news
            messages=[{"role": "user", "content": prompt}],
            response_format={ "type": "json_object" }
        )
        # Handle different response formats from LLMs
        data = json.loads(response.choices[0].message.content)
        return data.get('headlines', data) if isinstance(data, dict) else data
    except Exception as e:
        print(f"Sentiment Error: {e}")
        return []

def execute_trade(symbol, direction, lot):
    """Sends the trade to Valetax MT5 via the bridge."""
    if not mt5.initialize():
        return {"status": "error", "message": "MT5 Bridge Offline"}

    # Refresh symbol info
    mt5.symbol_select(symbol, True)
    tick = mt5.symbol_info_tick(symbol)
    
    order_type = mt5.ORDER_BUY if direction == "BUY" else mt5.ORDER_SELL
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

    result = mt5.order_send(request)
    return result

def main_cycle(pair, lot):
    """One full bot loop."""
    print(f"Analyzing {pair}...")
    headlines = get_sentiment(pair)
    
    bulls = sum(1 for h in headlines if h['sentiment'] == 'BUY')
    bears = sum(1 for h in headlines if h['sentiment'] == 'SELL')
    
    direction = None
    if bulls > bears: direction = "BUY"
    elif bears > bulls: direction = "SELL"
    
    if direction:
        mt5_symbol = SYMBOL_MAP.get(pair, pair.replace("/", ""))
        print(f"Executing {direction} on {mt5_symbol}")
        res = execute_trade(mt5_symbol, direction, lot)
        return {"headlines": headlines, "trade": str(res.comment), "direction": direction}
    
    return {"headlines": headlines, "trade": "No Clear Majority", "direction": None}

if __name__ == "__main__":
    # In a Railway environment, you might use a Flask wrapper to trigger this from the UI
    # For now, this runs as a standalone test
    if mt5.initialize():
        print("Bot Engine Started Successfully")
        # main_cycle("EUR/USD", 0.1) 
    else:
        print("Failed to sync with Wine MT5")
