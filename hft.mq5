
//+------------------------------------------------------------------+
//|                                                      HFT_Neural.mq5 |
//|                                                      Version 2.5 |
//|                                             HFT Neural Dashboard |
//+------------------------------------------------------------------+
#property copyright "HFT Neural Quantum Trading Engine"
#property version   "2.50"
#property strict

#include <Trade/Trade.mq5>
#include <Trade/SymbolInfo.mq5>
#include <Trade/PositionInfo.mq5>
#include <Trade/AccountInfo.mq5>
#include <Arrays/ArrayObj.mq5>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input double   RiskPercent        = 1.0;     // Risk per trade (%)
input double   MaxDailyLoss       = 3.0;     // Max daily loss (%)
input int      MaxOpenTrades      = 5;       // Max open trades
input int      CooldownSeconds    = 10;      // Cooldown between trades
input string   TradingPairs       = "BTCUSD,ETHUSD,SOLUSD,BNBUSD,XRPUSD,ADAUSD,AVAXUSD,DOGEUSD,DOTUSD,LINKUSD,MATICUSD,SHIBUSD,LTCUSD,TRXUSD,UNIUSD,BCHUSD,XLMUSD,NEARUSD,ATOMUSD,XMRUSD";
input int      StopLossPips       = 30;      // Stop Loss in Pips
input int      TakeProfitPips     = 60;      // Take Profit in Pips

//+------------------------------------------------------------------+
//| Definitions & Structures                                         |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_TYPE { SIGNAL_BULLISH, SIGNAL_BEARISH, SIGNAL_NEUTRAL };

struct SStrategy {
   string name;
   double winRate;
   bool   isActive;
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade          trade;
CSymbolInfo     m_symbol;
CAccountInfo    account;
CPositionInfo   m_pos;

// State
double    initialBalance;
bool      botRunning = true;
datetime  lastTradeTime = 0;
datetime  sessionStart;
int       totalWins = 0, totalLosses = 0;

// Indicator Handles
int       rsiH, macdH, adxH;
double    rsiVal, macdMain, macdSig, adxVal;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   sessionStart = TimeCurrent();
   account.Refresh();
   initialBalance = account.Balance();
   
   trade.SetExpertMagicNumber(998877);
   
   // Initialize Handles
   rsiH = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
   macdH = iMACD(_Symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
   adxH = iADX(_Symbol, PERIOD_M1, 14);
   
   if(rsiH == INVALID_HANDLE || macdH == INVALID_HANDLE) return INIT_FAILED;
   
   Print("HFT Neural v2.5 initialized. Monitoring: ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
// New Inputs for Trailing Stop
input int TrailingStopPips = 20; // Distance to trail (in pips)
input int TrailingStartPips = 10; // Only start trailing after this much profit

void OnTick() {
   if(!botRunning) return;

   if(!UpdateMarketData()) return;
   UpdateDailyStats();
   
   // 1. Risk Management Check
   double currentPNL = (account.Equity() - initialBalance) / initialBalance * 100.0;
   if(currentPNL <= -MaxDailyLoss) { botRunning = false; return; }

   // 2. Apply Trailing Stop to all active positions
   ApplyTrailingStop();

   // 3. Trading Logic
   if(TimeCurrent() - lastTradeTime >= CooldownSeconds && PositionsTotal() < MaxOpenTrades) {
      CheckSignalsAndExecute();
   }
   
   DisplayDashboard();
}

void ApplyTrailingStop() {
   double pSize = GetPipValue();
   double trailDist = TrailingStopPips * pSize;
   double trailStart = TrailingStartPips * pSize;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_pos.SelectByIndex(i)) {
         if(m_pos.Symbol() != _Symbol) continue;

         double currentSL = m_pos.StopLoss();
         double openPrice = m_pos.PriceOpen();
         double currentPrice = (m_pos.PositionType() == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         if(m_pos.PositionType() == POSITION_TYPE_BUY) {
            // Check if price is far enough above entry to start trailing
            if(currentPrice - openPrice > trailStart) {
               double newSL = NormalizeDouble(currentPrice - trailDist, _Digits);
               if(newSL > currentSL || currentSL == 0) {
                  trade.PositionModify(m_pos.Ticket(), newSL, m_pos.TakeProfit());
               }
            }
         } 
         else if(m_pos.PositionType() == POSITION_TYPE_SELL) {
            if(openPrice - currentPrice > trailStart) {
               double newSL = NormalizeDouble(currentPrice + trailDist, _Digits);
               if(newSL < currentSL || currentSL == 0) {
                  trade.PositionModify(m_pos.Ticket(), newSL, m_pos.TakeProfit());
               }
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//| Core Functions                                                   |
//+------------------------------------------------------------------+

bool UpdateMarketData() {
   double r[], m[], s[], a[];
   if(CopyBuffer(rsiH,0,0,1,r)<1 || CopyBuffer(macdH,0,0,1,m)<1 || 
      CopyBuffer(macdH,1,0,1,s)<1 || CopyBuffer(adxH,0,0,1,a)<1) return false;
      
   rsiVal = r[0];
   macdMain = m[0];
   macdSig = s[0];
   adxVal = a[0];
   return true;
}

void CheckSignalsAndExecute() {
   ENUM_SIGNAL_TYPE signal = SIGNAL_NEUTRAL;
   
   // Neural-style logic: Trend (ADX) + Momentum (MACD) + Mean Reversion (RSI)
   if(adxVal > 20) { // Only trade if there is trend strength
      if(rsiVal < 35 && macdMain > macdSig) signal = SIGNAL_BULLISH;
      if(rsiVal > 65 && macdMain < macdSig) signal = SIGNAL_BEARISH;
   }

   if(signal != SIGNAL_NEUTRAL) {
      double lot = CalculateLot();
      Execute(signal == SIGNAL_BULLISH ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, lot);
   }
}

void Execute(ENUM_ORDER_TYPE type, double lot) {
   m_symbol.Name(_Symbol);
   m_symbol.RefreshRates();
   
   double price = (type == ORDER_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();
   double pSize = GetPipValue();
   
   double sl = (type == ORDER_TYPE_BUY) ? price - (StopLossPips * pSize) : price + (StopLossPips * pSize);
   double tp = (type == ORDER_TYPE_BUY) ? price + (TakeProfitPips * pSize) : price - (TakeProfitPips * pSize);

   if(trade.PositionOpen(_Symbol, type, lot, price, sl, tp, "HFT Neural")) {
      lastTradeTime = TimeCurrent();
      Print("HFT Trade Executed: ", EnumToString(type));
   }
}

double CalculateLot() {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot = NormalizeDouble((account.Balance() * (RiskPercent/100.0)) / 1000.0, 2);
   return (lot < minLot) ? minLot : lot;
}

double GetPipValue() {
   // Logic to handle 3/5 digit brokers and Crypto decimals
   if(_Digits == 3 || _Digits == 5) return _Point * 10;
   return _Point;
}

void UpdateDailyStats() {
   if(!HistorySelect(sessionStart, TimeCurrent())) return;
   totalWins = 0; totalLosses = 0;
   
   for(int i = HistoryDealsTotal()-1; i >= 0; i--) {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double p = HistoryDealGetDouble(t, DEAL_PROFIT);
         if(p > 0) totalWins++; else if(p < 0) totalLosses++;
      }
   }
}

void DisplayDashboard() {
   double wr = (totalWins + totalLosses > 0) ? (double)totalWins/(totalWins+totalLosses)*100.0 : 0;
   Comment("=== HFT NEURAL QUANTUM ===\n",
           "Status: ", (botRunning ? "RUNNING" : "STOPPED"), "\n",
           "Balance: ", DoubleToString(account.Balance(), 2), "\n",
           "Today Wins/Losses: ", totalWins, "/", totalLosses, "\n",
           "Win Rate: ", DoubleToString(wr, 1), "%\n",
           "RSI: ", DoubleToString(rsiVal, 1), " | ADX: ", DoubleToString(adxVal, 1));
}

void OnDeinit(const int reason) {
   IndicatorRelease(rsiH);
   IndicatorRelease(macdH);
   IndicatorRelease(adxH);
   Comment("");
}
