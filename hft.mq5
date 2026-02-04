//+------------------------------------------------------------------+
//|                                     HFT_2026_QuantumShield_ULTRA |
//|                                  Copyright 2026, Gemini Adaptive |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini AI"
#property version   "11.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- HYPER-HFT INPUTS
input double InpStartLot      = 0.1;        
input double InpExpFactor     = 0.0001;     
input double InpLockProfit    = 2.0;        // LOWERED to $2.0 for faster rotations
input int    InpMaxPos        = 100;        // INCREASED global limit
input int    InpSpreadLimit   = 100;       // RELAXED to 100 points (1.0 pip) for high activity
input int    InpDeviation     = 10;         // TIGHTER 10-point gap for instant entries
input string InpShieldID      = "QS_ULTRA_TOTAL_2026";

CTrade      m_trade;
double      g_shield_total = 0;
string      g_pairs[] = {"EURUSD","GBPUSD","USDJPY","AUDUSD","USDCAD","NZDUSD","USDCHF","EURGBP","EURJPY","GBPJPY"};

int OnInit() {
   if(GlobalVariableCheck(InpShieldID)) g_shield_total = GlobalVariableGet(InpShieldID);
   else GlobalVariableSet(InpShieldID, 0.0);

   m_trade.SetExpertMagicNumber(2026999);
   m_trade.SetAsyncMode(true); 
   
   // FORCE FILLING: Ensures Valetax and ECN brokers accept the order instantly
   m_trade.SetTypeFilling(ORDER_FILLING_IOC); 

   Print("HYPER-KERNEL ACTIVE. READY FOR INSTANT EXECUTION.");
   return(INIT_SUCCEEDED);
}

void OnTick() {
   double d_lot = NormalizeDouble(InpStartLot + (g_shield_total * InpExpFactor), 2);
   if(d_lot > 20.0) d_lot = 20.0;

   for(int i=0; i<ArraySize(g_pairs); i++) {
      string sym = g_pairs[i];
      
      // OPTIMIZED: Direct tick check (Faster than SymbolSelect)
      MqlTick last_tick;
      if(!SymbolInfoTick(sym, last_tick)) continue;
      
      // SPREAD CHECK
      int spread = (int)((last_tick.ask - last_tick.bid) / SymbolInfoDouble(sym, SYMBOL_POINT));
      if(spread > InpSpreadLimit) continue;

      // FAST ANCHOR (20 EMA for HFT Speed)
      double anchor = iMA(sym, _Period, 20, 0, MODE_EMA, PRICE_CLOSE);
      double gap = InpDeviation * SymbolInfoDouble(sym, SYMBOL_POINT);

      // HYPER-ENTRY LOGIC
      if(PositionsTotal() < InpMaxPos) {
         if(last_tick.bid < anchor - gap) m_trade.Buy(d_lot, sym, last_tick.ask, 0, 0, "HFT_INSTANT");
         if(last_tick.ask > anchor + gap) m_trade.Sell(d_lot, sym, last_tick.bid, 0, 0, "HFT_INSTANT");
      }
   }

   // AGGRESSIVE LOCKING
   for(int j=PositionsTotal()-1; j>=0; j--) {
      ulong ticket = PositionGetTicket(j);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetDouble(POSITION_PROFIT) >= InpLockProfit) {
            g_shield_total += PositionGetDouble(POSITION_PROFIT);
            GlobalVariableSet(InpShieldID, g_shield_total);
            m_trade.PositionClose(ticket);
         }
      }
   }
}
