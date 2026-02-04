//+------------------------------------------------------------------+
//|                                     HFT_2026_QuantumShield_ULTRA |
//|                                  Copyright 2026, Gemini Adaptive |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property version   "15.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- HYPER-HFT INPUTS
input double InpLotSize        = 0.1;      // Standard HFT Lot
input int    InpMaxPos         = 50;       // Max Concurrent Trades
input int    InpSpreadLimit    = 40;       // Points (4.0 pips)
input int    InpGapThreshold   = 5;        // Points movement for instant entry
input double InpLockProfit     = 1.0;      // Hard $1.00 profit capture
input string InpShieldID       = "QS_ULTRA_TOTAL_2026";

//--- SYSTEM STATE
CTrade          m_trade;
CPositionInfo   m_position;
double          g_shield_total = 0;
double          g_last_bid[];

string g_pairs[] = {
    "EURUSD","GBPUSD","USDJPY","AUDUSD","USDCAD","NZDUSD","USDCHF",
    "EURGBP","EURJPY","GBPJPY","EURAUD","EURCAD","EURNZD","EURCHF",
    "GBPAUD","GBPCAD","GBPNZD","GBPCHF","AUDJPY","AUDCAD","AUDNZD",
    "AUDCHF","CADJPY","CADCHF","NZDJPY","NZDCAD","NZDCHF","CHFJPY"
};

//+------------------------------------------------------------------+
//| KERNEL INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit() {
    if(GlobalVariableCheck(InpShieldID)) 
        g_shield_total = GlobalVariableGet(InpShieldID);
    else 
        GlobalVariableSet(InpShieldID, 0.0);

    m_trade.SetExpertMagicNumber(2026888);
    m_trade.SetAsyncMode(true); 
    
    // Auto-detect filling mode
    uint fill = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    m_trade.SetTypeFilling(((fill & SYMBOL_FILLING_FOK) != 0) ? ORDER_FILLING_FOK : ORDER_FILLING_IOC);

    ArrayResize(g_last_bid, ArraySize(g_pairs));
    for(int i=0; i<ArraySize(g_pairs); i++) {
        SymbolSelect(g_pairs[i], true);
        g_last_bid[i] = SymbolInfoDouble(g_pairs[i], SYMBOL_BID);
    }

    Print("KERNEL ONLINE. ASYNC ENGINE ENABLED.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| HFT TICK ENGINE                                                  |
//+------------------------------------------------------------------+
void OnTick() {
    // 1. SCAN AND OPEN AGGRESSIVELY
    for(int i=0; i<ArraySize(g_pairs); i++) {
        string sym = g_pairs[i];
        MqlTick tick;
        if(!SymbolInfoTick(sym, tick)) continue;

        // Spread Filter
        int spread = (int)((tick.ask - tick.bid) / SymbolInfoDouble(sym, SYMBOL_POINT));
        if(spread > InpSpreadLimit) continue;

        // HFT Momentum Calculation
        double move = (tick.bid - g_last_bid[i]) / SymbolInfoDouble(sym, SYMBOL_POINT);
        g_last_bid[i] = tick.bid;

        if(PositionsTotal() < InpMaxPos && !HasPosition(sym)) {
            if(move >= InpGapThreshold)  m_trade.Buy(InpLotSize, sym, tick.ask, 0, 0, "HFT_GO");
            if(move <= -InpGapThreshold) m_trade.Sell(InpLotSize, sym, tick.bid, 0, 0, "HFT_GO");
        }
    }

    // 2. HYPER-SCALP EXIT LOGIC
    for(int j=PositionsTotal()-1; j>=0; j--) {
        if(m_position.SelectByIndex(j)) {
            if(m_position.Magic() != 2026888) continue;

            double profit = m_position.Profit();
            datetime age = TimeCurrent() - m_position.Time();

            // Exit Rules: $1 Profit, or close green trade after 10 seconds
            if(profit >= InpLockProfit) {
                CaptureProfit(m_position.Ticket(), profit);
            }
            else if(age > 10 && profit > 0.20) {
                CaptureProfit(m_position.Ticket(), profit);
            }
            else if(age > 30) { // Safety timeout
                m_trade.PositionClose(m_position.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| UTILITIES                                                        |
//+------------------------------------------------------------------+
void CaptureProfit(ulong ticket, double amount) {
    if(m_trade.PositionClose(ticket)) {
        g_shield_total += amount;
        GlobalVariableSet(InpShieldID, g_shield_total);
        Print("SHIELD UPDATED: +$", amount, " [TOTAL: $", g_shield_total, "]");
    }
}

bool HasPosition(string sym) {
    for(int i=0; i<PositionsTotal(); i++) {
        if(m_position.SelectByIndex(i) && m_position.Symbol() == sym) return true;
    }
    return false;
}

void OnDeinit(const int reason) {
    GlobalVariableSet(InpShieldID, g_shield_total);
}
