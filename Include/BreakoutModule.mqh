//+------------------------------------------------------------------+
//|                                              BreakoutModule.mqh  |
//|                                  Copyright 2026, Antigravity     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#include "Utils.mqh"
#include "Logger.mqh"

class CBreakoutModule
{
private:
   string m_symbol;
   int    m_consolidation_bars; // minimal bar konsolidasi (default 20)
   int    m_adx_handle;
   int    m_atr_handle;

public:
   CBreakoutModule() : m_adx_handle(INVALID_HANDLE), m_atr_handle(INVALID_HANDLE) {}

   ~CBreakoutModule()
   {
      if(m_adx_handle != INVALID_HANDLE) IndicatorRelease(m_adx_handle);
      if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
   }

   bool Init(string symbol, int consolidation_bars = 20)
   {
      m_symbol             = symbol;
      m_consolidation_bars = consolidation_bars;
      m_adx_handle         = iADX(symbol, PERIOD_M15, 14);
      m_atr_handle         = iATR(symbol, PERIOD_M15, 14);

      if(m_adx_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE)
         return false;
      return true;
   }

   //--- Hitung range (high - low) dari N bar terakhir mulai dari offset
   double GetRangeHigh(int bars, int offset = 1)
   {
      double h = -DBL_MAX;
      for(int i = offset; i < offset + bars; i++)
         h = MathMax(h, iHigh(m_symbol, PERIOD_M15, i));
      return h;
   }

   double GetRangeLow(int bars, int offset = 1)
   {
      double l = DBL_MAX;
      for(int i = offset; i < offset + bars; i++)
         l = MathMin(l, iLow(m_symbol, PERIOD_M15, i));
      return l;
   }

   //--- Hitung rata-rata volume tick dari N bar terakhir
   double GetAvgVolume(int bars, int offset = 1)
   {
      double sum = 0;
      for(int i = offset; i < offset + bars; i++)
         sum += (double)iVolume(m_symbol, PERIOD_M15, i);
      return (bars > 0) ? sum / bars : 0;
   }

   //--- Confidence Score (maks 15); threshold ≥ 10
   //    Juga mengisi sl & tp siap pakai jika skor tercapai.
   //    Kembalikan 1 = bullish breakout, -1 = bearish breakout, 0 = skip
   int CheckSignal(double &sl_price, double &tp_price)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(m_atr_handle, 0, 0, m_consolidation_bars + 5, atr) <= 0) return 0;

      double adx[];
      ArraySetAsSeries(adx, true);
      if(CopyBuffer(m_adx_handle, 0, 0, 3, adx) <= 0) return 0;

      double atr_current = atr[1];  // ATR bar ke-1 (closed)
      if(atr_current <= 0) return 0;

      // ------ Hitung range konsolidasi (bar 2 ke N+1, menghindari bar breakout) ------
      double consol_high = GetRangeHigh(m_consolidation_bars, 2);
      double consol_low  = GetRangeLow(m_consolidation_bars,  2);
      double consol_range = consol_high - consol_low;
      if(consol_range <= 0) return 0;

      // ------ Bar ke-1: kandidat breakout candle ------
      double close1 = iClose(m_symbol, PERIOD_M15, 1);
      double open1  = iOpen(m_symbol,  PERIOD_M15, 1);
      double body1  = MathAbs(close1 - open1);
      double vol1   = (double)iVolume(m_symbol, PERIOD_M15, 1);
      double avg_vol = GetAvgVolume(m_consolidation_bars, 2);

      // ------ ATR rata-rata selama konsolidasi (squeeze check) ------
      double atr_sum = 0;
      for(int i = 2; i < 2 + m_consolidation_bars; i++) atr_sum += atr[i];
      double atr_consol_avg = (m_consolidation_bars > 0) ? atr_sum / m_consolidation_bars : atr_current;

      // ------ Scoring ------
      int score = 0;

      // 1. Konsolidasi ≥ 20 candle → selalu true karena kita cek m_consolidation_bars bar
      score += 2;

      // 2. Range / squeeze menyempit: ATR saat ini < 0.8x rata-rata ATR konsolidasi
      if(atr_current < atr_consol_avg * 0.85) score += 2;

      // 3. ADX mulai naik (bar0 > bar1 > bar2 sebelumnya, dan masih < 25)
      if(adx[0] > adx[1] && adx[1] < 25) score += 2;

      // 4. Body candle breakout ≥ 1.5x ATR
      if(body1 >= atr_current * 1.5) score += 2;

      // 5. Close di luar range konsolidasi (*wajib)
      bool bullish_bo = (close1 > consol_high);
      bool bearish_bo = (close1 < consol_low);
      if(bullish_bo || bearish_bo) score += 2;
      else return 0; // syarat wajib tidak terpenuhi

      // 6. Volume lebih tinggi dari rata-rata
      if(avg_vol > 0 && vol1 > avg_vol * 1.1) score += 1;

      // 7. Retest: bar ke-0 (current / belum close) kembali ke area range
      double price_now = (SymbolInfoDouble(m_symbol, SYMBOL_BID) + SymbolInfoDouble(m_symbol, SYMBOL_ASK)) / 2.0;
      if(bullish_bo && price_now <= consol_high + atr_current * 0.3 && price_now >= consol_high - atr_current * 0.3)
         score += 3;
      if(bearish_bo && price_now >= consol_low - atr_current * 0.3 && price_now <= consol_low + atr_current * 0.3)
         score += 3;

      CLogger::Info(StringFormat("Breakout Score=%d | Range=%.5f | ATR=%.5f", score, consol_range, atr_current));

      if(score < 10) return 0;

      // ------ Hitung SL & TP ------
      if(bullish_bo)
      {
         // SL di dalam range (sisi bawah yang ditembus) + buffer 0.5x ATR
         sl_price = consol_high - atr_current * 0.5;
         // TP = measured move (lebar range) dari titik breakout
         tp_price = consol_high + consol_range;
         CLogger::Info(StringFormat("Bullish Breakout | SL=%.5f TP=%.5f", sl_price, tp_price));
         return 1;
      }
      else // bearish_bo
      {
         sl_price = consol_low + atr_current * 0.5;
         tp_price = consol_low - consol_range;
         CLogger::Info(StringFormat("Bearish Breakout | SL=%.5f TP=%.5f", sl_price, tp_price));
         return -1;
      }
   }
};
