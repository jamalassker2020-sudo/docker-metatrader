//+------------------------------------------------------------------+
//|                        HFT_2026_QuantumShield_ULTRA_PRO_v12_5    |
//|                                  Copyright 2026, Advanced Market |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property version   "12.5"
#property strict
#property expert_gateway "HFT_KERNEL"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- HYPER-HFT INPUTS
input double    InpStartLot         = 0.01;         
input double    InpExpFactor        = 0.00005;      
input double    InpLockProfit       = 0.5;          
input int       InpMaxPos           = 200;          
input int       InpSpreadLimit      = 80;           
input int       InpDeviation        = 15;           
input int       InpTrailStart       = 10;           
input int       InpTrailStep        = 5;            
input bool      InpUseECBAnchor     = true;         
input string    InpShieldID         = "QS_ULTRA_TOTAL_2026_PRO";
input int       InpMagicNumber      = 2026999;

//--- 29 Major Pairs + Crosses
string g_pairs[] = {"EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD","NZDUSD","EURGBP","EURJPY","EURCHF","EURAUD","EURCAD","EURNZD","GBPJPY","GBPCHF","GBPAUD","GBPCAD","GBPNZD","AUDJPY","CADJPY","CHFJPY","NZDJPY","AUDCAD","AUDCHF","AUDNZD","CADCHF","NZDCHF","NZDCAD","USDSEK"};

CTrade          m_trade;
CPositionInfo   m_position;
CSymbolInfo     m_symbol_info; // Renamed for clarity
double          g_shield_total = 0;
double          g_active_profit = 0;

int OnInit() {
   if(GlobalVariableCheck(InpShieldID)) g_shield_total = GlobalVariableGet(InpShieldID);
   else GlobalVariableSet(InpShieldID, 0.0);
   
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetAsyncMode(true);
   
   // FIX: Specific Broker Filling Check
   uint fill = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fill & SYMBOL_FILLING_FOK) != 0) m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else m_trade.SetTypeFilling(ORDER_FILLING_IOC);

   for(int i = 0; i < ArraySize(g_pairs); i++) SymbolSelect(g_pairs[i], true);
   
   EventSetMillisecondTimer(100); // 1ms is often too fast for MT5 CPU, 100ms is the HFT 'Sweet Spot'
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   EventKillTimer();
   GlobalVariableSet(InpShieldID, g_shield_total);
}

void OnTick() {
   double d_lot = CalculateDynamicLot();
   for(int i = 0; i < ArraySize(g_pairs); i++) {
      ProcessSymbol(g_pairs[i], d_lot);
   }
   ManagePositions();
   g_active_profit = CalculateActiveProfit();
   UpdateDisplay();
}

void OnTimer() {
   CheckAndLockProfits();
}

double CalculateDynamicLot() {
   double lot = InpStartLot * (1 + (g_shield_total * InpExpFactor));
   return NormalizeDouble(MathMin(lot, 50.0), 2);
}

void ProcessSymbol(string symbol, double lot_size) {
   if(!m_symbol_info.Name(symbol)) return;
   m_symbol_info.Refresh(); // CRITICAL: Refresh data for the specific symbol in loop
   
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick)) return;
   
   if(((tick.ask - tick.bid)/m_symbol_info.Point()) > InpSpreadLimit) return;
   if(PositionsTotal() >= InpMaxPos) return;
   
   double anchor = CalculateAnchor(symbol);
   double dev = InpDeviation * m_symbol_info.Point();
   
   if(tick.bid < anchor - dev) m_trade.Buy(lot_size, symbol, tick.ask, 0, 0);
   if(tick.ask > anchor + dev) m_trade.Sell(lot_size, symbol, tick.bid, 0, 0);
}

double CalculateAnchor(string symbol) {
   return iMA(symbol, PERIOD_M1, 15, 0, MODE_EMA, PRICE_CLOSE); // Optimized for pure HFT speed
}

void ManagePositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Magic() != InpMagicNumber) continue;
         ApplyTrailingStop(m_position.Ticket(), m_position.Symbol());
      }
   }
}

void ApplyTrailingStop(ulong ticket, string sym) {
   double p_bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double p_ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double sl = PositionGetDouble(POSITION_SL);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
      if(p_bid - open > InpTrailStart * point) {
         double new_sl = p_bid - (InpTrailStep * point);
         if(new_sl > sl) m_trade.PositionModify(ticket, new_sl, 0);
      }
   } else {
      if(open - p_ask > InpTrailStart * point) {
         double new_sl = p_ask + (InpTrailStep * point);
         if(new_sl < sl || sl == 0) m_trade.PositionModify(ticket, new_sl, 0);
      }
   }
}

void CheckAndLockProfits() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if(m_position.Magic() == InpMagicNumber && m_position.Profit() >= InpLockProfit) {
            double p = m_position.Profit();
            if(m_trade.PositionClose(m_position.Ticket())) {
               g_shield_total += p;
               GlobalVariableSet(InpShieldID, g_shield_total);
            }
         }
      }
   }
}

double CalculateActiveProfit() {
   double total = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      if(m_position.SelectByIndex(i) && m_position.Magic() == InpMagicNumber)
         total += m_position.Profit();
   }
   return total;
}

void UpdateDisplay() {
   Comment("HFT QUANTUM SHIELD 2026\n------------------\nSHIELDED: $", DoubleToString(g_shield_total, 2), 
           "\nACTIVE: $", DoubleToString(g_active_profit, 2), "\nLOT: ", CalculateDynamicLot());
}
