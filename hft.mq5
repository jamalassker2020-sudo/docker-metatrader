//+------------------------------------------------------------------+
//|                                     HFT_ForexStrategy_2026.mq5 |
//|                                High-Frequency Trading Strategy          |
//|                         Multi-Pair with Trailing Stop & Profit Lock  |
//+------------------------------------------------------------------+
#property copyright "HFT Strategy 2026"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Input Parameters
input double   InpLotSize        = 0.1;      // Lot Size
input int      InpMaxPositions   = 10;       // Max Open Positions
input int      InpTakeProfit     = 20;       // Take Profit (pips)
input int      InpStopLoss       = 15;       // Stop Loss (pips)
input int      InpTrailingStart  = 10;       // Trailing Start (pips)
input int      InpTrailingStep   = 5;        // Trailing Step (pips)
input double   InpProfitLockPct  = 0.5;      // Profit Lock Percentage (0.5 = 50%)
input int      InpSignalPeriod   = 14;       // Signal Period
input double   InpSignalThreshold= 0.6;      // Signal Threshold
input bool     InpUseBalanceShield = true;   // Use Balance Shield
input double   InpMaxDrawdownPct = 10.0;     // Max Drawdown % for Shield

//--- Global Variables
CTrade          trade;
CPositionInfo   posInfo;
CAccountInfo    accInfo;

string pairs[] = {
    "EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD","NZDUSD",
    "EURGBP","EURJPY","EURCHF","EURAUD","EURCAD","EURNZD",
    "GBPJPY","GBPCHF","GBPAUD","GBPCAD","GBPNZD",
    "AUDJPY","AUDCHF","AUDCAD","AUDNZD",
    "CADJPY","CADCHF","CHFJPY","NZDJPY","NZDCHF","NZDCAD","USDSGD"
};

double peakBalance = 0;
double lockedProfit = 0;
double initialBalance = 0;
int totalWins = 0;
int totalLosses = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    initialBalance = accInfo.Balance();
    peakBalance = initialBalance;
    lockedProfit = 0;
    
    trade.SetExpertMagicNumber(202601);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    Print("HFT Forex Strategy 2026 Initialized");
    Print("Initial Balance: ", initialBalance);
    Print("Monitoring ", ArraySize(pairs), " currency pairs");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Strategy stopped. Final Stats:");
    Print("Locked Profit: $", lockedProfit);
    Print("Win Rate: ", (totalWins + totalLosses > 0) ? 
          (double)totalWins / (totalWins + totalLosses) * 100 : 0, "%");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Balance Shield Check
    if(InpUseBalanceShield && CheckDrawdownExceeded())
    {
       CloseAllPositions("Balance Shield Triggered");
       return;
    }
    
    // Update Trailing Stops
    UpdateTrailingStops();
    
    // Check Profit Lock
    CheckAndLockProfit();
    
    // Generate Signals and Trade
    if(CountOpenPositions() < InpMaxPositions)
    {
       for(int i = 0; i < ArraySize(pairs); i++)
       {
          ProcessPair(pairs[i]);
       }
    }
}

//+------------------------------------------------------------------+
//| Process individual pair for signals                              |
//+------------------------------------------------------------------+
void ProcessPair(string symbol)
{
    if(!SymbolSelect(symbol, true)) return;
    if(HasOpenPosition(symbol)) return;
    
    double signal = CalculateSignal(symbol);
    
    if(signal > InpSignalThreshold)
    {
       OpenTrade(symbol, ORDER_TYPE_BUY);
    }
    else if(signal < -InpSignalThreshold)
    {
       OpenTrade(symbol, ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Calculate trading signal (-1 to 1)                               |
//+------------------------------------------------------------------+
double CalculateSignal(string symbol)
{
    double signal = 0;
    
    // RSI Component
    double rsi[];
    ArraySetAsSeries(rsi, true);
    int rsiHandle = iRSI(symbol, PERIOD_M1, InpSignalPeriod, PRICE_CLOSE);
    if(rsiHandle != INVALID_HANDLE)
    {
       if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) > 0)
       {
          if(rsi[0] < 30) signal += 0.4;
          else if(rsi[0] > 70) signal -= 0.4;
       }
       IndicatorRelease(rsiHandle);
    }
    
    // Momentum Component
    double ma_fast[], ma_slow[];
    ArraySetAsSeries(ma_fast, true);
    ArraySetAsSeries(ma_slow, true);
    
    int maFastHandle = iMA(symbol, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE);
    int maSlowHandle = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
    
    if(maFastHandle != INVALID_HANDLE && maSlowHandle != INVALID_HANDLE)
    {
       if(CopyBuffer(maFastHandle, 0, 0, 2, ma_fast) > 0 &&
          CopyBuffer(maSlowHandle, 0, 0, 2, ma_slow) > 0)
       {
          if(ma_fast[0] > ma_slow[0] && ma_fast[1] <= ma_slow[1])
             signal += 0.5;
          else if(ma_fast[0] < ma_slow[0] && ma_fast[1] >= ma_slow[1])
             signal -= 0.5;
       }
       IndicatorRelease(maFastHandle);
       IndicatorRelease(maSlowHandle);
    }
    
    // Volume spike detection - FIXED: Must use long array for Tick Volume
    long tick_volume[];
    ArraySetAsSeries(tick_volume, true);
    if(CopyTickVolume(symbol, PERIOD_M1, 0, 20, tick_volume) > 0)
    {
       double avgVol = 0;
       for(int i = 1; i < 20; i++) avgVol += (double)tick_volume[i];
       avgVol /= 19;
       
       if((double)tick_volume[0] > avgVol * 1.5)
          signal *= 1.3;
    }
    
    return MathMax(-1, MathMin(1, signal));
}

//+------------------------------------------------------------------+
//| Open a trade                                                     |
//+------------------------------------------------------------------+
void OpenTrade(string symbol, ENUM_ORDER_TYPE orderType)
{
    double price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(symbol, SYMBOL_BID);
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pipValue = (StringFind(symbol, "JPY") >= 0) ? 0.01 : 0.0001;
    
    double sl, tp;
    if(orderType == ORDER_TYPE_BUY)
    {
       sl = NormalizeDouble(price - InpStopLoss * pipValue, digits);
       tp = NormalizeDouble(price + InpTakeProfit * pipValue, digits);
    }
    else
    {
       sl = NormalizeDouble(price + InpStopLoss * pipValue, digits);
       tp = NormalizeDouble(price - InpTakeProfit * pipValue, digits);
    }
    
    // FIXED: PositionOpen parameters
    if(trade.PositionOpen(symbol, orderType, InpLotSize, price, sl, tp, "HFT2026"))
    {
       Print("Opened ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), 
             " on ", symbol, " at ", price);
    }
}

//+------------------------------------------------------------------+
//| Update trailing stops for all positions                          |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
       if(!posInfo.SelectByIndex(i)) continue;
       if(posInfo.Magic() != 202601) continue;
       
       string symbol = posInfo.Symbol();
       double pipValue = (StringFind(symbol, "JPY") >= 0) ? 0.01 : 0.0001;
       
       double currentPrice = posInfo.PriceCurrent();
       double openPrice = posInfo.PriceOpen();
       double currentSL = posInfo.StopLoss();
       
       if(posInfo.PositionType() == POSITION_TYPE_BUY)
       {
          double profitPips = (currentPrice - openPrice) / pipValue;
          if(profitPips >= InpTrailingStart)
          {
             double newSL = NormalizeDouble(currentPrice - InpTrailingStep * pipValue, 
                           (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
             if(newSL > currentSL)
             {
                trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
             }
          }
       }
       else
       {
          double profitPips = (openPrice - currentPrice) / pipValue;
          if(profitPips >= InpTrailingStart)
          {
             double newSL = NormalizeDouble(currentPrice + InpTrailingStep * pipValue,
                           (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
             if(newSL < currentSL || currentSL == 0)
             {
                trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
             }
          }
       }
    }
}

//+------------------------------------------------------------------+
//| Check and lock profits (ratchet mechanism)                       |
//+------------------------------------------------------------------+
void CheckAndLockProfit()
{
    double currentBalance = accInfo.Balance();
    double currentEquity = accInfo.Equity();
    double profit = currentBalance - initialBalance;
    
    if(currentBalance > peakBalance)
    {
       peakBalance = currentBalance;
       double newLock = profit * InpProfitLockPct;
       if(newLock > lockedProfit)
       {
          lockedProfit = newLock;
          Print("PROFIT LOCKED: $", lockedProfit);
       }
    }
    
    if(InpUseBalanceShield && lockedProfit > 0)
    {
       double minEquity = initialBalance + lockedProfit;
       if(currentEquity < minEquity * 0.95)
       {
          CloseAllPositions("Protecting Locked Profit");
          Print("SHIELD: Closed positions to protect $", lockedProfit, " locked profit");
       }
    }
}

//+------------------------------------------------------------------+
//| Check if drawdown exceeded                                       |
//+------------------------------------------------------------------+
bool CheckDrawdownExceeded()
{
    double currentEquity = accInfo.Equity();
    double drawdownPct = (peakBalance - currentEquity) / peakBalance * 100;
    return drawdownPct >= InpMaxDrawdownPct;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
       if(!posInfo.SelectByIndex(i)) continue;
       if(posInfo.Magic() != 202601) continue;
       
       if(posInfo.Profit() > 0) totalWins++;
       else totalLosses++;
       
       trade.PositionClose(posInfo.Ticket());
    }
    Print("All positions closed: ", reason);
}

//+------------------------------------------------------------------+
//| Count open positions                                             |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
       if(posInfo.SelectByIndex(i) && posInfo.Magic() == 202601)
          count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Check if position exists for symbol                              |
//+------------------------------------------------------------------+
bool HasOpenPosition(string symbol)
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
       if(posInfo.SelectByIndex(i) && 
          posInfo.Magic() == 202601 && 
          posInfo.Symbol() == symbol)
          return true;
    }
    return false;
}
