
//+------------------------------------------------------------------+
//|                                              HFT_Ultra_2026.mq5  |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

input double InpBaseLot=0.01;
input int    InpTakeProfit=15;
input int    InpStopLoss=5;
input int    InpTrailStart=6;
input double InpTrailFactor=0.4;
input int    InpMaxPositions=6;
input int    InpCooldownSec=3;

input int    InpRSIPeriod=14;
input int    InpRSIOversold=25;
input int    InpRSIOverbought=75;

input int    InpMinStrength=3;
input int    InpMinScore=25;
input double InpMaxSpread=2.0;

input double InpMaxDrawdown=5.0;
input double InpDailyLossLimit=3.0;
input bool   InpUseCorrelation=true;

input bool   InpDynamicLots=true;
input double InpMinLot=0.01;
input double InpMaxLot=0.05;

input int    InpMagicNumber=20260101;
input string InpComment="HFT_Ultra_2026";

CTrade trade;
CPositionInfo posInfo;
CAccountInfo accountInfo;
CSymbolInfo symbolInfo;

double g_startEquity,g_peakEquity,g_dailyStartEquity;
int g_totalWins,g_totalLosses,g_streak;
double g_grossWin,g_grossLoss;
datetime g_currentDay;

string g_symbols[];
int g_symbolCount;
int g_rsiHandle[];
datetime g_lastTradeTime[];

//------------------------------------------------------------------//
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);

   g_startEquity=accountInfo.Equity();
   g_peakEquity=g_startEquity;
   g_dailyStartEquity=g_startEquity;

   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   dt.hour=0; dt.min=0; dt.sec=0;
   g_currentDay=StructToTime(dt);

   string tmp[]={"EURUSD","GBPUSD","USDJPY","XAUUSD"};
   ArrayResize(g_symbols,ArraySize(tmp));
   ArrayResize(g_lastTradeTime,ArraySize(tmp));
   g_symbolCount=0;

   for(int i=0;i<ArraySize(tmp);i++)
   {
      if(SymbolSelect(tmp[i],true))
      {
         g_symbols[g_symbolCount]=tmp[i];
         g_lastTradeTime[g_symbolCount]=0;
         g_symbolCount++;
      }
   }

   ArrayResize(g_symbols,g_symbolCount);
   ArrayResize(g_lastTradeTime,g_symbolCount);
   ArrayResize(g_rsiHandle,g_symbolCount);

   for(int i=0;i<g_symbolCount;i++)
      g_rsiHandle[i]=iRSI(g_symbols[i],PERIOD_M1,InpRSIPeriod,PRICE_CLOSE);

   return INIT_SUCCEEDED;
}

//------------------------------------------------------------------//
void OnTick()
{
   double equity=accountInfo.Equity();
   if(equity>g_peakEquity) g_peakEquity=equity;

   double dd=(g_peakEquity-equity)/g_peakEquity*100.0;
   if(dd>=InpMaxDrawdown) return;

   double dailyPnL=equity-g_dailyStartEquity;
   if(dailyPnL<0 && MathAbs(dailyPnL)/g_dailyStartEquity*100.0>=InpDailyLossLimit)
      return;

   ManagePositions();
   ScanForSignals();
}

//------------------------------------------------------------------//
void ScanForSignals()
{
   if(PositionsTotal()>=InpMaxPositions) return;

   for(int i=0;i<g_symbolCount;i++)
   {
      string symbol=g_symbols[i];
      if(TimeCurrent()-g_lastTradeTime[i]<InpCooldownSec) continue;

      if(!SymbolSelect(symbol,true)) continue;
      symbolInfo.Name(symbol);
      symbolInfo.RefreshRates();

      double bid=symbolInfo.Bid();
      double ask=symbolInfo.Ask();

      double spreadPoints=(ask-bid)/symbolInfo.Point();
      double spreadPips=spreadPoints;
      if(symbolInfo.Digits()==3||symbolInfo.Digits()==5)
         spreadPips/=10.0;

      if(spreadPips>InpMaxSpread) continue;

      double rsi[];
      ArraySetAsSeries(rsi,true);
      if(CopyBuffer(g_rsiHandle[i],0,0,1,rsi)<=0) continue;

      int signal=0;
      if(rsi[0]<InpRSIOversold) signal=1;
      if(rsi[0]>InpRSIOverbought) signal=-1;
      if(signal==0) continue;

      double lot=InpBaseLot;
      double point=symbolInfo.Point();
      int digits=symbolInfo.Digits();
      double pip=(digits==3||digits==5)?point*10:point;

      if(signal==1)
      {
         trade.Buy(lot,symbol,ask,
            NormalizeDouble(ask-InpStopLoss*pip,digits),
            NormalizeDouble(ask+InpTakeProfit*pip,digits),
            InpComment);
      }
      else
      {
         trade.Sell(lot,symbol,bid,
            NormalizeDouble(bid+InpStopLoss*pip,digits),
            NormalizeDouble(bid-InpTakeProfit*pip,digits),
            InpComment);
      }

      g_lastTradeTime[i]=TimeCurrent();
   }
}

//------------------------------------------------------------------//
void ManagePositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic()!=InpMagicNumber) continue;

      string symbol=posInfo.Symbol();
      if(!SymbolSelect(symbol,true)) continue;
      symbolInfo.Name(symbol);
      symbolInfo.RefreshRates();

      double point=symbolInfo.Point();
      int digits=symbolInfo.Digits();
      double pip=(digits==3||digits==5)?point*10:point;

      double price=(posInfo.PositionType()==POSITION_TYPE_BUY)?
         symbolInfo.Bid():symbolInfo.Ask();

      double profitPips=(posInfo.PositionType()==POSITION_TYPE_BUY)?
         (price-posInfo.PriceOpen())/pip:
         (posInfo.PriceOpen()-price)/pip;

      if(profitPips<InpTrailStart) continue;

      double trail=InpTrailStart*pip*InpTrailFactor;
      double newSL=(posInfo.PositionType()==POSITION_TYPE_BUY)?
         price-trail:price+trail;

      trade.PositionModify(posInfo.Ticket(),
         NormalizeDouble(newSL,digits),
         posInfo.TakeProfit());
   }
}
