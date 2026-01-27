//+------------------------------------------------------------------+
//|                                                HFT_PRO_2026.mq5 |
//|                                  Copyright 2026, Gemini AI Labs |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini AI Labs"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS
input double   InpLot          = 0.01;     // Nano Lot Size
input int      InpTP           = 12;       // Take Profit (Pips)
input int      InpSL           = 6;        // Stop Loss (Pips)
input int      InpTrailStart   = 5;        // Trail after Pips Profit
input int      InpMaxPositions = 8;        // Max Concurrent Positions
input int      InpThreshold    = 55;       // Entry Score Threshold (Base 50)
input int      InpMagic        = 202601;   // Magic Number

//--- GLOBALS
CTrade         trade;
double         ExtPipSize;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Manage Existing Positions (Trailing Logic)
   ManageTrailingStops();

   // 2. Check for New Entries
   if(PositionsTotal() < InpMaxPositions)
   {
      // Iterate through the requested symbols (Majors & Gold as per HTML logic)
      string symbolsToTrade[] = {"EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD","NZDUSD","XAUUSD"};
      
      for(int i=0; i<ArraySize(symbolsToTrade); i++)
      {
         CheckSignalAndTrade(symbolsToTrade[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| Multi-Strategy Scoring Logic                                     |
//+------------------------------------------------------------------+
int GetSignalScore(string symbol, int &strength, string &direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 2, rates) < 2) return 50;

   double close0 = rates[0].close;
   double close1 = rates[1].close;
   double diffPips = (close0 - close1) / SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Handle JPY and Gold pip scaling
   double pipAdjust = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) <= 3) ? 10.0 : 1.0;
   double normalizedChange = diffPips / pipAdjust;

   int score = 50;
   strength = 0;

   // STRATEGY 1 & 2: MOMENTUM & TREND
   if(normalizedChange > 0.5) { score += 12; strength++; }
   else if(normalizedChange < -0.5) { score -= 12; strength++; }
   
   if(normalizedChange > 0.2 && close0 > close1) { score += 8; strength++; }
   else if(normalizedChange < -0.2 && close0 < close1) { score -= 8; strength++; }

   // STRATEGY 3: VOLATILITY BREAKOUT
   if(MathAbs(normalizedChange) > 1.5) {
      score += (normalizedChange > 0) ? 15 : -15;
      strength += 2;
   }

   // STRATEGY 5: CORRELATION (Gold Inverse to USD via EURUSD)
   if(symbol == "XAUUSD") {
      MqlRates eur[];
      if(CopyRates("EURUSD", PERIOD_M1, 0, 1, eur) > 0) {
         double eurChange = (eur[0].close - eur[0].open);
         if(eurChange > 0) score += 8; // Weak USD = Gold Up
         else if(eurChange < 0) score -= 8;
      }
   }

   // FINAL DIRECTION
   direction = "NONE";
   if(score >= InpThreshold + 12 && strength >= 2) direction = "BUY";
   else if(score <= 100 - InpThreshold - 12 && strength >= 2) direction = "SELL";

   return score;
}

//+------------------------------------------------------------------+
//| Execution Engine                                                 |
//+------------------------------------------------------------------+
void CheckSignalAndTrade(string symbol)
{
   // Ensure symbol is in MarketWatch
   SymbolSelect(symbol, true);
   
   // Check if already open
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(PositionGetSymbol(i) == symbol) return;

   int strength = 0;
   string dir = "";
   GetSignalScore(symbol, strength, dir);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Pip calculation for TP/SL
   double pipVal = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) <= 3) ? point * 10 : point;

   if(dir == "BUY")
   {
      double sl = ask - (InpSL * pipVal);
      double tp = ask + (InpTP * pipVal);
      trade.Buy(InpLot, symbol, ask, sl, tp, "HFT PRO SCALP");
   }
   else if(dir == "SELL")
   {
      double sl = bid + (InpSL * pipVal);
      double tp = bid - (InpTP * pipVal);
      trade.Sell(InpLot, symbol, bid, sl, tp, "HFT PRO SCALP");
   }
}

//+------------------------------------------------------------------+
//| Trailing Stop Management                                         |
//+------------------------------------------------------------------+
void ManageTrailingStops()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

         string symbol = PositionGetString(POSITION_SYMBOL);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double pipVal = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) <= 3) ? point * 10 : point;
         
         double priceCurrent = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
                               ? SymbolInfoDouble(symbol, SYMBOL_BID) 
                               : SymbolInfoDouble(symbol, SYMBOL_ASK);
                               
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         
         double profitPips = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                             ? (priceCurrent - openPrice) / pipVal
                             : (openPrice - priceCurrent) / pipVal;

         // Trail logic: After InpTrailStart pips, tighten SL to Current - half of trail dist
         if(profitPips >= InpTrailStart)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               double newSL = priceCurrent - (InpTrailStart * pipVal * 0.5);
               if(newSL > currentSL) trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
            }
            else
            {
               double newSL = priceCurrent + (InpTrailStart * pipVal * 0.5);
               if(newSL < currentSL || currentSL == 0) trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}
