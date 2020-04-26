//+------------------------------------------------------------------+
//|                                               CCIMaContainer.mqh |
//|                                                         SteelRat |
//|                                                             none |
//+------------------------------------------------------------------+
#include <Object.mqh>
#include "SignalContainer.mqh"

#property copyright "SteelRat"
#property link      "none"


enum CCIState {
   OVERSOLD, OVERBOUGHT, TOTAL_OVERSOLD, TOTAL_OVERBOUGHT
};

class CCIMaContainer : public CObject
{
private:
            double CCI_Buffer[];
            double MA_Buffer[];
            double ChannelUp_Buffer[];
            double ChannelDown_Buffer[];
            
            int cciMaHandle;
            
            bool cciOverbought;
            bool cciOversold;
            
            bool cciGoingSouth;
            bool cciGoingNorth;
            
            double cciMin;
            double cciMax;
            
            SignalContainer *signalContainer;
            SignalType signalType;
            ENUM_TIMEFRAMES period; 
            int buyColor2;
            int buyColor3;
            int sellColor2;
            int sellColor3;                      
                                  

public:
            CCIMaContainer(string commodity, ENUM_TIMEFRAMES per,ENUM_INDEXBUFFER_TYPE data, SignalContainer *signalContainer);
           ~CCIMaContainer();
           bool copyBuffers();
           void generateTradeSignal(MqlRates &mrate[]);
           bool cciBelowChannelUp();
           bool cciGoBelowChannelUp();
           bool cciGoAboveChannelUp();
           bool cciGoAboveChannelDown();
           bool cciGoBelowChannelDown();
           bool cciAboveMa();
           bool cciGoAboveMa();
           bool cciGoBelowMa();
           bool cciAboveChannelUp();
           bool cciBelowChannelDown();
           double calculateMaVector();
           void drawVerticalLine(MqlRates &mrate[], int colour);
           
           bool cciSellSignal;
           bool cciBuySignal;
           CCIState lastState;
           int signalAge;
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCIMaContainer::CCIMaContainer(string commodity, ENUM_TIMEFRAMES per,ENUM_INDEXBUFFER_TYPE data, SignalContainer *signalContainer)
  {
      this.signalContainer = signalContainer;
      this.period = per;
      if(period == PERIOD_H4) {
         signalType = CCIH4;
         buyColor2 = clrSpringGreen;
         buyColor3 = clrLime;
         sellColor2 = clrMagenta;
         sellColor3 = clrRed;
      } else {
         signalType = CCIH1;
         buyColor2 = clrLimeGreen;
         buyColor3 = clrGreen;
         sellColor2 = clrHotPink;
         sellColor3 = clrSalmon;
      }
      
      SetIndexBuffer(0,CCI_Buffer,INDICATOR_DATA);
      SetIndexBuffer(1,MA_Buffer,INDICATOR_DATA);
      SetIndexBuffer(3,ChannelUp_Buffer,INDICATOR_DATA);
      SetIndexBuffer(4,ChannelDown_Buffer,INDICATOR_DATA);
      
      ArraySetAsSeries(CCI_Buffer,true);
      ArraySetAsSeries(MA_Buffer,true);
      ArraySetAsSeries(ChannelUp_Buffer,true);
      ArraySetAsSeries(ChannelDown_Buffer,true);
      
      cciMaHandle = iCustom(commodity,per,"CCIMa",
                     36,//72
                     12,//18
                     30,
                     PRICE_TYPICAL); 
  
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCIMaContainer::~CCIMaContainer()
  {
  }
 //+------------------------------------------------------------------+
bool CCIMaContainer::copyBuffers() {

   //--- Get the details of the latest 3 bars
 
    if(CopyBuffer(cciMaHandle,0,0,3,CCI_Buffer)<0 || CopyBuffer(cciMaHandle,1,0,3,MA_Buffer)<0 ||
        CopyBuffer(cciMaHandle,2,0,3,ChannelUp_Buffer)<0 || CopyBuffer(cciMaHandle,3,0,3,ChannelDown_Buffer)<0)
    {
      Alert("Error copying Stochastic indicator Buffers - error:",GetLastError(),"!!");
      ResetLastError();
      return false;
     }
               
   return true;
}

void CCIMaContainer::generateTradeSignal(MqlRates &mrate[]) {
   
   //increase age
   signalAge++;
   
   if(cciGoBelowChannelDown()) {
      //cci goes down
      cciGoingSouth = true;
   }
   
   if(cciGoingSouth && (cciBuySignal || cciSellSignal)) {
      cciBuySignal = false;
      cciSellSignal = false;
      signalContainer.setCciSignalStrenght(period,0);
   }
   
   if(cciGoingSouth) { 
      if(cciMin > CCI_Buffer[1]) {
         cciMin = CCI_Buffer[1];
      } else {
         cciOversold = true;
         if(cciMin < 100) {
            lastState = TOTAL_OVERSOLD;
         } else {
            lastState = OVERSOLD;
         }
      }
   }
   
   if(cciGoAboveChannelDown()) {
      cciGoingSouth = false;
      cciMin = CCI_Buffer[1];
   }
   
   if(cciOversold && !cciGoingSouth) {
      cciBuySignal = true;
      signalContainer.registerBuySignal(signalType);
      signalAge = 0;
      cciOversold = false;
   }
   
   if(cciBuySignal && cciGoBelowMa()) {
      cciBuySignal = false;
   }
   //sell signal
   if(cciGoAboveChannelUp()) {
      cciGoingNorth = true;
   }
   
   if(cciGoingNorth && (cciBuySignal || cciSellSignal)) {
      cciBuySignal = false;
      cciSellSignal = false;
      signalContainer.setCciSignalStrenght(period,0);
   }
   
   if(cciGoingNorth) { 
      if(cciMax < CCI_Buffer[1]) {
         cciMax = CCI_Buffer[1];
      } else {
         cciOverbought = true;
         if(cciMax > 100) {
            lastState = TOTAL_OVERBOUGHT;
         } else {
            lastState = OVERBOUGHT;
         }
      }
   }
   
   if(cciGoBelowMa()) {
      cciGoingNorth = false;
      cciMax = CCI_Buffer[1];
   }
   
   if(cciOverbought && !cciGoingNorth ) {
      cciSellSignal = true;
      signalContainer.registerSellSignal(signalType);
      signalAge = 0;
      cciOverbought = false;
   }
   
   if(cciSellSignal && cciGoAboveMa()) {
      cciSellSignal = false;
   }
   
   if(cciBuySignal || cciSellSignal) {
      if(lastState == TOTAL_OVERBOUGHT || lastState == TOTAL_OVERSOLD) {
         signalContainer.setCciSignalStrenght(period,4);
         if(cciBuySignal) {
            drawVerticalLine(mrate, buyColor3);
         } else {
            drawVerticalLine(mrate, sellColor3);
         }
      } else if(lastState == OVERBOUGHT || lastState == OVERSOLD) {
         signalContainer.setCciSignalStrenght(period,2);
         if(cciBuySignal) {
            drawVerticalLine(mrate, buyColor2);
         } else {
            drawVerticalLine(mrate, sellColor2);
         }
      } else {
         signalContainer.setCciSignalStrenght(period,1);
         //drawVerticalLine(mrate, clrLightPink);
      }
   }
   
   
   signalContainer.setCciMaVector(period,calculateMaVector());
}

void CCIMaContainer::drawVerticalLine(MqlRates &mrate[], int colour) {
       
       string name = "CCI_signal" + TimeToString (mrate[0].time, TIME_DATE|TIME_SECONDS);
       
       ObjectCreate(0,name,OBJ_VLINE,0,mrate[0].time,0); 
       ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
}

//MA Vector shows if MA is going up (positive value) or down (negative)
double CCIMaContainer::calculateMaVector() {
   return MA_Buffer[1] - MA_Buffer[10];
}

bool CCIMaContainer::cciBelowChannelUp() {
   return CCI_Buffer[1] < ChannelUp_Buffer[1];
}

bool CCIMaContainer::cciGoBelowChannelUp() {
   return CCI_Buffer[2] > ChannelUp_Buffer[2] && CCI_Buffer[1] <= ChannelUp_Buffer[1];
}

bool CCIMaContainer::cciGoAboveChannelUp() {
   return CCI_Buffer[2] <= ChannelUp_Buffer[2] && CCI_Buffer[1] > ChannelUp_Buffer[1];
}

bool CCIMaContainer::cciGoBelowChannelDown() {
   return CCI_Buffer[2] > ChannelDown_Buffer[2] && CCI_Buffer[1] <= ChannelDown_Buffer[1];
}

bool CCIMaContainer::cciGoAboveChannelDown() {
   return CCI_Buffer[2] <= ChannelDown_Buffer[2] && CCI_Buffer[1] > ChannelDown_Buffer[1];
}

bool CCIMaContainer::cciAboveMa() {
   return CCI_Buffer[1] >= MA_Buffer[1]; 
}

bool CCIMaContainer::cciGoAboveMa() {
   return CCI_Buffer[2] <= MA_Buffer[2] && CCI_Buffer[1] > MA_Buffer[1]; 
}

bool CCIMaContainer::cciGoBelowMa() {
   return CCI_Buffer[2] >= MA_Buffer[2] && CCI_Buffer[1] < MA_Buffer[1]; 
}

bool CCIMaContainer::cciAboveChannelUp() {
   return CCI_Buffer[1] > ChannelUp_Buffer[1]; 
}

bool CCIMaContainer::cciBelowChannelDown() {
   return CCI_Buffer[1] < ChannelDown_Buffer[1]; 
}