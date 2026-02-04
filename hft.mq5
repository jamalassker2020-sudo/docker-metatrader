//+------------------------------------------------------------------+
//|                                     QuantumShield_HFT_2026.mq5 |
//|                                  Copyright 2026, Quantum Ecosystem |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property version   "3.10"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- INPUTS
input double InpLotSize      = 0.1;       // Trading Volume
input double InpDeviation    = 0.0030;    // Deviation trigger (from JS logic)
input double InpProfitLock   = 1.0;       // Profit to harvest ($)
input string InpShieldID     = "QS_SHIELD_2026";

//--- GLOBALS
CTrade          m_trade;
CPositionInfo   m_pos;
double          g_shield_total = 0;
double          g_anchor_price = 0;

// Pairs from your JS config
string g_pairs[] = {"EURUSD","GBPUSD","USDJPY","AUDUSD","EURGBP","EURJPY","GBPJPY","USDCAD","NZDUSD","EURCHF","GBPCHF","AUDJPY","GBPAUD","EURCAD","EURAUD","CADJPY","CHFJPY","GBPCAD","AUDCAD","NZDJPY","AUDNZD","EURNZD","GBPNZD","USDCHF","USDMXN","USDZAR","USDTRY","EURPLN"};

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit() {
    m_trade.SetExpertMagicNumber(2026310);
    m_trade.SetAsyncMode(true); // ULTRA-HFT SPEED
    
    // Load persistent shield profit (similar to localStorage)
    if(GlobalVariableCheck(InpShieldID)) 
        g_shield_total = GlobalVariableGet(InpShieldID);
        
    // Initial Anchor Setup
    g_anchor_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    Print("QUANTUM_SHIELD_v3.10 ONLINE. HFT MODE ACTIVE.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Main Tick Loop (Simulating the 200ms tick() from JS)             |
//+------------------------------------------------------------------+
void OnTick() {
    // 1. Sync Virtual Anchor (Occasional drift to prevent stagnation)
    if(MathRand()%100 == 0) g_anchor_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // 2. Scan All Pairs (Aggressive HFT Scanning)
    for(int i=0; i<ArraySize(g_pairs); i++) {
        string sym = g_pairs[i];
        double current_price = SymbolInfoDouble(sym, SYMBOL_BID);
        if(current_price <= 0) continue;

        double deviation = current_price - g_anchor_price;

        // No restrictions: If price moves, we enter.
        if(!HasPosition(sym)) {
            if(deviation > InpDeviation) 
                m_trade.Buy(InpLotSize, sym, SymbolInfoDouble(sym, SYMBOL_ASK), 0, 0, "QS_HFT");
            else if(deviation < -InpDeviation) 
                m_trade.Sell(InpLotSize, sym, current_price, 0, 0, "QS_HFT");
        }
    }

    // 3. Profit Lock & Shield Update
    for(int i=PositionsTotal()-1; i>=0; i--) {
        if(m_pos.SelectByIndex(i) && m_pos.Magic() == 2026310) {
            if(m_pos.Profit() >= InpProfitLock) {
                double p = m_pos.Profit();
                if(m_trade.PositionClose(m_pos.Ticket())) {
                    g_shield_total += p;
                    GlobalVariableSet(InpShieldID, g_shield_total);
                    Print("LOCKED PROFIT: +$", p, " | SHIELD TOTAL: $", g_shield_total);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
bool HasPosition(string sym) {
    for(int i=0; i<PositionsTotal(); i++) {
        if(m_pos.SelectByIndex(i) && m_pos.Symbol() == sym && m_pos.Magic() == 2026310) return true;
    }
    return false;
}
