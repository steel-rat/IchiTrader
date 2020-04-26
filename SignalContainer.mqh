//+------------------------------------------------------------------+
//|                                              SignalContainer.mqh |
//|                                                         SteelRat |
//|                                                             none |
//+------------------------------------------------------------------+
#property copyright "SteelRat"
#property link      "none"

enum SignalType {
   CCIH4,
   CCIH1,
   ICHIH4,
   ICHIH1,
   STOCH4,
   STOCH1
};

class SignalContainer : public CObject
{
private:
     int cciH4SignalStrenght;
     int cciH4BuySignalStrenght;
     int cciH4SellSignalStrenght;
     bool cciH4BuySignal;
     bool cciH4SellSignal;
     double cciH4MaVector;
     
     int cciH1SignalStrenght;
     int cciH1BuySignalStrenght;
     int cciH1SellSignalStrenght;
     bool cciH1BuySignal;
     bool cciH1SellSignal;
     double cciH1MaVector;
     
     int ichiH4SignalStrenght;
     bool ichiH4BuySignal;
     bool ichiH4SellSignal;
     
     int ichiH1SignalStrenght;
     bool ichiH1BuySignal;
     bool ichiH1SellSignal;
     
     
     
public:
     SignalContainer();
     ~SignalContainer();
     void setCciSignalStrenght(ENUM_TIMEFRAMES period,int strenght);
     void setCciBuySignalStrenght(ENUM_TIMEFRAMES period,int strenght);
     void setCciSellSignalStrenght(ENUM_TIMEFRAMES period,int strenght);
     void setCciMaVector(ENUM_TIMEFRAMES period,double vector);
     void registerBuySignal(SignalType type);
     void registerSellSignal(SignalType type);
     bool returnBuySignal();
     bool returnSellSignal();
     bool closeBuySignal(void);
     bool closeSellSignal(void);
     bool stochH4BuySignal;
     bool stochH4SellSignal;
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
SignalContainer::SignalContainer()
  {
      
  
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
SignalContainer::~SignalContainer()
  {
  }
////--cci handling
void SignalContainer::setCciSignalStrenght(ENUM_TIMEFRAMES period,int strenght) {
 
 if(period == PERIOD_H4) {
   cciH4SignalStrenght = strenght;
 } 
 if(period == PERIOD_H1) {
   cciH1SignalStrenght = strenght;
 }
}

void SignalContainer::setCciBuySignalStrenght(ENUM_TIMEFRAMES period,int strenght) {
 
 if(period == PERIOD_H4) {
   cciH4BuySignalStrenght = strenght;
 } 
 if(period == PERIOD_H1) {
   cciH1BuySignalStrenght = strenght;
 }
}

void SignalContainer::setCciSellSignalStrenght(ENUM_TIMEFRAMES period,int strenght) {
 
 if(period == PERIOD_H4) {
   cciH4SellSignalStrenght = strenght;
 } 
 if(period == PERIOD_H1) {
   cciH1SellSignalStrenght = strenght;
 }
}


void SignalContainer::setCciMaVector(ENUM_TIMEFRAMES period,double vector) {
 
 if(period == PERIOD_H4) {
   cciH4MaVector = vector;
 } 
 if(period == PERIOD_H1) {
   cciH1MaVector = vector;
 }
}
//-------
void SignalContainer::registerBuySignal(SignalType type) {
 if(type == CCIH1) {
   cciH1SellSignal = false;
   cciH1BuySignal = true;
 } else if(type == CCIH4) {
   cciH4SellSignal = false;
   cciH4BuySignal = true;
 } else if(type == ICHIH1) {
   ichiH1SellSignal = false;
   ichiH1BuySignal = true;
 } else if(type == ICHIH4) {
   ichiH4SellSignal = false;
   ichiH4BuySignal = true;
 } else if(type == STOCH4) {
   stochH4SellSignal = false;
   stochH4BuySignal = true;
 }
 
}
//----------------
void SignalContainer::registerSellSignal(SignalType type) {
 if(type == CCIH1) {
   cciH1BuySignal = false;
   cciH1SellSignal = true;
 } else if(type == CCIH4) {
   cciH4BuySignal = false;
   cciH4SellSignal = true;
 } else if(type == ICHIH1) {
   ichiH1BuySignal = false;
   ichiH1SellSignal = true;
 } else if(type == ICHIH4) {
   ichiH4BuySignal = false;
   ichiH4SellSignal = true;
 }

}
///------------open trade signals
bool SignalContainer::returnBuySignal(void) {
   if(ichiH1BuySignal) {
      if(cciH1BuySignal && cciH1SignalStrenght >= 2) { 
        return ichiH1BuySignal;  
      }
   }
   
   return false;
}

bool SignalContainer::returnSellSignal(void) {
   if(ichiH1SellSignal) {
      if(cciH1SellSignal && cciH1SignalStrenght >= 2) {
         return ichiH1SellSignal;
      }
   }
   
   return false;
}
///------------close trade signals
bool SignalContainer::closeBuySignal(void) {
   //calculate current strenght of position
   if(cciH1MaVector > 0) {
      cciH1SignalStrenght++;
   }
   if(cciH1SignalStrenght <= 1) {
      return ichiH1SellSignal;
   }
   return false;
}

bool SignalContainer::closeSellSignal(void) {
   return ichiH1BuySignal;
}




