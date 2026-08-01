//+------------------------------------------------------------------+
//|                                               MarketDetector.mqh |
//|                                  Copyright 2026, Antigravity     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#include "Utils.mqh"

enum ENUM_MARKET_MODE
{
   MODE_UNCERTAIN = 0,
   MODE_TREND = 1,
   MODE_SIDEWAYS = 2,
   MODE_BREAKOUT = 3
};

class CMarketDetector
{
private:
   int m_adx_handle;
   int m_ema_handle;
   int m_atr_14_handle;
   int m_atr_50_handle;
   
   string m_symbol;
   ENUM_TIMEFRAMES m_tf;
   
public:
   CMarketDetector() : m_adx_handle(INVALID_HANDLE), m_ema_handle(INVALID_HANDLE),
                       m_atr_14_handle(INVALID_HANDLE), m_atr_50_handle(INVALID_HANDLE) {}
                       
   ~CMarketDetector()
   {
      if(m_adx_handle != INVALID_HANDLE) IndicatorRelease(m_adx_handle);
      if(m_ema_handle != INVALID_HANDLE) IndicatorRelease(m_ema_handle);
      if(m_atr_14_handle != INVALID_HANDLE) IndicatorRelease(m_atr_14_handle);
      if(m_atr_50_handle != INVALID_HANDLE) IndicatorRelease(m_atr_50_handle);
   }

   bool Init(string symbol, ENUM_TIMEFRAMES tf, int adx_period, int ema_period)
   {
      m_symbol = symbol;
      m_tf = tf;
      
      m_adx_handle = iADX(symbol, tf, adx_period);
      m_ema_handle = iMA(symbol, tf, ema_period, 0, MODE_EMA, PRICE_CLOSE);
      m_atr_14_handle = iATR(symbol, tf, 14);
      m_atr_50_handle = iATR(symbol, tf, 50);
      
      if(m_adx_handle == INVALID_HANDLE || m_ema_handle == INVALID_HANDLE ||
         m_atr_14_handle == INVALID_HANDLE || m_atr_50_handle == INVALID_HANDLE)
         return false;
         
      return true;
   }
   
   ENUM_MARKET_MODE DetectRegime()
   {
      double adx[];
      ArraySetAsSeries(adx, true);
      if(CopyBuffer(m_adx_handle, 0, 0, 1, adx) <= 0) return MODE_UNCERTAIN;
      
      double atr_14 = CUtils::GetATR(m_atr_14_handle, 0);
      double atr_50 = CUtils::GetATR(m_atr_50_handle, 0);
      double atr_ratio = (atr_50 > 0) ? (atr_14 / atr_50) : 1.0;
      
      double ema_0 = CUtils::GetEMA(m_ema_handle, 0);
      double ema_10 = CUtils::GetEMA(m_ema_handle, 10);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double ema_slope = (ema_10 > 0) ? MathAbs(ema_0 - ema_10) / point : 0;
      
      int trend_score = 0;
      int sideways_score = 0;
      int breakout_score = 0;
      
      // ADX Rule
      if(adx[0] > 28) trend_score += 3;
      else if(adx[0] >= 15 && adx[0] < 25) sideways_score += 3;
      else if(adx[0] < 15) breakout_score += 3; // Extreme low ADX = compression
      
      // ATR Ratio Rule
      if(atr_ratio > 1.3) trend_score += 2;
      else if(atr_ratio >= 0.6 && atr_ratio < 1.0) sideways_score += 2;
      else if(atr_ratio < 0.6) breakout_score += 2; // Extreme low volatility
      
      // EMA Slope Rule (Threshold ~20 points over 10 bars)
      if(ema_slope > 20) trend_score += 2;
      else if(ema_slope < 10) { 
         sideways_score += 2; 
         breakout_score += 2; // Flat EMA applies to both
      }
      
      if(trend_score >= 5) return MODE_TREND;
      if(breakout_score >= 5) return MODE_BREAKOUT; // Prioritize breakout prep
      if(sideways_score >= 5) return MODE_SIDEWAYS;
      
      return MODE_UNCERTAIN;
   }
};
