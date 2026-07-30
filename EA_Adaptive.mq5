//+------------------------------------------------------------------+
//|                                                  EA_Adaptive.mq5 |
//|                                  Copyright 2026, Antigravity     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "Include/MarketDetector.mqh"
#include "Include/TrendModule.mqh"
#include "Include/RiskManager.mqh"
#include "Include/PositionMgr.mqh"
#include "Include/Logger.mqh"
#include <Trade\Trade.mqh>

input int    InpADXPeriod      = 14;     // ADX Period
input int    InpEMAPeriod      = 200;    // EMA Period
input double InpRiskPercent    = 1.0;    // Risk per Trade (%)
input double InpMaxDrawdown    = 3.0;    // Max Daily Drawdown (%)
input int    InpMaxPositions   = 3;      // Max Open Positions
input ulong  InpMagicNumber    = 12345;  // Magic Number
input double InpATRSLMult      = 0.5;    // Stop Loss (ATR Multiplier)
input double InpATRTPMult      = 1.5;    // Take Profit (ATR Multiplier)

CMarketDetector *g_detector;
CTrendModule    *g_trend_module;
CRiskManager    *g_risk_mgr;
CPositionMgr    *g_pos_mgr;
CTrade           g_trade;

int g_atr_handle;

int OnInit()
{
   g_detector = new CMarketDetector();
   if(!g_detector.Init(Symbol(), PERIOD_H1, InpADXPeriod, InpEMAPeriod))
   {
      CLogger::Error("Failed to init MarketDetector");
      return INIT_FAILED;
   }
   
   g_trend_module = new CTrendModule();
   if(!g_trend_module.Init(Symbol()))
   {
      CLogger::Error("Failed to init TrendModule");
      return INIT_FAILED;
   }
   
   g_risk_mgr = new CRiskManager(InpRiskPercent, InpMaxDrawdown, InpMaxPositions);
   
   g_pos_mgr = new CPositionMgr();
   g_pos_mgr.SetMagicNumber(InpMagicNumber);
   
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   
   g_atr_handle = iATR(Symbol(), PERIOD_H1, 14);
   
   CLogger::Info("EA_Adaptive Initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_detector) delete g_detector;
   if(g_trend_module) delete g_trend_module;
   if(g_risk_mgr) delete g_risk_mgr;
   if(g_pos_mgr) delete g_pos_mgr;
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   
   CLogger::Info("EA_Adaptive Deinitialized");
}

void OnTick()
{
   if(CUtils::IsNewBar(Symbol(), PERIOD_D1))
   {
      g_risk_mgr.OnNewDay();
   }
   
   double atr_val = CUtils::GetATR(g_atr_handle, 0);
   if(atr_val <= 0) return;
   
   // Manage existing positions
   g_pos_mgr.ManagePositions(Symbol(), atr_val);
   
   if(!CUtils::IsNewBar(Symbol(), PERIOD_M15)) return;
   
   if(!g_risk_mgr.CanOpenPosition()) return;
   
   ENUM_MARKET_MODE mode = g_detector.DetectRegime();
   
   if(mode == MODE_TREND)
   {
      int signal = g_trend_module.CheckSignal();
      
      if(signal == 1) // BUY
      {
         double sl_pts = atr_val * InpATRSLMult / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
         double lot = g_risk_mgr.CalculateLotSize(Symbol(), sl_pts);
         
         double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         double sl = ask - (atr_val * InpATRSLMult);
         double tp = ask + (atr_val * InpATRTPMult);
         
         g_trade.Buy(lot, Symbol(), ask, sl, tp);
         CLogger::Info("BUY Executed");
      }
      else if(signal == -1) // SELL
      {
         double sl_pts = atr_val * InpATRSLMult / SymbolInfoDouble(Symbol(), SYMBOL_POINT);
         double lot = g_risk_mgr.CalculateLotSize(Symbol(), sl_pts);
         
         double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         double sl = bid + (atr_val * InpATRSLMult);
         double tp = bid - (atr_val * InpATRTPMult);
         
         g_trade.Sell(lot, Symbol(), bid, sl, tp);
         CLogger::Info("SELL Executed");
      }
   }
}
