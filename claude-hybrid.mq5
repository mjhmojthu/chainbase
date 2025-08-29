//+------------------------------------------------------------------+
//|                                                HybridGridBot     |
//|                              Hybrid Smart Grid với Profit Logic |
//|                          Dynamic Spacing + Smart Entry Control  |
//+------------------------------------------------------------------+
#property copyright "Hybrid Smart Grid Bot EA"
#property version   "2.1"
#property strict
#include <Trade/Trade.mqh>

//==== Inputs ====
// Grid settings - Cài đặt lưới hybrid
input int    InpMinGridPips       = 15;       // Spacing tối thiểu (pips) | Minimum grid spacing (pips)
input int    InpMaxGridPips       = 40;       // Spacing tối đa (pips) | Maximum grid spacing (pips)
input double InpATRMultiplier     = 2.0;      // Hệ số ATR cho spacing | ATR multiplier for spacing
input int    InpMaxGridLevels     = 6;        // Số level tối đa | Maximum grid levels
input double InpBaseLot           = 0.05;     // Lot cơ bản | Base lot size
input double InpLotMultiplier     = 1.3;      // Nhân lot theo level | Lot multiplier per level
input double InpTpPerLevel        = 20.0;     // TP cho mỗi level ($) | Take profit per level (USD)

// Hybrid Logic - Logic hybrid thông minh
input bool   InpUseHybridLogic    = true;     // Sử dụng logic hybrid | Use hybrid logic
input double InpMinNegativeRatio  = 0.3;      // Tỷ lệ lệnh âm tối thiểu | Minimum negative ratio to continue
input bool   InpAllowCounterTrend = true;     // Cho phép hedge ngược chiều | Allow counter-trend hedge

// Smart Risk Management
input double InpMaxFloatingLoss   = 150.0;    // Floating loss tối đa ($) | Maximum floating loss (USD)
input double InpReduceLotAt       = 75.0;     // Giảm lot khi loss >= ($) | Reduce lot when loss >= (USD)
input double InpStopTradingAt     = 120.0;    // Dừng trade khi loss >= ($) | Stop trading when loss >= (USD)
input double InpDailyTargetUSD    = 200.0;    // Target hàng ngày ($) | Daily target (USD)
input int    InpPauseAfterLossMin = 30;       // Nghỉ sau loss lớn (phút) | Pause after big loss (minutes)

// Smart Trend Filter
input int    InpMAPeriodFast      = 20;       // MA nhanh | Fast MA period
input int    InpMAPeriodSlow      = 50;       // MA chậm | Slow MA period
input int    InpTrendMinPips      = 15;       // Xu hướng tối thiểu (pips) | Minimum trend strength (pips)

// Execution
input int    InpMaxSpreadPips     = 30;       // Spread tối đa (pips) | Maximum spread (pips)
input long   InpMagic             = 20250827; // Magic number
input string InpSymbol            = "XAUUSD"; // Symbol để trade

// Objects
CTrade trade;
int maFastHandle = INVALID_HANDLE;
int maSlowHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

// Tracking variables
double basePrice = 0;           
int currentTrend = 0;           // 1=UP, -1=DOWN, 0=RANGE
double dynamicGridSpacing = 0;  
int activeGrids = 0;
datetime pauseUntil = 0;
double lastFloatingLoss = 0;
bool lotReduced = false;
bool tradingStopped = false;

// Daily tracking
datetime dailyStartTime = 0;
double dailyStartBalance = 0;
double dailyPnL = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   
   // Initialize indicators
   maFastHandle = iMA(_Symbol, _Period, InpMAPeriodFast, 0, MODE_SMA, PRICE_CLOSE);
   maSlowHandle = iMA(_Symbol, _Period, InpMAPeriodSlow, 0, MODE_SMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, _Period, 14);
   
   if(maFastHandle == INVALID_HANDLE || maSlowHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot create indicators");
      return INIT_FAILED;
   }
   
   ResetDailyTracking();
   
   Print("🔄 === Hybrid Smart Grid Bot Initialized ===");
   Print("📊 Dynamic Grid: ", InpMinGridPips, "-", InpMaxGridPips, " pips");
   Print("🧠 Hybrid Logic: ", InpUseHybridLogic ? "ENABLED" : "DISABLED");
   Print("🎯 Max Floating Loss: $", InpMaxFloatingLoss);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(maFastHandle);
   IndicatorRelease(maSlowHandle);
   IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckDailyReset();
   
   if(TimeCurrent() < pauseUntil) return;
   
   UpdateDynamicParameters();
   
   if(!SmartRiskCheck()) return;
   
   UpdateSmartTrend();
   
   ManagePositions();
   
   HybridGridEntry();
   
   static datetime lastLog = 0;
   if(TimeCurrent() - lastLog >= 1800) // Every 30 minutes
   {
      PrintHybridStatus();
      lastLog = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Update dynamic parameters                                        |
//+------------------------------------------------------------------+
void UpdateDynamicParameters()
{
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) != 1) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   double atrPips = atr[0] / point;
   if(digits == 5 || digits == 3) atrPips /= 10;
   
   double dynamicPips = atrPips * InpATRMultiplier;
   dynamicPips = MathMax(dynamicPips, InpMinGridPips);
   dynamicPips = MathMin(dynamicPips, InpMaxGridPips);
   
   if(digits == 5 || digits == 3)
      dynamicGridSpacing = dynamicPips * point * 10;
   else
      dynamicGridSpacing = dynamicPips * point;
}

//+------------------------------------------------------------------+
//| Update smart trend                                               |
//+------------------------------------------------------------------+
void UpdateSmartTrend()
{
   double maFast[2], maSlow[2];
   
   if(CopyBuffer(maFastHandle, 0, 0, 2, maFast) != 2 ||
      CopyBuffer(maSlowHandle, 0, 0, 2, maSlow) != 2)
      return;
   
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   double trendDistance = MathAbs(currentPrice - maSlow[0]);
   double trendPips = trendDistance / point;
   if(digits == 5 || digits == 3) trendPips /= 10;
   
   if(currentPrice > maFast[0] && maFast[0] > maSlow[0] && 
      maFast[0] > maFast[1] && trendPips >= InpTrendMinPips)
      currentTrend = 1;  // Uptrend
   else if(currentPrice < maFast[0] && maFast[0] < maSlow[0] && 
           maFast[0] < maFast[1] && trendPips >= InpTrendMinPips)
      currentTrend = -1; // Downtrend
   else
      currentTrend = 0;  // Range
}

//+------------------------------------------------------------------+
//| Smart risk management                                            |
//+------------------------------------------------------------------+
bool SmartRiskCheck()
{
   if(GetSpreadInPips() > InpMaxSpreadPips) return false;
   
   double floatingLoss = -GetTotalFloatingPnL();
   lastFloatingLoss = floatingLoss;
   
   if(floatingLoss >= InpMaxFloatingLoss)
   {
      Print("🚨 CRITICAL: Max floating loss reached: $", floatingLoss);
      CloseAllPositions();
      pauseUntil = TimeCurrent() + (InpPauseAfterLossMin * 60);
      return false;
   }
   
   if(floatingLoss >= InpStopTradingAt && !tradingStopped)
   {
      Print("⚠️ WARNING: Stop trading threshold reached: $", floatingLoss);
      tradingStopped = true;
      return false;
   }
   
   if(floatingLoss >= InpReduceLotAt && !lotReduced)
   {
      Print("📉 INFO: Reducing lot sizes. Floating loss: $", floatingLoss);
      lotReduced = true;
   }
   
   if(floatingLoss < InpReduceLotAt * 0.5)
   {
      lotReduced = false;
      tradingStopped = false;
   }
   
   UpdateDailyPnL();
   if(dailyPnL >= InpDailyTargetUSD)
   {
      Print("🎯 Daily target reached: $", dailyPnL);
      CloseAllPositions();
      pauseUntil = TimeCurrent() + 86400;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| HYBRID GRID ENTRY - Core logic                                  |
//+------------------------------------------------------------------+
void HybridGridEntry()
{
   if(tradingStopped) return;
   
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
   
   if(CountMyPositions() == 0)
   {
      basePrice = currentPrice;
      activeGrids = 0;
      Print("🎯 Setting new base price: ", basePrice);
   }
   
   if(!InpUseHybridLogic)
   {
      // Classic grid - always place both directions
      PlaceBuyGrid();
      PlaceSellGrid();
      return;
   }
   
   // === HYBRID LOGIC ===
   
   // Analyze current position status
   double buyStats[], sellStats[];  // Dynamic arrays
   AnalyzePositionStats(buyStats, sellStats);
   
   bool shouldPlaceBuyGrid = ShouldPlaceBuyGrid(buyStats);
   bool shouldPlaceSellGrid = ShouldPlaceSellGrid(sellStats);
   
   Print("🧮 BUY Stats: Total=", buyStats[0], " Pos=", buyStats[1], " Neg=", buyStats[2], 
         " → Place: ", shouldPlaceBuyGrid);
   Print("🧮 SELL Stats: Total=", sellStats[0], " Pos=", sellStats[1], " Neg=", sellStats[2], 
         " → Place: ", shouldPlaceSellGrid);
   
   // Execute hybrid grid placement
   if(shouldPlaceBuyGrid) PlaceBuyGrid();
   if(shouldPlaceSellGrid) PlaceSellGrid();
}

//+------------------------------------------------------------------+
//| Analyze position statistics                                      |
//+------------------------------------------------------------------+
void AnalyzePositionStats(double &buyStats[], double &sellStats[])
{
   // Resize arrays
   ArrayResize(buyStats, 3);
   ArrayResize(sellStats, 3);
   
   // Reset stats
   ArrayInitialize(buyStats, 0);
   ArrayInitialize(sellStats, 0);
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      if(posType == POSITION_TYPE_BUY)
      {
         buyStats[0]++; // Total
         if(profit > 0) buyStats[1]++; // Positive
         else buyStats[2]++; // Negative
      }
      else
      {
         sellStats[0]++; // Total
         if(profit > 0) sellStats[1]++; // Positive
         else sellStats[2]++; // Negative
      }
   }
}

//+------------------------------------------------------------------+
//| Should place BUY grid? - Hybrid logic                           |
//+------------------------------------------------------------------+
bool ShouldPlaceBuyGrid(double &buyStats[])
{
   double totalBuy = buyStats[0];
   double positiveBuy = buyStats[1];
   double negativeBuy = buyStats[2];
   
   // No BUY positions yet - always allow
   if(totalBuy == 0) return true;
   
   // All BUY positions are positive - STOP placing more BUY
   if(positiveBuy == totalBuy && totalBuy > 0)
   {
      Print("🛑 All BUY positions positive - NOT placing more BUY");
      return false;
   }
   
   // Check minimum negative ratio
   double negativeRatio = negativeBuy / totalBuy;
   if(negativeRatio < InpMinNegativeRatio)
   {
      Print("📊 BUY negative ratio too low: ", NormalizeDouble(negativeRatio * 100, 1), 
            "% < ", NormalizeDouble(InpMinNegativeRatio * 100, 1), "%");
      return false;
   }
   
   // Strong downtrend - allow BUY (buy the dip)
   if(currentTrend == -1) return true;
   
   // Range or weak uptrend - allow if have negative positions
   return (negativeBuy > 0);
}

//+------------------------------------------------------------------+
//| Should place SELL grid? - Hybrid logic                          |
//+------------------------------------------------------------------+
bool ShouldPlaceSellGrid(double &sellStats[])
{
   double totalSell = sellStats[0];
   double positiveSell = sellStats[1];
   double negativeSell = sellStats[2];
   
   // No SELL positions yet - always allow
   if(totalSell == 0) return true;
   
   // All SELL positions are positive - STOP placing more SELL
   if(positiveSell == totalSell && totalSell > 0)
   {
      Print("🛑 All SELL positions positive - NOT placing more SELL");
      return false;
   }
   
   // Check minimum negative ratio
   double negativeRatio = negativeSell / totalSell;
   if(negativeRatio < InpMinNegativeRatio)
   {
      Print("📊 SELL negative ratio too low: ", NormalizeDouble(negativeRatio * 100, 1), 
            "% < ", NormalizeDouble(InpMinNegativeRatio * 100, 1), "%");
      return false;
   }
   
   // Strong uptrend - allow SELL (sell the rally)
   if(currentTrend == 1) return true;
   
   // Range or weak downtrend - allow if have negative positions
   return (negativeSell > 0);
}

//+------------------------------------------------------------------+
//| Place BUY grid                                                   |
//+------------------------------------------------------------------+
void PlaceBuyGrid()
{
   for(int level = 1; level <= InpMaxGridLevels; level++)
   {
      double buyPrice = basePrice - (level * dynamicGridSpacing);
      
      if(!HasPositionAtLevel(buyPrice, ORDER_TYPE_BUY) && !HasPendingAtLevel(buyPrice, ORDER_TYPE_BUY_LIMIT))
      {
         double lot = CalculateSmartLotSize(level);
         if(lot <= 0) continue;
         
         double tp = buyPrice + (InpTpPerLevel / GetTickValue());
         
         if(trade.BuyLimit(lot, buyPrice, _Symbol, 0, tp, ORDER_TIME_GTC, 0, "Hybrid_BUY_L" + IntegerToString(level)))
         {
            Print("✅ BUY LIMIT L", level, " at ", buyPrice, " | Lot: ", lot);
            activeGrids++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Place SELL grid                                                  |
//+------------------------------------------------------------------+
void PlaceSellGrid()
{
   for(int level = 1; level <= InpMaxGridLevels; level++)
   {
      double sellPrice = basePrice + (level * dynamicGridSpacing);
      
      if(!HasPositionAtLevel(sellPrice, ORDER_TYPE_SELL) && !HasPendingAtLevel(sellPrice, ORDER_TYPE_SELL_LIMIT))
      {
         double lot = CalculateSmartLotSize(level);
         if(lot <= 0) continue;
         
         double tp = sellPrice - (InpTpPerLevel / GetTickValue());
         
         if(trade.SellLimit(lot, sellPrice, _Symbol, 0, tp, ORDER_TIME_GTC, 0, "Hybrid_SELL_L" + IntegerToString(level)))
         {
            Print("✅ SELL LIMIT L", level, " at ", sellPrice, " | Lot: ", lot);
            activeGrids++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate smart lot size                                         |
//+------------------------------------------------------------------+
double CalculateSmartLotSize(int level)
{
   double baseLot = InpBaseLot * MathPow(InpLotMultiplier, level - 1);
   
   if(lotReduced) baseLot *= 0.5;
   if(level > 4) baseLot *= 0.8;
   
   double maxRisk = AccountInfoDouble(ACCOUNT_BALANCE) * 0.02;
   double maxLot = maxRisk / InpTpPerLevel;
   baseLot = MathMin(baseLot, maxLot);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxSymbolLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   baseLot = MathMax(baseLot, minLot);
   baseLot = MathMin(baseLot, maxSymbolLot);
   baseLot = MathFloor(baseLot / stepLot) * stepLot;
   
   return NormalizeDouble(baseLot, 2);
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
double GetTotalFloatingPnL()
{
   double total = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      total += PositionGetDouble(POSITION_PROFIT);
   }
   return total;
}

void UpdateDailyPnL()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double floatingPnL = GetTotalFloatingPnL();
   dailyPnL = (currentBalance - dailyStartBalance) + floatingPnL;
}

bool HasPositionAtLevel(double price, ENUM_ORDER_TYPE orderType)
{
   double tolerance = dynamicGridSpacing * 0.3;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      if((orderType == ORDER_TYPE_BUY && posType == POSITION_TYPE_BUY) ||
         (orderType == ORDER_TYPE_SELL && posType == POSITION_TYPE_SELL))
      {
         if(MathAbs(openPrice - price) <= tolerance) return true;
      }
   }
   return false;
}

bool HasPendingAtLevel(double price, ENUM_ORDER_TYPE orderType)
{
   double tolerance = dynamicGridSpacing * 0.3;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      
      ENUM_ORDER_TYPE pendingType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      double openPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      
      if(pendingType == orderType && MathAbs(openPrice - price) <= tolerance) return true;
   }
   return false;
}

void ManagePositions() { }

int CountMyPositions()
{
   int count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      count++;
   }
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      count++;
   }
   
   return count;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      trade.PositionClose(ticket);
   }
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      trade.OrderDelete(ticket);
   }
   
   basePrice = 0;
   activeGrids = 0;
   lotReduced = false;
   tradingStopped = false;
}

double GetSpreadInPips()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   return (ask - bid) / point / (digits == 5 || digits == 3 ? 10 : 1);
}

double GetTickValue()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
}

void CheckDailyReset()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime todayStart = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   
   if(dailyStartTime != todayStart) ResetDailyTracking();
}

void ResetDailyTracking()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dailyStartTime = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dailyPnL = 0;
   lotReduced = false;
   tradingStopped = false;
   pauseUntil = 0;
}

void PrintHybridStatus()
{
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
   double floatingPnL = GetTotalFloatingPnL();
   UpdateDailyPnL();
   
   double buyStats[], sellStats[];
   ArrayResize(buyStats, 3);
   ArrayResize(sellStats, 3);
   AnalyzePositionStats(buyStats, sellStats);
   
   int pendings = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      pendings++;
   }
   
   string trendStr = currentTrend == 1 ? "🟢 UPTREND" : currentTrend == -1 ? "🔴 DOWNTREND" : "🟡 RANGE";
   string statusFlags = "";
   if(lotReduced) statusFlags += " [LOT_REDUCED]";
   if(tradingStopped) statusFlags += " [TRADING_STOPPED]";
   if(pauseUntil > TimeCurrent()) statusFlags += " [PAUSED]";
   
   Print("🔄 === Hybrid Grid Bot Status ===");
   Print("💹 Price: ", currentPrice, " | Trend: ", trendStr);
   Print("📊 BUY: ", buyStats[0], " (Pos:", buyStats[1], " Neg:", buyStats[2], ")");
   Print("📊 SELL: ", sellStats[0], " (Pos:", sellStats[1], " Neg:", sellStats[2], ")");
   Print("📝 Pending Orders: ", pendings);
   Print("💰 Floating P&L: $", NormalizeDouble(floatingPnL, 2), " | Daily P&L: $", NormalizeDouble(dailyPnL, 2));
   Print("🎯 Grid Spacing: ", NormalizeDouble(dynamicGridSpacing / SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 
         ((int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5 ? 10 : 1), 1), " pips", statusFlags);
}