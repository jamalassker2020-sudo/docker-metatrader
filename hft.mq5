//+------------------------------------------------------------------+
//|                                              AI_Sentiment_Bot.mq5|
//|                                  Copyright 2026, AI Trading Corp |
//+------------------------------------------------------------------+
#property strict
#property advertising "AI Sentiment Bot"

// --- INPUT PARAMETERS ---
input string   InpApiKey      = "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"; // OpenRouter API Key
input double   InpLotSize     = 0.01;                           // Trade Lot Size
input int      InpMagicNumber = 123456;                         // Magic Number
input int      InpSleepHour   = 1;                              // Hours to wait between cycles

// List of pairs (Comma separated)
input string   InpWatchList   = "EURUSD,BTCUSD,ETHUSD,XAUUSD,SOLUSD";

// --- GLOBALS ---
string g_symbols[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Split watch list into array
   ushort sep = StringGetCharacter(",", 0);
   StringSplit(InpWatchList, sep, g_symbols);
   
   // Set timer for first execution
   EventSetTimer(5); 
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { EventKillTimer(); }

//+------------------------------------------------------------------+
//| Timer function (The Main Loop)                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   EventKillTimer(); // Pause timer while working
   
   Print("🤖 AI Bot Cycle Starting...");
   
   for(int i=0; i<ArraySize(g_symbols); i++)
   {
      string baseSymbol = g_symbols[i];
      string brokerSymbol = baseSymbol + ".vx";
      
      Print("📊 Processing: ", brokerSymbol);
      
      string sentiment = GetAISentiment(baseSymbol);
      
      if(sentiment == "BUY") 
         ExecuteTrade(brokerSymbol, ORDER_TYPE_BUY);
      else if(sentiment == "SELL") 
         ExecuteTrade(brokerSymbol, ORDER_TYPE_SELL);
      else
         Print("⚖️ Sentiment Neutral or Error for ", baseSymbol);
         
      Sleep(5000); // 5 second gap between symbols
   }

   Print("😴 Cycle Complete. Sleeping for ", InpSleepHour, " hour(s).");
   EventSetTimer(InpSleepHour * 3600);
}

//+------------------------------------------------------------------+
//| Fetch AI Sentiment via WebRequest                                |
//+------------------------------------------------------------------+
string GetAISentiment(string symbol)
{
   char post[], result[];
   string result_headers;
   string url = "https://openrouter.ai/api/v1/chat/completions";
   
   // Prepare the prompt
   string prompt = "Generate 5 news headlines for " + symbol + ". Return ONLY JSON: {\"sentiment\":\"BUY\"} or {\"sentiment\":\"SELL\"} or {\"sentiment\":\"NEUTRAL\"}";
   
   // Prepare JSON Payload
   string payload = "{\"model\": \"google/gemini-2.0-flash-001\", \"messages\": [{\"role\": \"user\", \"content\": \"" + prompt + "\"}]}";
   StringToCharArray(payload, post);
   
   string headers = "Authorization: Bearer " + InpApiKey + "\r\nContent-Type: application/json\r\n";
   
   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, post, result, result_headers);

   if(res == -1)
   {
      Print("❌ WebRequest Error: ", GetLastError());
      return "ERROR";
   }

   string responseText = CharArrayToString(result);
   
   // Simple JSON parsing (Looking for the sentiment value)
   if(StringFind(responseText, "\"sentiment\":\"BUY\"") != -1) return "BUY";
   if(StringFind(responseText, "\"sentiment\":\"SELL\"") != -1) return "SELL";
   
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Execute the Trade                                                |
//+------------------------------------------------------------------+
void ExecuteTrade(string symbol, ENUM_ORDER_TYPE type)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   if(!SymbolSelect(symbol, true))
   {
      Print("❌ Symbol ", symbol, " not found.");
      return;
   }

   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   
   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = symbol;
   request.volume       = InpLotSize;
   request.type         = type;
   request.price        = price;
   request.magic        = InpMagicNumber;
   request.deviation    = 10;
   request.type_filling = ORDER_FILLING_IOC;
   request.comment      = "AI Bot .vx MQL5";

   if(!OrderSend(request, result))
      Print("❌ Trade Failed: ", GetLastError());
   else
      Print("✅ Trade Success! Ticket: ", result.order);
}
