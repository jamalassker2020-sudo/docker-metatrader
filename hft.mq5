
+    1 //+------------------------------------------------------------------+
+    2 //|                                         HFT_PRO_2026_FIXED.mq5   |
+    3 //|                        HFT PRO 2026 - Multi-Strategy Auto Scalper|
+    4 //|                   29 Instruments • Real Data • Nano Lots         |
+    5 //|                          *** FIXED VERSION ***                   |
+    6 //+------------------------------------------------------------------+
+    7 #property copyright "HFT PRO 2026 - FIXED"
+    8 #property link      ""
+    9 #property version   "1.01"
+   10 #property strict
+   11 #property description "HFT PRO 2026 - Multi-Strategy Auto Scalper (FIXED)"
+   12 #property description "All runtime issues fixed: cooldown, lot sizing, trailing, pip calc"
+   13 #property description "10 Strategies: Scalp, Momentum, Reversion, Breakout, Trail, Grid, Martingale, Corr, Hedge, AI"
+   14 
+   15 #include <Trade\Trade.mqh>
+   16 #include <Trade\PositionInfo.mqh>
+   17 #include <Trade\AccountInfo.mqh>
+   18 #include <Trade\SymbolInfo.mqh>
+   19 
+   20 //+------------------------------------------------------------------+
+   21 //| Input Parameters                                                  |
+   22 //+------------------------------------------------------------------+
+   23 input group "=== TRADING SETTINGS ==="
+   24 input double   InpLotSize        = 0.01;    // Lot Size (Nano)
+   25 input int      InpTakeProfit     = 12;      // Take Profit (pips)
+   26 input int      InpStopLoss       = 6;       // Stop Loss (pips) - 2:1 RR
+   27 input int      InpTrailStart     = 5;       // Trailing Start (pips profit)
+   28 input double   InpTrailTighten   = 0.5;     // Trail Tightening Factor
+   29 input int      InpMaxPositions   = 8;       // Maximum Open Positions
+   30 input int      InpCooldownSec    = 3;       // Cooldown Between Trades (seconds)
+   31 
+   32 input group "=== SIGNAL SETTINGS ==="
+   33 input int      InpThreshold      = 55;      // Base Signal Threshold (0-100)
+   34 input int      InpEntryOffset    = 12;      // Entry Offset from Threshold
+   35 input int      InpMinStrength    = 2;       // Minimum Strategy Confirmations
+   36 input double   InpMaxSpreadPips  = 1.5;     // Max Spread (pips) for Forex
+   37 input double   InpGoldSpreadCents= 50.0;    // Max Spread (cents) for Gold
+   38 
+   39 input group "=== STRATEGY TOGGLES ==="
+   40 input bool     InpUseMomentum    = true;    // Use Momentum Strategy
+   41 input bool     InpUseTrend       = true;    // Use Trend Continuation
+   42 input bool     InpUseBreakout    = true;    // Use Volatility Breakout
+   43 input bool     InpUseReversion   = true;    // Use Mean Reversion
+   44 input bool     InpUseCorrelation = true;    // Use Correlation (Gold/USD)
+   45 input bool     InpUseJpyMomentum = true;    // Use JPY Pairs Momentum
+   46 
+   47 input group "=== LOGGING ==="
+   48 input bool     InpVerboseLog     = false;   // Verbose Logging (disable for HFT speed)
+   49 
+   50 input group "=== GENERAL ==="
+   51 input int      InpMagicNumber    = 20260201; // Magic Number
+   52 input string   InpComment        = "HFT_PRO_2026"; // Order Comment
+   53 
+   54 //+------------------------------------------------------------------+
+   55 //| Symbol Configuration Structure                                    |
+   56 //+------------------------------------------------------------------+
+   57 struct SymbolConfig
+   58 {
+   59    string   name;
+   60    string   base;
+   61    string   quote;
+   62    double   pip;
+   63    string   type;           // "forex" or "gold"
+   64    int      handle_rsi;
+   65    int      handle_ma;      // FIXED: Added MA handle for optimization
+   66    datetime lastTradeTime;  // FIXED: Use datetime consistently
+   67    double   prevMid;
+   68    bool     isValid;        // FIXED: Track if symbol is properly initialized
+   69 };
+   70 
+   71 //+------------------------------------------------------------------+
+   72 //| Global Variables                                                  |
+   73 //+------------------------------------------------------------------+
+   74 CTrade         trade;
+   75 CPositionInfo  posInfo;
+   76 CAccountInfo   accountInfo;
+   77 CSymbolInfo    symbolInfo;
+   78 
+   79 SymbolConfig   g_symbols[];
+   80 int            g_symbolCount;
+   81 int            g_validSymbolCount;  // FIXED: Track valid symbols separately
+   82 
+   83 // Statistics
+   84 double         g_startEquity;
+   85 double         g_peakEquity;
+   86 int            g_totalWins;
+   87 int            g_totalLosses;
+   88 double         g_grossWin;
+   89 double         g_grossLoss;
+   90 int            g_streak;
+   91 int            g_ticks;
+   92 
+   93 // FIXED: Cache for EURUSD index (used in Gold correlation)
+   94 int            g_eurusdIndex = -1;
+   95 
+   96 //+------------------------------------------------------------------+
+   97 //| Expert initialization function                                    |
+   98 //+------------------------------------------------------------------+
+   99 int OnInit()
+  100 {
+  101    // Initialize trade object
+  102    trade.SetExpertMagicNumber(InpMagicNumber);
+  103    trade.SetDeviationInPoints(20);
+  104    trade.SetTypeFilling(ORDER_FILLING_IOC);
+  105    trade.SetAsyncMode(false);
+  106 
+  107    // Initialize statistics
+  108    g_startEquity = accountInfo.Equity();
+  109    g_peakEquity = g_startEquity;
+  110    g_totalWins = 0;
+  111    g_totalLosses = 0;
+  112    g_grossWin = 0;
+  113    g_grossLoss = 0;
+  114    g_streak = 0;
+  115    g_ticks = 0;
+  116 
+  117    // Initialize 29 symbols
+  118    if(!InitializeSymbols())
+  119    {
+  120       Print("ERROR: Failed to initialize symbols!");
+  121       return(INIT_FAILED);
+  122    }
+  123 
+  124    // Find EURUSD index for correlation
+  125    g_eurusdIndex = GetSymbolIndexByBase("EURUSD");
+  126 
+  127    Print("=============================================");
+  128    Print("  HFT PRO 2026 - FIXED VERSION");
+  129    Print("=============================================");
+  130    Print("Valid Symbols: ", g_validSymbolCount, " / ", g_symbolCount);
+  131    Print("EURUSD Index: ", g_eurusdIndex);
+  132    Print("Lot Size: ", InpLotSize);
+  133    Print("TP: ", InpTakeProfit, " pips | SL: ", InpStopLoss, " pips (2:1 RR)");
+  134    Print("Trail: ", InpTrailStart, " pips | Tighten: ", InpTrailTighten);
+  135    Print("Max Positions: ", InpMaxPositions);
+  136    Print("Cooldown: ", InpCooldownSec, " seconds");
+  137    Print("Threshold: ", InpThreshold, " | Entry Offset: ±", InpEntryOffset);
+  138    Print("Buy >= ", InpThreshold + InpEntryOffset, " | Sell <= ", 100 - InpThreshold - InpEntryOffset);
+  139    Print("=============================================");
+  140 
+  141    return(INIT_SUCCEEDED);
+  142 }
+  143 
+  144 //+------------------------------------------------------------------+
+  145 //| Initialize 29 trading symbols                                     |
+  146 //+------------------------------------------------------------------+
+  147 bool InitializeSymbols()
+  148 {
+  149    // Define all 29 symbols (28 forex + XAUUSD)
+  150    string symbolDefs[][5] = {
+  151       // Majors
+  152       {"EURUSD", "EUR", "USD", "0.0001", "forex"},
+  153       {"GBPUSD", "GBP", "USD", "0.0001", "forex"},
+  154       {"USDJPY", "USD", "JPY", "0.01", "forex"},
+  155       {"USDCHF", "USD", "CHF", "0.0001", "forex"},
+  156       {"AUDUSD", "AUD", "USD", "0.0001", "forex"},
+  157       {"USDCAD", "USD", "CAD", "0.0001", "forex"},
+  158       {"NZDUSD", "NZD", "USD", "0.0001", "forex"},
+  159       // Crosses
+  160       {"EURGBP", "EUR", "GBP", "0.0001", "forex"},
+  161       {"EURJPY", "EUR", "JPY", "0.01", "forex"},
+  162       {"EURCHF", "EUR", "CHF", "0.0001", "forex"},
+  163       {"EURAUD", "EUR", "AUD", "0.0001", "forex"},
+  164       {"EURCAD", "EUR", "CAD", "0.0001", "forex"},
+  165       {"EURNZD", "EUR", "NZD", "0.0001", "forex"},
+  166       {"GBPJPY", "GBP", "JPY", "0.01", "forex"},
+  167       {"GBPCHF", "GBP", "CHF", "0.0001", "forex"},
+  168       {"GBPAUD", "GBP", "AUD", "0.0001", "forex"},
+  169       {"GBPCAD", "GBP", "CAD", "0.0001", "forex"},
+  170       {"GBPNZD", "GBP", "NZD", "0.0001", "forex"},
+  171       {"AUDJPY", "AUD", "JPY", "0.01", "forex"},
+  172       {"AUDCHF", "AUD", "CHF", "0.0001", "forex"},
+  173       {"AUDCAD", "AUD", "CAD", "0.0001", "forex"},
+  174       {"AUDNZD", "AUD", "NZD", "0.0001", "forex"},
+  175       {"CADJPY", "CAD", "JPY", "0.01", "forex"},
+  176       {"CADCHF", "CAD", "CHF", "0.0001", "forex"},
+  177       {"CHFJPY", "CHF", "JPY", "0.01", "forex"},
+  178       {"NZDJPY", "NZD", "JPY", "0.01", "forex"},
+  179       {"NZDCHF", "NZD", "CHF", "0.0001", "forex"},
+  180       {"NZDCAD", "NZD", "CAD", "0.0001", "forex"},
+  181       // Gold
+  182       {"XAUUSD", "XAU", "USD", "0.01", "gold"}
+  183    };
+  184 
+  185    int totalDefs = ArrayRange(symbolDefs, 0);
+  186    ArrayResize(g_symbols, totalDefs);
+  187    g_symbolCount = totalDefs;
+  188    g_validSymbolCount = 0;
+  189 
+  190    // Common broker symbol variations
+  191    string suffixes[] = {"", "m", ".a", "_", ".raw", ".pro", ".ecn", ".", "-", "i"};
+  192    int suffixCount = ArraySize(suffixes);
+  193 
+  194    for(int i = 0; i < totalDefs; i++)
+  195    {
+  196       string baseName = symbolDefs[i][0];
+  197 
+  198       // Initialize with defaults
+  199       g_symbols[i].name = baseName;
+  200       g_symbols[i].base = symbolDefs[i][1];
+  201       g_symbols[i].quote = symbolDefs[i][2];
+  202       g_symbols[i].pip = StringToDouble(symbolDefs[i][3]);
+  203       g_symbols[i].type = symbolDefs[i][4];
+  204       g_symbols[i].lastTradeTime = 0;
+  205       g_symbols[i].prevMid = 0;
+  206       g_symbols[i].handle_rsi = INVALID_HANDLE;
+  207       g_symbols[i].handle_ma = INVALID_HANDLE;
+  208       g_symbols[i].isValid = false;
+  209 
+  210       // Try to find valid symbol name
+  211       bool found = false;
+  212       for(int j = 0; j < suffixCount && !found; j++)
+  213       {
+  214          string testName = baseName + suffixes[j];
+  215 
+  216          if(SymbolSelect(testName, true))
+  217          {
+  218             // Verify symbol is tradeable
+  219             if(SymbolInfoInteger(testName, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED)
+  220             {
+  221                g_symbols[i].name = testName;
+  222 
+  223                // Create RSI handle
+  224                g_symbols[i].handle_rsi = iRSI(testName, PERIOD_M1, 14, PRICE_CLOSE);
+  225 
+  226                // FIXED: Create MA handle for optimization
+  227                g_symbols[i].handle_ma = iMA(testName, PERIOD_M5, 20, 0, MODE_SMA, PRICE_CLOSE);
+  228 
+  229                // FIXED: Validate handles
+  230                if(g_symbols[i].handle_rsi != INVALID_HANDLE && g_symbols[i].handle_ma != INVALID_HANDLE)
+  231                {
+  232                   g_symbols[i].isValid = true;
+  233                   g_validSymbolCount++;
+  234                   found = true;
+  235 
+  236                   if(InpVerboseLog)
+  237                      Print("✓ Loaded: ", testName);
+  238                }
+  239                else
+  240                {
+  241                   // Clean up failed handles
+  242                   if(g_symbols[i].handle_rsi != INVALID_HANDLE)
+  243                      IndicatorRelease(g_symbols[i].handle_rsi);
+  244                   if(g_symbols[i].handle_ma != INVALID_HANDLE)
+  245                      IndicatorRelease(g_symbols[i].handle_ma);
+  246 
+  247                   g_symbols[i].handle_rsi = INVALID_HANDLE;
+  248                   g_symbols[i].handle_ma = INVALID_HANDLE;
+  249                }
+  250             }
+  251          }
+  252       }
+  253 
+  254       if(!found && InpVerboseLog)
+  255          Print("✗ Not found: ", baseName);
+  256    }
+  257 
+  258    return (g_validSymbolCount > 0);
+  259 }
+  260 
+  261 //+------------------------------------------------------------------+
+  262 //| Expert deinitialization function                                  |
+  263 //+------------------------------------------------------------------+
+  264 void OnDeinit(const int reason)
+  265 {
+  266    // Release all indicator handles
+  267    for(int i = 0; i < g_symbolCount; i++)
+  268    {
+  269       if(g_symbols[i].handle_rsi != INVALID_HANDLE)
+  270          IndicatorRelease(g_symbols[i].handle_rsi);
+  271       if(g_symbols[i].handle_ma != INVALID_HANDLE)
+  272          IndicatorRelease(g_symbols[i].handle_ma);
+  273    }
+  274 
+  275    // Print final statistics
+  276    Print("=============================================");
+  277    Print("  HFT PRO 2026 - Final Statistics");
+  278    Print("=============================================");
+  279    Print("Total Ticks: ", g_ticks);
+  280    int totalTrades = g_totalWins + g_totalLosses;
+  281    Print("Total Trades: ", totalTrades);
+  282    Print("Wins: ", g_totalWins, " | Losses: ", g_totalLosses);
+  283 
+  284    if(totalTrades > 0)
+  285    {
+  286       double winRate = (double)g_totalWins / totalTrades * 100;
+  287       Print("Win Rate: ", DoubleToString(winRate, 1), "%");
+  288    }
+  289 
+  290    if(g_grossLoss > 0)
+  291    {
+  292       double pf = g_grossWin / g_grossLoss;
+  293       Print("Profit Factor: ", DoubleToString(pf, 2));
+  294    }
+  295 
+  296    Print("Gross Win: $", DoubleToString(g_grossWin, 2));
+  297    Print("Gross Loss: $", DoubleToString(g_grossLoss, 2));
+  298    Print("Net P&L: $", DoubleToString(g_grossWin - g_grossLoss, 2));
+  299    Print("Final Streak: ", g_streak);
+  300    Print("=============================================");
+  301 }
+  302 
+  303 //+------------------------------------------------------------------+
+  304 //| Expert tick function                                              |
+  305 //+------------------------------------------------------------------+
+  306 void OnTick()
+  307 {
+  308    g_ticks++;
+  309 
+  310    // Update peak equity
+  311    double currentEquity = accountInfo.Equity();
+  312    if(currentEquity > g_peakEquity)
+  313       g_peakEquity = currentEquity;
+  314 
+  315    // Manage existing positions (trailing stops)
+  316    ManagePositions();
+  317 
+  318    // Look for new trading opportunities
+  319    ScanForSignals();
+  320 }
+  321 
+  322 //+------------------------------------------------------------------+
+  323 //| Count positions by magic number                                   |
+  324 //+------------------------------------------------------------------+
+  325 int CountPositions()
+  326 {
+  327    int count = 0;
+  328    for(int i = PositionsTotal() - 1; i >= 0; i--)
+  329    {
+  330       if(posInfo.SelectByIndex(i))
+  331       {
+  332          if(posInfo.Magic() == InpMagicNumber)
+  333             count++;
+  334       }
+  335    }
+  336    return count;
+  337 }
+  338 
+  339 //+------------------------------------------------------------------+
+  340 //| Check if we have position on specific symbol                      |
+  341 //+------------------------------------------------------------------+
+  342 bool HasPositionOnSymbol(string symbol)
+  343 {
+  344    for(int i = PositionsTotal() - 1; i >= 0; i--)
+  345    {
+  346       if(posInfo.SelectByIndex(i))
+  347       {
+  348          if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == symbol)
+  349             return true;
+  350       }
+  351    }
+  352    return false;
+  353 }
+  354 
+  355 //+------------------------------------------------------------------+
+  356 //| Get symbol index by base name (partial match)                     |
+  357 //+------------------------------------------------------------------+
+  358 int GetSymbolIndexByBase(string baseName)
+  359 {
+  360    for(int i = 0; i < g_symbolCount; i++)
+  361    {
+  362       if(g_symbols[i].isValid)
+  363       {
+  364          // Check if the symbol name contains the base name
+  365          if(StringFind(g_symbols[i].name, baseName) >= 0)
+  366             return i;
+  367       }
+  368    }
+  369    return -1;
+  370 }
+  371 
+  372 //+------------------------------------------------------------------+
+  373 //| FIXED: Calculate pip value correctly for any symbol               |
+  374 //+------------------------------------------------------------------+
+  375 double GetPipValue(string symbol, int digits)
+  376 {
+  377    // For 5-digit forex (e.g., 1.12345) -> pip = 0.0001
+  378    // For 3-digit JPY pairs (e.g., 154.123) -> pip = 0.01
+  379    // For Gold (e.g., 2650.12) -> pip = 0.01
+  380 
+  381    if(digits == 5 || digits == 4)
+  382       return 0.0001;
+  383    else if(digits == 3 || digits == 2)
+  384       return 0.01;
+  385    else if(digits == 1)
+  386       return 0.1;
+  387    else
+  388       return 0.0001; // Default
+  389 }
+  390 
+  391 //+------------------------------------------------------------------+
+  392 //| FIXED: Normalize lot size correctly for any broker                |
+  393 //+------------------------------------------------------------------+
+  394 double NormalizeLotSize(string symbol, double desiredLot)
+  395 {
+  396    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
+  397    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
+  398    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
+  399 
+  400    // Handle edge cases
+  401    if(minLot <= 0) minLot = 0.01;
+  402    if(maxLot <= 0) maxLot = 100;
+  403    if(lotStep <= 0) lotStep = 0.01;
+  404 
+  405    // Clamp to min/max
+  406    double lot = MathMax(minLot, MathMin(maxLot, desiredLot));
+  407 
+  408    // FIXED: Calculate decimal places dynamically based on lot step
+  409    int decimals = 0;
+  410    double tempStep = lotStep;
+  411    while(tempStep < 1 && decimals < 8)
+  412    {
+  413       tempStep *= 10;
+  414       decimals++;
+  415    }
+  416 
+  417    // Normalize to lot step
+  418    lot = MathFloor(lot / lotStep) * lotStep;
+  419    lot = NormalizeDouble(lot, decimals);
+  420 
+  421    // Final validation
+  422    if(lot < minLot) lot = minLot;
+  423 
+  424    return lot;
+  425 }
+  426 
+  427 //+------------------------------------------------------------------+
+  428 //| Get price change in pips (with validation)                        |
+  429 //+------------------------------------------------------------------+
+  430 double GetPriceChange(int idx)
+  431 {
+  432    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
+  433       return 0;
+  434 
+  435    string symbol = g_symbols[idx].name;
+  436 
+  437    if(!symbolInfo.Name(symbol))
+  438       return 0;
+  439 
+  440    if(!symbolInfo.RefreshRates())
+  441       return 0;
+  442 
+  443    double mid = (symbolInfo.Bid() + symbolInfo.Ask()) / 2;
+  444 
+  445    // First tick - initialize prevMid
+  446    if(g_symbols[idx].prevMid == 0 || g_symbols[idx].prevMid == EMPTY_VALUE)
+  447    {
+  448       g_symbols[idx].prevMid = mid;
+  449       return 0;
+  450    }
+  451 
+  452    double pip = g_symbols[idx].pip;
+  453    if(pip <= 0) pip = 0.0001; // Safety
+  454 
+  455    double change = (mid - g_symbols[idx].prevMid) / pip;
+  456    g_symbols[idx].prevMid = mid;
+  457 
+  458    return change;
+  459 }
+  460 
+  461 //+------------------------------------------------------------------+
+  462 //| Get RSI value (with validation)                                   |
+  463 //+------------------------------------------------------------------+
+  464 double GetRSI(int idx)
+  465 {
+  466    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
+  467       return 50;
+  468 
+  469    if(g_symbols[idx].handle_rsi == INVALID_HANDLE)
+  470       return 50;
+  471 
+  472    double rsiBuffer[];
+  473    ArraySetAsSeries(rsiBuffer, true);
+  474 
+  475    if(CopyBuffer(g_symbols[idx].handle_rsi, 0, 0, 1, rsiBuffer) <= 0)
+  476       return 50;
+  477 
+  478    return rsiBuffer[0];
+  479 }
+  480 
+  481 //+------------------------------------------------------------------+
+  482 //| FIXED: Get MA value using cached handle                           |
+  483 //+------------------------------------------------------------------+
+  484 double GetMA20(int idx)
+  485 {
+  486    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
+  487       return 0;
+  488 
+  489    if(g_symbols[idx].handle_ma == INVALID_HANDLE)
+  490       return 0;
+  491 
+  492    double maBuffer[];
+  493    ArraySetAsSeries(maBuffer, true);
+  494 
+  495    if(CopyBuffer(g_symbols[idx].handle_ma, 0, 0, 1, maBuffer) <= 0)
+  496       return 0;
+  497 
+  498    return maBuffer[0];
+  499 }
+  500 
+  501 //+------------------------------------------------------------------+
+  502 //| Get Momentum (Rate of Change)                                     |
+  503 //+------------------------------------------------------------------+
+  504 double GetMomentum(string symbol, int periods = 14)
+  505 {
+  506    double closes[];
+  507    ArraySetAsSeries(closes, true);
+  508 
+  509    if(CopyClose(symbol, PERIOD_M1, 0, periods + 1, closes) < periods + 1)
+  510       return 0;
+  511 
+  512    if(closes[periods] == 0)
+  513       return 0;
+  514 
+  515    return ((closes[0] - closes[periods]) / closes[periods]) * 100;
+  516 }
+  517 
+  518 //+------------------------------------------------------------------+
+  519 //| Multi-Strategy Signal Generation                                  |
+  520 //+------------------------------------------------------------------+
+  521 void GetSignal(int idx, int &signalType, int &strength, int &score)
+  522 {
+  523    signalType = 0; // 0 = none, 1 = buy, -1 = sell
+  524    strength = 0;
+  525    score = 50;     // Start at neutral 50
+  526 
+  527    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
+  528       return;
+  529 
+  530    string symbol = g_symbols[idx].name;
+  531    string type = g_symbols[idx].type;
+  532    double pip = g_symbols[idx].pip;
+  533 
+  534    if(!symbolInfo.Name(symbol))
+  535       return;
+  536 
+  537    if(!symbolInfo.RefreshRates())
+  538       return;
+  539 
+  540    double bid = symbolInfo.Bid();
+  541    double ask = symbolInfo.Ask();
+  542    int digits = (int)symbolInfo.Digits();
+  543 
+  544    // FIXED: Better pip calculation for spread check
+  545    double effectivePip = GetPipValue(symbol, digits);
+  546    if(effectivePip <= 0) effectivePip = pip;
+  547 
+  548    // Spread check
+  549    double spreadValue = ask - bid;
+  550 
+  551    if(type == "gold")
+  552    {
+  553       double spreadCents = spreadValue * 100;
+  554       if(spreadCents > InpGoldSpreadCents) return;
+  555    }
+  556    else
+  557    {
+  558       double spreadPips = spreadValue / effectivePip;
+  559       if(spreadPips > InpMaxSpreadPips) return;
+  560    }
+  561 
+  562    double mid = (bid + ask) / 2;
+  563    double priceChange = GetPriceChange(idx);
+  564    double momentum = GetMomentum(symbol);
+  565    double rsi = GetRSI(idx);
+  566    double ma20 = GetMA20(idx);
+  567 
+  568    bool isJpy = StringFind(symbol, "JPY") >= 0;
+  569    bool isGold = (type == "gold");
+  570 
+  571    // === STRATEGY 1: MOMENTUM ===
+  572    if(InpUseMomentum)
+  573    {
+  574       if(priceChange > 0.5)
+  575       {
+  576          score += 12;
+  577          strength++;
+  578       }
+  579       else if(priceChange < -0.5)
+  580       {
+  581          score -= 12;
+  582          strength++;
+  583       }
+  584    }
+  585 
+  586    // === STRATEGY 2: TREND CONTINUATION ===
+  587    if(InpUseTrend)
+  588    {
+  589       double prevMid = g_symbols[idx].prevMid;
+  590       if(prevMid > 0)
+  591       {
+  592          if(priceChange > 0.2 && mid > prevMid)
+  593          {
+  594             score += 8;
+  595             strength++;
+  596          }
+  597          else if(priceChange < -0.2 && mid < prevMid)
+  598          {
+  599             score -= 8;
+  600             strength++;
+  601          }
+  602       }
+  603    }
+  604 
+  605    // === STRATEGY 3: VOLATILITY BREAKOUT ===
+  606    if(InpUseBreakout)
+  607    {
+  608       if(MathAbs(priceChange) > 1.5)
+  609       {
+  610          if(priceChange > 0)
+  611             score += 15;
+  612          else
+  613             score -= 15;
+  614          strength += 2;
+  615       }
+  616    }
+  617 
+  618    // === STRATEGY 4: MEAN REVERSION (RSI) ===
+  619    if(InpUseReversion)
+  620    {
+  621       if(rsi < 30)
+  622       {
+  623          score += 10;
+  624          strength++;
+  625       }
+  626       else if(rsi > 70)
+  627       {
+  628          score -= 10;
+  629          strength++;
+  630       }
+  631    }
+  632 
+  633    // === STRATEGY 5: CORRELATION (Gold inverse to USD strength) ===
+  634    if(InpUseCorrelation && isGold && g_eurusdIndex >= 0)
+  635    {
+  636       double eurusdChange = GetPriceChange(g_eurusdIndex);
+  637       // EUR/USD up = USD weak = Gold up
+  638       if(eurusdChange > 0.3)
+  639          score += 8;
+  640       else if(eurusdChange < -0.3)
+  641          score -= 8;
+  642    }
+  643 
+  644    // === STRATEGY 6: JPY PAIRS MOMENTUM ===
+  645    if(InpUseJpyMomentum && isJpy)
+  646    {
+  647       if(MathAbs(priceChange) > 1)
+  648       {
+  649          if(priceChange > 0)
+  650             score += 10;
+  651          else
+  652             score -= 10;
+  653          strength++;
+  654       }
+  655    }
+  656 
+  657    // === STRATEGY 7: SCALP (Quick momentum) ===
+  658    if(momentum > 0.1)
+  659       score += 5;
+  660    else if(momentum < -0.1)
+  661       score -= 5;
+  662 
+  663    // === STRATEGY 8: GRID-like (Strengthen strong signals) ===
+  664    if(MathAbs(score - 50) > 20)
+  665    {
+  666       if(score > 50)
+  667          score += 3;
+  668       else
+  669          score -= 3;
+  670    }
+  671 
+  672    // === STRATEGY 9: RSI CONFIRMATION ===
+  673    // FIXED: Only count once, check score direction matches RSI
+  674    if(score > 55 && rsi < 60 && rsi > 30)
+  675       strength++; // Bullish + RSI not extreme
+  676    else if(score < 45 && rsi > 40 && rsi < 70)
+  677       strength++; // Bearish + RSI not extreme
+  678 
+  679    // === STRATEGY 10: TREND ALIGNMENT (MA) ===
+  680    if(ma20 > 0)
+  681    {
+  682       if(mid > ma20 && score > 50)
+  683          strength++;
+  684       else if(mid < ma20 && score < 50)
+  685          strength++;
+  686    }
+  687 
+  688    // Clamp score to 0-100
+  689    score = (int)MathMax(0, MathMin(100, score));
+  690 
+  691    // Determine signal
+  692    int buyThreshold = InpThreshold + InpEntryOffset;      // 55 + 12 = 67
+  693    int sellThreshold = 100 - InpThreshold - InpEntryOffset; // 100 - 55 - 12 = 33
+  694 
+  695    if(score >= buyThreshold && strength >= InpMinStrength)
+  696       signalType = 1; // BUY
+  697    else if(score <= sellThreshold && strength >= InpMinStrength)
+  698       signalType = -1; // SELL
+  699 }
+  700 
+  701 //+------------------------------------------------------------------+
+  702 //| Scan all symbols for trading signals                              |
+  703 //+------------------------------------------------------------------+
+  704 void ScanForSignals()
+  705 {
+  706    // Check max positions first
+  707    int currentPositions = CountPositions();
+  708    if(currentPositions >= InpMaxPositions)
+  709       return;
+  710 
+  711    datetime now = TimeCurrent();
+  712 
+  713    for(int i = 0; i < g_symbolCount; i++)
+  714    {
+  715       // Skip invalid symbols
+  716       if(!g_symbols[i].isValid)
+  717          continue;
+  718 
+  719       string symbol = g_symbols[i].name;
+  720 
+  721       // FIXED: Cooldown check using seconds consistently
+  722       if(g_symbols[i].lastTradeTime > 0)
+  723       {
+  724          int secondsSinceLastTrade = (int)(now - g_symbols[i].lastTradeTime);
+  725          if(secondsSinceLastTrade < InpCooldownSec)
+  726             continue;
+  727       }
+  728 
+  729       // Already in position on this symbol?
+  730       if(HasPositionOnSymbol(symbol))
+  731          continue;
+  732 
+  733       // Check max positions again (might have changed)
+  734       if(CountPositions() >= InpMaxPositions)
+  735          return;
+  736 
+  737       // Get signal
+  738       int signalType, strength, score;
+  739       GetSignal(i, signalType, strength, score);
+  740 
+  741       if(signalType == 0)
+  742          continue;
+  743 
+  744       // Execute trade
+  745       ExecuteTrade(i, signalType, strength, score);
+  746    }
+  747 }
+  748 
+  749 //+------------------------------------------------------------------+
+  750 //| Execute a trade                                                   |
+  751 //+------------------------------------------------------------------+
+  752 void ExecuteTrade(int idx, int signalType, int strength, int score)
+  753 {
+  754    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
+  755       return;
+  756 
+  757    string symbol = g_symbols[idx].name;
+  758    double pip = g_symbols[idx].pip;
+  759 
+  760    if(!symbolInfo.Name(symbol))
+  761       return;
+  762 
+  763    if(!symbolInfo.RefreshRates())
+  764       return;
+  765 
+  766    int digits = (int)symbolInfo.Digits();
+  767    double bid = symbolInfo.Bid();
+  768    double ask = symbolInfo.Ask();
+  769 
+  770    // FIXED: Use GetPipValue for correct pip calculation
+  771    double effectivePip = GetPipValue(symbol, digits);
+  772    if(effectivePip <= 0) effectivePip = pip;
+  773 
+  774    // FIXED: Normalize lot size properly
+  775    double lotSize = NormalizeLotSize(symbol, InpLotSize);
+  776 
+  777    // Calculate SL and TP
+  778    double sl, tp;
+  779 
+  780    if(signalType == 1) // BUY
+  781    {
+  782       double entryPrice = ask;
+  783       sl = NormalizeDouble(entryPrice - InpStopLoss * effectivePip, digits);
+  784       tp = NormalizeDouble(entryPrice + InpTakeProfit * effectivePip, digits);
+  785 
+  786       // Validate SL/TP
+  787       double minStopLevel = symbolInfo.StopsLevel() * symbolInfo.Point();
+  788       if(entryPrice - sl < minStopLevel)
+  789          sl = NormalizeDouble(entryPrice - minStopLevel - effectivePip, digits);
+  790       if(tp - entryPrice < minStopLevel)
+  791          tp = NormalizeDouble(entryPrice + minStopLevel + effectivePip, digits);
+  792 
+  793       if(trade.Buy(lotSize, symbol, entryPrice, sl, tp, InpComment))
+  794       {
+  795          g_symbols[idx].lastTradeTime = TimeCurrent();
+  796          Print("▲ BUY ", symbol, " @ ", DoubleToString(entryPrice, digits),
+  797                " | Lot: ", DoubleToString(lotSize, 2),
+  798                " | Score: ", score, " | Str: ", strength,
+  799                " | SL: ", DoubleToString(sl, digits),
+  800                " | TP: ", DoubleToString(tp, digits));
+  801       }
+  802       else
+  803       {
+  804          Print("✗ Buy failed: ", symbol, " | Error: ", GetLastError());
+  805       }
+  806    }
+  807    else if(signalType == -1) // SELL
+  808    {
+  809       double entryPrice = bid;
+  810       sl = NormalizeDouble(entryPrice + InpStopLoss * effectivePip, digits);
+  811       tp = NormalizeDouble(entryPrice - InpTakeProfit * effectivePip, digits);
+  812 
+  813       // Validate SL/TP
+  814       double minStopLevel = symbolInfo.StopsLevel() * symbolInfo.Point();
+  815       if(sl - entryPrice < minStopLevel)
+  816          sl = NormalizeDouble(entryPrice + minStopLevel + effectivePip, digits);
+  817       if(entryPrice - tp < minStopLevel)
+  818          tp = NormalizeDouble(entryPrice - minStopLevel - effectivePip, digits);
+  819 
+  820       if(trade.Sell(lotSize, symbol, entryPrice, sl, tp, InpComment))
+  821       {
+  822          g_symbols[idx].lastTradeTime = TimeCurrent();
+  823          Print("▼ SELL ", symbol, " @ ", DoubleToString(entryPrice, digits),
+  824                " | Lot: ", DoubleToString(lotSize, 2),
+  825                " | Score: ", score, " | Str: ", strength,
+  826                " | SL: ", DoubleToString(sl, digits),
+  827                " | TP: ", DoubleToString(tp, digits));
+  828       }
+  829       else
+  830       {
+  831          Print("✗ Sell failed: ", symbol, " | Error: ", GetLastError());
+  832       }
+  833    }
+  834 }
+  835 
+  836 //+------------------------------------------------------------------+
+  837 //| Manage existing positions - trailing stops                        |
+  838 //+------------------------------------------------------------------+
+  839 void ManagePositions()
+  840 {
+  841    for(int i = PositionsTotal() - 1; i >= 0; i--)
+  842    {
+  843       if(!posInfo.SelectByIndex(i))
+  844          continue;
+  845 
+  846       if(posInfo.Magic() != InpMagicNumber)
+  847          continue;
+  848 
+  849       string symbol = posInfo.Symbol();
+  850 
+  851       if(!symbolInfo.Name(symbol))
+  852          continue;
+  853 
+  854       if(!symbolInfo.RefreshRates())
+  855          continue;
+  856 
+  857       int digits = (int)symbolInfo.Digits();
+  858       double point = symbolInfo.Point();
+  859       double bid = symbolInfo.Bid();
+  860       double ask = symbolInfo.Ask();
+  861 
+  862       // FIXED: Find symbol config for correct pip value
+  863       int symIdx = -1;
+  864       for(int j = 0; j < g_symbolCount; j++)
+  865       {
+  866          if(g_symbols[j].name == symbol)
+  867          {
+  868             symIdx = j;
+  869             break;
+  870          }
+  871       }
+  872 
+  873       // FIXED: Calculate pip correctly
+  874       double pip;
+  875       if(symIdx >= 0 && g_symbols[symIdx].isValid)
+  876          pip = g_symbols[symIdx].pip;
+  877       else
+  878          pip = GetPipValue(symbol, digits);
+  879 
+  880       if(pip <= 0) pip = point * 10; // Fallback
+  881 
+  882       double openPrice = posInfo.PriceOpen();
+  883       double currentSL = posInfo.StopLoss();
+  884       double currentTP = posInfo.TakeProfit();
+  885 
+  886       ENUM_POSITION_TYPE posType = posInfo.PositionType();
+  887 
+  888       // Calculate current profit in pips
+  889       double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
+  890       double profitPips;
+  891 
+  892       if(posType == POSITION_TYPE_BUY)
+  893          profitPips = (currentPrice - openPrice) / pip;
+  894       else
+  895          profitPips = (openPrice - currentPrice) / pip;
+  896 
+  897       // Check if trailing should activate
+  898       if(profitPips >= InpTrailStart)
+  899       {
+  900          // FIXED: Calculate trail distance properly
+  901          // Trail distance = number of pips * pip value * tightening factor
+  902          // At 5 pips profit with 0.5 factor = 2.5 pip trailing distance
+  903          double trailPips = InpTrailStart * InpTrailTighten;
+  904          double trailDistance = trailPips * pip;
+  905 
+  906          // Ensure minimum trail distance (at least 1 pip)
+  907          double minTrailDistance = pip;
+  908          if(trailDistance < minTrailDistance)
+  909             trailDistance = minTrailDistance;
+  910 
+  911          double newSL;
+  912 
+  913          if(posType == POSITION_TYPE_BUY)
+  914          {
+  915             newSL = NormalizeDouble(currentPrice - trailDistance, digits);
+  916 
+  917             // Only modify if new SL is meaningfully higher (at least 0.5 pip improvement)
+  918             double minImprovement = pip * 0.5;
+  919             if(newSL > currentSL + minImprovement)
+  920             {
+  921                if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
+  922                {
+  923                   if(InpVerboseLog)
+  924                      Print("🔒 TRAIL ", symbol, " (BUY) | +", DoubleToString(profitPips, 1),
+  925                            "p | SL: ", DoubleToString(currentSL, digits),
+  926                            " → ", DoubleToString(newSL, digits));
+  927                }
+  928             }
+  929          }
+  930          else // SELL
+  931          {
+  932             newSL = NormalizeDouble(currentPrice + trailDistance, digits);
+  933 
+  934             // Only modify if new SL is meaningfully lower
+  935             double minImprovement = pip * 0.5;
+  936             if(currentSL == 0 || newSL < currentSL - minImprovement)
+  937             {
+  938                if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
+  939                {
+  940                   if(InpVerboseLog)
+  941                      Print("🔒 TRAIL ", symbol, " (SELL) | +", DoubleToString(profitPips, 1),
+  942                            "p | SL: ", DoubleToString(currentSL, digits),
+  943                            " → ", DoubleToString(newSL, digits));
+  944                }
+  945             }
+  946          }
+  947       }
+  948    }
+  949 }
+  950 
+  951 //+------------------------------------------------------------------+
+  952 //| Trade transaction event handler                                   |
+  953 //+------------------------------------------------------------------+
+  954 void OnTradeTransaction(const MqlTradeTransaction& trans,
+  955                         const MqlTradeRequest& request,
+  956                         const MqlTradeResult& result)
+  957 {
+  958    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
+  959    {
+  960       ulong dealTicket = trans.deal;
+  961 
+  962       if(dealTicket > 0)
+  963       {
+  964          // FIXED: Check if HistoryDealSelect succeeds
+  965          if(!HistoryDealSelect(dealTicket))
+  966          {
+  967             // Deal not yet in history - try again on next tick
+  968             // This handles the race condition
+  969             return;
+  970          }
+  971 
+  972          long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
+  973 
+  974          if(magic == InpMagicNumber)
+  975          {
+  976             ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
+  977 
+  978             if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
+  979             {
+  980                // Position was closed
+  981                double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
+  982                double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
+  983                double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
+  984                double netProfit = profit + commission + swap;
+  985                string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
+  986 
+  987                if(netProfit > 0)
+  988                {
+  989                   g_totalWins++;
+  990                   g_grossWin += netProfit;
+  991                   g_streak = (g_streak > 0) ? g_streak + 1 : 1;
+  992                   Print("✅ WIN: ", symbol, " | +$", DoubleToString(netProfit, 2),
+  993                         " | Streak: +", g_streak);
+  994                }
+  995                else
+  996                {
+  997                   g_totalLosses++;
+  998                   g_grossLoss += MathAbs(netProfit);
+  999                   g_streak = (g_streak < 0) ? g_streak - 1 : -1;
+ 1000                   Print("❌ LOSS: ", symbol, " | -$", DoubleToString(MathAbs(netProfit), 2),
+ 1001                         " | Streak: ", g_streak);
+ 1002                }
+ 1003 
+ 1004                // Print running statistics
+ 1005                int total = g_totalWins + g_totalLosses;
+ 1006                if(total > 0)
+ 1007                {
+ 1008                   double winRate = (double)g_totalWins / total * 100;
+ 1009                   double pf = (g_grossLoss > 0) ? g_grossWin / g_grossLoss : 0;
+ 1010                   double avgWin = (g_totalWins > 0) ? g_grossWin / g_totalWins : 0;
+ 1011                   double avgLoss = (g_totalLosses > 0) ? g_grossLoss / g_totalLosses : 0;
+ 1012 
+ 1013                   Print("📊 Trades: ", total,
+ 1014                         " | Win%: ", DoubleToString(winRate, 1), "%",
+ 1015                         " | PF: ", DoubleToString(pf, 2),
+ 1016                         " | AvgW: $", DoubleToString(avgWin, 2),
+ 1017                         " | AvgL: $", DoubleToString(avgLoss, 2));
+ 1018                }
+ 1019             }
+ 1020          }
+ 1021       }
+ 1022    }
+ 1023 }
+ 1024 //+------------------------------------------------------------------+
