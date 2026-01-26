
cat << 'EOF' > /root/.wine/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Experts/hft.mq5
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

// Standard Library Includes
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
CSymbolInfo    m_symbol; // Renamed to avoid 'struct undefined' conflicts

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
string         g_corrPairs[10][3]; // Fixed dimensions

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetAsyncMode(false);
   
   g_startEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = g_startEquity;
   g_dailyStartEquity = g_startEquity;
   g_totalWins = 0;
   g_totalLosses = 0;
   g_grossWin = 0;
   g_grossLoss = 0;
   g_streak = 0;
   g_currentDay = iTime(_Symbol, PERIOD_D1, 0);
   
   InitializeSymbols();
   InitializeIndicators();
   InitializeCorrelations();
   
   Print("HFT ULTRA 2026 Started. Symbols: ", g_symbolCount);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize trading symbols                                        |
//+------------------------------------------------------------------+
void InitializeSymbols()
{
   string tempSymbols[] = {
      "BTCUSD", "ETHUSD", "XRPUSD", "SOLUSD",
      "EURUSD", "GBPUSD", "USDJPY", "USDCHF",
      "AUDUSD", "USDCAD", "NZDUSD",
      "EURJPY", "GBPJPY", "EURGBP", "AUDNZD",
      "XAUUSD", "XAGUSD"
   };
   
   g_symbolCount = 0;
   int total = ArraySize(tempSymbols);
   ArrayResize(g_symbols, total);
   ArrayResize(g_lastTradeTime, total);
   
   for(int i = 0; i < total; i++)
   {
      if(SymbolSelect(tempSymbols[i], true))
      {
         g_symbols[g_symbolCount] = tempSymbols[i];
         g_lastTradeTime[g_symbolCount] = 0;
         g_symbolCount++;
      }
   }
   ArrayResize(g_symbols, g_symbolCount);
   ArrayResize(g_lastTradeTime, g_symbolCount);
}

void InitializeIndicators()
{
   ArrayResize(g_rsiHandle, g_symbolCount);
   for(int i = 0; i < g_symbolCount; i++)
   {
      g_rsiHandle[i] = iRSI(g_symbols[i], PERIOD_M1, InpRSIPeriod, PRICE_CLOSE);
   }
}

void InitializeCorrelations()
{
   g_corrPairs[0][0] = "BTCUSD"; g_corrPairs[0][1] = "ETHUSD"; g_corrPairs[0][2] = "SOLUSD";
   g_corrPairs[1][0] = "ETHUSD"; g_corrPairs[1][1] = "BTCUSD"; g_corrPairs[1][2] = "SOLUSD";
   g_corrPairs[2][0] = "EURUSD"; g_corrPairs[2][1] = "GBPUSD";
}

void OnDeinit(const int reason)
{
   for(int i = 0; i < g_symbolCount; i++)
   {
      if(g_rsiHandle[i] != INVALID_HANDLE)
         IndicatorRelease(g_rsiHandle[i]);
   }
}

void OnTick()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != g_currentDay)
   {
      g_currentDay = today;
      g_dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   }
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity > g_peakEquity) g_peakEquity = currentEquity;
   
   if(!CheckRiskShield()) return;
   
   ManagePositions();
   ScanForSignals();
}

bool CheckRiskShield()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdownPct = (g_peakEquity - currentEquity) / g_peakEquity * 100;
   if(drawdownPct >= InpMaxDrawdown) return false;
   
   double dailyPnL = currentEquity - g_dailyStartEquity;
   double dailyLossPct = MathAbs(dailyPnL) / g_dailyStartEquity * 100;
   if(dailyPnL < 0 && dailyLossPct >= InpDailyLossLimit) return false;
   
   return true;
}

int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
         if(posInfo.Magic() == InpMagicNumber) count++;
   }
   return count;
}

bool HasPositionOnSymbol(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
         if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == symbol) return true;
   }
   return false;
}

bool HasCorrelatedPosition(string symbol)
{
   if(HasPositionOnSymbol(symbol)) return true;
   if(!InpUseCorrelation) return false;
   
   for(int i = 0; i < 10; i++)
   {
      if(g_corrPairs[i][0] == symbol)
      {
         if(g_corrPairs[i][1] != "" && HasPositionOnSymbol(g_corrPairs[i][1])) return true;
         if(g_corrPairs[i][2] != "" && HasPositionOnSymbol(g_corrPairs[i][2])) return true;
      }
   }
   return false;
}

double GetRSI(int index)
{
   double buffer[];
   if(CopyBuffer(g_rsiHandle[index], 0, 0, 1, buffer) <= 0) return 50;
   return buffer[0];
}

double GetMomentum(string symbol)
{
   double closes[];
   if(CopyClose(symbol, PERIOD_M1, 0, 11, closes) < 11) return 0;
   if(closes[10] == 0) return 0;
   return ((closes[0] - closes[10]) / closes[10]) * 100;
}

double GetVolatility(string symbol)
{
   double closes[];
   if(CopyClose(symbol, PERIOD_M1, 0, 11, closes) < 11) return 0;
   double sum = 0;
   for(int i = 0; i < 10; i++) sum += MathAbs(closes[i] - closes[i+1]);
   return sum / 10;
}

void GetSignal(string symbol, int index, int &sigType, int &strength, int &score)
{
   sigType = 0; strength = 0; score = 0;
   if(!m_symbol.Name(symbol)) return;
   
   m_symbol.RefreshRates();
   double bid = m_symbol.Bid();
   double ask = m_symbol.Ask();
   double spread = (ask - bid) / m_symbol.Point();
   
   if(spread > InpMaxSpread * 10) return;
   
   double rsi = GetRSI(index);
   double mom = GetMomentum(symbol);
   
   if(rsi < InpRSIOversold) { score += 20; strength++; }
   if(rsi > InpRSIOverbought) { score -= 20; strength++; }
   if(mom > 0.05) { score += 15; strength++; }
   if(mom < -0.05) { score -= 15; strength++; }
   
   if(score >= InpMinScore && strength >= InpMinStrength) sigType = 1;
   if(score <= -InpMinScore && strength >= InpMinStrength) sigType = -1;
}

void ScanForSignals()
{
   if(CountPositions() >= InpMaxPositions) return;
   
   for(int i = 0; i < g_symbolCount; i++)
   {
      string sym = g_symbols[i];
      if(TimeCurrent() - g_lastTradeTime[i] < InpCooldownSec) continue;
      if(HasCorrelatedPosition(sym)) continue;
      
      int sig, str, scr;
      GetSignal(sym, i, sig, str, scr);
      if(sig == 0) continue;
      
      m_symbol.Name(sym);
      m_symbol.RefreshRates();
      double pips = (m_symbol.Digits() == 3 || m_symbol.Digits() == 5) ? 10 * m_symbol.Point() : m_symbol.Point();
      
      double sl, tp, price;
      if(sig == 1)
      {
         price = m_symbol.Ask();
         sl = price - InpStopLoss * pips;
         tp = price + InpTakeProfit * pips;
         if(trade.Buy(InpBaseLot, sym, price, sl, tp)) g_lastTradeTime[i] = TimeCurrent();
      }
      else
      {
         price = m_symbol.Bid();
         sl = price + InpStopLoss * pips;
         tp = price - InpTakeProfit * pips;
         if(trade.Sell(InpBaseLot, sym, price, sl, tp)) g_lastTradeTime[i] = TimeCurrent();
      }
   }
}

void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i) || posInfo.Magic() != InpMagicNumber) continue;
      
      string sym = posInfo.Symbol();
      if(!m_symbol.Name(sym)) continue;
      m_symbol.RefreshRates();
      
      double pips = (m_symbol.Digits() == 3 || m_symbol.Digits() == 5) ? 10 * m_symbol.Point() : m_symbol.Point();
      double currentPrice = (posInfo.PositionType() == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
      double profit = (posInfo.PositionType() == POSITION_TYPE_BUY) ? (currentPrice - posInfo.PriceOpen()) : (posInfo.PriceOpen() - currentPrice);
      
      if(profit / pips >= InpTrailStart)
      {
         double trail = InpTrailStart * pips * InpTrailFactor;
         double newSL = (posInfo.PositionType() == POSITION_TYPE_BUY) ? (currentPrice - trail) : (currentPrice + trail);
         trade.PositionModify(posInfo.Ticket(), NormalizeDouble(newSL, m_symbol.Digits()), posInfo.TakeProfit());
      }
   }
}

void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& req, const MqlTradeResult& res) {}
EOF
