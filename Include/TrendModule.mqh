//+------------------------------------------------------------------+
//|                                                  TrendModule.mqh |
//|                                  Copyright 2026, Antigravity     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#include "Utils.mqh"
#include "RiskManager.mqh"

class CTrendModule
{
private:
   int m_ema50_h4_handle;
   int m_ema200_h4_handle;
   int m_macd_h1_handle;
   int m_ema20_m15_handle;
   
   string m_symbol;
   
public:
   CTrendModule() : m_ema50_h4_handle(INVALID_HANDLE), m_ema200_h4_handle(INVALID_HANDLE),
                    m_macd_h1_handle(INVALID_HANDLE), m_ema20_m15_handle(INVALID_HANDLE) {}
                    
   ~CTrendModule()
   {
      if(m_ema50_h4_handle != INVALID_HANDLE) IndicatorRelease(m_ema50_h4_handle);
      if(m_ema200_h4_handle != INVALID_HANDLE) IndicatorRelease(m_ema200_h4_handle);
      if(m_macd_h1_handle != INVALID_HANDLE) IndicatorRelease(m_macd_h1_handle);
      if(m_ema20_m15_handle != INVALID_HANDLE) IndicatorRelease(m_ema20_m15_handle);
   }
   
   bool Init(string symbol)
   {
      m_symbol = symbol;
      m_ema50_h4_handle = iMA(symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_ema200_h4_handle = iMA(symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_macd_h1_handle = iMACD(symbol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE);
      m_ema20_m15_handle = iMA(symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
      
      if(m_ema50_h4_handle == INVALID_HANDLE || m_ema200_h4_handle == INVALID_HANDLE ||
         m_macd_h1_handle == INVALID_HANDLE || m_ema20_m15_handle == INVALID_HANDLE)
         return false;
         
      return true;
   }
   
   int CheckSignal()
   {
      double ema50_h4 = CUtils::GetEMA(m_ema50_h4_handle, 1);
      double ema200_h4 = CUtils::GetEMA(m_ema200_h4_handle, 1);
      
      double macd_main = CUtils::GetMACD(m_macd_h1_handle, 0, 1);
      double macd_signal = CUtils::GetMACD(m_macd_h1_handle, 1, 1);
      
      double ema20_m15 = CUtils::GetEMA(m_ema20_m15_handle, 1);
      
      double close_m15 = iClose(m_symbol, PERIOD_M15, 1);
      double low_m15 = iLow(m_symbol, PERIOD_M15, 1);
      double high_m15 = iHigh(m_symbol, PERIOD_M15, 1);
      
      // BUY Rule: 
      // 1. H4 Trend Up
      // 2. MACD H1 momentum up
      // 3. M15 pullback to EMA20
      if(ema50_h4 > ema200_h4 && close_m15 > ema50_h4)
      {
         if(macd_main > 0 && macd_main > macd_signal)
         {
            if(low_m15 <= ema20_m15 && close_m15 > ema20_m15)
            {
               return 1; // BUY
            }
         }
      }
      
      // SELL Rule:
      if(ema50_h4 < ema200_h4 && close_m15 < ema50_h4)
      {
         if(macd_main < 0 && macd_main < macd_signal)
         {
            if(high_m15 >= ema20_m15 && close_m15 < ema20_m15)
            {
               return -1; // SELL
            }
         }
      }
      
      return 0; // NO SIGNAL
   }
};
