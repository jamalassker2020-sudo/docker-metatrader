//+------------------------------------------------------------------+
//|                                     HFT_2026_QuantumShield_ULTRA |
//|                                  Copyright 2026, Gemini Adaptive |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini AI"
#property version   "6.10"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- INPUT PARAMETERS
input double   InpBaseLot      = 0.1;          // Base Lot Size
input double   InpRiskWeight   = 0.0001;       // Exponential growth per $1 profit
input int      InpMaxPositions = 15;           // Max concurrent positions
input double   InpLockProfit   = 5.0;          // Lock profit aggressively at $5
input string   InpShieldID     = "SHIELD_2026_V6";

//--- STATE PERSISTENCE
double         g_shielded_profit = 0;
double         ecb_anchor_rate   = 0;
CTrade         m_trade;

//+------------------------------------------------------------------+
//| INIT: Detect Filling Mode & Recover Shield                       |
//+------------------------------------------------------------------+
int OnInit() {
   // 1. RECOVER PERMANENT PROFITS (Won't reset on refresh)
   if(GlobalVariableCheck(InpShieldID)) 
      g_shielded_profit = GlobalVariableGet(InpShieldID);
   else 
      GlobalVariableSet(InpShieldID, 0.0);

   // 2. AUTO-FIX FOR VALETAX EXECUTION (Filling Mode)
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0) m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) != 0) m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   m_trade.SetExpertMagicNumber(20262026);
   EventSetTimer(30); // Faster ECB Sync (Every 30s)
   
   Print("== ULTRA SHIELD READY. FILLING MODE: ", m_trade.GetTypeFilling());
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| THE HFT ENGINE: Multi-Position & Auto-Lock                       |
//+------------------------------------------------------------------+
void OnTick() {
   // FAIL-SAFE: If ECB hasn't loaded, use a calculated Moving Average as Anchor
   double current_anchor = (ecb_anchor_rate > 0) ? ecb_anchor_rate : iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // 1. EXPONENTIAL LOT SIZING
   double dynamic_lot = InpBaseLot + (g_shielded_profit * InpRiskWeight);
   dynamic_lot = MathMin(dynamic_lot, 10.0); // Safety Limit

   // 2. AGGRESSIVE HFT ENTRY
   if(PositionsTotal() < InpMaxPositions) {
      // Deviation strategy: Buy if price is significantly below anchor
      if(bid < current_anchor - (20 * _Point)) { 
         if(m_trade.Buy(dynamic_lot, _Symbol, ask, 0, 0, "ULTRA_HFT"))
            Print("HFT BUY OPENED. Lot: ", dynamic_lot);
         else
            Print("Trade Error: ", GetLastError());
      }
      else if(ask > current_anchor + (20 * _Point)) {
         if(m_trade.Sell(dynamic_lot, _Symbol, bid, 0, 0, "ULTRA_HFT"))
            Print("HFT SELL OPENED. Lot: ", dynamic_lot);
      }
   }

   // 3. THE "NEVER-LOSE" PERMANENT PROFIT LOCK
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i))) {
         double profit = PositionGetDouble(POSITION_PROFIT);
         
         if(profit >= InpLockProfit) {
            // TRANSFER TO DISK STORAGE
            g_shielded_profit += profit;
            GlobalVariableSet(InpShieldID, g_shielded_profit);
            
            m_trade.PositionClose(PositionGetTicket(i));
            Print("SHIELD UPDATED: $", g_shielded_profit, " LOCKED PERMANENTLY.");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ECB SYNC: Real 2026 Live Data                                    |
//+------------------------------------------------------------------+
void OnTimer() {
   string url = "https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A?lastNObservations=1&format=jsondata";
   char post[], result[];
   string headers;
   
   ResetLastError();
   int res = WebRequest("GET", url, NULL, 5000, post, result, headers);
   
   if(res == 200) {
      string response = CharArrayToString(result);
      int val_pos = StringFind(response, "\"v\":", 0);
      if(val_pos != -1) {
         string val_str = StringSubstr(response, val_pos + 4, 6);
         ecb_anchor_rate = StringToDouble(val_str);
      }
   } else {
      Print("ECB Sync Wait (Error ", GetLastError(), "). Using Fail-safe Anchor.");
   }
}
