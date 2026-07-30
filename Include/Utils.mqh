//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|                                  Copyright 2026, Antigravity     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"

class CUtils
{
private:
   static datetime m_last_bar_time;

public:
   static bool IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      datetime current_time = iTime(symbol, timeframe, 0);
      if(m_last_bar_time != current_time)
      {
         m_last_bar_time = current_time;
         return true;
      }
      return false;
   }

   static bool IsSpreadOK(string symbol, double max_spread_pts)
   {
      double current_spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      return (current_spread <= max_spread_pts);
   }
   
   static double GetATR(int handle, int index)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(handle, 0, index, 1, atr) > 0)
         return atr[0];
      return 0.0;
   }
   
   static double GetEMA(int handle, int index)
   {
      double ema[];
      ArraySetAsSeries(ema, true);
      if(CopyBuffer(handle, 0, index, 1, ema) > 0)
         return ema[0];
      return 0.0;
   }
   
   static double GetMACD(int handle, int buffer_num, int index)
   {
      double macd[];
      ArraySetAsSeries(macd, true);
      if(CopyBuffer(handle, buffer_num, index, 1, macd) > 0)
         return macd[0];
      return 0.0;
   }
};

datetime CUtils::m_last_bar_time = 0;
