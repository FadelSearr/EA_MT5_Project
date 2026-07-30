//+------------------------------------------------------------------+
//|                                                  PositionMgr.mqh |
//|                                  Copyright 2026, Antigravity     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#include <Trade\Trade.mqh>
#include "Utils.mqh"
#include "Logger.mqh"

class CPositionMgr
{
private:
   CTrade m_trade;
   
public:
   CPositionMgr()
   {
      m_trade.SetExpertMagicNumber(12345);
   }
   
   void SetMagicNumber(ulong magic)
   {
      m_trade.SetExpertMagicNumber(magic);
   }

   void ManagePositions(string symbol, double atr)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         string pos_symbol = PositionGetSymbol(i);
         if(pos_symbol == symbol)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_sl = PositionGetDouble(POSITION_SL);
            double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            long type = PositionGetInteger(POSITION_TYPE);
            
            // Break Even logic: 1x ATR
            double be_distance = atr;
            
            // Trailing Stop logic: 1.5x ATR distance, trigger after 1.5x ATR profit
            double ts_trigger = atr * 1.5;
            double ts_distance = atr * 1.5;
            
            if(type == POSITION_TYPE_BUY)
            {
               // Break-even
               if(current_price - open_price >= be_distance)
               {
                  if(current_sl < open_price)
                  {
                     m_trade.PositionModify(ticket, open_price, PositionGetDouble(POSITION_TP));
                     CLogger::Info("BE applied for BUY position " + IntegerToString(ticket));
                  }
               }
               // Trailing Stop
               if(current_price - open_price >= ts_trigger)
               {
                  double new_sl = current_price - ts_distance;
                  if(new_sl > current_sl && new_sl > open_price)
                  {
                     m_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
                     CLogger::Info("TS applied for BUY position " + IntegerToString(ticket));
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               // Break-even
               if(open_price - current_price >= be_distance)
               {
                  if(current_sl > open_price || current_sl == 0)
                  {
                     m_trade.PositionModify(ticket, open_price, PositionGetDouble(POSITION_TP));
                     CLogger::Info("BE applied for SELL position " + IntegerToString(ticket));
                  }
               }
               // Trailing Stop
               if(open_price - current_price >= ts_trigger)
               {
                  double new_sl = current_price + ts_distance;
                  if((new_sl < current_sl || current_sl == 0) && new_sl < open_price)
                  {
                     m_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
                     CLogger::Info("TS applied for SELL position " + IntegerToString(ticket));
                  }
               }
            }
         }
      }
   }
};
