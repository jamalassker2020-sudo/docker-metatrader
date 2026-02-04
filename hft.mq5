//+------------------------------------------------------------------+
//|                                     HFT_ForexStrategy_2026.mq5 |
//|                                Hyper-Active HFT Execution Kernel |
//+------------------------------------------------------------------+
#property copyright "HFT Strategy 2026"
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- HYPER-HFT INPUTS
input double   InpLotSize        = 0.1;      
input int      InpMaxPositions   = 50;       // Increased for HFT
input int      InpTakeProfit     = 5;        // Micro-targets (5 pips)
input int      InpStopLoss       = 100;      // Wider SL to allow breathing
input int      InpTrailingStart  = 2;        // Immediate trail (2 pips)
input int      InpTrailingStep   = 1;        
input int      InpSpreadLimit    = 50;       // Max 5 pips spread
input int      InpSensitivity    = 5;        // Points movement for trigger
input bool     InpUseBalanceShield = true;
input string   InpShieldID       = "QS_ULTRA_PERSIST_2026";

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

double last_prices[];
double lockedProfit = 0;

int OnInit() {
    trade.SetExpertMagicNumber(202601);
    trade.SetAsyncMode(true); // FIRE AND FORGET SPEED
    trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    ArrayResize(last_prices, ArraySize(pairs));
    for(int i=0; i<ArraySize(pairs); i++) {
        SymbolSelect(pairs[i], true);
        last_prices[i] = SymbolInfoDouble(pairs[i], SYMBOL_BID);
    }

    if(GlobalVariableCheck(InpShieldID)) lockedProfit = GlobalVariableGet(InpShieldID);
    
    Print("ULTRA-HFT ACTIVE. ASYNC ENGINE ENABLED.");
    return(INIT_SUCCEEDED);
}

void OnTick() {
    for(int i = 0; i < ArraySize(pairs); i++) {
        ProcessHFT(pairs[i], i);
    }
    
    UpdateTrailingStops();
    CheckAndLockProfit();
}

void ProcessHFT(string symbol, int index) {
    MqlTick tick;
    if(!SymbolInfoTick(symbol, tick)) return;
    
    // Spread Defense
    int current_spread = (int)((tick.ask - tick.bid) / SymbolInfoDouble(symbol, SYMBOL_POINT));
    if(current_spread > InpSpreadLimit) return;

    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double pip = (StringFind(symbol, "JPY") >= 0) ? 0.01 : 0.0001;
    
    // ULTRA-HFT TRIGGER: Price Action Momentum (Last Tick vs Current Tick)
    double move = (tick.bid - last_prices[index]) / point;
    last_prices[index] = tick.bid;

    if(CountOpenPositions() < InpMaxPositions && !HasOpenPosition(symbol)) {
        if(move >= InpSensitivity) { // Upward Spike
            ExecuteHFT(symbol, ORDER_TYPE_BUY, tick.ask, pip);
        }
        else if(move <= -InpSensitivity) { // Downward Spike
            ExecuteHFT(symbol, ORDER_TYPE_SELL, tick.bid, pip);
        }
    }
}

void ExecuteHFT(string symbol, ENUM_ORDER_TYPE type, double price, double pip) {
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double sl = (type == ORDER_TYPE_BUY) ? price - (InpStopLoss * pip) : price + (InpStopLoss * pip);
    double tp = (type == ORDER_TYPE_BUY) ? price + (InpTakeProfit * pip) : price - (InpTakeProfit * pip);

    trade.PositionOpen(symbol, type, InpLotSize, price, NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), "ULTRA_HFT");
}

void UpdateTrailingStops() {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(!posInfo.SelectByIndex(i) || posInfo.Magic() != 202601) continue;
        
        string sym = posInfo.Symbol();
        double pip = (StringFind(sym, "JPY") >= 0) ? 0.01 : 0.0001;
        double currentSL = posInfo.StopLoss();
        int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

        if(posInfo.PositionType() == POSITION_TYPE_BUY) {
            if(posInfo.PriceCurrent() - posInfo.PriceOpen() > InpTrailingStart * pip) {
                double newSL = NormalizeDouble(posInfo.PriceCurrent() - (InpTrailingStep * pip), digits);
                if(newSL > currentSL) trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
            }
        } else {
            if(posInfo.PriceOpen() - posInfo.PriceCurrent() > InpTrailingStart * pip) {
                double newSL = NormalizeDouble(posInfo.PriceCurrent() + (InpTrailingStep * pip), digits);
                if(newSL < currentSL || currentSL == 0) trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
            }
        }
    }
}

void CheckAndLockProfit() {
    double profit = AccountInfoDouble(ACCOUNT_PROFIT);
    if(profit >= 1.0) { // Lock every $1 of floating profit immediately
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            if(posInfo.SelectByIndex(i) && posInfo.Magic() == 202601) {
                if(posInfo.Profit() > 0.10) {
                    lockedProfit += posInfo.Profit();
                    GlobalVariableSet(InpShieldID, lockedProfit);
                    trade.PositionClose(posInfo.Ticket());
                }
            }
        }
    }
}

int CountOpenPositions() {
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(posInfo.SelectByIndex(i) && posInfo.Magic() == 202601) count++;
    }
    return count;
}

bool HasOpenPosition(string symbol) {
    for(int i = 0; i < PositionsTotal(); i++) {
        if(posInfo.SelectByIndex(i) && posInfo.Magic() == 202601 && posInfo.Symbol() == symbol) return true;
    }
    return false;
}
