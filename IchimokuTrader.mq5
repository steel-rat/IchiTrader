//+------------------------------------------------------------------+
//|                                               IchimokuTrader.mq5 |
//|                                                         SteelRat |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "SteelRat"
#property version     "1.00"
#property description "This Expert Advisor places pending orders"
#property description "during StartHour to EndHour at distance"
#property description "1 point out of the daily range. StopLoss price"
#property description "of each order is placed on the opposite side"
#property description "of the price range. After order execution"
#property description "it places TakeProfit at price, calculated by"
#property description "'indicator_TP', StopLoss is placed to SMA,"
#property description "in case of the profitable zone."

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
//#include <Expert\Expert.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include "TradeExecutor.mqh"
#include "IchimokuContainer.mqh"
#include "StochasticContainer.mqh"
#include "CCIMaContainer.mqh"


CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object

//--- input parameters
input int      StopLoss=100000;      // Stop Loss
input int      TakeProfit=300;   // Take Profit
input int      ADX_Period=8;     // ADX Period
input int      MA_Period=8;      // Moving Average Period
input int      EA_Magic=12345;   // EA Magic Number
input double   Adx_Min=22.0;     // Minimum ADX Value
input double   Lot=1.0;          // Lots to Trade
//--- input parameters
input int    StartHour = 7;
input int    EndHour   = 19;
input int    MAper     = 240;
//input double Lots      = 1;

input int InpTenkan=9;     // Tenkan-sen
input int InpKijun=26;     // Kijun-sen
input int InpSenkou=52;    // Senkou Span B

//int hMA,hCI;
//int hIchimokuCur;

//double plsDI[],minDI[],adxVal[]; // Dynamic arrays to hold the values of +DI, -DI and ADX values for each bars
double tenkan[],kijun[],senkou[]; // Dynamic arrays to hold the values of +DI, -DI and ADX values for each bars
//double maVal[]; // Dynamic array to hold the values of Moving Average for each bars
//double p_close; // Variable to store the close value of a bar
int STP, TKP;   // To be used for Stop Loss & Take Profit values

bool ichimokuBuySignal;
bool ichimokuSellSignal;
//bool stochBuySignal;
//bool stochSellSignal;

//double         Stoch_Main_Buffer[];
//double         Stoch_Sig_Buffer[];
int ticksSinceBuy;
int maxTradesPerSignal = 10;//2
int tradePerSignal = 0;
bool positionOpenedOnSignal = false;
bool positionClosedOnStochSignal = false;

IchimokuContainer *ichimokuContainer_H4;
IchimokuContainer *ichimokuContainer_H1;

//StochasticContainer *stochasticContainer_H4;
StochasticContainer *stochasticContainer_H1;

//------ Trade executor
TradeExecutor *tradeExecutor;

SignalContainer *mainSignalContainer;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {
   string sym = "USDJPY";

   //--- Let us handle currency pairs with 5 or 3 digit prices instead of 4
   STP = StopLoss;
   TKP = TakeProfit;
   if(_Digits==5 || _Digits==3)
     {
      STP = STP*10;
      TKP = TKP*10;
     }
   mainSignalContainer = new SignalContainer();
   ichimokuContainer_H4 = new IchimokuContainer(sym,PERIOD_H4,INDICATOR_DATA, mainSignalContainer);
   ichimokuContainer_H1 = new IchimokuContainer(sym,PERIOD_H1,INDICATOR_DATA, mainSignalContainer);
   //ichimokuContainer_M15 = new IchimokuContainer(sym,PERIOD_M15,INDICATOR_DATA);
   
   //stochasticContainer_H4 = new StochasticContainer(sym,PERIOD_H4,INDICATOR_DATA);
   stochasticContainer_H1 = new StochasticContainer(sym,PERIOD_H1,INDICATOR_DATA, mainSignalContainer);
         
   tradeExecutor = new TradeExecutor(sym);
   
      
   //--- create timer
   EventSetTimer(60);
   
//---
   //return(INIT_SUCCEEDED);
   return;//(0);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   
   //IndicatorRelease(hIchimoku);      
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Do we have enough bars to work with
   if(Bars(_Symbol,_Period)<10) // if total bars is less than 60 bars
     {
      Alert("We have less than 60 bars, EA will now exit!!");
      return;
     }  

// We will use the static Old_Time variable to serve the bar time.
// At each OnTick execution we will check the current bar time with the saved one.
// If the bar time isn't equal to the saved time, it indicates that we have a new tick.

   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar=false;

// copying the last bar time to the element New_Time[0]
   int copied=CopyTime(_Symbol,_Period,0,1,New_Time);
   if(copied>0) // ok, the data has been copied successfully
     {
      if(Old_Time!=New_Time[0]) // if old time isn't equal to new bar time
        {
         IsNewBar=true;   // if it isn't a first call, the new bar has appeared
         if(MQL5InfoInteger(MQL5_DEBUGGING)) Print("We have new bar here ",New_Time[0]," old time was ",Old_Time);
         Old_Time=New_Time[0];            // saving bar time
        }
     }
   else
     {
      Alert("Error in copying historical times data, error =",GetLastError());
      ResetLastError();
      return;
     }

//--- EA should only check for new trade if we have a new bar
   if(IsNewBar==false)
     {
      return;
     }
 
//--- Do we have enough bars to work with
   int Mybars=Bars(_Symbol,_Period);
   if(Mybars<10) // if total bars is less than 60 bars
     {
      Alert("We have less than 60 bars, EA will now exit!!");
      return;
     }

//--- Define some MQL5 Structures we will use for our trade
   MqlTick latest_price;      // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
   MqlRates mrate[];          // To be used to store the prices, volumes and spread of each bar
   ZeroMemory(mrequest);      // Initialization of mrequest structure
/*
     Let's make sure our arrays values for the Rates, ADX Values and MA values 
     is store serially similar to the timeseries array
*/
// the rates arrays
   ArraySetAsSeries(mrate,true);

   
 

//--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol,latest_price))
     {
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return;
     }

//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }

//--- Copy the new values of our indicators to buffers (arrays) using the handle
     
   //if(CopyBuffer(hIchimoku,0,0,3,Tenkan_sen_Buffer)<0 || CopyBuffer(hIchimoku,1,0,3,Kijun_sen_Buffer)<0
   //   || CopyBuffer(hIchimoku,3,0,3,Senkou_Span_B_Buffer)<0)
   //  {
   //   Alert("Error copying Ichimoku indicator Buffers - error:",GetLastError(),"!!");
   //   ResetLastError();
   //   return;
   //  }
       
     ichimokuContainer_H4.copyBuffers();
     ichimokuContainer_H1.copyBuffers();
     //ichimokuContainer_M15.copyBuffers();
     
     //stochasticContainer_H4.copyBuffers();
     stochasticContainer_H1.copyBuffers();
     
     tradeExecutor.copyBuffers();
     
//--- we have no errors, so continue
//--- Do we have positions opened already?
   bool Position_opened=false;
   bool Buy_opened=false;  // variable to hold the result of Buy opened position
   bool Sell_opened=false; // variables to hold the result of Sell opened position
   

   if(PositionSelect(_Symbol)==true) // we have an opened position
     {
      Position_opened = true;
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         Buy_opened=true;  //It is a Buy
        }
      else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
        {
         Sell_opened=true; // It is a Sell
        }
        
      //ulong  position_ticket=PositionGetTicket(i);                                    // ticket of the position
      
     } 

// Copy the bar close price for the previous bar prior to the current bar, that is Bar 1
 //  p_close=mrate[1].close;  // bar 1 close price

/*
    1. Check for a long/Buy Setup : MA-8 increasing upwards, 
    previous price close above it, ADX > 22, +DI > -DI
*/
//--- Declare bool type variables to hold our Buy Conditions
//   bool Buy_Condition_1=(maVal[0]>maVal[1]) && (maVal[1]>maVal[2]); // MA-8 Increasing upwards
 //  bool Buy_Condition_2 = (p_close > maVal[1]);         // previuos price closed above MA-8
 //  bool Buy_Condition_3 = (adxVal[0]>Adx_Min);          // Current ADX value greater than minimum value (22)
 //  bool Buy_Condition_4 = (plsDI[0]>minDI[0]);          // +DI greater than -DI

//      bool Buy_Condition_1=  Tenkan_sen_Buffer[1] > Kijun_sen_Buffer[1];  //tenkan > kijan
//      bool Buy_Condition_2 = Tenkan_sen_Buffer[2] <= Kijun_sen_Buffer[2];
 //     bool Buy_Condition_3 = Senkou_Span_B_Buffer[1] < p_close;
     
 //    bool Buy_Condition_4 = p_close > Kijun_sen_Buffer[1];
 //    bool Buy_Condition_5 = mrate[2].close < Kijun_sen_Buffer[2];
     
     //tradeExecutor.setStochSignalsH4(stochasticContainer_H4);
     
     //stochBuySignal = stochasticContainer_H4.stochasticBuySignal();
     //stochSellSignal = stochasticContainer_H4.stochasticSellSignal();
     //if(stochBuySignal || stochSellSignal) {
     // Alert("STOCH_______: BUY: "+stochBuySignal+" ---- SELL: "+stochSellSignal);
     //}
     ticksSinceBuy++;
     
     tradeExecutor.checkTradeConditions(mrate);
     
////-------managing opened positions
   if(Position_opened) {      
     if(Buy_opened) {
         //Alert("We already have a Buy Position!!!");  
         //close if we are not in Kumo for H1
         //if(ichimokuContainer_H1.priceInKumo()) {
         //if(ichimokuContainer_H4.priceBelowKijun()) {
         if(ticksSinceBuy > 4 && tradeExecutor.positionOpenedCloseTradeSignal(POSITION_TYPE_BUY)) {
         //if(ticksSinceBuy > 4 && stochSellSignal) {
            closeTrade();
            positionClosedOnStochSignal = true;
         }
     }       
     if(Sell_opened) {
         //Alert("We already have a Sell position!!!");  
         //close if we are not in Kumo for H1
         //if(ichimokuContainer_H1.priceInKumo()) {
        // if(ichimokuContainer_H4.priceAboveKijun()) {
        if(ticksSinceBuy > 4 && tradeExecutor.positionOpenedCloseTradeSignal(POSITION_TYPE_SELL)) {
        //if(ticksSinceBuy > 4 && stochBuySignal) {
            closeTrade();
            positionClosedOnStochSignal = true;
        }      
     }          
   }
           
//--- Putting all together 
//check if tradeExecutor want to buy
   if(tradeExecutor.noPositionTradeDecision(POSITION_TYPE_BUY, Sell_opened))
   //if(ichimokuContainer_H4.tenkanKijunBuyCondition() /*&& !ichimokuContainer_H4.priceInKumo()*/)  
  // if(Buy_Condition_1 && Buy_Condition_2)
   //if(Buy_Condition_4 && Buy_Condition_5)
     {
     
     //reset counter on trade signal switch
     if(ichimokuSellSignal == true) {
      Alert("Trade per signal reset!");
      tradePerSignal = 0;
     } 
     
     
     ichimokuSellSignal=false;
     
     //if we have sell position on bull market
     if(Sell_opened) {

            closeTrade();
        
         }
      
    // if(ichimokuContainer_H4.priceAboveKumo() && !ichimokuContainer_H4.priceInKumo())
     if(true)
        {
        ichimokuBuySignal=true;
        
          // any opened Buy position?
         if(Buy_opened)
           {
            //Alert("We already have a Buy Position!!!");            
            return;    // Don't open a new Buy Position
           }
           if(tradePerSignal == maxTradesPerSignal) {
                  return;
               }  
           ///
            
         ZeroMemory(mrequest);
         mrequest.action = TRADE_ACTION_DEAL;                                  // immediate order execution
         mrequest.price = NormalizeDouble(latest_price.ask,_Digits);           // latest ask price
    //     mrequest.sl = NormalizeDouble(latest_price.ask - STP*_Point,_Digits); // Stop Loss
         
         //mrequest.tp = NormalizeDouble(latest_price.ask + TKP*_Point,_Digits); // Take Profit
         mrequest.symbol = _Symbol;                                            // currency pair
         mrequest.volume = Lot;                                                 // number of lots to trade
         mrequest.magic = EA_Magic;                                             // Order Magic Number
         mrequest.type = ORDER_TYPE_BUY;
                                                    // Buy Order
         mrequest.type_filling = ORDER_FILLING_FOK;                             // Order execution type
         mrequest.deviation=100;                                                // Deviation from current price
         //--- send order
         OrderSend(mrequest,mresult);
         // get the result code
         if(mresult.retcode==10009 || mresult.retcode==10008) //Request is completed or order placed
           {
            Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
            ticksSinceBuy = 0;
            tradePerSignal++;
            Alert("1Trade per signal: "+tradePerSignal);
            positionOpenedOnSignal = true;
            tradeExecutor.executeTrade();
           }
         else
           {
            Alert("The Buy order request could not be completed -error:",GetLastError());
            ResetLastError();           
            return;
           }
        } 
        
     }
/*
    2. Check for a Short/Sell Setup : MA-8 decreasing downwards, 
    previous price close below it, ADX > 22, -DI > +DI
*/
//--- Declare bool type variables to hold our Sell Conditions
   //bool Sell_Condition_1 = (maVal[0]<maVal[1]) && (maVal[1]<maVal[2]);  // MA-8 decreasing downwards
   //bool Sell_Condition_2 = (p_close <maVal[1]);                         // Previous price closed below MA-8
   //bool Sell_Condition_3 = (adxVal[0]>Adx_Min);                         // Current ADX value greater than minimum (22)
   //bool Sell_Condition_4 = (plsDI[0]<minDI[0]);                         // -DI greater than +DI

//   bool Sell_Condition_1 = Kijun_sen_Buffer[1] > Tenkan_sen_Buffer[1];
//   bool Sell_Condition_2 = Kijun_sen_Buffer[2] <= Tenkan_sen_Buffer[2];
//   bool Sell_Condition_3 = Senkou_Span_B_Buffer[1] > p_close;
   
//   bool Sell_Condition_4 = p_close < Kijun_sen_Buffer[1];
//   bool Sell_Condition_5 = mrate[2].close > Kijun_sen_Buffer[2];

//--- Putting all together
   if(tradeExecutor.noPositionTradeDecision(POSITION_TYPE_SELL, Buy_opened))
   //if(ichimokuContainer_H4.tenkanKijunSellCondition() /*&& !ichimokuContainer_H4.priceInKumo()*/)
   //if(Sell_Condition_1 && Sell_Condition_2)
   //if(Sell_Condition_4 && Sell_Condition_5)
     {
     
     //reset counter on trade signal switch
     if(ichimokuBuySignal == true) {
      Alert("Trade per signal reset!");
      tradePerSignal = 0;
     }     
     
     ichimokuBuySignal = false;
     

       if(Buy_opened) {
            closeTrade();
         }
     //&& !ichimokuContainer_H4.priceInKumo()
     
     //if(ichimokuContainer_H4.priceBelowKumo() && !ichimokuContainer_H4.priceInKumo())
 //    if(Sell_Condition_3/* && Sell_Condition_4*/)
     // if(Sell_Condition_4)
     if(true)
        {
        ichimokuSellSignal=true;
         // any opened Sell position?
         if(Sell_opened)
           {
            //Alert("We already have a Sell position!!!");
 
            return;    // Don't open a new Sell Position
           }
          if(tradePerSignal == maxTradesPerSignal) {
                  return;
               }   
       
         
           
         ZeroMemory(mrequest);
         mrequest.action=TRADE_ACTION_DEAL;                                // immediate order execution
         mrequest.price = NormalizeDouble(latest_price.bid,_Digits);           // latest Bid price
    //     mrequest.sl = NormalizeDouble(latest_price.bid + STP*_Point,_Digits); // Stop Loss
         
         //mrequest.tp = NormalizeDouble(latest_price.bid - TKP*_Point,_Digits); // Take Profit
         mrequest.symbol = _Symbol;                                          // currency pair
         mrequest.volume = Lot;                                              // number of lots to trade
         mrequest.magic = EA_Magic;                                          // Order Magic Number
         mrequest.type= ORDER_TYPE_SELL;                                     // Sell Order
         
         mrequest.type_filling = ORDER_FILLING_FOK;                          // Order execution type
         mrequest.deviation=100;                                             // Deviation from current price
         //--- send order
         OrderSend(mrequest,mresult);
         // get the result code
         if(mresult.retcode==10009 || mresult.retcode==10008) //Request is completed or order placed
           {
            Alert("A Sell order has been successfully placed with Ticket#:",mresult.order,"!!");
            ticksSinceBuy = 0;
            tradePerSignal++;
            Alert("2Trade per signal: "+tradePerSignal);
            positionOpenedOnSignal = true;
            tradeExecutor.executeTrade();
           }
         else
           {
            Alert("The Sell order request could not be completed -error:",GetLastError());
            ResetLastError();
            return;
           }
        }
     }
     
  ////BULL && BEAR on H4 - speculative
  if(!Position_opened) {  
     if(ichimokuContainer_H4.tenkanKijunBull() && ichimokuBuySignal) {
        
         //below condition probably gives some positves
        if(tradePerSignal == 1 && positionClosedOnStochSignal) {
         if(ichimokuContainer_H4.priceBelowKumo() && ichimokuContainer_H1.priceBelowKumo()) {
            return;
         }
        }
        
       // if(stochasticContainer_H4.mainBelowSignal()) {
      //   return;
       // }
        
        //stochastic condition
         if(stochasticContainer_H1.mainLineBelow20Hit && stochasticContainer_H1.stochasticBuySignal()) {
            if(!Buy_opened) {
            
               if(tradePerSignal == maxTradesPerSignal) {
                  return;
               }
               Alert("Trade stoch per signal: "+tradePerSignal+" maxTrades: "+maxTradesPerSignal);
            
               orderBuy(latest_price, mrequest, mresult);
               
            }      
         
         }       
        
        
        //we have buy signal on H4 but we are below kumo - but it can be good position on H1
         if(ichimokuContainer_H1.tenkanKijunBuyCondition() && !ichimokuContainer_H1.priceInKumo()) {
            
            if(!Buy_opened) {
            
               if(tradePerSignal == maxTradesPerSignal) {
                  return;
               }
               Alert("Trade ichi per signal: "+tradePerSignal+" maxTrades: "+maxTradesPerSignal);
            
               orderBuy(latest_price, mrequest, mresult);
               
            }        
         }
     }
     
     if(ichimokuContainer_H4.tenkanKijunBear() && ichimokuSellSignal) {
         
         //if(stochasticContainer_H4.mainAboveSignal()) {
        // return;
        //} 
        //below condition probably gives some positves
        if(tradePerSignal == 1 && positionClosedOnStochSignal) {
         if(ichimokuContainer_H4.priceAboveKumo()) {
            return;
         }
        }        
         
         //stochastic condition
         if(stochasticContainer_H1.mainLineAbove80Hit && stochasticContainer_H1.stochasticSellSignal()) {
            if(!Sell_opened) {
            
               if(tradePerSignal == maxTradesPerSignal) {
                  return;
               }     
               Alert("Trade per signal: "+tradePerSignal+" maxTrades: "+maxTradesPerSignal);
                      
               orderSell(latest_price, mrequest, mresult);
               
            }        
         
         }
                
         
         if(ichimokuContainer_H1.tenkanKijunSellCondition() && !ichimokuContainer_H1.priceInKumo()) {
            
            if(!Sell_opened) {
            
               if(tradePerSignal == maxTradesPerSignal) {
                  return;
               }     
               Alert("Trade per signal: "+tradePerSignal+" maxTrades: "+maxTradesPerSignal);
                      
               orderSell(latest_price, mrequest, mresult);
               
            }        
         }
     
     
     
     }
     
}
     
     
     

   return;
  }
  
void orderBuy(MqlTick &latest_price, MqlTradeRequest &mrequest, MqlTradeResult &mresult) {
   
   
            ZeroMemory(mrequest);
         mrequest.action = TRADE_ACTION_DEAL;                                  // immediate order execution
         mrequest.price = NormalizeDouble(latest_price.ask,_Digits);           // latest ask price
         mrequest.sl = NormalizeDouble(latest_price.ask - STP*_Point,_Digits); // Stop Loss
         //mrequest.tp = NormalizeDouble(latest_price.ask + TKP*_Point,_Digits); // Take Profit
         mrequest.symbol = _Symbol;                                            // currency pair
         mrequest.volume = Lot;                                                 // number of lots to trade
         mrequest.magic = EA_Magic;                                             // Order Magic Number
         mrequest.type = ORDER_TYPE_BUY;                                        // Buy Order
         mrequest.type_filling = ORDER_FILLING_FOK;                             // Order execution type
         mrequest.deviation=100;                                                // Deviation from current price
         //--- send order
         OrderSend(mrequest,mresult);
         // get the result code
         if(mresult.retcode==10009 || mresult.retcode==10008) //Request is completed or order placed
           {
            Alert("A spec Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
            tradePerSignal++;
            Alert("Trade per signal: "+tradePerSignal);
            positionOpenedOnSignal = false;
           }
         else
           {
            Alert("The Buy order request could not be completed -error:",GetLastError());
            ResetLastError();           
            return;
           }


}  

void orderSell(MqlTick &latest_price, MqlTradeRequest &mrequest, MqlTradeResult &mresult) {
   
      ZeroMemory(mrequest);
         mrequest.action=TRADE_ACTION_DEAL;                                // immediate order execution
         mrequest.price = NormalizeDouble(latest_price.bid,_Digits);           // latest Bid price
         mrequest.sl = NormalizeDouble(latest_price.bid + STP*_Point,_Digits); // Stop Loss
         //mrequest.tp = NormalizeDouble(latest_price.bid - TKP*_Point,_Digits); // Take Profit
         mrequest.symbol = _Symbol;                                          // currency pair
         mrequest.volume = Lot;                                              // number of lots to trade
         mrequest.magic = EA_Magic;                                          // Order Magic Number
         mrequest.type= ORDER_TYPE_SELL;                                     // Sell Order
         mrequest.type_filling = ORDER_FILLING_FOK;                          // Order execution type
         mrequest.deviation=100;                                             // Deviation from current price
         //--- send order
         OrderSend(mrequest,mresult);
         // get the result code
         if(mresult.retcode==10009 || mresult.retcode==10008) //Request is completed or order placed
           {
            Alert("A spec Sell order has been successfully placed with Ticket#:",mresult.order,"!!");
            tradePerSignal++;
            Alert("Trade per signal: "+tradePerSignal);
            positionOpenedOnSignal = false;
           }
         else
           {
            Alert("The Sell order request could not be completed -error:",GetLastError());
            ResetLastError();
            return;
         }

}

void closeTrade() {
   
    //---
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current position
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
      {
         if(m_position.Symbol()==Symbol())
            m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
  }
//+------------------------------------------------------------------+

}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
//---
   
  }
//+------------------------------------------------------------------+

