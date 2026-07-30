//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Copyright 2026, Antigravity     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#include <Trade\Trade.mqh>

class CRiskManager
{
private:
   double m_risk_percent;
   double m_max_daily_drawdown;
   int    m_max_positions;
   
   double m_start_day_balance;
   
public:
   CRiskManager(double risk_pct, double max_dd, int max_pos)
   {
      m_risk_percent = risk_pct;
      m_max_daily_drawdown = max_dd;
      m_max_positions = max_pos;
      m_start_day_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   void OnNewDay()
   {
      m_start_day_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   bool IsDrawdownOK()
   {
      double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(m_start_day_balance > 0)
      {
         double dd_pct = (m_start_day_balance - current_equity) / m_start_day_balance * 100.0;
         if(dd_pct >= m_max_daily_drawdown)
            return false;
      }
      return true;
   }
   
   bool CanOpenPosition()
   {
      int total_positions = PositionsTotal();
      if(total_positions >= m_max_positions)
         return false;
         
      return IsDrawdownOK();
   }

   double CalculateLotSize(string symbol, double stop_loss_points)
   {
      if(stop_loss_points <= 0) return 0.01;
      
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = balance * (m_risk_percent / 100.0);
      
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(tick_size == 0 || tick_value == 0) return 0.01;
      
      double point_value = tick_value / (tick_size / SymbolInfoDouble(symbol, SYMBOL_POINT));
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      double calc_lot = risk_amount / (stop_loss_points * point_value);
      
      // Normalize to step
      calc_lot = MathFloor(calc_lot / lot_step) * lot_step;
      
      if(calc_lot < min_lot) calc_lot = min_lot;
      if(calc_lot > max_lot) calc_lot = max_lot;
      
      return calc_lot;
   }
};
