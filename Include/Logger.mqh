//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                  Copyright 2026, Antigravity     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"

class CLogger
{
public:
   static void Info(string msg) {
      Print("[INFO] ", msg);
   }
   
   static void Error(string msg) {
      Print("[ERROR] ", msg);
   }
   
   static void Warn(string msg) {
      Print("[WARN] ", msg);
   }
};
