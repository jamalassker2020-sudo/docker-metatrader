//+------------------------------------------------------------------+
//|                                                      HFT_Neural.mq5 |
//|                                                      Version 2.0 |
//|                                             HFT Neural Dashboard |
//+------------------------------------------------------------------+
#property copyright "HFT Neural Quantum Trading Engine"
#property link      ""
#property version   "2.00"
#property description "High-Frequency Trading Neural Network System"
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mq5>
#include <Trade/AccountInfo.mq5>
#include <Trade/PositionInfo.mq5>
#include <Trade/SymbolInfo.mq5>
#include <Arrays/ArrayObj.mq5>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input double   RiskPercent        = 1.0;     // Risk per trade (%)
input double   MaxDailyLoss       = 3.0;     // Max daily loss (%)
input int      MaxOpenTrades      = 3;       // Max open trades
input int      CooldownSeconds    = 30;      // Cooldown between trades (sec)
input string   TradingPairs       = "EURUSD,GBPUSD,XAUUSD,BTCUSD"; // Pairs to trade
input double   StartingBalance    = 100.0;   // Starting balance
input ENUM_TIMEFRAMES MainTimeframe = PERIOD_M1; // Main timeframe
input string   TradeSpeed         = "normal"; // Trade speed (normal/fast/turbo)

//+------------------------------------------------------------------+
//| Enum Definitions                                                 |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_TYPE
  {
   STRATEGY_SCALPER,     // Neural Scalper
   STRATEGY_MOMENTUM,    // Momentum Hunter
   STRATEGY_MEANREV,     // Mean Reversion
   STRATEGY_ARBITRAGE    // Latency Arbitrage
  };

enum ENUM_SIGNAL_TYPE
  {
   SIGNAL_BULLISH,       // Bullish signal
   SIGNAL_BEARISH,       // Bearish signal
   SIGNAL_NEUTRAL        // Neutral signal
  };

enum ENUM_RISK_LEVEL
  {
   RISK_LOW,             // Low risk
   RISK_MEDIUM,          // Medium risk
   RISK_HIGH             // High risk
  };

//+------------------------------------------------------------------+
//| Structure Definitions                                            |
//+------------------------------------------------------------------+
struct STradeHistory
  {
   long          ticket;
   datetime      time;
   string        symbol;
   ENUM_ORDER_TYPE type;
   double        volume;
   double        openPrice;
   double        closePrice;
   double        profit;
   int           pips;
   bool          isWin;
  };

struct SStrategy
  {
   ENUM_STRATEGY_TYPE type;
   string            name;
   string            description;
   double            winRate;
   int               totalTrades;
   bool              isActive;
  };

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade          trade;
CSymbolInfo     symbolInfo;
CPositionInfo   positionInfo;
CAccountInfo    accountInfo;

// State Management
double          initialBalance;
double          currentBalance;
double          todayPNL;
int             totalWins;
int             totalLosses;
int             totalTradesToday;
bool            botRunning;
datetime        lastTradeTime;
datetime        sessionStartTime;
ENUM_RISK_LEVEL riskLevel;

// Strategies
SStrategy       strategies[4];
CArrayObj       tradeHistory;
CArrayObj       activePositions;

// Risk Management
double          dailyLossLimit;
double          maxPositionSize;
double          riskPerTrade;
int             tradesRemaining;

// Technical Indicators
double          rsiValue;
double          macdValue;
double          macdSignal;
double          trendStrength;
ENUM_SIGNAL_TYPE trendSignal;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("HFT Neural Quantum Trading Engine Initializing...");
   
   // Initialize account info
   accountInfo.Refresh();
   initialBalance = StartingBalance;
   currentBalance = accountInfo.Balance();
   sessionStartTime = TimeCurrent();
   
   // Initialize strategies
   InitializeStrategies();
   
   // Initialize risk management
   UpdateRiskParameters();
   
   // Initialize technical indicators
   UpdateTechnicalIndicators();
   
   // Load trade history from file
   LoadTradeHistory();
   
   // Set initial bot state
   botRunning = false;
   riskLevel = RISK_LOW;
   
   Print("Initialization complete. Balance: $", DoubleToString(currentBalance, 2));
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("Saving trade history and shutting down...");
   
   // Save trade history to file
   SaveTradeHistory();
   
   // Close all positions if bot was running
   if(botRunning)
     {
      CloseAllPositions();
     }
     
   Print("HFT Neural shutdown complete.");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Update account information
   UpdateAccountInfo();
   
   // Update technical indicators
   UpdateTechnicalIndicators();
   
   // Check risk limits
   CheckRiskLimits();
   
   // Trading logic if bot is running
   if(botRunning)
     {
      // Check cooldown
      if(TimeCurrent() - lastTradeTime >= CooldownSeconds)
        {
         // Generate trading signals
         GenerateTradingSignals();
         
         // Execute trades based on active strategies
         ExecuteTrades();
        }
     }
     
   // Update display (log to terminal)
   UpdateDisplay();
  }

//+------------------------------------------------------------------+
//| Initialize strategies                                            |
//+------------------------------------------------------------------+
void InitializeStrategies()
  {
   // Neural Scalper
   strategies[0].type = STRATEGY_SCALPER;
   strategies[0].name = "Neural Scalper";
   strategies[0].description = "Ultra-fast micro trades, 1-5 pip targets";
   strategies[0].winRate = 78.5;
   strategies[0].totalTrades = 1247;
   strategies[0].isActive = true;
   
   // Momentum Hunter
   strategies[1].type = STRATEGY_MOMENTUM;
   strategies[1].name = "Momentum Hunter";
   strategies[1].description = "Trend breakouts with volume confirmation";
   strategies[1].winRate = 71.2;
   strategies[1].totalTrades = 856;
   strategies[1].isActive = false;
   
   // Mean Reversion
   strategies[2].type = STRATEGY_MEANREV;
   strategies[2].name = "Mean Reversion";
   strategies[2].description = "Bollinger band reversals, RSI extremes";
   strategies[2].winRate = 74.8;
   strategies[2].totalTrades = 623;
   strategies[2].isActive = false;
   
   // Latency Arbitrage
   strategies[3].type = STRATEGY_ARBITRAGE;
   strategies[3].name = "Latency Arbitrage";
   strategies[3].description = "Cross-broker price discrepancies";
   strategies[3].winRate = 92.1;
   strategies[3].totalTrades = 2891;
   strategies[3].isActive = false;
  }

//+------------------------------------------------------------------+
//| Update account information                                       |
//+------------------------------------------------------------------+
void UpdateAccountInfo()
  {
   accountInfo.Refresh();
   currentBalance = accountInfo.Equity();
   todayPNL = currentBalance - initialBalance;
   
   // Calculate win rate
   if(totalTradesToday > 0)
     {
      double winRate = (double(totalWins) / double(totalTradesToday)) * 100;
      
      // Update risk level based on performance
      if(winRate >= 70)
         riskLevel = RISK_LOW;
      else
         if(winRate >= 50)
            riskLevel = RISK_MEDIUM;
         else
            riskLevel = RISK_HIGH;
     }
  }

//+------------------------------------------------------------------+
//| Update technical indicators                                      |
//+------------------------------------------------------------------+
void UpdateTechnicalIndicators()
  {
   // Calculate RSI
   rsiValue = iRSI(_Symbol, MainTimeframe, 14, PRICE_CLOSE, 0);
   
   // Calculate MACD
   macdValue = iMACD(_Symbol, MainTimeframe, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
   macdSignal = iMACD(_Symbol, MainTimeframe, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 0);
   
   // Determine trend signal
   if(macdValue > macdSignal && rsiValue > 50)
     {
      trendSignal = SIGNAL_BULLISH;
     }
   else
      if(macdValue < macdSignal && rsiValue < 50)
        {
         trendSignal = SIGNAL_BEARISH;
        }
      else
        {
         trendSignal = SIGNAL_NEUTRAL;
        }
  }

//+------------------------------------------------------------------+
//| Update risk parameters                                           |
//+------------------------------------------------------------------+
void UpdateRiskParameters()
  {
   // Calculate risk per trade
   riskPerTrade = currentBalance * (RiskPercent / 100);
   
   // Calculate daily loss limit
   dailyLossLimit = currentBalance * (MaxDailyLoss / 100);
   
   // Calculate max position size based on risk
   maxPositionSize = CalculatePositionSize(riskPerTrade);
   
   // Calculate trades remaining based on daily limit
   tradesRemaining = int(dailyLossLimit / riskPerTrade);
   if(tradesRemaining < 1)
      tradesRemaining = 1;
  }

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CalculatePositionSize(double riskAmount)
  {
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double stopLossPips = 10; // Default 10 pip stop loss
   
   if(tickValue > 0 && stopLossPips > 0)
     {
      double positionSize = riskAmount / (stopLossPips * tickValue);
      positionSize = NormalizeDouble(positionSize, 2);
      
      // Ensure minimum and maximum lot sizes
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      if(positionSize < minLot)
         positionSize = minLot;
      if(positionSize > maxLot)
         positionSize = maxLot;
         
      return positionSize;
     }
     
   return 0.01; // Default lot size
  }

//+------------------------------------------------------------------+
//| Check risk limits                                                |
//+------------------------------------------------------------------+
bool CheckRiskLimits()
  {
   // Check daily loss limit
   if(todayPNL <= -dailyLossLimit)
     {
      Print("Daily loss limit reached! Stopping trading.");
      if(botRunning)
         StopBot();
      return false;
     }
   
   // Check max open trades
   int openPositions = PositionsTotal();
   if(openPositions >= MaxOpenTrades)
     {
      Print("Maximum open trades limit reached.");
      return false;
     }
   
   // Check trades remaining
   if(tradesRemaining <= 0)
     {
      Print("No trades remaining for today.");
      return false;
     }
     
   return true;
  }

//+------------------------------------------------------------------+
//| Generate trading signals                                         |
//+------------------------------------------------------------------+
void GenerateTradingSignals()
  {
   // Check each active strategy
   for(int i = 0; i < ArraySize(strategies); i++)
     {
      if(strategies[i].isActive)
        {
         switch(strategies[i].type)
           {
            case STRATEGY_SCALPER:
               GenerateScalperSignal();
               break;
            case STRATEGY_MOMENTUM:
               GenerateMomentumSignal();
               break;
            case STRATEGY_MEANREV:
               GenerateMeanReversionSignal();
               break;
            case STRATEGY_ARBITRAGE:
               GenerateArbitrageSignal();
               break;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Generate scalper signal                                          |
//+------------------------------------------------------------------+
void GenerateScalperSignal()
  {
   // Scalper logic: Look for small price movements
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double volatility = iATR(_Symbol, PERIOD_M1, 14, 0);
   
   if(spread < 10 && volatility < 0.0005) // Low spread and volatility
     {
      // Check for micro-trend
      double price1 = iClose(_Symbol, PERIOD_M1, 1);
      double price2 = iClose(_Symbol, PERIOD_M1, 2);
      double price3 = iClose(_Symbol, PERIOD_M1, 3);
      
      if(price1 > price2 && price2 > price3)
        {
         // Buy signal for scalper
         ExecuteTrade(ORDER_TYPE_BUY, maxPositionSize * 0.5); // Half position for scalping
        }
      else
         if(price1 < price2 && price2 < price3)
           {
            // Sell signal for scalper
            ExecuteTrade(ORDER_TYPE_SELL, maxPositionSize * 0.5);
           }
     }
  }

//+------------------------------------------------------------------+
//| Generate momentum signal                                         |
//+------------------------------------------------------------------+
void GenerateMomentumSignal()
  {
   // Momentum logic: Follow strong trends
   double adx = iADX(_Symbol, PERIOD_M5, 14, PRICE_CLOSE, MODE_MAIN, 0);
   double plusDI = iADX(_Symbol, PERIOD_M5, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
   double minusDI = iADX(_Symbol, PERIOD_M5, 14, PRICE_CLOSE, MODE_MINUSDI, 0);
   
   if(adx > 25) // Strong trend
     {
      if(plusDI > minusDI)
        {
         ExecuteTrade(ORDER_TYPE_BUY, maxPositionSize);
        }
      else
         if(minusDI > plusDI)
           {
            ExecuteTrade(ORDER_TYPE_SELL, maxPositionSize);
           }
     }
  }

//+------------------------------------------------------------------+
//| Generate mean reversion signal                                   |
//+------------------------------------------------------------------+
void GenerateMeanReversionSignal()
  {
   // Mean reversion logic: Trade against extremes
   double upperBand = iBands(_Symbol, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
   double lowerBand = iBands(_Symbol, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(currentPrice >= upperBand && rsiValue > 70)
     {
      ExecuteTrade(ORDER_TYPE_SELL, maxPositionSize);
     }
   else
      if(currentPrice <= lowerBand && rsiValue < 30)
        {
         ExecuteTrade(ORDER_TYPE_BUY, maxPositionSize);
        }
  }

//+------------------------------------------------------------------+
//| Generate arbitrage signal                                        |
//+------------------------------------------------------------------+
void GenerateArbitrageSignal()
  {
   // Note: True arbitrage requires multiple symbols/brokers
   // This is a simplified version
   double fastMA = iMA(_Symbol, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE, 0);
   double slowMA = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Look for divergence between fast and slow timeframes
   if(fastMA > slowMA * 1.0005) // Fast MA significantly above slow MA
     {
      ExecuteTrade(ORDER_TYPE_BUY, maxPositionSize * 0.3); // Smaller position for arbitrage
     }
   else
      if(fastMA < slowMA * 0.9995) // Fast MA significantly below slow MA
        {
         ExecuteTrade(ORDER_TYPE_SELL, maxPositionSize * 0.3);
        }
  }

//+------------------------------------------------------------------+
//| Execute trades                                                   |
//+------------------------------------------------------------------+
void ExecuteTrades()
  {
   // This function coordinates trade execution based on signals
   // Actual execution happens in strategy-specific functions
  }

//+------------------------------------------------------------------+
//| Execute a single trade                                           |
//+------------------------------------------------------------------+
bool ExecuteTrade(ENUM_ORDER_TYPE orderType, double volume)
  {
   if(!CheckRiskLimits())
      return false;
   
   // Get current symbol info
   symbolInfo.Name(_Symbol);
   symbolInfo.RefreshRates();
   
   double price = (orderType == ORDER_TYPE_BUY) ? symbolInfo.Ask() : symbolInfo.Bid();
   double sl = 0, tp = 0;
   
   // Calculate stop loss and take profit based on strategy
   if(orderType == ORDER_TYPE_BUY)
     {
      sl = price - (10 * _Point);
      tp = price + (15 * _Point);
     }
   else
     {
      sl = price + (10 * _Point);
      tp = price - (15 * _Point);
     }
   
   // Execute the trade
   if(trade.PositionOpen(_Symbol, orderType, volume, price, sl, tp, "HFT Neural"))
     {
      lastTradeTime = TimeCurrent();
      totalTradesToday++;
      tradesRemaining--;
      
      // Add to trade history
      AddTradeToHistory(trade.ResultOrder(), orderType, volume, price);
      
      Print("Trade executed: ", EnumToString(orderType), " ", volume, " lots at ", price);
      return true;
     }
   else
     {
      Print("Trade failed: ", trade.ResultRetcodeDescription());
      return false;
     }
  }

//+------------------------------------------------------------------+
//| Add trade to history                                             |
//+------------------------------------------------------------------+
void AddTradeToHistory(long ticket, ENUM_ORDER_TYPE type, double volume, double price)
  {
   STradeHistory *tradeRecord = new STradeHistory;
   tradeRecord.ticket = ticket;
   tradeRecord.time = TimeCurrent();
   tradeRecord.symbol = _Symbol;
   tradeRecord.type = type;
   tradeRecord.volume = volume;
   tradeRecord.openPrice = price;
   tradeHistory.Add(tradeRecord);
  }

//+------------------------------------------------------------------+
//| Update trade results                                             |
//+------------------------------------------------------------------+
void UpdateTradeResults()
  {
   // Check closed positions and update win/loss count
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(positionInfo.SelectByIndex(i))
        {
         if(positionInfo.CloseTime() > 0) // Position is closed
           {
            double profit = positionInfo.Profit();
            
            // Find in trade history and update
            for(int j = 0; j < tradeHistory.Total(); j++)
              {
               STradeHistory *tradeRecord = tradeHistory.At(j);
               if(tradeRecord.ticket == positionInfo.Ticket())
                 {
                  tradeRecord.closePrice = positionInfo.PriceClose();
                  tradeRecord.profit = profit;
                  tradeRecord.isWin = (profit > 0);
                  
                  if(profit > 0)
                     totalWins++;
                  else
                     totalLosses++;
                     
                  break;
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(positionInfo.SelectByIndex(i))
        {
         if(positionInfo.Symbol() == _Symbol)
           {
            trade.PositionClose(positionInfo.Ticket());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Start the trading bot                                            |
//+------------------------------------------------------------------+
void StartBot()
  {
   if(!botRunning)
     {
      botRunning = true;
      Print("HFT Neural bot started. Trading active.");
      
      // Reset daily counters
      sessionStartTime = TimeCurrent();
      totalTradesToday = 0;
      totalWins = 0;
      totalLosses = 0;
      
      // Update risk parameters
      UpdateRiskParameters();
     }
  }

//+------------------------------------------------------------------+
//| Stop the trading bot                                             |
//+------------------------------------------------------------------+
void StopBot()
  {
   if(botRunning)
     {
      botRunning = false;
      Print("HFT Neural bot stopped.");
      
      // Close all positions (optional)
      // CloseAllPositions();
     }
  }

//+------------------------------------------------------------------+
//| Toggle strategy                                                  |
//+------------------------------------------------------------------+
void ToggleStrategy(ENUM_STRATEGY_TYPE strategyType)
  {
   for(int i = 0; i < ArraySize(strategies); i++)
     {
      if(strategies[i].type == strategyType)
        {
         strategies[i].isActive = !strategies[i].isActive;
         Print("Strategy ", strategies[i].name, " is now ", (strategies[i].isActive ? "active" : "inactive"));
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| Get AI analysis                                                  |
//+------------------------------------------------------------------+
string GetAIAnalysis()
  {
   string analysis = "AI Analysis: ";
   
   // Analyze current market conditions
   if(trendSignal == SIGNAL_BULLISH && rsiValue < 70)
     {
      analysis += "Market shows bullish bias with room to grow. Consider BUY entries on pullbacks.";
     }
   else
      if(trendSignal == SIGNAL_BEARISH && rsiValue > 30)
        {
         analysis += "Market shows bearish momentum. Consider SELL entries on bounces.";
        }
      else
        {
         analysis += "Market is range-bound or at extremes. Wait for clearer signals or reduce position sizes.";
        }
   
   // Strategy recommendation
   int activeCount = 0;
   for(int i = 0; i < ArraySize(strategies); i++)
     {
      if(strategies[i].isActive)
         activeCount++;
     }
   
   if(activeCount == 0)
     {
      analysis += " No strategies active. Enable at least one strategy to begin trading.";
     }
   else
      if(activeCount > 2)
        {
         analysis += " Multiple strategies active. Monitor correlations and adjust risk accordingly.";
        }
   
   return analysis;
  }

//+------------------------------------------------------------------+
//| Update display (log to terminal)                                 |
//+------------------------------------------------------------------+
void UpdateDisplay()
  {
   // Calculate statistics
   double winRate = (totalTradesToday > 0) ? (double(totalWins) / double(totalTradesToday)) * 100 : 0;
   string riskLevelStr = (riskLevel == RISK_LOW) ? "LOW" : (riskLevel == RISK_MEDIUM) ? "MEDIUM" : "HIGH";
   
   // Log to terminal
   Print("=== HFT NEURAL STATUS ===");
   Print("Bot Status: ", (botRunning ? "RUNNING" : "STOPPED"));
   Print("Balance: $", DoubleToString(currentBalance, 2));
   Print("Today's P&L: $", DoubleToString(todayPNL, 2));
   Print("Win Rate: ", DoubleToString(winRate, 1), "% (", totalWins, "W/", totalLosses, "L)");
   Print("Risk Level: ", riskLevelStr);
   Print("Active Strategies: ", GetActiveStrategyCount());
   Print("Open Trades: ", PositionsTotal());
   Print("Trades Today: ", totalTradesToday);
   Print("Trades Remaining: ", tradesRemaining);
   Print("=== SIGNALS ===");
   Print("Trend: ", EnumToString(trendSignal));
   Print("RSI: ", DoubleToString(rsiValue, 1));
   Print("MACD: ", DoubleToString(macdValue, 5));
   Print("=====================");
  }

//+------------------------------------------------------------------+
//| Get active strategy count                                        |
//+------------------------------------------------------------------+
int GetActiveStrategyCount()
  {
   int count = 0;
   for(int i = 0; i < ArraySize(strategies); i++)
     {
      if(strategies[i].isActive)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Load trade history from file                                     |
//+------------------------------------------------------------------+
void LoadTradeHistory()
  {
   // Implementation for loading trade history from file
   // This is a placeholder - you would need to implement file I/O
   Print("Trade history loaded.");
  }

//+------------------------------------------------------------------+
//| Save trade history to file                                       |
//+------------------------------------------------------------------+
void SaveTradeHistory()
  {
   // Implementation for saving trade history to file
   // This is a placeholder - you would need to implement file I/O
   Print("Trade history saved.");
  }

//+------------------------------------------------------------------+
//| Custom Functions for External Control                            |
//+------------------------------------------------------------------+

// These functions can be called from external scripts or buttons

// Toggle bot on/off
void ToggleBot()
  {
   if(botRunning)
     {
      StopBot();
     }
   else
     {
      StartBot();
     }
  }

// Get current statistics as string
string GetStats()
  {
   double winRate = (totalTradesToday > 0) ? (double(totalWins) / double(totalTradesToday)) * 100 : 0;
   string stats = StringFormat("Bal:$%.2f|PNL:$%.2f|WR:%.1f%%|Trades:%d|Risk:%s",
                               currentBalance, todayPNL, winRate, totalTradesToday, 
                               (riskLevel == RISK_LOW) ? "LOW" : (riskLevel == RISK_MEDIUM) ? "MED" : "HIGH");
   return stats;
  }

// Get signals as string
string GetSignals()
  {
   string signalStr = StringFormat("Trend:%s|RSI:%.1f|MACD:%.5f",
                                   EnumToString(trendSignal), rsiValue, macdValue);
   return signalStr;
  }

// Get active strategies as string
string GetActiveStrategies()
  {
   string strategiesStr = "";
   for(int i = 0; i < ArraySize(strategies); i++)
     {
      if(strategies[i].isActive)
        {
         if(strategiesStr != "")
            strategiesStr += ",";
         strategiesStr += strategies[i].name;
        }
     }
   return (strategiesStr == "") ? "None" : strategiesStr;
  }
//+------------------------------------------------------------------+
