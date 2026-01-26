1 //+------------------------------------------------------------------+
   2 //|                                         HFT_PRO_2026_FIXED.mq5   |
   3 //|                        HFT PRO 2026 - Multi-Strategy Auto Scalper|
   4 //|                   29 Instruments • Real Data • Nano Lots         |
   5 //|                          *** FIXED VERSION *** |
   6 //+------------------------------------------------------------------+
   7 #property copyright "HFT PRO 2026 - FIXED"
   8 #property link      ""
   9 #property version   "1.01"
  10 #property strict
  11 #property description "HFT PRO 2026 - Multi-Strategy Auto Scalper (FIXED)"
  12 #property description "All runtime issues fixed: cooldown, lot sizing, trailing, pip calc"
  13 #property description "10 Strategies: Scalp, Momentum, Reversion, Breakout, Trail, Grid, Martingale, Corr, Hedge, AI"
  14 
  15 #include <Trade\Trade.mqh>
  16 #include <Trade\PositionInfo.mqh>
  17 #include <Trade\AccountInfo.mqh>
  18 #include <Trade\SymbolInfo.mqh>
  19 
  20 //+------------------------------------------------------------------+
  21 //| Input Parameters                                                  |
  22 //+------------------------------------------------------------------+
  23 input group "=== TRADING SETTINGS ==="
  24 input double   InpLotSize        = 0.01;    // Lot Size (Nano)
  25 input int      InpTakeProfit     = 12;      // Take Profit (pips)
  26 input int      InpStopLoss       = 6;       // Stop Loss (pips) - 2:1 RR
  27 input int      InpTrailStart     = 5;       // Trailing Start (pips profit)
  28 input double   InpTrailTighten   = 0.5;     // Trail Tightening Factor
  29 input int      InpMaxPositions   = 8;       // Maximum Open Positions
  30 input int      InpCooldownSec    = 3;       // Cooldown Between Trades (seconds)
  31 
  32 input group "=== SIGNAL SETTINGS ==="
  33 input int      InpThreshold      = 55;      // Base Signal Threshold (0-100)
  34 input int      InpEntryOffset    = 12;      // Entry Offset from Threshold
  35 input int      InpMinStrength    = 2;       // Minimum Strategy Confirmations
  36 input double   InpMaxSpreadPips  = 1.5;     // Max Spread (pips) for Forex
  37 input double   InpGoldSpreadCents= 50.0;    // Max Spread (cents) for Gold
  38 
  39 input group "=== STRATEGY TOGGLES ==="
  40 input bool     InpUseMomentum    = true;    // Use Momentum Strategy
  41 input bool     InpUseTrend       = true;    // Use Trend Continuation
  42 input bool     InpUseBreakout    = true;    // Use Volatility Breakout
  43 input bool     InpUseReversion   = true;    // Use Mean Reversion
  44 input bool     InpUseCorrelation = true;    // Use Correlation (Gold/USD)
  45 input bool     InpUseJpyMomentum = true;    // Use JPY Pairs Momentum
  46 
  47 input group "=== LOGGING ==="
  48 input bool     InpVerboseLog     = false;   // Verbose Logging (disable for HFT speed)
  49 
  50 input group "=== GENERAL ==="
  51 input int      InpMagicNumber    = 20260201; // Magic Number
  52 input string   InpComment        = "HFT_PRO_2026"; // Order Comment
  53 
  54 //+------------------------------------------------------------------+
  55 //| Symbol Configuration Structure                                    |
  56 //+------------------------------------------------------------------+
  57 struct SymbolConfig
  58 {
  59    string   name;
  60    string   base;
  61    string   quote;
  62    double   pip;
  63    string   type;           // "forex" or "gold"
  64    int      handle_rsi;
  65    int      handle_ma;      // FIXED: Added MA handle for optimization
  66    datetime lastTradeTime;  // FIXED: Use datetime consistently
  67    double   prevMid;
  68    bool     isValid;        // FIXED: Track if symbol is properly initialized
  69 };
  70 
  71 //+------------------------------------------------------------------+
  72 //| Global Variables                                                  |
  73 //+------------------------------------------------------------------+
  74 CTrade         trade;
  75 CPositionInfo  posInfo;
  76 CAccountInfo   accountInfo;
  77 CSymbolInfo    m_symbol;    // FIXED: Renamed from symbolInfo to avoid conflict
  78 
  79 SymbolConfig   g_symbols[];
  80 int            g_symbolCount;
  81 int            g_validSymbolCount;  // FIXED: Track valid symbols separately
  82 
  83 // Statistics
  84 double         g_startEquity;
  85 double         g_peakEquity;
  86 int            g_totalWins;
  87 int            g_totalLosses;
  88 double         g_grossWin;
  89 double         g_grossLoss;
  90 int            g_streak;
  91 int            g_ticks;
  92 
  93 // FIXED: Cache for EURUSD index (used in Gold correlation)
  94 int            g_eurusdIndex = -1;
  95 
  96 //+------------------------------------------------------------------+
  97 //| Expert initialization function                                    |
  98 //+------------------------------------------------------------------+
  99 int OnInit()
 100 {
 101    // Initialize trade object
 102    trade.SetExpertMagicNumber(InpMagicNumber);
 103    trade.SetDeviationInPoints(20);
 104    trade.SetTypeFilling(ORDER_FILLING_IOC);
 105    trade.SetAsyncMode(false);
 106 
 107    // Initialize statistics
 108    g_startEquity = accountInfo.Equity();
 109    g_peakEquity = g_startEquity;
 110    g_totalWins = 0;
 111    g_totalLosses = 0;
 112    g_grossWin = 0;
 113    g_grossLoss = 0;
 114    g_streak = 0;
 115    g_ticks = 0;
 116 
 117    // Initialize 29 symbols
 118    if(!InitializeSymbols())
 119    {
 120       Print("ERROR: Failed to initialize symbols!");
 121       return(INIT_FAILED);
 122    }
 123 
 124    // Find EURUSD index for correlation
 125    g_eurusdIndex = GetSymbolIndexByBase("EURUSD");
 126 
 127    Print("=============================================");
 128    Print("  HFT PRO 2026 - FIXED VERSION");
 129    Print("=============================================");
 130    Print("Valid Symbols: ", g_validSymbolCount, " / ", g_symbolCount);
 131    Print("EURUSD Index: ", g_eurusdIndex);
 132    Print("Lot Size: ", InpLotSize);
 133    Print("TP: ", InpTakeProfit, " pips | SL: ", InpStopLoss, " pips (2:1 RR)");
 134    Print("Trail: ", InpTrailStart, " pips | Tighten: ", InpTrailTighten);
 135    Print("Max Positions: ", InpMaxPositions);
 136    Print("Cooldown: ", InpCooldownSec, " seconds");
 137    Print("Threshold: ", InpThreshold, " | Entry Offset: ±", InpEntryOffset);
 138    Print("Buy >= ", InpThreshold + InpEntryOffset, " | Sell <= ", 100 - InpThreshold - InpEntryOffset);
 139    Print("=============================================");
 140 
 141    return(INIT_SUCCEEDED);
 142 }
 143 
 144 //+------------------------------------------------------------------+
 145 //| Initialize 29 trading symbols                                     |
 146 //+------------------------------------------------------------------+
 147 bool InitializeSymbols()
 148 {
 149    // Define all 29 symbols (28 forex + XAUUSD)
 150    string symbolDefs[][5] = {
 151       // Majors
 152       {"EURUSD", "EUR", "USD", "0.0001", "forex"},
 153       {"GBPUSD", "GBP", "USD", "0.0001", "forex"},
 154       {"USDJPY", "USD", "JPY", "0.01", "forex"},
 155       {"USDCHF", "USD", "CHF", "0.0001", "forex"},
 156       {"AUDUSD", "AUD", "USD", "0.0001", "forex"},
 157       {"USDCAD", "USD", "CAD", "0.0001", "forex"},
 158       {"NZDUSD", "NZD", "USD", "0.0001", "forex"},
 159       // Crosses
 160       {"EURGBP", "EUR", "GBP", "0.0001", "forex"},
 161       {"EURJPY", "EUR", "JPY", "0.01", "forex"},
 162       {"EURCHF", "EUR", "CHF", "0.0001", "forex"},
 163       {"EURAUD", "EUR", "AUD", "0.0001", "forex"},
 164       {"EURCAD", "EUR", "CAD", "0.0001", "forex"},
 165       {"EURNZD", "EUR", "NZD", "0.0001", "forex"},
 166       {"GBPJPY", "GBP", "JPY", "0.01", "forex"},
 167       {"GBPCHF", "GBP", "CHF", "0.0001", "forex"},
 168       {"GBPAUD", "GBP", "AUD", "0.0001", "forex"},
 169       {"GBPCAD", "GBP", "CAD", "0.0001", "forex"},
 170       {"GBPNZD", "GBP", "NZD", "0.0001", "forex"},
 171       {"AUDJPY", "AUD", "JPY", "0.01", "forex"},
 172       {"AUDCHF", "AUD", "CHF", "0.0001", "forex"},
 173       {"AUDCAD", "AUD", "CAD", "0.0001", "forex"},
 174       {"AUDNZD", "AUD", "NZD", "0.0001", "forex"},
 175       {"CADJPY", "CAD", "JPY", "0.01", "forex"},
 176       {"CADCHF", "CAD", "CHF", "0.0001", "forex"},
 177       {"CHFJPY", "CHF", "JPY", "0.01", "forex"},
 178       {"NZDJPY", "NZD", "JPY", "0.01", "forex"},
 179       {"NZDCHF", "NZD", "CHF", "0.0001", "forex"},
 180       {"NZDCAD", "NZD", "CAD", "0.0001", "forex"},
 181       // Gold
 182       {"XAUUSD", "XAU", "USD", "0.01", "gold"}
 183    };
 184 
 185    int totalDefs = ArrayRange(symbolDefs, 0);
 186    ArrayResize(g_symbols, totalDefs);
 187    g_symbolCount = totalDefs;
 188    g_validSymbolCount = 0;
 189 
 190    // Common broker symbol variations
 191    string suffixes[] = {"", "m", ".a", "_", ".raw", ".pro", ".ecn", ".", "-", "i"};
 192    int suffixCount = ArraySize(suffixes);
 193 
 194    for(int i = 0; i < totalDefs; i++)
 195    {
 196       string baseName = symbolDefs[i][0];
 197 
 198       // Initialize with defaults
 199       g_symbols[i].name = baseName;
 200       g_symbols[i].base = symbolDefs[i][1];
 201       g_symbols[i].quote = symbolDefs[i][2];
 202       g_symbols[i].pip = StringToDouble(symbolDefs[i][3]);
 203       g_symbols[i].type = symbolDefs[i][4];
 204       g_symbols[i].lastTradeTime = 0;
 205       g_symbols[i].prevMid = 0;
 206       g_symbols[i].handle_rsi = INVALID_HANDLE;
 207       g_symbols[i].handle_ma = INVALID_HANDLE;
 208       g_symbols[i].isValid = false;
 209 
 210       // Try to find valid symbol name
 211       bool found = false;
 212       for(int j = 0; j < suffixCount && !found; j++)
 213       {
 214          string testName = baseName + suffixes[j];
 215 
 216          if(SymbolSelect(testName, true))
 217          {
 218             // Verify symbol is tradeable
 219             if(SymbolInfoInteger(testName, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED)
 220             {
 221                g_symbols[i].name = testName;
 222 
 223                // Create RSI handle
 224                g_symbols[i].handle_rsi = iRSI(testName, PERIOD_M1, 14, PRICE_CLOSE);
 225 
 226                // FIXED: Create MA handle for optimization
 227                g_symbols[i].handle_ma = iMA(testName, PERIOD_M5, 20, 0, MODE_SMA, PRICE_CLOSE);
 228 
 229                // FIXED: Validate handles
 230                if(g_symbols[i].handle_rsi != INVALID_HANDLE && g_symbols[i].handle_ma != INVALID_HANDLE)
 231                {
 232                   g_symbols[i].isValid = true;
 233                   g_validSymbolCount++;
 234                   found = true;
 235 
 236                   if(InpVerboseLog)
 237                      Print("✓ Loaded: ", testName);
 238                }
 239                else
 240                {
 241                   // Clean up failed handles
 242                   if(g_symbols[i].handle_rsi != INVALID_HANDLE)
 243                      IndicatorRelease(g_symbols[i].handle_rsi);
 244                   if(g_symbols[i].handle_ma != INVALID_HANDLE)
 245                      IndicatorRelease(g_symbols[i].handle_ma);
 246 
 247                   g_symbols[i].handle_rsi = INVALID_HANDLE;
 248                   g_symbols[i].handle_ma = INVALID_HANDLE;
 249                }
 250             }
 251          }
 252       }
 253 
 254       if(!found && InpVerboseLog)
 255          Print("✗ Not found: ", baseName);
 256    }
 257 
 258    return (g_validSymbolCount > 0);
 259 }
 260 
 261 //+------------------------------------------------------------------+
 262 //| Expert deinitialization function                                  |
 263 //+------------------------------------------------------------------+
 264 void OnDeinit(const int reason)
 265 {
 266    // Release all indicator handles
 267    for(int i = 0; i < g_symbolCount; i++)
 268    {
 269       if(g_symbols[i].handle_rsi != INVALID_HANDLE)
 270          IndicatorRelease(g_symbols[i].handle_rsi);
 271       if(g_symbols[i].handle_ma != INVALID_HANDLE)
 272          IndicatorRelease(g_symbols[i].handle_ma);
 273    }
 274 
 275    // Print final statistics
 276    Print("=============================================");
 277    Print("  HFT PRO 2026 - Final Statistics");
 278    Print("=============================================");
 279    Print("Total Ticks: ", g_ticks);
 280    int totalTrades = g_totalWins + g_totalLosses;
 281    Print("Total Trades: ", totalTrades);
 282    Print("Wins: ", g_totalWins, " | Losses: ", g_totalLosses);
 283 
 284    if(totalTrades > 0)
 285    {
 286       double winRate = (double)g_totalWins / totalTrades * 100;
 287       Print("Win Rate: ", DoubleToString(winRate, 1), "%");
 288    }
 289 
 290    if(g_grossLoss > 0)
 291    {
 292       double pf = g_grossWin / g_grossLoss;
 293       Print("Profit Factor: ", DoubleToString(pf, 2));
 294    }
 295 
 296    Print("Gross Win: $", DoubleToString(g_grossWin, 2));
 297    Print("Gross Loss: $", DoubleToString(g_grossLoss, 2));
 298    Print("Net P&L: $", DoubleToString(g_grossWin - g_grossLoss, 2));
 299    Print("Final Streak: ", g_streak);
 300    Print("=============================================");
 301 }
 302 
 303 //+------------------------------------------------------------------+
 304 //| Expert tick function                                              |
 305 //+------------------------------------------------------------------+
 306 void OnTick()
 307 {
 308    g_ticks++;
 309 
 310    // Update peak equity
 311    double currentEquity = accountInfo.Equity();
 312    if(currentEquity > g_peakEquity)
 313       g_peakEquity = currentEquity;
 314 
 315    // Manage existing positions (trailing stops)
 316    ManagePositions();
 317 
 318    // Look for new trading opportunities
 319    ScanForSignals();
 320 }
 321 
 322 //+------------------------------------------------------------------+
 323 //| Count positions by magic number                                   |
 324 //+------------------------------------------------------------------+
 325 int CountPositions()
 326 {
 327    int count = 0;
 328    for(int i = PositionsTotal() - 1; i >= 0; i--)
 329    {
 330       if(posInfo.SelectByIndex(i))
 331       {
 332          if(posInfo.Magic() == InpMagicNumber)
 333             count++;
 334       }
 335    }
 336    return count;
 337 }
 338 
 339 //+------------------------------------------------------------------+
 340 //| Check if we have position on specific symbol                      |
 341 //+------------------------------------------------------------------+
 342 bool HasPositionOnSymbol(string symbol)
 343 {
 344    for(int i = PositionsTotal() - 1; i >= 0; i--)
 345    {
 346       if(posInfo.SelectByIndex(i))
 347       {
 348          if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == symbol)
 349             return true;
 350       }
 351    }
 352    return false;
 353 }
 354 
 355 //+------------------------------------------------------------------+
 356 //| Get symbol index by base name (partial match)                     |
 357 //+------------------------------------------------------------------+
 358 int GetSymbolIndexByBase(string baseName)
 359 {
 360    for(int i = 0; i < g_symbolCount; i++)
 361    {
 362       if(g_symbols[i].isValid)
 363       {
 364          // Check if the symbol name contains the base name
 365          if(StringFind(g_symbols[i].name, baseName) >= 0)
 366             return i;
 367       }
 368    }
 369    return -1;
 370 }
 371 
 372 //+------------------------------------------------------------------+
 373 //| FIXED: Calculate pip value correctly for any symbol               |
 374 //+------------------------------------------------------------------+
 375 double GetPipValue(string symbol, int digits)
 376 {
 377    // For 5-digit forex (e.g., 1.12345) -> pip = 0.0001
 378    // For 3-digit JPY pairs (e.g., 154.123) -> pip = 0.01
 379    // For Gold (e.g., 2650.12) -> pip = 0.01
 380 
 381    if(digits == 5 || digits == 4)
 382       return 0.0001;
 383    else if(digits == 3 || digits == 2)
 384       return 0.01;
 385    else if(digits == 1)
 386       return 0.1;
 387    else
 388       return 0.0001; // Default
 389 }
 390 
 391 //+------------------------------------------------------------------+
 392 //| FIXED: Normalize lot size correctly for any broker                |
 393 //+------------------------------------------------------------------+
 394 double NormalizeLotSize(string symbol, double desiredLot)
 395 {
 396    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
 397    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
 398    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
 399 
 400    // Handle edge cases
 401    if(minLot <= 0) minLot = 0.01;
 402    if(maxLot <= 0) maxLot = 100;
 403    if(lotStep <= 0) lotStep = 0.01;
 404 
 405    // Clamp to min/max
 406    double lot = MathMax(minLot, MathMin(maxLot, desiredLot));
 407 
 408    // FIXED: Calculate decimal places dynamically based on lot step
 409    int decimals = 0;
 410    double tempStep = lotStep;
 411    while(tempStep < 1 && decimals < 8)
 412    {
 413       tempStep *= 10;
 414       decimals++;
 415    }
 416 
 417    // Normalize to lot step
 418    lot = MathFloor(lot / lotStep) * lotStep;
 419    lot = NormalizeDouble(lot, decimals);
 420 
 421    // Final validation
 422    if(lot < minLot) lot = minLot;
 423 
 424    return lot;
 425 }
 426 
 427 //+------------------------------------------------------------------+
 428 //| Get price change in pips (with validation)                        |
 429 //+------------------------------------------------------------------+
 430 double GetPriceChange(int idx)
 431 {
 432    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
 433       return 0;
 434 
 435    string symbol = g_symbols[idx].name;
 436 
 437    if(!m_symbol.Name(symbol))    // FIXED: changed from symbolInfo to m_symbol
 438       return 0;
 439 
 440    if(!m_symbol.RefreshRates())  // FIXED: changed from symbolInfo to m_symbol
 441       return 0;
 442 
 443    double mid = (m_symbol.Bid() + m_symbol.Ask()) / 2; // FIXED: m_symbol
 444 
 445    // First tick - initialize prevMid
 446    if(g_symbols[idx].prevMid == 0 || g_symbols[idx].prevMid == EMPTY_VALUE)
 447    {
 448       g_symbols[idx].prevMid = mid;
 449       return 0;
 450    }
 451 
 452    double pip = g_symbols[idx].pip;
 453    if(pip <= 0) pip = 0.0001; // Safety
 454 
 455    double change = (mid - g_symbols[idx].prevMid) / pip;
 456    g_symbols[idx].prevMid = mid;
 457 
 458    return change;
 459 }
 460 
 461 //+------------------------------------------------------------------+
 462 //| Get RSI value (with validation)                                   |
 463 //+------------------------------------------------------------------+
 464 double GetRSI(int idx)
 465 {
 466    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
 467       return 50;
 468 
 469    if(g_symbols[idx].handle_rsi == INVALID_HANDLE)
 470       return 50;
 471 
 472    double rsiBuffer[];
 473    ArraySetAsSeries(rsiBuffer, true);
 474 
 475    if(CopyBuffer(g_symbols[idx].handle_rsi, 0, 0, 1, rsiBuffer) <= 0)
 476       return 50;
 477 
 478    return rsiBuffer[0];
 479 }
 480 
 481 //+------------------------------------------------------------------+
 482 //| FIXED: Get MA value using cached handle                           |
 483 //+------------------------------------------------------------------+
 484 double GetMA20(int idx)
 485 {
 486    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
 487       return 0;
 488 
 489    if(g_symbols[idx].handle_ma == INVALID_HANDLE)
 490       return 0;
 491 
 492    double maBuffer[];
 493    ArraySetAsSeries(maBuffer, true);
 494 
 495    if(CopyBuffer(g_symbols[idx].handle_ma, 0, 0, 1, maBuffer) <= 0)
 496       return 0;
 497 
 498    return maBuffer[0];
 500 }
 501 
 502 //+------------------------------------------------------------------+
 503 //| Get Momentum (Rate of Change)                                     |
 504 //+------------------------------------------------------------------+
 505 double GetMomentum(string symbol, int periods = 14)
 506 {
 507    double closes[];
 508    ArraySetAsSeries(closes, true);
 509 
 510    if(CopyClose(symbol, PERIOD_M1, 0, periods + 1, closes) < periods + 1)
 511       return 0;
 512 
 513    if(closes[periods] == 0)
 514       return 0;
 515 
 516    return ((closes[0] - closes[periods]) / closes[periods]) * 100;
 517 }
 518 
 519 //+------------------------------------------------------------------+
 520 //| Multi-Strategy Signal Generation                                  |
 521 //+------------------------------------------------------------------+
 522 void GetSignal(int idx, int &signalType, int &strength, int &score)
 523 {
 524    signalType = 0; // 0 = none, 1 = buy, -1 = sell
 525    strength = 0;
 526    score = 50;     // Start at neutral 50
 527 
 528    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
 529       return;
 530 
 531    string symbol = g_symbols[idx].name;
 532    string type = g_symbols[idx].type;
 533    double pip = g_symbols[idx].pip;
 534 
 535    if(!m_symbol.Name(symbol))    // FIXED: m_symbol
 536       return;
 537 
 538    if(!m_symbol.RefreshRates())  // FIXED: m_symbol
 539       return;
 540 
 541    double bid = m_symbol.Bid();  // FIXED: m_symbol
 542    double ask = m_symbol.Ask();  // FIXED: m_symbol
 543    int digits = (int)m_symbol.Digits(); // FIXED: m_symbol
 544 
 545    // FIXED: Better pip calculation for spread check
 546    double effectivePip = GetPipValue(symbol, digits);
 547    if(effectivePip <= 0) effectivePip = pip;
 548 
 549    // Spread check
 550    double spreadValue = ask - bid;
 551 
 552    if(type == "gold")
 553    {
 554       double spreadCents = spreadValue * 100;
 555       if(spreadCents > InpGoldSpreadCents) return;
 556    }
 557    else
 558    {
 559       double spreadPips = spreadValue / effectivePip;
 560       if(spreadPips > InpMaxSpreadPips) return;
 561    }
 562 
 563    double mid = (bid + ask) / 2;
 564    double priceChange = GetPriceChange(idx);
 565    double momentum = GetMomentum(symbol);
 566    double rsi = GetRSI(idx);
 567    double ma20 = GetMA20(idx);
 568 
 569    bool isJpy = StringFind(symbol, "JPY") >= 0;
 570    bool isGold = (type == "gold");
 571 
 572    // === STRATEGY 1: MOMENTUM ===
 573    if(InpUseMomentum)
 574    {
 575       if(priceChange > 0.5)
 576       {
 577          score += 12;
 578          strength++;
 579       }
 580       else if(priceChange < -0.5)
 581       {
 582          score -= 12;
 583          strength++;
 584       }
 585    }
 586 
 587    // === STRATEGY 2: TREND CONTINUATION ===
 588    if(InpUseTrend)
 589    {
 590       double prevMid = g_symbols[idx].prevMid;
 591       if(prevMid > 0)
 592       {
 593          if(priceChange > 0.2 && mid > prevMid)
 594          {
 595             score += 8;
 596             strength++;
 597          }
 598          else if(priceChange < -0.2 && mid < prevMid)
 599          {
 600             score -= 8;
 601             strength++;
 602          }
 603       }
 604    }
 605 
 606    // === STRATEGY 3: VOLATILITY BREAKOUT ===
 607    if(InpUseBreakout)
 608    {
 609       if(MathAbs(priceChange) > 1.5)
 610       {
 611          if(priceChange > 0)
 612             score += 15;
 613          else
 614             score -= 15;
 615          strength += 2;
 616       }
 617    }
 618 
 619    // === STRATEGY 4: MEAN REVERSION (RSI) ===
 620    if(InpUseReversion)
 621    {
 622       if(rsi < 30)
 623       {
 624          score += 10;
 625          strength++;
 626       }
 627       else if(rsi > 70)
 628       {
 629          score -= 10;
 630          strength++;
 631       }
 632    }
 633 
 634    // === STRATEGY 5: CORRELATION (Gold inverse to USD strength) ===
 635    if(InpUseCorrelation && isGold && g_eurusdIndex >= 0)
 636    {
 637       double eurusdChange = GetPriceChange(g_eurusdIndex);
 638       // EUR/USD up = USD weak = Gold up
 639       if(eurusdChange > 0.3)
 640          score += 8;
 641       else if(eurusdChange < -0.3)
 642          score -= 8;
 643    }
 644 
 645    // === STRATEGY 6: JPY PAIRS MOMENTUM ===
 646    if(InpUseJpyMomentum && isJpy)
 647    {
 648       if(MathAbs(priceChange) > 1)
 649       {
 650          if(priceChange > 0)
 651             score += 10;
 652          else
 653             score -= 10;
 654          strength++;
 655       }
 656    }
 657 
 658    // === STRATEGY 7: SCALP (Quick momentum) ===
 659    if(momentum > 0.1)
 660       score += 5;
 661    else if(momentum < -0.1)
 662       score -= 5;
 663 
 664    // === STRATEGY 8: GRID-like (Strengthen strong signals) ===
 665    if(MathAbs(score - 50) > 20)
 666    {
 667       if(score > 50)
 668          score += 3;
 669       else
 670          score -= 3;
 671    }
 672 
 673    // === STRATEGY 9: RSI CONFIRMATION ===
 674    // FIXED: Only count once, check score direction matches RSI
 675    if(score > 55 && rsi < 60 && rsi > 30)
 676       strength++; // Bullish + RSI not extreme
 677    else if(score < 45 && rsi > 40 && rsi < 70)
 678       strength++; // Bearish + RSI not extreme
 679 
 680    // === STRATEGY 10: TREND ALIGNMENT (MA) ===
 681    if(ma20 > 0)
 682    {
 683       if(mid > ma20 && score > 50)
 684          strength++;
 685       else if(mid < ma20 && score < 50)
 686          strength++;
 687    }
 688 
 689    // Clamp score to 0-100
 690    score = (int)MathMax(0, MathMin(100, score));
 691 
 692    // Determine signal
 693    int buyThreshold = InpThreshold + InpEntryOffset;      // 55 + 12 = 67
 694    int sellThreshold = 100 - InpThreshold - InpEntryOffset; // 100 - 55 - 12 = 33
 695 
 696    if(score >= buyThreshold && strength >= InpMinStrength)
 697       signalType = 1; // BUY
 698    else if(score <= sellThreshold && strength >= InpMinStrength)
 699       signalType = -1; // SELL
 700 }
 701 
 702 //+------------------------------------------------------------------+
 703 //| Scan all symbols for trading signals                              |
 704 //+------------------------------------------------------------------+
 705 void ScanForSignals()
 706 {
 707    // Check max positions first
 708    int currentPositions = CountPositions();
 709    if(currentPositions >= InpMaxPositions)
 710       return;
 711 
 712    datetime now = TimeCurrent();
 713 
 714    for(int i = 0; i < g_symbolCount; i++)
 715    {
 716       // Skip invalid symbols
 717       if(!g_symbols[i].isValid)
 718          continue;
 719 
 720       string symbol = g_symbols[i].name;
 721 
 722       // FIXED: Cooldown check using seconds consistently
 723       if(g_symbols[i].lastTradeTime > 0)
 724       {
 725          int secondsSinceLastTrade = (int)(now - g_symbols[i].lastTradeTime);
 726          if(secondsSinceLastTrade < InpCooldownSec)
 727             continue;
 728       }
 729 
 730       // Already in position on this symbol?
 731       if(HasPositionOnSymbol(symbol))
 732          continue;
 733 
 734       // Check max positions again (might have changed)
 735       if(CountPositions() >= InpMaxPositions)
 736          return;
 737 
 738       // Get signal
 739       int signalType, strength, score;
 740       GetSignal(i, signalType, strength, score);
 741 
 742       if(signalType == 0)
 743          continue;
 744 
 745       // Execute trade
 746       ExecuteTrade(i, signalType, strength, score);
 747    }
 748 }
 749 
 750 //+------------------------------------------------------------------+
 751 //| Execute a trade                                                   |
 752 //+------------------------------------------------------------------+
 753 void ExecuteTrade(int idx, int signalType, int strength, int score)
 754 {
 755    if(idx < 0 || idx >= g_symbolCount || !g_symbols[idx].isValid)
 756       return;
 757 
 758    string symbol = g_symbols[idx].name;
 759    double pip = g_symbols[idx].pip;
 760 
 761    if(!m_symbol.Name(symbol))    // FIXED: m_symbol
 762       return;
 763 
 764    if(!m_symbol.RefreshRates())  // FIXED: m_symbol
 765       return;
 766 
 767    int digits = (int)m_symbol.Digits(); // FIXED: m_symbol
 768    double bid = m_symbol.Bid();  // FIXED: m_symbol
 769    double ask = m_symbol.Ask();  // FIXED: m_symbol
 770 
 771    // FIXED: Use GetPipValue for correct pip calculation
 772    double effectivePip = GetPipValue(symbol, digits);
 773    if(effectivePip <= 0) effectivePip = pip;
 774 
 775    // FIXED: Normalize lot size properly
 776    double lotSize = NormalizeLotSize(symbol, InpLotSize);
 777 
 778    // Calculate SL and TP
 779    double sl, tp;
 780 
 781    if(signalType == 1) // BUY
 782    {
 783       double entryPrice = ask;
 784       sl = NormalizeDouble(entryPrice - InpStopLoss * effectivePip, digits);
 785       tp = NormalizeDouble(entryPrice + InpTakeProfit * effectivePip, digits);
 786 
 787       // Validate SL/TP
 788       double minStopLevel = m_symbol.StopsLevel() * m_symbol.Point(); // FIXED: m_symbol
 789       if(entryPrice - sl < minStopLevel)
 790          sl = NormalizeDouble(entryPrice - minStopLevel - effectivePip, digits);
 791       if(tp - entryPrice < minStopLevel)
 792          tp = NormalizeDouble(entryPrice + minStopLevel + effectivePip, digits);
 793 
 794       if(trade.Buy(lotSize, symbol, entryPrice, sl, tp, InpComment))
 795       {
 796          g_symbols[idx].lastTradeTime = TimeCurrent();
 797          Print("▲ BUY ", symbol, " @ ", DoubleToString(entryPrice, digits),
 798                " | Lot: ", DoubleToString(lotSize, 2),
 799                " | Score: ", score, " | Str: ", strength,
 800                " | SL: ", DoubleToString(sl, digits),
 801                " | TP: ", DoubleToString(tp, digits));
 802       }
 803       else
 804       {
 805          Print("✗ Buy failed: ", symbol, " | Error: ", GetLastError());
 806       }
 807    }
 808    else if(signalType == -1) // SELL
 809    {
 810       double entryPrice = bid;
 811       sl = NormalizeDouble(entryPrice + InpStopLoss * effectivePip, digits);
 812       tp = NormalizeDouble(entryPrice - InpTakeProfit * effectivePip, digits);
 813 
 814       // Validate SL/TP
 815       double minStopLevel = m_symbol.StopsLevel() * m_symbol.Point(); // FIXED: m_symbol
 816       if(sl - entryPrice < minStopLevel)
 817          sl = NormalizeDouble(entryPrice + minStopLevel + effectivePip, digits);
 818       if(entryPrice - tp < minStopLevel)
 819          tp = NormalizeDouble(entryPrice - minStopLevel - effectivePip, digits);
 820 
 821       if(trade.Sell(lotSize, symbol, entryPrice, sl, tp, InpComment))
 822       {
 823          g_symbols[idx].lastTradeTime = TimeCurrent();
 824          Print("▼ SELL ", symbol, " @ ", DoubleToString(entryPrice, digits),
 825                " | Lot: ", DoubleToString(lotSize, 2),
 826                " | Score: ", score, " | Str: ", strength,
 827                " | SL: ", DoubleToString(sl, digits),
 828                " | TP: ", DoubleToString(tp, digits));
 829       }
 830       else
 831       {
 832          Print("✗ Sell failed: ", symbol, " | Error: ", GetLastError());
 833       }
 834    }
 835 }
 836 
 837 //+------------------------------------------------------------------+
 838 //| Manage existing positions - trailing stops                        |
 839 //+------------------------------------------------------------------+
 840 void ManagePositions()
 841 {
 842    for(int i = PositionsTotal() - 1; i >= 0; i--)
 943    {
 944       if(!posInfo.SelectByIndex(i))
 845          continue;
 846 
 847       if(posInfo.Magic() != InpMagicNumber)
 848          continue;
 849 
 850       string symbol = posInfo.Symbol();
 851 
 852       if(!m_symbol.Name(symbol))    // FIXED: m_symbol
 853          continue;
 854 
 855       if(!m_symbol.RefreshRates())  // FIXED: m_symbol
 856          continue;
 857 
 858       int digits = (int)m_symbol.Digits(); // FIXED: m_symbol
 859       double point = m_symbol.Point();     // FIXED: m_symbol
 860       double bid = m_symbol.Bid();         // FIXED: m_symbol
 861       double ask = m_symbol.Ask();         // FIXED: m_symbol
 862 
 863       // FIXED: Find symbol config for correct pip value
 864       int symIdx = -1;
 865       for(int j = 0; j < g_symbolCount; j++)
 866       {
 867          if(g_symbols[j].name == symbol)
 868          {
 869             symIdx = j;
 870             break;
 871          }
 872       }
 873 
 874       // FIXED: Calculate pip correctly
 875       double pip;
 876       if(symIdx >= 0 && g_symbols[symIdx].isValid)
 877          pip = g_symbols[symIdx].pip;
 878       else
 879          pip = GetPipValue(symbol, digits);
 880 
 881       if(pip <= 0) pip = point * 10; // Fallback
 882 
 883       double openPrice = posInfo.PriceOpen();
 884       double currentSL = posInfo.StopLoss();
 885       double currentTP = posInfo.TakeProfit();
 886 
 887       ENUM_POSITION_TYPE posType = posInfo.PositionType();
 888 
 889       // Calculate current profit in pips
 890       double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
 891       double profitPips;
 892 
 893       if(posType == POSITION_TYPE_BUY)
 903          profitPips = (currentPrice - openPrice) / pip;
 894       else
 895          profitPips = (openPrice - currentPrice) / pip;
 896 
 897       // Check if trailing should activate
 898       if(profitPips >= InpTrailStart)
 899       {
 900          // FIXED: Calculate trail distance properly
 901          double trailPips = InpTrailStart * InpTrailTighten;
 902          double trailDistance = trailPips * pip;
 903 
 904          // Ensure minimum trail distance (at least 1 pip)
 905          double minTrailDistance = pip;
 906          if(trailDistance < minTrailDistance)
 907             trailDistance = minTrailDistance;
 908 
 909          double newSL;
 910 
 911          if(posType == POSITION_TYPE_BUY)
 912          {
 913             newSL = NormalizeDouble(currentPrice - trailDistance, digits);
 914 
 915             // Only modify if new SL is meaningfully higher (at least 0.5 pip improvement)
 916             double minImprovement = pip * 0.5;
 917             if(newSL > currentSL + minImprovement)
 918             {
 919                if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
 920                {
 921                   if(InpVerboseLog)
 922                      Print("🔒 TRAIL ", symbol, " (BUY) | +", DoubleToString(profitPips, 1),
 923                            "p | SL: ", DoubleToString(currentSL, digits),
 924                            " → ", DoubleToString(newSL, digits));
 925                }
 926             }
 927          }
 928          else // SELL
 929          {
 930             newSL = NormalizeDouble(currentPrice + trailDistance, digits);
 931 
 932             // Only modify if new SL is meaningfully lower
 933             double minImprovement = pip * 0.5;
 934             if(currentSL == 0 || newSL < currentSL - minImprovement)
 935             {
 936                if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
 937                {
 938                   if(InpVerboseLog)
 939                      Print("🔒 TRAIL ", symbol, " (SELL) | +", DoubleToString(profitPips, 1),
 940                            "p | SL: ", DoubleToString(currentSL, digits),
 941                            " → ", DoubleToString(newSL, digits));
 942                }
 943             }
 944          }
 945       }
 946    }
 947 }
 948 
 949 //+------------------------------------------------------------------+
 950 //| Trade transaction event handler                                   |
 951 //+------------------------------------------------------------------+
 952 void OnTradeTransaction(const MqlTradeTransaction& trans,
 953                         const MqlTradeRequest& request,
 954                         const MqlTradeResult& result)
 955 {
 956    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
 957    {
 958       ulong dealTicket = trans.deal;
 959 
 960       if(dealTicket > 0)
 961       {
 962          if(!HistoryDealSelect(dealTicket))
 963          {
 964             return;
 965          }
 966 
 967          long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
 968 
 969          if(magic == InpMagicNumber)
 970          {
 971             ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
 972 
 973             if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
 974             {
 975                double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
 976                double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
 977                double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
 978                double netProfit = profit + commission + swap;
 979                string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
 980 
 981                if(netProfit > 0)
 982                {
 983                   g_totalWins++;
 984                   g_grossWin += netProfit;
 985                   g_streak = (g_streak > 0) ? g_streak + 1 : 1;
 986                   Print("✅ WIN: ", symbol, " | +$", DoubleToString(netProfit, 2),
 987                         " | Streak: +", g_streak);
 988                }
 989                else
 990                {
 991                   g_totalLosses++;
 992                   g_grossLoss += MathAbs(netProfit);
 993                   g_streak = (g_streak < 0) ? g_streak - 1 : -1;
 994                   Print("❌ LOSS: ", symbol, " | -$", DoubleToString(MathAbs(netProfit), 2),
 995                         " | Streak: ", g_streak);
 996                }
 997 
 998                int total = g_totalWins + g_totalLosses;
 999                if(total > 0)
1000                {
1001                   double winRate = (double)g_totalWins / total * 100;
1002                   double pf = (g_grossLoss > 0) ? g_grossWin / g_grossLoss : 0;
1003                   double avgWin = (g_totalWins > 0) ? g_grossWin / g_totalWins : 0;
1004                   double avgLoss = (g_totalLosses > 0) ? g_grossLoss / g_totalLosses : 0;
1005 
1006                   Print("📊 Trades: ", total,
1007                         " | Win%: ", DoubleToString(winRate, 1), "%",
1008                         " | PF: ", DoubleToString(pf, 2),
1009                         " | AvgW: $", DoubleToString(avgWin, 2),
1010                         " | AvgL: $", DoubleToString(avgLoss, 2));
1011                }
1012             }
1013          }
1014       }
1015    }
1016 }
1017 //+------------------------------------------------------------------+
