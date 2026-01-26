
//+------------------------------------------------------------------+
//|                                              HFT_Ultra_2026.mq5  |
//|                                    HFT Ultra 2026 Expert Advisor |
//|                          Multi-Strategy AI Signal Trading System |
//+------------------------------------------------------------------+
#property copyright "HFT Ultra 2026"
#property link      ""
#property version   "1.00"
#property strict
#property description "HFT Ultra 2026 - Multi-Strategy Trading System"
#property description "Features: RSI, Momentum, Trend Following, Risk Shield"
#property description "Trailing Stops, Correlation Hedging, Dynamic Lot Sizing"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== TRADING PARAMETERS ==="
input double   InpBaseLot        = 0.01;    // Base Lot Size
input int      InpTakeProfit     = 15;      // Take Profit (pips)
input int      InpStopLoss       = 5;       // Stop Loss (pips)
input int      InpTrailStart     = 6;       // Trail Start (pips profit)
input double   InpTrailFactor    = 0.4;     // Trail Tightness (0.1-1.0)
input int      InpMaxPositions   = 6;       // Maximum Open Positions
input int      InpCooldownSec    = 3;       // Cooldown Between Trades (seconds)

input group "=== RSI SETTINGS ==="
input int      InpRSIPeriod      = 14;      // RSI Period
input int      InpRSIOversold    = 25;      // RSI Oversold Level
input int      InpRSIOverbought  = 75;      // RSI Overbought Level

input group "=== SIGNAL REQUIREMENTS ==="
input int      InpMinStrength    = 3;       // Minimum Signal Strength (1-7)
input int      InpMinScore       = 25;      // Minimum Signal Score
input double   InpMaxSpread      = 2.0;     // Maximum Spread (pips)

input group "=== RISK SHIELD ==="
input double   InpMaxDrawdown    = 5.0;     // Max Drawdown % (Circuit Breaker)
input double   InpDailyLossLimit = 3.0;     // Daily Loss Limit %
input bool     InpUseCorrelation = true;    // Use Correlation Hedging

input group "=== DYNAMIC LOT SIZING ==="
input bool     InpDynamicLots    = true;    // Enable Dynamic Lot Sizing
input double   InpMinLot         = 0.01;    // Minimum Lot Size
input double   InpMaxLot         = 0.05;    // Maximum Lot Size

input group "=== GENERAL ==="
input int      InpMagicNumber    = 20260101; // Magic Number
input string   InpComment        = "HFT_Ultra_2026"; // Order Comment

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  posInfo;
CAccountInfo   accountInfo;
CSymbolInfo    symbolInfo;

// Statistics
double         g_startEquity;
double         g_peakEquity;
double         g_dailyStartEquity;
int            g_totalWins;
int            g_totalLosses;
double         g_grossWin;
double         g_grossLoss;
int            g_streak;
datetime       g_lastTradeTime[];
datetime       g_currentDay;

// RSI handles for multi-symbol
int            g_rsiHandle[];
string         g_symbols[];
int            g_symbolCount;

// Correlation pairs mapping
string         g_corrPairs[][3]; // symbol, corr1, corr2

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetAsyncMode(false);
   
   // Initialize statistics
   g_startEquity = accountInfo.Equity();
   g_peakEquity = g_startEquity;
   g_dailyStartEquity = g_startEquity;
   g_totalWins = 0;
   g_totalLosses = 0;
   g_grossWin = 0;
   g_grossLoss = 0;
   g_streak = 0;
   
   // Get current day's midnight time
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   g_currentDay = StructToTime(dt);
   
   // Initialize symbols - using common forex/crypto pairs available on MT5
   InitializeSymbols();
   
   // Initialize RSI indicators for each symbol
   InitializeIndicators();
   
   // Initialize correlation pairs
   InitializeCorrelations();
   
   Print("===========================================");
   Print("  HFT ULTRA 2026 - Expert Advisor Started");
   Print("===========================================");
   Print("Symbols: ", g_symbolCount);
   Print("Base Lot: ", InpBaseLot);
   Print("TP: ", InpTakeProfit, " pips | SL: ", InpStopLoss, " pips");
   Print("Max Positions: ", InpMaxPositions);
   Print("Risk Shield: DD ", InpMaxDrawdown, "% | Daily ", InpDailyLossLimit, "%");
   Print("===========================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize trading symbols                                        |
//+------------------------------------------------------------------+
void InitializeSymbols()
{
   // Define symbols to trade - adjust based on your broker's available symbols
   string tempSymbols[] = {
      "BTCUSD", "ETHUSD", "XRPUSD", "SOLUSD",    // Crypto (if available)
      "EURUSD", "GBPUSD", "USDJPY", "USDCHF",    // Major Forex
      "AUDUSD", "USDCAD", "NZDUSD",              // Commodity currencies
      "EURJPY", "GBPJPY", "EURGBP", "AUDNZD",    // Crosses
      "XAUUSD", "XAGUSD"                          // Metals
   };
   
   // Check which symbols are available
   g_symbolCount = 0;
   ArrayResize(g_symbols, ArraySize(tempSymbols));
   ArrayResize(g_lastTradeTime, ArraySize(tempSymbols));
   
   for(int i = 0; i < ArraySize(tempSymbols); i++)
   {
      // Check if symbol exists
      if(SymbolInfoInteger(tempSymbols[i], SYMBOL_SELECT))
      {
         g_symbols[g_symbolCount] = tempSymbols[i];
         g_lastTradeTime[g_symbolCount] = 0;
         g_symbolCount++;
      }
      else
      {
         // Try with common suffixes
         string variations[] = {"BTCUSD.c", "ETHUSD.c", "BTCUSDpro", "ETHUSDpro", 
                                "XRPUSD.c", "SOLUSD.c", "BTCUSD.d", "ETHUSD.d"};
         bool found = false;
         for(int j = 0; j < ArraySize(variations); j++)
         {
            if(StringFind(variations[j], tempSymbols[i]) == 0)
            {
               if(SymbolInfoInteger(variations[j], SYMBOL_SELECT))
               {
                  g_symbols[g_symbolCount] = variations[j];
                  g_lastTradeTime[g_symbolCount] = 0;
                  g_symbolCount++;
                  found = true;
                  break;
               }
            }
         }
         
         // If not found, try selecting the symbol
         if(!found)
         {
            if(SymbolSelect(tempSymbols[i], true))
            {
               g_symbols[g_symbolCount] = tempSymbols[i];
               g_lastTradeTime[g_symbolCount] = 0;
               g_symbolCount++;
            }
         }
      }
   }
   
   ArrayResize(g_symbols, g_symbolCount);
   ArrayResize(g_lastTradeTime, g_symbolCount);
   
   Print("Initialized ", g_symbolCount, " trading symbols");
}

//+------------------------------------------------------------------+
//| Initialize RSI indicators for all symbols                         |
//+------------------------------------------------------------------+
void InitializeIndicators()
{
   ArrayResize(g_rsiHandle, g_symbolCount);
   
   for(int i = 0; i < g_symbolCount; i++)
   {
      g_rsiHandle[i] = iRSI(g_symbols[i], PERIOD_M1, InpRSIPeriod, PRICE_CLOSE);
      if(g_rsiHandle[i] == INVALID_HANDLE)
      {
         Print("Failed to create RSI handle for ", g_symbols[i], " Error: ", GetLastError());
      }
      else
      {
         Print("Created RSI indicator for ", g_symbols[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize correlation pairs                                      |
//+------------------------------------------------------------------+
void InitializeCorrelations()
{
   // Define correlated pairs for hedging protection
   ArrayResize(g_corrPairs, 10);
   
   // Crypto correlations
   g_corrPairs[0][0] = "BTCUSD"; g_corrPairs[0][1] = "ETHUSD"; g_corrPairs[0][2] = "SOLUSD";
   g_corrPairs[1][0] = "ETHUSD"; g_corrPairs[1][1] = "BTCUSD"; g_corrPairs[1][2] = "SOLUSD";
   
   // Forex correlations
   g_corrPairs[2][0] = "EURUSD"; g_corrPairs[2][1] = "GBPUSD"; g_corrPairs[2][2] = "";
   g_corrPairs[3][0] = "GBPUSD"; g_corrPairs[3][1] = "EURUSD"; g_corrPairs[3][2] = "";
   g_corrPairs[4][0] = "AUDUSD"; g_corrPairs[4][1] = "NZDUSD"; g_corrPairs[4][2] = "";
   g_corrPairs[5][0] = "NZDUSD"; g_corrPairs[5][1] = "AUDUSD"; g_corrPairs[5][2] = "";
   g_corrPairs[6][0] = "EURJPY"; g_corrPairs[6][1] = "GBPJPY"; g_corrPairs[6][2] = "";
   g_corrPairs[7][0] = "GBPJPY"; g_corrPairs[7][1] = "EURJPY"; g_corrPairs[7][2] = "";
   
   // Metals correlation
   g_corrPairs[8][0] = "XAUUSD"; g_corrPairs[8][1] = "XAGUSD"; g_corrPairs[8][2] = "";
   g_corrPairs[9][0] = "XAGUSD"; g_corrPairs[9][1] = "XAUUSD"; g_corrPairs[9][2] = "";
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   for(int i = 0; i < g_symbolCount; i++)
   {
      if(g_rsiHandle[i] != INVALID_HANDLE)
         IndicatorRelease(g_rsiHandle[i]);
   }
   
   Print("===========================================");
   Print("  HFT ULTRA 2026 - Final Statistics");
   Print("===========================================");
   Print("Total Trades: ", g_totalWins + g_totalLosses);
   Print("Wins: ", g_totalWins, " | Losses: ", g_totalLosses);
   if(g_totalWins + g_totalLosses > 0)
      Print("Win Rate: ", NormalizeDouble((double)g_totalWins / (g_totalWins + g_totalLosses) * 100, 1), "%");
   if(g_grossLoss > 0)
      Print("Profit Factor: ", NormalizeDouble(g_grossWin / g_grossLoss, 2));
   Print("===========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new day - reset daily stats
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime today = StructToTime(dt);
   
   if(today != g_currentDay)
   {
      g_currentDay = today;
      g_dailyStartEquity = accountInfo.Equity();
      Print("New trading day - Daily equity reset: ", g_dailyStartEquity);
   }
   
   // Update peak equity
   double currentEquity = accountInfo.Equity();
   if(currentEquity > g_peakEquity)
      g_peakEquity = currentEquity;
   
   // Check Risk Shield
   if(!CheckRiskShield())
   {
      return; // Trading halted by risk shield
   }
   
   // Manage existing positions (trailing stops)
   ManagePositions();
   
   // Look for new trading opportunities
   ScanForSignals();
}

//+------------------------------------------------------------------+
//| Risk Shield - Circuit Breakers                                    |
//+------------------------------------------------------------------+
bool CheckRiskShield()
{
   double currentEquity = accountInfo.Equity();
   
   // Check max drawdown from peak
   double drawdownPct = (g_peakEquity - currentEquity) / g_peakEquity * 100;
   if(drawdownPct >= InpMaxDrawdown)
   {
      static datetime lastDDWarning = 0;
      if(TimeCurrent() - lastDDWarning > 300) // Warn every 5 minutes
      {
         Print("RISK SHIELD: Max drawdown reached (", NormalizeDouble(drawdownPct, 2), "%) - Trading HALTED");
         lastDDWarning = TimeCurrent();
      }
      return false;
   }
   
   // Check daily loss limit
   double dailyPnL = currentEquity - g_dailyStartEquity;
   double dailyLossPct = MathAbs(dailyPnL) / g_dailyStartEquity * 100;
   if(dailyPnL < 0 && dailyLossPct >= InpDailyLossLimit)
   {
      static datetime lastDailyWarning = 0;
      if(TimeCurrent() - lastDailyWarning > 300)
      {
         Print("RISK SHIELD: Daily loss limit reached (", NormalizeDouble(dailyLossPct, 2), "%) - Trading HALTED");
         lastDailyWarning = TimeCurrent();
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Count positions by magic number                                   |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Magic() == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if we have position on symbol or correlated symbol          |
//+------------------------------------------------------------------+
bool HasCorrelatedPosition(string symbol)
{
   if(!InpUseCorrelation)
      return HasPositionOnSymbol(symbol);
   
   // Check for position on same symbol
   if(HasPositionOnSymbol(symbol))
      return true;
   
   // Find correlated pairs
   for(int i = 0; i < ArrayRange(g_corrPairs, 0); i++)
   {
      if(g_corrPairs[i][0] == symbol)
      {
         // Check correlated symbols
         if(g_corrPairs[i][1] != "" && HasPositionOnSymbol(g_corrPairs[i][1]))
            return true;
         if(g_corrPairs[i][2] != "" && HasPositionOnSymbol(g_corrPairs[i][2]))
            return true;
         break;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if we have position on specific symbol                      |
//+------------------------------------------------------------------+
bool HasPositionOnSymbol(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == symbol)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get RSI value for symbol                                          |
//+------------------------------------------------------------------+
double GetRSI(int symbolIndex)
{
   if(symbolIndex < 0 || symbolIndex >= g_symbolCount)
      return 50;
   
   if(g_rsiHandle[symbolIndex] == INVALID_HANDLE)
      return 50;
   
   double rsiBuffer[];
   ArraySetAsSeries(rsiBuffer, true);
   
   if(CopyBuffer(g_rsiHandle[symbolIndex], 0, 0, 3, rsiBuffer) <= 0)
   {
      Print("Failed to copy RSI buffer for ", g_symbols[symbolIndex], " Error: ", GetLastError());
      return 50;
   }
   
   return rsiBuffer[0];
}

//+------------------------------------------------------------------+
//| Calculate Momentum (Rate of Change)                               |
//+------------------------------------------------------------------+
double GetMomentum(string symbol, int periods = 10)
{
   double closes[];
   ArraySetAsSeries(closes, true);
   
   if(CopyClose(symbol, PERIOD_M1, 0, periods + 1, closes) < periods + 1)
   {
      Print("Failed to copy close prices for ", symbol);
      return 0;
   }
   
   if(closes[periods] == 0)
      return 0;
   
   return ((closes[0] - closes[periods]) / closes[periods]) * 100;
}

//+------------------------------------------------------------------+
//| Calculate Volatility (ATR-like)                                   |
//+------------------------------------------------------------------+
double GetVolatility(string symbol, int periods = 10)
{
   double closes[];
   ArraySetAsSeries(closes, true);
   
   if(CopyClose(symbol, PERIOD_M1, 0, periods + 1, closes) < periods + 1)
   {
      Print("Failed to copy close prices for volatility: ", symbol);
      return 0;
   }
   
   double sum = 0;
   for(int i = 0; i < periods; i++)
   {
      sum += MathAbs(closes[i] - closes[i + 1]);
   }
   
   return sum / periods;
}

//+------------------------------------------------------------------+
//| Get 20-period Moving Average                                      |
//+------------------------------------------------------------------+
double GetMA20(string symbol)
{
   double closes[];
   ArraySetAsSeries(closes, true);
   
   if(CopyClose(symbol, PERIOD_M1, 0, 20, closes) < 20)
   {
      Print("Failed to copy close prices for MA20: ", symbol);
      return 0;
   }
   
   double sum = 0;
   for(int i = 0; i < 20; i++)
      sum += closes[i];
   
   return sum / 20;
}

//+------------------------------------------------------------------+
//| Get symbol index                                                  |
//+------------------------------------------------------------------+
int GetSymbolIndex(string symbol)
{
   for(int i = 0; i < g_symbolCount; i++)
   {
      if(g_symbols[i] == symbol)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Generate trading signal for symbol                                |
//+------------------------------------------------------------------+
void GetSignal(string symbol, int symbolIndex, int &signalType, int &strength, int &score)
{
   signalType = 0; // 0 = none, 1 = buy, -1 = sell
   strength = 0;
   score = 0;
   
   if(!symbolInfo.Name(symbol))
   {
      Print("Failed to set symbol: ", symbol);
      return;
   }
   
   symbolInfo.RefreshRates();
   
   double bid = symbolInfo.Bid();
   double ask = symbolInfo.Ask();
   double point = symbolInfo.Point();
   double spread = (ask - bid) / point;
   
   // Spread filter - convert pips to points (1 pip = 10 points for 5-digit brokers)
   double spreadPips = spread / (symbolInfo.Digits() == 5 ? 10 : 1);
   if(spreadPips > InpMaxSpread)
      return;
   
   // Get indicators
   double rsi = GetRSI(symbolIndex);
   double momentum = GetMomentum(symbol);
   double volatility = GetVolatility(symbol);
   double ma20 = GetMA20(symbol);
   double midPrice = (bid + ask) / 2;
   
   // 1. RSI Strategy (Oversold/Overbought)
   if(rsi < InpRSIOversold)
   {
      score += 20;
      strength++;
   }
   else if(rsi > InpRSIOverbought)
   {
      score -= 20;
      strength++;
   }
   else if(rsi < 40)
   {
      score += 10;
   }
   else if(rsi > 60)
   {
      score -= 10;
   }
   
   // 2. Momentum Confirmation
   if(momentum > 0.05 && rsi < 50)
   {
      score += 15;
      strength++;
   }
   else if(momentum < -0.05 && rsi > 50)
   {
      score -= 15;
      strength++;
   }
   
   // 3. Trend Following (price above/below MA)
   if(ma20 > 0)
   {
      if(midPrice > ma20 && momentum > 0)
      {
         score += 12;
         strength++;
      }
      else if(midPrice < ma20 && momentum < 0)
      {
         score -= 12;
         strength++;
      }
   }
   
   // 4. Volatility Filter - prefer low volatility entries
   if(volatility < midPrice * 0.001)
   {
      strength++;
   }
   
   // 5. Price change momentum (using recent close comparison)
   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(symbol, PERIOD_H1, 0, 2, closes) >= 2)
   {
      double hourChange = ((closes[0] - closes[1]) / closes[1]) * 100;
      if(hourChange > 0.5 && rsi < 60)
      {
         score += 10;
         strength++;
      }
      else if(hourChange < -0.5 && rsi > 40)
      {
         score -= 10;
         strength++;
      }
   }
   
   // 6. Check correlation with major pairs
   if(StringFind(symbol, "BTC") < 0 && StringFind(symbol, "ETH") < 0)
   {
      // For forex, check correlation with EUR/USD
      int eurusdIdx = GetSymbolIndex("EURUSD");
      if(eurusdIdx >= 0)
      {
         double eurusdMom = GetMomentum(g_symbols[eurusdIdx]);
         if((momentum > 0 && eurusdMom > 0) || (momentum < 0 && eurusdMom < 0))
            strength++;
      }
   }
   
   // 7. Cross-pair confirmation
   for(int i = 0; i < ArrayRange(g_corrPairs, 0); i++)
   {
      if(g_corrPairs[i][0] == symbol)
      {
         for(int j = 1; j <= 2; j++)
         {
            if(g_corrPairs[i][j] != "")
            {
               double corrMom = GetMomentum(g_corrPairs[i][j]);
               if((score > 0 && corrMom > 0) || (score < 0 && corrMom < 0))
                  strength++;
            }
         }
         break;
      }
   }
   
   // Determine signal
   if(score >= InpMinScore && strength >= InpMinStrength)
      signalType = 1; // BUY
   else if(score <= -InpMinScore && strength >= InpMinStrength)
      signalType = -1; // SELL
}

//+------------------------------------------------------------------+
//| Calculate dynamic lot size                                        |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol)
{
   if(!InpDynamicLots)
      return InpBaseLot;
   
   double lot = InpBaseLot;
   
   // Volatility adjustment
   double volatility = GetVolatility(symbol);
   symbolInfo.Name(symbol);
   symbolInfo.RefreshRates();
   double midPrice = (symbolInfo.Bid() + symbolInfo.Ask()) / 2;
   
   if(midPrice > 0)
   {
      double volFactor = MathMax(0.5, 1.0 - (volatility / midPrice) * 100);
      lot *= volFactor;
   }
   
   // Streak adjustment - reduce after consecutive losses
   if(g_streak < -2)
      lot *= 0.5;
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathMax(InpMinLot, MathMin(InpMaxLot, lot));
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = NormalizeDouble(MathFloor(lot / lotStep) * lotStep, 2);
   
   return lot;
}

//+------------------------------------------------------------------+
//| Scan all symbols for trading signals                              |
//+------------------------------------------------------------------+
void ScanForSignals()
{
   // Check max positions
   if(CountPositions() >= InpMaxPositions)
      return;
   
   for(int i = 0; i < g_symbolCount; i++)
   {
      string symbol = g_symbols[i];
      
      // Cooldown check
      if(TimeCurrent() - g_lastTradeTime[i] < InpCooldownSec)
         continue;
      
      // Skip if we have position on this or correlated symbol
      if(HasCorrelatedPosition(symbol))
         continue;
      
      // Check max positions again (might have changed)
      if(CountPositions() >= InpMaxPositions)
         return;
      
      // Get signal
      int signalType, strength, score;
      GetSignal(symbol, i, signalType, strength, score);
      
      if(signalType == 0)
         continue;
      
      // Prepare for trade
      if(!symbolInfo.Name(symbol))
      {
         Print("Failed to set symbol for trade: ", symbol);
         continue;
      }
      
      symbolInfo.RefreshRates();
      
      double point = symbolInfo.Point();
      int digits = (int)symbolInfo.Digits();
      double bid = symbolInfo.Bid();
      double ask = symbolInfo.Ask();
      
      // Calculate pip value (handle 5-digit and 3-digit brokers)
      double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
      double pipValue = point * pipMultiplier;
      
      // Calculate lot size
      double lotSize = CalculateLotSize(symbol);
      
      // Calculate SL and TP
      double sl, tp;
      
      if(signalType == 1) // BUY
      {
         double entryPrice = ask;
         sl = NormalizeDouble(entryPrice - InpStopLoss * pipValue, digits);
         tp = NormalizeDouble(entryPrice + InpTakeProfit * pipValue, digits);
         
         if(trade.Buy(lotSize, symbol, entryPrice, sl, tp, InpComment))
         {
            g_lastTradeTime[i] = TimeCurrent();
            Print("BUY ", symbol, " @ ", entryPrice, " | Lot: ", lotSize, 
                  " | Strength: ", strength, " | Score: ", score);
         }
         else
         {
            Print("Buy order failed for ", symbol, ": ", trade.ResultRetcodeDescription());
         }
      }
      else if(signalType == -1) // SELL
      {
         double entryPrice = bid;
         sl = NormalizeDouble(entryPrice + InpStopLoss * pipValue, digits);
         tp = NormalizeDouble(entryPrice - InpTakeProfit * pipValue, digits);
         
         if(trade.Sell(lotSize, symbol, entryPrice, sl, tp, InpComment))
         {
            g_lastTradeTime[i] = TimeCurrent();
            Print("SELL ", symbol, " @ ", entryPrice, " | Lot: ", lotSize,
                  " | Strength: ", strength, " | Score: ", score);
         }
         else
         {
            Print("Sell order failed for ", symbol, ": ", trade.ResultRetcodeDescription());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions - trailing stops                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i))
         continue;
      
      if(posInfo.Magic() != InpMagicNumber)
         continue;
      
      string symbol = posInfo.Symbol();
      
      if(!symbolInfo.Name(symbol))
         continue;
      
      symbolInfo.RefreshRates();
      
      double point = symbolInfo.Point();
      int digits = (int)symbolInfo.Digits();
      double bid = symbolInfo.Bid();
      double ask = symbolInfo.Ask();
      double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
      double pipValue = point * pipMultiplier;
      
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double currentTP = posInfo.TakeProfit();
      
      ENUM_POSITION_TYPE posType = posInfo.PositionType();
      
      // Calculate current profit in pips
      double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
      double profitPips;
      
      if(posType == POSITION_TYPE_BUY)
         profitPips = (currentPrice - openPrice) / pipValue;
      else
         profitPips = (openPrice - currentPrice) / pipValue;
      
      // Check if trailing should activate
      if(profitPips >= InpTrailStart)
      {
         double newSL;
         double trailDistance = InpTrailStart * pipValue * InpTrailFactor;
         
         if(posType == POSITION_TYPE_BUY)
         {
            newSL = NormalizeDouble(currentPrice - trailDistance, digits);
            
            // Only modify if new SL is higher than current
            if(newSL > currentSL + point || currentSL == 0)
            {
               if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
               {
                  Print("Trailing stop updated for ", symbol, " (BUY) | New SL: ", newSL);
               }
               else
               {
                  Print("Failed to modify position: ", trade.ResultRetcodeDescription());
               }
            }
         }
         else // SELL
         {
            newSL = NormalizeDouble(currentPrice + trailDistance, digits);
            
            // Only modify if new SL is lower than current
            if(newSL < currentSL - point || currentSL == 0)
            {
               if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
               {
                  Print("Trailing stop updated for ", symbol, " (SELL) | New SL: ", newSL);
               }
               else
               {
                  Print("Failed to modify position: ", trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Trade transaction event handler                                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // A deal was added
      ulong dealTicket = trans.deal;
      
      if(dealTicket > 0)
      {
         if(HistoryDealSelect(dealTicket))
         {
            long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            
            if(magic == InpMagicNumber)
            {
               ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
               
               if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
               {
                  // Position was closed
                  double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                  double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                  double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
                  double netProfit = profit + commission + swap;
                  string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
                  
                  if(netProfit > 0)
                  {
                     g_totalWins++;
                     g_grossWin += netProfit;
                     g_streak = (g_streak > 0) ? g_streak + 1 : 1;
                     Print("WIN: ", symbol, " | Profit: $", NormalizeDouble(netProfit, 2), 
                           " | Streak: +", g_streak);
                  }
                  else
                  {
                     g_totalLosses++;
                     g_grossLoss += MathAbs(netProfit);
                     g_streak = (g_streak < 0) ? g_streak - 1 : -1;
                     Print("LOSS: ", symbol, " | Loss: $", NormalizeDouble(netProfit, 2),
                           " | Streak: ", g_streak);
                  }
                  
                  // Print statistics
                  int total = g_totalWins + g_totalLosses;
                  if(total > 0)
                  {
                     double winRate = (double)g_totalWins / total * 100;
                     double pf = (g_grossLoss > 0) ? g_grossWin / g_grossLoss : 0;
                     Print("Stats | Trades: ", total, " | Win%: ", NormalizeDouble(winRate, 1),
                           "% | PF: ", NormalizeDouble(pf, 2));
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function (optional - for periodic tasks)                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Can be used for periodic statistics display
}

//+------------------------------------------------------------------+
//| ChartEvent function (optional - for GUI)                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Can be used for chart interactions
}
//+------------------------------------------------------------------+
