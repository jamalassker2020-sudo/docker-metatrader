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
input int      InpStopLoss    = 500;                            // SL in Points (0 = None)
input int      InpTakeProfit  = 1000;                           // TP in Points (0 = None)

// List of pairs (Base symbols without suffix)
input string   InpWatchList   = "EURUSD,BTCUSD,ETHUSD,XAUUSD,SOLUSD";

// --- GLOBALS ---
string g_symbols[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ushort sep = StringGetCharacter(",", 0);
   StringSplit(InpWatchList, sep, g_symbols);
   
   // Enable Timer to start the cycle
   EventSetTimer(5); 
   Print("🤖 Bot Initialized. Watchlist size: ", ArraySize(g_symbols));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { EventKillTimer(); }

//+------------------------------------------------------------------+
//| Main Logic Loop                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   EventKillTimer(); // Pause to prevent overlapping cycles
   
   Print("🚀 Starting AI Sentiment Trade Cycle...");
   
   for(int i=0; i<ArraySize(g_symbols); i++)
   {
      string base = g_symbols[i];
      StringTrimLeft(base); StringTrimRight(base);
      
      string brokerSymbol = base + ".vx"; // Adding the .vx suffix
      
      // Ensure symbol is available in Market Watch
      if(!SymbolSelect(brokerSymbol, true)) {
         Print("❌ Symbol ", brokerSymbol, " not found in Market Watch.");
         continue;
      }

      string sentiment = GetAISentiment(base);
      Print("📊 Symbol: ", brokerSymbol, " | Sentiment: ", sentiment);
      
      if(sentiment == "BUY") 
         ExecuteTrade(brokerSymbol, ORDER_TYPE_BUY);
      else if(sentiment == "SELL") 
         ExecuteTrade(brokerSymbol, ORDER_TYPE_SELL);
      
      Sleep(2000); // Prevent spamming API
   }

   Print("😴 Cycle Complete. Waiting ", InpSleepHour, " hour(s).");
   EventSetTimer(InpSleepHour * 3600);
}

//+------------------------------------------------------------------+
//| API Call to OpenRouter                                           |
//+------------------------------------------------------------------+
string GetAISentiment(string symbol)
{
   char post[], result[];
   string result_headers;
   string url = "https://openrouter.ai/api/v1/chat/completions";
   
   // Updated prompt to be extremely specific to avoid parsing errors
   string prompt = "Analyze current news for " + symbol + ". Verdict MUST be one word: BUY, SELL, or NEUTRAL. Return JSON: {\"sentiment\":\"VERDICT\"}";
   
   string payload = "{\"model\": \"google/gemini-2.0-flash-001\", \"messages\": [{\"role\": \"user\", \"content\": \"" + prompt + "\"}]}";
   StringToCharArray(payload, post);
   
   string headers = "Authorization: Bearer " + InpApiKey + "\r\nContent-Type: application/json\r\n";
   
   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, post, result, result_headers);

   if(res <= 0) {
      Print("❌ WebRequest Failed. Error Code: ", GetLastError());
      return "ERROR";
   }

   string response = CharArrayToString(result);
   
   // Case-insensitive search for the sentiment
   if(StringFind(response, "\"BUY\"", 0) != -1 || StringFind(response, "\"buy\"", 0) != -1) return "BUY";
   if(StringFind(response, "\"SELL\"", 0) != -1 || StringFind(response, "\"sell\"", 0) != -1) return "SELL";
   
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Trade Execution with SL/TP Logic                                 |
//+------------------------------------------------------------------+
void ExecuteTrade(string symbol, ENUM_ORDER_TYPE type)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double price = (type == ORDER_TYPE_BUY) ? ask : bid;
   
   // Calculate SL/TP
   double sl = 0, tp = 0;
   if(InpStopLoss > 0)
      sl = (type == ORDER_TYPE_BUY) ? (price - InpStopLoss * point) : (price + InpStopLoss * point);
   if(InpTakeProfit > 0)
      tp = (type == ORDER_TYPE_BUY) ? (price + InpTakeProfit * point) : (price - InpTakeProfit * point);

   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = symbol;
   request.volume       = InpLotSize;
   request.type         = type;
   request.price        = price;
   request.sl           = sl;
   request.tp           = tp;
   request.magic        = InpMagicNumber;
   request.deviation    = 10;
   request.type_filling = ORDER_FILLING_IOC; 
   request.comment      = "AI Sentiment Bot .vx";

   if(!OrderSend(request, result))
      Print("❌ OrderSend Error for ", symbol, ": ", GetLastError());
   else
      Print("✅ Trade Opened: ", symbol, " Ticket: ", result.order);
}
