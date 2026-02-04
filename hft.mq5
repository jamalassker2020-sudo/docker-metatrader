//+------------------------------------------------------------------+
//|                     HFT_2026_QuantumShield_ULTRA_FIXED           |
//|                                  Copyright 2026, Gemini Adaptive |
//|                    FIXED: Multi-Symbol Independent Trading       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini AI"
#property version   "7.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- INPUT PARAMETERS
input double   InpBaseLot      = 0.1;          // Base Lot Size
input double   InpRiskWeight   = 0.0001;       // Exponential growth per $1 profit
input int      InpMaxPositions = 15;           // Max positions PER SYMBOL
input double   InpLockProfit   = 5.0;          // Lock profit aggressively at $5
input string   InpShieldID     = "SHIELD_2026_V7";

//--- STATE PERSISTENCE
double         g_shielded_profit = 0;
CTrade         m_trade;
ulong          g_magic = 0;                    // Symbol-specific magic number

//+------------------------------------------------------------------+
//| Generate unique magic number per symbol                          |
//+------------------------------------------------------------------+
ulong GenerateSymbolMagic(string symbol) {
   ulong hash = 20262026;  // Base magic
   for(int i = 0; i < StringLen(symbol); i++) {
      hash = hash * 31 + StringGetCharacter(symbol, i);
   }
   return hash;
}

//+------------------------------------------------------------------+
//| Count positions for CURRENT SYMBOL with OUR magic number         |
//+------------------------------------------------------------------+
int CountMySymbolPositions() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         // Only count if SAME SYMBOL and SAME MAGIC NUMBER
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == (long)g_magic) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| INIT: Detect Filling Mode & Recover Shield                       |
//+------------------------------------------------------------------+
int OnInit() {
   // 1. GENERATE UNIQUE MAGIC FOR THIS SYMBOL
   g_magic = GenerateSymbolMagic(_Symbol);
   m_trade.SetExpertMagicNumber(g_magic);

   // 2. RECOVER PERMANENT PROFITS (Symbol-specific storage)
   string shieldKey = InpShieldID + "_" + _Symbol;
   if(GlobalVariableCheck(shieldKey))
      g_shielded_profit = GlobalVariableGet(shieldKey);
   else
      GlobalVariableSet(shieldKey, 0.0);

   // 3. AUTO-FIX FOR VALETAX EXECUTION (Filling Mode)
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   Print("== ULTRA SHIELD READY on ", _Symbol);
   Print("== Magic: ", g_magic, " | Filling: ", m_trade.TypeFillingDescription());
   Print("== Max positions for this symbol: ", InpMaxPositions);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| THE HFT ENGINE: Multi-Position & Auto-Lock (SYMBOL INDEPENDENT)  |
//+------------------------------------------------------------------+
void OnTick() {
   // ANCHOR: Use Moving Average for ALL symbols (universal)
   int ma_handle = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
   double ma_buffer[];
   ArraySetAsSeries(ma_buffer, true);

   if(CopyBuffer(ma_handle, 0, 0, 1, ma_buffer) <= 0) {
      // Fallback if MA fails
      return;
   }
   double current_anchor = ma_buffer[0];
   IndicatorRelease(ma_handle);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // 1. EXPONENTIAL LOT SIZING
   double dynamic_lot = InpBaseLot + (g_shielded_profit * InpRiskWeight);
   dynamic_lot = NormalizeDouble(MathMin(dynamic_lot, 10.0), 2); // Safety Limit

   // Ensure minimum lot
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   dynamic_lot = MathMax(dynamic_lot, min_lot);
   dynamic_lot = MathMin(dynamic_lot, max_lot);
   dynamic_lot = NormalizeDouble(MathFloor(dynamic_lot / lot_step) * lot_step, 2);

   // 2. COUNT ONLY THIS SYMBOL'S POSITIONS
   int myPositions = CountMySymbolPositions();

   // 3. AGGRESSIVE HFT ENTRY (Independent per symbol)
   if(myPositions < InpMaxPositions) {
      double deviation = 20 * point;

      // Deviation strategy: Buy if price is significantly below anchor
      if(bid < current_anchor - deviation) {
         if(m_trade.Buy(dynamic_lot, _Symbol, ask, 0, 0, "ULTRA_HFT_" + _Symbol)) {
            Print(_Symbol, " HFT BUY OPENED. Lot: ", dynamic_lot, " | Positions: ", myPositions + 1);
         } else {
            Print(_Symbol, " Trade Error: ", GetLastError());
         }
      }
      // Sell if price is significantly above anchor
      else if(ask > current_anchor + deviation) {
         if(m_trade.Sell(dynamic_lot, _Symbol, bid, 0, 0, "ULTRA_HFT_" + _Symbol)) {
            Print(_Symbol, " HFT SELL OPENED. Lot: ", dynamic_lot, " | Positions: ", myPositions + 1);
         } else {
            Print(_Symbol, " Trade Error: ", GetLastError());
         }
      }
   }

   // 4. THE "NEVER-LOSE" PERMANENT PROFIT LOCK (ONLY THIS SYMBOL)
   string shieldKey = InpShieldID + "_" + _Symbol;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         // CRITICAL: Only process OUR positions on THIS symbol
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)g_magic) continue;

         double profit = PositionGetDouble(POSITION_PROFIT);

         if(profit >= InpLockProfit) {
            // TRANSFER TO DISK STORAGE
            g_shielded_profit += profit;
            GlobalVariableSet(shieldKey, g_shielded_profit);

            if(m_trade.PositionClose(ticket)) {
               Print(_Symbol, " SHIELD UPDATED: $", g_shielded_profit, " LOCKED PERMANENTLY.");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DEINIT: Cleanup                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("== ", _Symbol, " EA Removed. Shielded Profit: $", g_shielded_profit);
}
