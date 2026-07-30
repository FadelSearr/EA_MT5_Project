//+------------------------------------------------------------------+
//|                                               MeanRevModule.mqh  |
//|                                  Copyright 2026, Antigravity     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#include "Utils.mqh"
#include "Logger.mqh"

class CMeanRevModule
{
private:
   int    m_donchian_period;
   int    m_rsi_handle;
   int    m_atr_handle;
   string m_symbol;

public:
   CMeanRevModule() : m_rsi_handle(INVALID_HANDLE), m_atr_handle(INVALID_HANDLE) {}

   ~CMeanRevModule()
   {
      if(m_rsi_handle  != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
      if(m_atr_handle  != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
   }

   bool Init(string symbol, int donchian_period = 20)
   {
      m_symbol          = symbol;
      m_donchian_period = donchian_period;
      m_rsi_handle      = iRSI(symbol, PERIOD_M15, 14, PRICE_CLOSE);
      m_atr_handle      = iATR(symbol, PERIOD_M15, 14);

      if(m_rsi_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE)
         return false;
      return true;
   }

   //--- Hitung batas Donchian Channel secara manual dari High/Low N bar terakhir
   bool GetDonchianLevels(double &upper, double &lower)
   {
      upper = -DBL_MAX;
      lower =  DBL_MAX;
      for(int i = 1; i <= m_donchian_period; i++)
      {
         double h = iHigh(m_symbol,  PERIOD_M15, i);
         double l = iLow(m_symbol,   PERIOD_M15, i);
         if(h > upper) upper = h;
         if(l < lower) lower = l;
      }
      return (upper > lower);
   }

   //--- Cek false-breakout: harga tembus < 0.5x ATR dan close kembali ke dalam range
   bool IsFalseBreakout(double upper, double lower, double atr)
   {
      double close1 = iClose(m_symbol, PERIOD_M15, 1);
      double high1  = iHigh(m_symbol,  PERIOD_M15, 1);
      double low1   = iLow(m_symbol,   PERIOD_M15, 1);
      double buffer = atr * 0.5;

      // False bearish breakout (tembus bawah, close kembali ke dalam)
      if(low1 < lower && low1 >= lower - buffer && close1 > lower)
         return true;
      // False bullish breakout (tembus atas, close kembali ke dalam)
      if(high1 > upper && high1 <= upper + buffer && close1 < upper)
         return true;

      return false;
   }

   //--- Konfirmasi pola candle pembalikan arah sederhana (Engulfing / Hammer / Pin Bar)
   bool IsBullishReversal()
   {
      double open1  = iOpen(m_symbol,  PERIOD_M15, 1);
      double close1 = iClose(m_symbol, PERIOD_M15, 1);
      double high1  = iHigh(m_symbol,  PERIOD_M15, 1);
      double low1   = iLow(m_symbol,   PERIOD_M15, 1);
      double open2  = iOpen(m_symbol,  PERIOD_M15, 2);
      double close2 = iClose(m_symbol, PERIOD_M15, 2);

      double body   = MathAbs(close1 - open1);
      double range  = high1 - low1;

      // Bullish Engulfing
      if(close2 < open2 && close1 > open1 && close1 > open2 && open1 < close2) return true;
      // Hammer / Pin Bar (lower shadow > 2x body)
      if(close1 > open1 && range > 0 && (open1 - low1) > 2.0 * body)          return true;

      return false;
   }

   bool IsBearishReversal()
   {
      double open1  = iOpen(m_symbol,  PERIOD_M15, 1);
      double close1 = iClose(m_symbol, PERIOD_M15, 1);
      double high1  = iHigh(m_symbol,  PERIOD_M15, 1);
      double low1   = iLow(m_symbol,   PERIOD_M15, 1);
      double open2  = iOpen(m_symbol,  PERIOD_M15, 2);
      double close2 = iClose(m_symbol, PERIOD_M15, 2);

      double body   = MathAbs(close1 - open1);
      double range  = high1 - low1;

      // Bearish Engulfing
      if(close2 > open2 && close1 < open1 && close1 < open2 && open1 > close2) return true;
      // Shooting Star / Inverted Hammer (upper shadow > 2x body)
      if(close1 < open1 && range > 0 && (high1 - open1) > 2.0 * body)         return true;

      return false;
   }

   //--- Kembalikan 1 (BUY), -1 (SELL), 0 (tidak ada sinyal)
   //    Juga mengisi sl & tp siap pakai
   int CheckSignal(double atr_h1, double &sl_price, double &tp_price)
   {
      double upper, lower;
      if(!GetDonchianLevels(upper, lower)) return 0;

      double range = upper - lower;
      if(range <= 0) return 0;

      double atr_m15   = CUtils::GetATR(m_atr_handle, 1);
      double mid        = lower + range * 0.5;

      // Ambil nilai RSI bar ke-1
      double rsi[];
      ArraySetAsSeries(rsi, true);
      if(CopyBuffer(m_rsi_handle, 0, 1, 1, rsi) <= 0) return 0;

      double close1    = iClose(m_symbol, PERIOD_M15, 1);

      // Posisi relatif dalam range (0 = bawah, 1 = atas)
      double pos = (close1 - lower) / range;

      bool false_bo = IsFalseBreakout(upper, lower, atr_m15);

      // ------- BUY (dekat support) -------
      if((pos <= 0.2 || false_bo) && rsi[0] < 32 && IsBullishReversal())
      {
         sl_price = lower - atr_m15 * 0.75;   // SL di luar Donchian lower
         tp_price = mid;                        // TP konservatif: tengah range
         CLogger::Info(StringFormat("MeanRev BUY | Pos=%.2f RSI=%.1f", pos, rsi[0]));
         return 1;
      }

      // ------- SELL (dekat resistance) -------
      if((pos >= 0.8 || false_bo) && rsi[0] > 68 && IsBearishReversal())
      {
         sl_price = upper + atr_m15 * 0.75;   // SL di luar Donchian upper
         tp_price = mid;                        // TP konservatif: tengah range
         CLogger::Info(StringFormat("MeanRev SELL | Pos=%.2f RSI=%.1f", pos, rsi[0]));
         return -1;
      }

      return 0;
   }
};
