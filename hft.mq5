+   1 //+------------------------------------------------------------------+
+   2 //|                                              HFT_Ultra_2026.mq5  |
+   3 //|                                    HFT Ultra 2026 Expert Advisor |
+   4 //|                          Multi-Strategy AI Signal Trading System |
+   5 //+------------------------------------------------------------------+
+   6 #property copyright "HFT Ultra 2026"
+   7 #property link      ""
+   8 #property version   "1.00"
+   9 #property strict
+  10 #property description "HFT Ultra 2026 - Multi-Strategy Trading System"
+  11 #property description "Features: RSI, Momentum, Trend Following, Risk Shield"
+  12 #property description "Trailing Stops, Correlation Hedging, Dynamic Lot Sizing"
+  13 
+  14 #include <Trade\Trade.mqh>
+  15 #include <Trade\PositionInfo.mqh>
+  16 #include <Trade\AccountInfo.mqh>
+  17 #include <Trade\SymbolInfo.mqh>
+  18 
+  19 //+------------------------------------------------------------------+
+  20 //| Input Parameters                                                  |
+  21 //+------------------------------------------------------------------+
+  22 input group "=== TRADING PARAMETERS ==="
+  23 input double   InpBaseLot        = 0.01;    // Base Lot Size
+  24 input int      InpTakeProfit     = 15;      // Take Profit (pips)
+  25 input int      InpStopLoss       = 5;       // Stop Loss (pips)
+  26 input int      InpTrailStart     = 6;       // Trail Start (pips profit)
+  27 input double   InpTrailFactor    = 0.4;     // Trail Tightness (0.1-1.0)
+  28 input int      InpMaxPositions   = 6;       // Maximum Open Positions
+  29 input int      InpCooldownSec    = 3;       // Cooldown Between Trades (seconds)
+  30 
+  31 input group "=== RSI SETTINGS ==="
+  32 input int      InpRSIPeriod      = 14;      // RSI Period
+  33 input int      InpRSIOversold    = 25;      // RSI Oversold Level
+  34 input int      InpRSIOverbought  = 75;      // RSI Overbought Level
+  35 
+  36 input group "=== SIGNAL REQUIREMENTS ==="
+  37 input int      InpMinStrength    = 3;       // Minimum Signal Strength (1-7)
+  38 input int      InpMinScore       = 25;      // Minimum Signal Score
+  39 input double   InpMaxSpread      = 2.0;     // Maximum Spread (pips)
+  40 
+  41 input group "=== RISK SHIELD ==="
+  42 input double   InpMaxDrawdown    = 5.0;     // Max Drawdown % (Circuit Breaker)
+  43 input double   InpDailyLossLimit = 3.0;     // Daily Loss Limit %
+  44 input bool     InpUseCorrelation = true;    // Use Correlation Hedging
+  45 
+  46 input group "=== DYNAMIC LOT SIZING ==="
+  47 input bool     InpDynamicLots    = true;    // Enable Dynamic Lot Sizing
+  48 input double   InpMinLot         = 0.01;    // Minimum Lot Size
+  49 input double   InpMaxLot         = 0.05;    // Maximum Lot Size
+  50 
+  51 input group "=== GENERAL ==="
+  52 input int      InpMagicNumber    = 20260101; // Magic Number
+  53 input string   InpComment        = "HFT_Ultra_2026"; // Order Comment
+  54 
+  55 //+------------------------------------------------------------------+
+  56 //| Global Variables                                                  |
+  57 //+------------------------------------------------------------------+
+  58 CTrade         trade;
+  59 CPositionInfo  posInfo;
+  60 CAccountInfo   accountInfo;
+  61 CSymbolInfo    symbolInfo;
+  62 
+  63 // Statistics
+  64 double         g_startEquity;
+  65 double         g_peakEquity;
+  66 double         g_dailyStartEquity;
+  67 int            g_totalWins;
+  68 int            g_totalLosses;
+  69 double         g_grossWin;
+  70 double         g_grossLoss;
+  71 int            g_streak;
+  72 datetime       g_lastTradeTime[];
+  73 datetime       g_currentDay;
+  74 
+  75 // RSI handles for multi-symbol
+  76 int            g_rsiHandle[];
+  77 string         g_symbols[];
+  78 int            g_symbolCount;
+  79 
+  80 // Correlation pairs mapping
+  81 string         g_corrPairs[][3]; // symbol, corr1, corr2
+  82 
+  83 //+------------------------------------------------------------------+
+  84 //| Expert initialization function                                    |
+  85 //+------------------------------------------------------------------+
+  86 int OnInit()
+  87 {
+  88    // Initialize trade object
+  89    trade.SetExpertMagicNumber(InpMagicNumber);
+  90    trade.SetDeviationInPoints(10);
+  91    trade.SetTypeFilling(ORDER_FILLING_IOC);
+  92    trade.SetAsyncMode(false);
+  93    
+  94    // Initialize statistics
+  95    g_startEquity = accountInfo.Equity();
+  96    g_peakEquity = g_startEquity;
+  97    g_dailyStartEquity = g_startEquity;
+  98    g_totalWins = 0;
+  99    g_totalLosses = 0;
+ 100    g_grossWin = 0;
+ 101    g_grossLoss = 0;
+ 102    g_streak = 0;
+ 103    g_currentDay = iTime(_Symbol, PERIOD_D1, 0);
+ 104    
+ 105    // Initialize symbols - using common forex/crypto pairs available on MT5
+ 106    InitializeSymbols();
+ 107    
+ 108    // Initialize RSI indicators for each symbol
+ 109    InitializeIndicators();
+ 110    
+ 111    // Initialize correlation pairs
+ 112    InitializeCorrelations();
+ 113    
+ 114    Print("===========================================");
+ 115    Print("  HFT ULTRA 2026 - Expert Advisor Started");
+ 116    Print("===========================================");
+ 117    Print("Symbols: ", g_symbolCount);
+ 118    Print("Base Lot: ", InpBaseLot);
+ 119    Print("TP: ", InpTakeProfit, " pips | SL: ", InpStopLoss, " pips");
+ 120    Print("Max Positions: ", InpMaxPositions);
+ 121    Print("Risk Shield: DD ", InpMaxDrawdown, "% | Daily ", InpDailyLossLimit, "%");
+ 122    Print("===========================================");
+ 123    
+ 124    return(INIT_SUCCEEDED);
+ 125 }
+ 126 
+ 127 //+------------------------------------------------------------------+
+ 128 //| Initialize trading symbols                                        |
+ 129 //+------------------------------------------------------------------+
+ 130 void InitializeSymbols()
+ 131 {
+ 132    // Define symbols to trade - adjust based on your broker's available symbols
+ 133    string tempSymbols[] = {
+ 134       "BTCUSD", "ETHUSD", "XRPUSD", "SOLUSD",    // Crypto (if available)
+ 135       "EURUSD", "GBPUSD", "USDJPY", "USDCHF",    // Major Forex
+ 136       "AUDUSD", "USDCAD", "NZDUSD",              // Commodity currencies
+ 137       "EURJPY", "GBPJPY", "EURGBP", "AUDNZD",    // Crosses
+ 138       "XAUUSD", "XAGUSD"                          // Metals
+ 139    };
+ 140    
+ 141    // Check which symbols are available
+ 142    g_symbolCount = 0;
+ 143    ArrayResize(g_symbols, ArraySize(tempSymbols));
+ 144    ArrayResize(g_lastTradeTime, ArraySize(tempSymbols));
+ 145    
+ 146    for(int i = 0; i < ArraySize(tempSymbols); i++)
+ 147    {
+ 148       if(SymbolSelect(tempSymbols[i], true))
+ 149       {
+ 150          g_symbols[g_symbolCount] = tempSymbols[i];
+ 151          g_lastTradeTime[g_symbolCount] = 0;
+ 152          g_symbolCount++;
+ 153       }
+ 154       else
+ 155       {
+ 156          // Try with suffix variations
+ 157          string variations[] = {tempSymbols[i] + ".a", tempSymbols[i] + "m", tempSymbols[i] + "_"};
+ 158          for(int j = 0; j < ArraySize(variations); j++)
+ 159          {
+ 160             if(SymbolSelect(variations[j], true))
+ 161             {
+ 162                g_symbols[g_symbolCount] = variations[j];
+ 163                g_lastTradeTime[g_symbolCount] = 0;
+ 164                g_symbolCount++;
+ 165                break;
+ 166             }
+ 167          }
+ 168       }
+ 169    }
+ 170    
+ 171    ArrayResize(g_symbols, g_symbolCount);
+ 172    ArrayResize(g_lastTradeTime, g_symbolCount);
+ 173    
+ 174    Print("Initialized ", g_symbolCount, " trading symbols");
+ 175 }
+ 176 
+ 177 //+------------------------------------------------------------------+
+ 178 //| Initialize RSI indicators for all symbols                         |
+ 179 //+------------------------------------------------------------------+
+ 180 void InitializeIndicators()
+ 181 {
+ 182    ArrayResize(g_rsiHandle, g_symbolCount);
+ 183    
+ 184    for(int i = 0; i < g_symbolCount; i++)
+ 185    {
+ 186       g_rsiHandle[i] = iRSI(g_symbols[i], PERIOD_M1, InpRSIPeriod, PRICE_CLOSE);
+ 187       if(g_rsiHandle[i] == INVALID_HANDLE)
+ 188       {
+ 189          Print("Failed to create RSI handle for ", g_symbols[i]);
+ 190       }
+ 191    }
+ 192 }
+ 193 
+ 194 //+------------------------------------------------------------------+
+ 195 //| Initialize correlation pairs                                      |
+ 196 //+------------------------------------------------------------------+
+ 197 void InitializeCorrelations()
+ 198 {
+ 199    // Define correlated pairs for hedging protection
+ 200    ArrayResize(g_corrPairs, 10);
+ 201    
+ 202    // Crypto correlations
+ 203    g_corrPairs[0][0] = "BTCUSD"; g_corrPairs[0][1] = "ETHUSD"; g_corrPairs[0][2] = "SOLUSD";
+ 204    g_corrPairs[1][0] = "ETHUSD"; g_corrPairs[1][1] = "BTCUSD"; g_corrPairs[1][2] = "SOLUSD";
+ 205    
+ 206    // Forex correlations
+ 207    g_corrPairs[2][0] = "EURUSD"; g_corrPairs[2][1] = "GBPUSD"; g_corrPairs[2][2] = "";
+ 208    g_corrPairs[3][0] = "GBPUSD"; g_corrPairs[3][1] = "EURUSD"; g_corrPairs[3][2] = "";
+ 209    g_corrPairs[4][0] = "AUDUSD"; g_corrPairs[4][1] = "NZDUSD"; g_corrPairs[4][2] = "";
+ 210    g_corrPairs[5][0] = "NZDUSD"; g_corrPairs[5][1] = "AUDUSD"; g_corrPairs[5][2] = "";
+ 211    g_corrPairs[6][0] = "EURJPY"; g_corrPairs[6][1] = "GBPJPY"; g_corrPairs[6][2] = "";
+ 212    g_corrPairs[7][0] = "GBPJPY"; g_corrPairs[7][1] = "EURJPY"; g_corrPairs[7][2] = "";
+ 213    
+ 214    // Metals correlation
+ 215    g_corrPairs[8][0] = "XAUUSD"; g_corrPairs[8][1] = "XAGUSD"; g_corrPairs[8][2] = "";
+ 216    g_corrPairs[9][0] = "XAGUSD"; g_corrPairs[9][1] = "XAUUSD"; g_corrPairs[9][2] = "";
+ 217 }
+ 218 
+ 219 //+------------------------------------------------------------------+
+ 220 //| Expert deinitialization function                                  |
+ 221 //+------------------------------------------------------------------+
+ 222 void OnDeinit(const int reason)
+ 223 {
+ 224    // Release indicator handles
+ 225    for(int i = 0; i < g_symbolCount; i++)
+ 226    {
+ 227       if(g_rsiHandle[i] != INVALID_HANDLE)
+ 228          IndicatorRelease(g_rsiHandle[i]);
+ 229    }
+ 230    
+ 231    Print("===========================================");
+ 232    Print("  HFT ULTRA 2026 - Final Statistics");
+ 233    Print("===========================================");
+ 234    Print("Total Trades: ", g_totalWins + g_totalLosses);
+ 235    Print("Wins: ", g_totalWins, " | Losses: ", g_totalLosses);
+ 236    if(g_totalWins + g_totalLosses > 0)
+ 237       Print("Win Rate: ", NormalizeDouble((double)g_totalWins / (g_totalWins + g_totalLosses) * 100, 1), "%");
+ 238    if(g_grossLoss > 0)
+ 239       Print("Profit Factor: ", NormalizeDouble(g_grossWin / g_grossLoss, 2));
+ 240    Print("===========================================");
+ 241 }
+ 242 
+ 243 //+------------------------------------------------------------------+
+ 244 //| Expert tick function                                              |
+ 245 //+------------------------------------------------------------------+
+ 246 void OnTick()
+ 247 {
+ 248    // Check for new day - reset daily stats
+ 249    datetime today = iTime(_Symbol, PERIOD_D1, 0);
+ 250    if(today != g_currentDay)
+ 251    {
+ 252       g_currentDay = today;
+ 253       g_dailyStartEquity = accountInfo.Equity();
+ 254       Print("New trading day - Daily equity reset: ", g_dailyStartEquity);
+ 255    }
+ 256    
+ 257    // Update peak equity
+ 258    double currentEquity = accountInfo.Equity();
+ 259    if(currentEquity > g_peakEquity)
+ 260       g_peakEquity = currentEquity;
+ 261    
+ 262    // Check Risk Shield
+ 263    if(!CheckRiskShield())
+ 264    {
+ 265       return; // Trading halted by risk shield
+ 266    }
+ 267    
+ 268    // Manage existing positions (trailing stops)
+ 269    ManagePositions();
+ 270    
+ 271    // Look for new trading opportunities
+ 272    ScanForSignals();
+ 273 }
+ 274 
+ 275 //+------------------------------------------------------------------+
+ 276 //| Risk Shield - Circuit Breakers                                    |
+ 277 //+------------------------------------------------------------------+
+ 278 bool CheckRiskShield()
+ 279 {
+ 280    double currentEquity = accountInfo.Equity();
+ 281    
+ 282    // Check max drawdown from peak
+ 283    double drawdownPct = (g_peakEquity - currentEquity) / g_peakEquity * 100;
+ 284    if(drawdownPct >= InpMaxDrawdown)
+ 285    {
+ 286       static datetime lastDDWarning = 0;
+ 287       if(TimeCurrent() - lastDDWarning > 300) // Warn every 5 minutes
+ 288       {
+ 289          Print("RISK SHIELD: Max drawdown reached (", NormalizeDouble(drawdownPct, 2), "%) - Trading HALTED");
+ 290          lastDDWarning = TimeCurrent();
+ 291       }
+ 292       return false;
+ 293    }
+ 294    
+ 295    // Check daily loss limit
+ 296    double dailyPnL = currentEquity - g_dailyStartEquity;
+ 297    double dailyLossPct = MathAbs(dailyPnL) / g_dailyStartEquity * 100;
+ 298    if(dailyPnL < 0 && dailyLossPct >= InpDailyLossLimit)
+ 299    {
+ 300       static datetime lastDailyWarning = 0;
+ 301       if(TimeCurrent() - lastDailyWarning > 300)
+ 302       {
+ 303          Print("RISK SHIELD: Daily loss limit reached (", NormalizeDouble(dailyLossPct, 2), "%) - Trading HALTED");
+ 304          lastDailyWarning = TimeCurrent();
+ 305       }
+ 306       return false;
+ 307    }
+ 308    
+ 309    return true;
+ 310 }
+ 311 
+ 312 //+------------------------------------------------------------------+
+ 313 //| Count positions by magic number                                   |
+ 314 //+------------------------------------------------------------------+
+ 315 int CountPositions()
+ 316 {
+ 317    int count = 0;
+ 318    for(int i = PositionsTotal() - 1; i >= 0; i--)
+ 319    {
+ 320       if(posInfo.SelectByIndex(i))
+ 321       {
+ 322          if(posInfo.Magic() == InpMagicNumber)
+ 323             count++;
+ 324       }
+ 325    }
+ 326    return count;
+ 327 }
+ 328 
+ 329 //+------------------------------------------------------------------+
+ 330 //| Check if we have position on symbol or correlated symbol          |
+ 331 //+------------------------------------------------------------------+
+ 332 bool HasCorrelatedPosition(string symbol)
+ 333 {
+ 334    if(!InpUseCorrelation)
+ 335       return HasPositionOnSymbol(symbol);
+ 336    
+ 337    // Check for position on same symbol
+ 338    if(HasPositionOnSymbol(symbol))
+ 339       return true;
+ 340    
+ 341    // Find correlated pairs
+ 342    for(int i = 0; i < ArrayRange(g_corrPairs, 0); i++)
+ 343    {
+ 344       if(g_corrPairs[i][0] == symbol)
+ 345       {
+ 346          // Check correlated symbols
+ 347          if(g_corrPairs[i][1] != "" && HasPositionOnSymbol(g_corrPairs[i][1]))
+ 348             return true;
+ 349          if(g_corrPairs[i][2] != "" && HasPositionOnSymbol(g_corrPairs[i][2]))
+ 350             return true;
+ 351          break;
+ 352       }
+ 353    }
+ 354    
+ 355    return false;
+ 356 }
+ 357 
+ 358 //+------------------------------------------------------------------+
+ 359 //| Check if we have position on specific symbol                      |
+ 360 //+------------------------------------------------------------------+
+ 361 bool HasPositionOnSymbol(string symbol)
+ 362 {
+ 363    for(int i = PositionsTotal() - 1; i >= 0; i--)
+ 364    {
+ 365       if(posInfo.SelectByIndex(i))
+ 366       {
+ 367          if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == symbol)
+ 368             return true;
+ 369       }
+ 370    }
+ 371    return false;
+ 372 }
+ 373 
+ 374 //+------------------------------------------------------------------+
+ 375 //| Get RSI value for symbol                                          |
+ 376 //+------------------------------------------------------------------+
+ 377 double GetRSI(int symbolIndex)
+ 378 {
+ 379    if(symbolIndex < 0 || symbolIndex >= g_symbolCount)
+ 380       return 50;
+ 381    
+ 382    if(g_rsiHandle[symbolIndex] == INVALID_HANDLE)
+ 383       return 50;
+ 384    
+ 385    double rsiBuffer[];
+ 386    ArraySetAsSeries(rsiBuffer, true);
+ 387    
+ 388    if(CopyBuffer(g_rsiHandle[symbolIndex], 0, 0, 1, rsiBuffer) <= 0)
+ 389       return 50;
+ 390    
+ 391    return rsiBuffer[0];
+ 392 }
+ 393 
+ 394 //+------------------------------------------------------------------+
+ 395 //| Calculate Momentum (Rate of Change)                               |
+ 396 //+------------------------------------------------------------------+
+ 397 double GetMomentum(string symbol, int periods = 10)
+ 398 {
+ 399    double closes[];
+ 400    ArraySetAsSeries(closes, true);
+ 401    
+ 402    if(CopyClose(symbol, PERIOD_M1, 0, periods + 1, closes) < periods + 1)
+ 403       return 0;
+ 404    
+ 405    if(closes[periods] == 0)
+ 406       return 0;
+ 407    
+ 408    return ((closes[0] - closes[periods]) / closes[periods]) * 100;
+ 409 }
+ 410 
+ 411 //+------------------------------------------------------------------+
+ 412 //| Calculate Volatility (ATR-like)                                   |
+ 413 //+------------------------------------------------------------------+
+ 414 double GetVolatility(string symbol, int periods = 10)
+ 415 {
+ 416    double closes[];
+ 417    ArraySetAsSeries(closes, true);
+ 418    
+ 419    if(CopyClose(symbol, PERIOD_M1, 0, periods + 1, closes) < periods + 1)
+ 420       return 0;
+ 421    
+ 422    double sum = 0;
+ 423    for(int i = 0; i < periods; i++)
+ 424    {
+ 425       sum += MathAbs(closes[i] - closes[i + 1]);
+ 426    }
+ 427    
+ 428    return sum / periods;
+ 429 }
+ 430 
+ 431 //+------------------------------------------------------------------+
+ 432 //| Get 20-period Moving Average                                      |
+ 433 //+------------------------------------------------------------------+
+ 434 double GetMA20(string symbol)
+ 435 {
+ 436    double closes[];
+ 437    ArraySetAsSeries(closes, true);
+ 438    
+ 439    if(CopyClose(symbol, PERIOD_M1, 0, 20, closes) < 20)
+ 440       return 0;
+ 441    
+ 442    double sum = 0;
+ 443    for(int i = 0; i < 20; i++)
+ 444       sum += closes[i];
+ 445    
+ 446    return sum / 20;
+ 447 }
+ 448 
+ 449 //+------------------------------------------------------------------+
+ 450 //| Get symbol index                                                  |
+ 451 //+------------------------------------------------------------------+
+ 452 int GetSymbolIndex(string symbol)
+ 453 {
+ 454    for(int i = 0; i < g_symbolCount; i++)
+ 455    {
+ 456       if(g_symbols[i] == symbol)
+ 457          return i;
+ 458    }
+ 459    return -1;
+ 460 }
+ 461 
+ 462 //+------------------------------------------------------------------+
+ 463 //| Generate trading signal for symbol                                |
+ 464 //+------------------------------------------------------------------+
+ 465 void GetSignal(string symbol, int symbolIndex, int &signalType, int &strength, int &score)
+ 466 {
+ 467    signalType = 0; // 0 = none, 1 = buy, -1 = sell
+ 468    strength = 0;
+ 469    score = 0;
+ 470    
+ 471    if(!symbolInfo.Name(symbol))
+ 472       return;
+ 473    
+ 474    symbolInfo.RefreshRates();
+ 475    
+ 476    double bid = symbolInfo.Bid();
+ 477    double ask = symbolInfo.Ask();
+ 478    double point = symbolInfo.Point();
+ 479    double spread = (ask - bid) / point;
+ 480    
+ 481    // Spread filter
+ 482    if(spread > InpMaxSpread * 10) // Convert pips to points
+ 483       return;
+ 484    
+ 485    // Get indicators
+ 486    double rsi = GetRSI(symbolIndex);
+ 487    double momentum = GetMomentum(symbol);
+ 488    double volatility = GetVolatility(symbol);
+ 489    double ma20 = GetMA20(symbol);
+ 490    double midPrice = (bid + ask) / 2;
+ 491    
+ 492    // 1. RSI Strategy (Oversold/Overbought)
+ 493    if(rsi < InpRSIOversold)
+ 494    {
+ 495       score += 20;
+ 496       strength++;
+ 497    }
+ 498    else if(rsi > InpRSIOverbought)
+ 499    {
+ 500       score -= 20;
+ 501       strength++;
+ 502    }
+ 503    else if(rsi < 40)
+ 504    {
+ 505       score += 10;
+ 506    }
+ 507    else if(rsi > 60)
+ 508    {
+ 509       score -= 10;
+ 510    }
+ 511    
+ 512    // 2. Momentum Confirmation
+ 513    if(momentum > 0.05 && rsi < 50)
+ 514    {
+ 515       score += 15;
+ 516       strength++;
+ 517    }
+ 518    else if(momentum < -0.05 && rsi > 50)
+ 519    {
+ 520       score -= 15;
+ 521       strength++;
+ 522    }
+ 523    
+ 524    // 3. Trend Following (price above/below MA)
+ 525    if(ma20 > 0)
+ 526    {
+ 527       if(midPrice > ma20 && momentum > 0)
+ 528       {
+ 529          score += 12;
+ 530          strength++;
+ 531       }
+ 532       else if(midPrice < ma20 && momentum < 0)
+ 533       {
+ 534          score -= 12;
+ 535          strength++;
+ 536       }
+ 537    }
+ 538    
+ 539    // 4. Volatility Filter - prefer low volatility entries
+ 540    if(volatility < midPrice * 0.001)
+ 541    {
+ 542       strength++;
+ 543    }
+ 544    
+ 545    // 5. Price change momentum (using recent close comparison)
+ 546    double closes[];
+ 547    ArraySetAsSeries(closes, true);
+ 548    if(CopyClose(symbol, PERIOD_H1, 0, 2, closes) >= 2)
+ 549    {
+ 550       double hourChange = ((closes[0] - closes[1]) / closes[1]) * 100;
+ 551       if(hourChange > 0.5 && rsi < 60)
+ 552       {
+ 553          score += 10;
+ 554          strength++;
+ 555       }
+ 556       else if(hourChange < -0.5 && rsi > 40)
+ 557       {
+ 558          score -= 10;
+ 559          strength++;
+ 560       }
+ 561    }
+ 562    
+ 563    // 6. Check correlation with major pairs
+ 564    if(StringFind(symbol, "BTC") < 0 && StringFind(symbol, "ETH") < 0)
+ 565    {
+ 566       // For forex, check correlation with EUR/USD
+ 567       int eurusdIdx = GetSymbolIndex("EURUSD");
+ 568       if(eurusdIdx >= 0)
+ 569       {
+ 570          double eurusdMom = GetMomentum(g_symbols[eurusdIdx]);
+ 571          if((momentum > 0 && eurusdMom > 0) || (momentum < 0 && eurusdMom < 0))
+ 572             strength++;
+ 573       }
+ 574    }
+ 575    
+ 576    // 7. Cross-pair confirmation
+ 577    for(int i = 0; i < ArrayRange(g_corrPairs, 0); i++)
+ 578    {
+ 579       if(g_corrPairs[i][0] == symbol)
+ 580       {
+ 581          for(int j = 1; j <= 2; j++)
+ 582          {
+ 583             if(g_corrPairs[i][j] != "")
+ 584             {
+ 585                double corrMom = GetMomentum(g_corrPairs[i][j]);
+ 586                if((score > 0 && corrMom > 0) || (score < 0 && corrMom < 0))
+ 587                   strength++;
+ 588             }
+ 589          }
+ 590          break;
+ 591       }
+ 592    }
+ 593    
+ 594    // Determine signal
+ 595    if(score >= InpMinScore && strength >= InpMinStrength)
+ 596       signalType = 1; // BUY
+ 597    else if(score <= -InpMinScore && strength >= InpMinStrength)
+ 598       signalType = -1; // SELL
+ 599 }
+ 600 
+ 601 //+------------------------------------------------------------------+
+ 602 //| Calculate dynamic lot size                                        |
+ 603 //+------------------------------------------------------------------+
+ 604 double CalculateLotSize(string symbol)
+ 605 {
+ 606    if(!InpDynamicLots)
+ 607       return InpBaseLot;
+ 608    
+ 609    double lot = InpBaseLot;
+ 610    
+ 611    // Volatility adjustment
+ 612    double volatility = GetVolatility(symbol);
+ 613    symbolInfo.Name(symbol);
+ 614    double midPrice = (symbolInfo.Bid() + symbolInfo.Ask()) / 2;
+ 615    
+ 616    if(midPrice > 0)
+ 617    {
+ 618       double volFactor = MathMax(0.5, 1.0 - (volatility / midPrice) * 100);
+ 619       lot *= volFactor;
+ 620    }
+ 621    
+ 622    // Streak adjustment - reduce after consecutive losses
+ 623    if(g_streak < -2)
+ 624       lot *= 0.5;
+ 625    
+ 626    // Normalize lot size
+ 627    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
+ 628    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
+ 629    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
+ 630    
+ 631    lot = MathMax(InpMinLot, MathMin(InpMaxLot, lot));
+ 632    lot = MathMax(minLot, MathMin(maxLot, lot));
+ 633    lot = NormalizeDouble(MathFloor(lot / lotStep) * lotStep, 2);
+ 634    
+ 635    return lot;
+ 636 }
+ 637 
+ 638 //+------------------------------------------------------------------+
+ 639 //| Scan all symbols for trading signals                              |
+ 640 //+------------------------------------------------------------------+
+ 641 void ScanForSignals()
+ 642 {
+ 643    // Check max positions
+ 644    if(CountPositions() >= InpMaxPositions)
+ 645       return;
+ 646    
+ 647    for(int i = 0; i < g_symbolCount; i++)
+ 648    {
+ 649       string symbol = g_symbols[i];
+ 650       
+ 651       // Cooldown check
+ 652       if(TimeCurrent() - g_lastTradeTime[i] < InpCooldownSec)
+ 653          continue;
+ 654       
+ 655       // Skip if we have position on this or correlated symbol
+ 656       if(HasCorrelatedPosition(symbol))
+ 657          continue;
+ 658       
+ 659       // Check max positions again (might have changed)
+ 660       if(CountPositions() >= InpMaxPositions)
+ 661          return;
+ 662       
+ 663       // Get signal
+ 664       int signalType, strength, score;
+ 665       GetSignal(symbol, i, signalType, strength, score);
+ 666       
+ 667       if(signalType == 0)
+ 668          continue;
+ 669       
+ 670       // Prepare for trade
+ 671       if(!symbolInfo.Name(symbol))
+ 672          continue;
+ 673       
+ 674       symbolInfo.RefreshRates();
+ 675       
+ 676       double point = symbolInfo.Point();
+ 677       int digits = (int)symbolInfo.Digits();
+ 678       double bid = symbolInfo.Bid();
+ 679       double ask = symbolInfo.Ask();
+ 680       
+ 681       // Calculate pip value (handle 5-digit and 3-digit brokers)
+ 682       double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
+ 683       double pipValue = point * pipMultiplier;
+ 684       
+ 685       // Calculate lot size
+ 686       double lotSize = CalculateLotSize(symbol);
+ 687       
+ 688       // Calculate SL and TP
+ 689       double sl, tp;
+ 690       
+ 691       if(signalType == 1) // BUY
+ 692       {
+ 693          double entryPrice = ask;
+ 694          sl = NormalizeDouble(entryPrice - InpStopLoss * pipValue, digits);
+ 695          tp = NormalizeDouble(entryPrice + InpTakeProfit * pipValue, digits);
+ 696          
+ 697          if(trade.Buy(lotSize, symbol, entryPrice, sl, tp, InpComment))
+ 698          {
+ 699             g_lastTradeTime[i] = TimeCurrent();
+ 700             Print("BUY ", symbol, " @ ", entryPrice, " | Lot: ", lotSize, 
+ 701                   " | Strength: ", strength, " | Score: ", score);
+ 702          }
+ 703          else
+ 704          {
+ 705             Print("Buy order failed for ", symbol, ": ", GetLastError());
+ 706          }
+ 707       }
+ 708       else if(signalType == -1) // SELL
+ 709       {
+ 710          double entryPrice = bid;
+ 711          sl = NormalizeDouble(entryPrice + InpStopLoss * pipValue, digits);
+ 712          tp = NormalizeDouble(entryPrice - InpTakeProfit * pipValue, digits);
+ 713          
+ 714          if(trade.Sell(lotSize, symbol, entryPrice, sl, tp, InpComment))
+ 715          {
+ 716             g_lastTradeTime[i] = TimeCurrent();
+ 717             Print("SELL ", symbol, " @ ", entryPrice, " | Lot: ", lotSize,
+ 718                   " | Strength: ", strength, " | Score: ", score);
+ 719          }
+ 720          else
+ 721          {
+ 722             Print("Sell order failed for ", symbol, ": ", GetLastError());
+ 723          }
+ 724       }
+ 725    }
+ 726 }
+ 727 
+ 728 //+------------------------------------------------------------------+
+ 729 //| Manage existing positions - trailing stops                        |
+ 730 //+------------------------------------------------------------------+
+ 731 void ManagePositions()
+ 732 {
+ 733    for(int i = PositionsTotal() - 1; i >= 0; i--)
+ 734    {
+ 735       if(!posInfo.SelectByIndex(i))
+ 736          continue;
+ 737       
+ 738       if(posInfo.Magic() != InpMagicNumber)
+ 739          continue;
+ 740       
+ 741       string symbol = posInfo.Symbol();
+ 742       
+ 743       if(!symbolInfo.Name(symbol))
+ 744          continue;
+ 745       
+ 746       symbolInfo.RefreshRates();
+ 747       
+ 748       double point = symbolInfo.Point();
+ 749       int digits = (int)symbolInfo.Digits();
+ 750       double bid = symbolInfo.Bid();
+ 751       double ask = symbolInfo.Ask();
+ 752       double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
+ 753       double pipValue = point * pipMultiplier;
+ 754       
+ 755       double openPrice = posInfo.PriceOpen();
+ 756       double currentSL = posInfo.StopLoss();
+ 757       double currentTP = posInfo.TakeProfit();
+ 758       
+ 759       ENUM_POSITION_TYPE posType = posInfo.PositionType();
+ 760       
+ 761       // Calculate current profit in pips
+ 762       double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
+ 763       double profitPips;
+ 764       
+ 765       if(posType == POSITION_TYPE_BUY)
+ 766          profitPips = (currentPrice - openPrice) / pipValue;
+ 767       else
+ 768          profitPips = (openPrice - currentPrice) / pipValue;
+ 769       
+ 770       // Check if trailing should activate
+ 771       if(profitPips >= InpTrailStart)
+ 772       {
+ 773          double newSL;
+ 774          double trailDistance = InpTrailStart * pipValue * InpTrailFactor;
+ 775          
+ 776          if(posType == POSITION_TYPE_BUY)
+ 777          {
+ 778             newSL = NormalizeDouble(currentPrice - trailDistance, digits);
+ 779             
+ 780             // Only modify if new SL is higher than current
+ 781             if(newSL > currentSL + point)
+ 782             {
+ 783                if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
+ 784                {
+ 785                   Print("Trailing stop updated for ", symbol, " (BUY) | New SL: ", newSL);
+ 786                }
+ 787             }
+ 788          }
+ 789          else // SELL
+ 790          {
+ 791             newSL = NormalizeDouble(currentPrice + trailDistance, digits);
+ 792             
+ 793             // Only modify if new SL is lower than current
+ 794             if(newSL < currentSL - point || currentSL == 0)
+ 795             {
+ 796                if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
+ 797                {
+ 798                   Print("Trailing stop updated for ", symbol, " (SELL) | New SL: ", newSL);
+ 799                }
+ 800             }
+ 801          }
+ 802       }
+ 803    }
+ 804 }
+ 805 
+ 806 //+------------------------------------------------------------------+
+ 807 //| Trade transaction event handler                                   |
+ 808 //+------------------------------------------------------------------+
+ 809 void OnTradeTransaction(const MqlTradeTransaction& trans,
+ 810                         const MqlTradeRequest& request,
+ 811                         const MqlTradeResult& result)
+ 812 {
+ 813    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
+ 814    {
+ 815       // A deal was added
+ 816       ulong dealTicket = trans.deal;
+ 817       
+ 818       if(dealTicket > 0)
+ 819       {
+ 820          if(HistoryDealSelect(dealTicket))
+ 821          {
+ 822             long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
+ 823             
+ 824             if(magic == InpMagicNumber)
+ 825             {
+ 826                ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
+ 827                
+ 828                if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
+ 829                {
+ 830                   // Position was closed
+ 831                   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
+ 832                   double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
+ 833                   double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
+ 834                   double netProfit = profit + commission + swap;
+ 835                   string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
+ 836                   
+ 837                   if(netProfit > 0)
+ 838                   {
+ 839                      g_totalWins++;
+ 840                      g_grossWin += netProfit;
+ 841                      g_streak = (g_streak > 0) ? g_streak + 1 : 1;
+ 842                      Print("WIN: ", symbol, " | Profit: $", NormalizeDouble(netProfit, 2), 
+ 843                            " | Streak: +", g_streak);
+ 844                   }
+ 845                   else
+ 846                   {
+ 847                      g_totalLosses++;
+ 848                      g_grossLoss += MathAbs(netProfit);
+ 849                      g_streak = (g_streak < 0) ? g_streak - 1 : -1;
+ 850                      Print("LOSS: ", symbol, " | Loss: $", NormalizeDouble(netProfit, 2),
+ 851                            " | Streak: ", g_streak);
+ 852                   }
+ 853                   
+ 854                   // Print statistics
+ 855                   int total = g_totalWins + g_totalLosses;
+ 856                   if(total > 0)
+ 857                   {
+ 858                      double winRate = (double)g_totalWins / total * 100;
+ 859                      double pf = (g_grossLoss > 0) ? g_grossWin / g_grossLoss : 0;
+ 860                      Print("Stats | Trades: ", total, " | Win%: ", NormalizeDouble(winRate, 1),
+ 861                            "% | PF: ", NormalizeDouble(pf, 2));
+ 862                   }
+ 863                }
+ 864             }
+ 865          }
+ 866       }
+ 867    }
+ 868 }
+ 869 
+ 870 //+------------------------------------------------------------------+
+ 871 //| Timer function (optional - for periodic tasks)                    |
+ 872 //+------------------------------------------------------------------+
+ 873 void OnTimer()
+ 874 {
+ 875    // Can be used for periodic statistics display
+ 876 }
+ 877 
+ 878 //+------------------------------------------------------------------+
+ 879 //| ChartEvent function (optional - for GUI)                          |
+ 880 //+------------------------------------------------------------------+
+ 881 void OnChartEvent(const int id,
+ 882                   const long &lparam,
+ 883                   const double &dparam,
+ 884                   const string &sparam)
+ 885 {
+ 886    // Can be used for chart interactions
+ 887 }
+ 888 //+------------------------------------------------------------------+
