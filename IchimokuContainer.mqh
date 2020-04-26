//+------------------------------------------------------------------+
//|                                            IchimokuContainer.mqh |
//|                                                         SteelRat |
//|                                                             none |
//+------------------------------------------------------------------+
#property copyright "SteelRat"
#property link      "none"
#property version   "1.00"

#include "SignalContainer.mqh"

//int InpTenkan=9;     // Tenkan-sen
//         int InpKijun=26;     // Kijun-sen
//         int InpSenkou=52;    // Senkou Span B

class IchimokuContainer : public CObject
  {
private:
         //--- indicator buffer
         double         Tenkan_sen_Buffer[];
         double         Kijun_sen_Buffer[];
         double         Senkou_Span_A_Buffer[];
         double         Senkou_Span_B_Buffer[];
         double         Chinkou_Span_Buffer[];
         //-timeframe
         ENUM_TIMEFRAMES period;
         SignalType signalType;
         
         MqlRates mrate[];          // To be used to store the prices, volumes and spread of each bar
         double p_close; // Variable to store the close value of a bar
         
         //handle to signal
         int hIchimoku;
         
         SignalContainer *signalContainer;

              
public:
         IchimokuContainer(string commodity, ENUM_TIMEFRAMES period,ENUM_INDEXBUFFER_TYPE data, SignalContainer *signalContainer);
         ~IchimokuContainer();
         void generateTradeSignal(MqlRates &mrate[]);
         bool copyBuffers();
         bool tenkanKijunBuyCondition();
         bool tenkanKijunSellCondition();
         bool priceAboveKumo();
         bool priceBelowKumo();
         bool priceInKumo();
         bool tenkanKijunBull();
         bool tenkanKijunBear();
         bool priceBelowKijun();
         bool priceAboveKijun();  //Kijun == slower
         bool priceGoAboveTenkan();
         bool priceGoBelowTenkan();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
IchimokuContainer::IchimokuContainer(string commodity, ENUM_TIMEFRAMES per,ENUM_INDEXBUFFER_TYPE data, SignalContainer *signalContainer)
  {
         this.signalContainer = signalContainer;
         this.period = per;
         
         if(period == PERIOD_H4) {
            signalType = ICHIH4;
         } else {
            signalType = ICHIH1;
         }
         
         //--- assignment of arrays to indicator buffers
         SetIndexBuffer(0,Tenkan_sen_Buffer,INDICATOR_DATA);
         SetIndexBuffer(1,Kijun_sen_Buffer,INDICATOR_DATA);
         SetIndexBuffer(2,Senkou_Span_A_Buffer,INDICATOR_DATA);
         SetIndexBuffer(3,Senkou_Span_B_Buffer,INDICATOR_DATA);
         SetIndexBuffer(4,Chinkou_Span_Buffer,INDICATOR_DATA);
         
         ArraySetAsSeries(Tenkan_sen_Buffer,true);
         ArraySetAsSeries(Kijun_sen_Buffer,true);
         ArraySetAsSeries(Senkou_Span_B_Buffer,true);
         
         hIchimoku = iIchimoku(commodity,period,InpTenkan,InpKijun,InpSenkou);
         
         // the rates arrays
         ArraySetAsSeries(mrate,true);
  
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
IchimokuContainer::~IchimokuContainer()
  {
   IndicatorRelease(hIchimoku);     
  }
//+------------------------------------------------------------------+

bool IchimokuContainer::copyBuffers() {

   //--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return false;
     }
//--- Copy the new values of our indicators to buffers (arrays) using the handle
   //copy indicator data to buffers
   if(CopyBuffer(hIchimoku,0,0,3,Tenkan_sen_Buffer)<0 || CopyBuffer(hIchimoku,1,0,3,Kijun_sen_Buffer)<0
      || CopyBuffer(hIchimoku,3,0,3,Senkou_Span_B_Buffer)<0 || CopyBuffer(hIchimoku,2,0,3,Senkou_Span_A_Buffer)<0)
     {
      Alert("Error copying Ichimoku indicator Buffers - error:",GetLastError(),"!!");
      ResetLastError();
      return false;
     }
     
   // Copy the bar close price for the previous bar prior to the current bar, that is Bar 1
   p_close=mrate[1].close;  // bar 1 close price
     
   return true;
}

bool IchimokuContainer::tenkanKijunBuyCondition(void) {
   
   bool Buy_Condition_1=  Tenkan_sen_Buffer[1] > Kijun_sen_Buffer[1];  //tenkan > kijan
   bool Buy_Condition_2 = Tenkan_sen_Buffer[2] <= Kijun_sen_Buffer[2];

   return Buy_Condition_1 && Buy_Condition_2;
   
  
}

bool IchimokuContainer::tenkanKijunSellCondition(void) {
    
   bool Sell_Condition_1 = Kijun_sen_Buffer[1] > Tenkan_sen_Buffer[1];
   bool Sell_Condition_2 = Kijun_sen_Buffer[2] <= Tenkan_sen_Buffer[2];

   return Sell_Condition_1 && Sell_Condition_2;
}

bool IchimokuContainer::priceAboveKumo(void) {

   bool Buy_Condition_3 = Senkou_Span_B_Buffer[1] < p_close;
   return Buy_Condition_3;
}

bool IchimokuContainer::priceBelowKumo(void) {
   bool Sell_Condition_3 = Senkou_Span_B_Buffer[1] > p_close;
   return Sell_Condition_3;
}

bool IchimokuContainer::priceInKumo() {

  //Alert("CHECK KUMO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

   if(Senkou_Span_A_Buffer[1] >= Senkou_Span_B_Buffer[1]) {
      //bull kumo
      return p_close < Senkou_Span_A_Buffer[1] && p_close > Senkou_Span_B_Buffer[1];
   } else {
      //bear kumo
      return p_close > Senkou_Span_A_Buffer[1] && p_close < Senkou_Span_B_Buffer[1];
   }

}

bool IchimokuContainer::tenkanKijunBull(void) {
   return Tenkan_sen_Buffer[1] > Kijun_sen_Buffer[1];
}

bool IchimokuContainer::tenkanKijunBear(void) {
   return Tenkan_sen_Buffer[1] < Kijun_sen_Buffer[1];
}

bool IchimokuContainer::priceBelowKijun(void) {
   return p_close < Kijun_sen_Buffer[1];
}

bool IchimokuContainer::priceAboveKijun(void) {
   return p_close > Kijun_sen_Buffer[1];
}

bool IchimokuContainer::priceGoAboveTenkan() {
   return mrate[1].close > Tenkan_sen_Buffer[1] && mrate[2].close < Tenkan_sen_Buffer[2];
}

bool IchimokuContainer::priceGoBelowTenkan() {
   return mrate[1].close < Tenkan_sen_Buffer[1] && mrate[2].close > Tenkan_sen_Buffer[2];
}

//generate trade signal
void IchimokuContainer::generateTradeSignal(MqlRates &mrate[]) {
   if(priceGoAboveTenkan()) {
      signalContainer.registerBuySignal(signalType);
   }
   if(priceGoBelowTenkan()) {
      signalContainer.registerSellSignal(signalType);
   }
}