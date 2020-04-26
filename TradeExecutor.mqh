//+------------------------------------------------------------------+
//|                                                TradeExecutor.mqh |
//|                                                         SteelRat |
//|                                                             none |
//+------------------------------------------------------------------+
#include <Object.mqh>
#include "StochasticContainer.mqh"
#include "IchimokuContainer.mqh"
#include "CCIMaContainer.mqh"
#include "SignalContainer.mqh"

#property copyright "SteelRat"
#property link      "none"

enum IchimokuMarket {
   ICHIMOKU_BULL,
   ICHIMOKU_BEAR
};


class TradeExecutor : public CObject
{
   private:
         
         //ichi
         IchimokuContainer *ichimokuContainer_H4;
         IchimokuContainer *ichimokuContainer_H1;
         //stochastic
         StochasticContainer *stochasticContainer_H4;
         StochasticContainer *stochasticContainer_H1;
         //--- Handle of the CCIMa.mq5 custom indicator
         CCIMaContainer *cciMaContainer_H4;
         CCIMaContainer *cciMaContainer_H1;
         
         SignalContainer *signalContainer;
                  
         IchimokuMarket ichimokuMarketH4;
         IchimokuMarket ichimokuMarketH1;
         bool ichimokuTradeSignalH4;
         bool ichimokuTradeSignalH1;
         bool ichimokuTradeWaitingForExecution;
         bool tradeSendToExecution;
         bool tradeExecuted;
         bool cciBelowChannelUpH1;
         bool cciGoBelowChannelUpH1;
         bool cciGoAboveChannelDownH1;
         bool tradeClosedOnCciDownSignal;
         bool cciAboveMaH1;
         int maxCciSignalAge;
                  
   public:
         TradeExecutor(string sym);
         ~TradeExecutor(void);
         void copyBuffers();
         void checkTradeConditions(MqlRates &mrate[]);
         bool positionOpenedCloseTradeSignal(ENUM_POSITION_TYPE positionType);
         bool noPositionTradeDecision(ENUM_POSITION_TYPE positionType, bool positionOpened);
         bool cciAllowBuyTrade(); 
         bool cciAllowSellTrade();   
                  
         void executeTrade();

  
};

TradeExecutor::TradeExecutor(string sym)
{
   maxCciSignalAge = 7;

   signalContainer = new SignalContainer();

   ichimokuContainer_H4 = new IchimokuContainer(sym,PERIOD_H4,INDICATOR_DATA, signalContainer);
   ichimokuContainer_H1 = new IchimokuContainer(sym,PERIOD_H1,INDICATOR_DATA, signalContainer);

   stochasticContainer_H4 = new StochasticContainer(sym,PERIOD_H4,INDICATOR_DATA, signalContainer);
   stochasticContainer_H1 = new StochasticContainer(sym,PERIOD_H1,INDICATOR_DATA, signalContainer);
   //cci ma
   cciMaContainer_H4 = new CCIMaContainer(sym,PERIOD_H4,INDICATOR_DATA, signalContainer);  
   cciMaContainer_H1 = new CCIMaContainer(sym,PERIOD_H1,INDICATOR_DATA, signalContainer);
   
   
}
  
TradeExecutor::~TradeExecutor(void)
{
}

void TradeExecutor::copyBuffers() {
   
   ichimokuContainer_H4.copyBuffers();
   ichimokuContainer_H1.copyBuffers();
   
   stochasticContainer_H4.copyBuffers();
   stochasticContainer_H1.copyBuffers();

   cciMaContainer_H4.copyBuffers();
   cciMaContainer_H1.copyBuffers();
}

bool TradeExecutor::positionOpenedCloseTradeSignal(ENUM_POSITION_TYPE positionType) {
   if(positionType == POSITION_TYPE_BUY) {
      //if(stochasticContainer_H4.stochasticSellSignal()) {
       //  return true;
      //}
      //if(cciGoBelowChannelUpH1) {
      //   tradeClosedOnCciDownSignal = true;
      //   return true;
      //}
      if(signalContainer.closeBuySignal()) {
         return true;
      }
      //if(cciMaContainer_H4.cciGoBelowMa()) {
      //   tradeClosedOnCciDownSignal = true;
      //   return true;
      //}
      
   } else {
      //if(stochasticContainer_H4.stochasticBuySignal()) {
      //   return true;
      //}
      //if(cciMaContainer_H4.cciGoAboveMa()) {
         //tradeClosedOnCciDownSignal = true;
      //   return true;
      //}
      if(signalContainer.closeSellSignal()) {
         return true;
      }
      
   }
   return false;
}


  
void TradeExecutor::executeTrade() {
  tradeExecuted = true;
  tradeSendToExecution = false;
  ichimokuTradeWaitingForExecution = false;
  
  tradeClosedOnCciDownSignal = false;
}
  
void TradeExecutor::checkTradeConditions(MqlRates &mrate[]) {
    //check trade signal on ichimoku H4
    if(ichimokuContainer_H4.tenkanKijunBuyCondition() || ichimokuContainer_H4.tenkanKijunSellCondition()) {
      ichimokuTradeSignalH4 = true;
    } else {
      ichimokuTradeSignalH4 = false;
      tradeExecuted = false;
    }
    
    if(ichimokuContainer_H1.tenkanKijunBuyCondition() || ichimokuContainer_H1.tenkanKijunSellCondition()) {
      ichimokuTradeSignalH1 = true;
    } else {
      ichimokuTradeSignalH1 = false;
    }
        
    if(!tradeExecuted && ichimokuTradeSignalH1) {
      ichimokuTradeWaitingForExecution = true;
    }
    
    if(tradeExecuted && tradeClosedOnCciDownSignal) {
      ichimokuTradeWaitingForExecution = true;
    }
    
    //check trend on ichimoku H4
    if(ichimokuContainer_H4.tenkanKijunBull()) {
      ichimokuMarketH4 = ICHIMOKU_BULL;
    }
    if(ichimokuContainer_H4.tenkanKijunBear()) {
      ichimokuMarketH4 = ICHIMOKU_BEAR;
    }
    //check trend on ichimoku H1
    if(ichimokuContainer_H1.tenkanKijunBull()) {
      ichimokuMarketH1 = ICHIMOKU_BULL;
    }
    if(ichimokuContainer_H1.tenkanKijunBear()) {
      ichimokuMarketH1 = ICHIMOKU_BEAR;
    }
    //if ichimokuTradeSignalH4 comes then we need to find optimal point of entry on H1
    cciMaContainer_H4.generateTradeSignal(mrate);
    cciMaContainer_H1.generateTradeSignal(mrate);
    
    ichimokuContainer_H4.generateTradeSignal(mrate);
    ichimokuContainer_H1.generateTradeSignal(mrate);
    
    stochasticContainer_H4.generateTradeSignal(mrate);
    
    cciBelowChannelUpH1 = cciMaContainer_H4.cciBelowChannelUp();
    cciGoBelowChannelUpH1 = cciMaContainer_H4.cciGoBelowChannelUp();
    cciGoAboveChannelDownH1 = cciMaContainer_H4.cciGoAboveChannelDown();
    cciAboveMaH1 = cciMaContainer_H4.cciAboveMa();
}
/// method returns true if trade should be performed (depending of position type)
bool TradeExecutor::noPositionTradeDecision(ENUM_POSITION_TYPE positionType, bool positionOpened) {
   //if(ichimokuTradeWaitingForExecution) {
      if(positionOpened) {
         return false;
      }
      
      if(positionType == POSITION_TYPE_BUY) {
         //if(ichimokuMarketH4 == ICHIMOKU_BULL && cciAllowBuyTrade()) {
         //if(cciAllowBuyTrade()) {
          
         if(signalContainer.returnBuySignal()) {
         
            tradeSendToExecution=true;
            cciMaContainer_H4.cciBuySignal = false; //how to retry trade on stoploss?
            Alert("TradeExecutorBuy");
            return true;
         }
      }
   
      if(positionType == POSITION_TYPE_SELL) {
         //if(ichimokuMarketH4 == ICHIMOKU_BEAR && cciAllowSellTrade()) {
         //if(cciAllowSellTrade()) {
         if(signalContainer.returnSellSignal()) {
         
            tradeSendToExecution=true;
            cciMaContainer_H4.cciSellSignal = false;
            Alert("TradeExecutorSell");
            return true;
         }
      }   
   
   
   //}
   return false;
}

bool TradeExecutor::cciAllowBuyTrade() {
   if(cciMaContainer_H4.cciBuySignal && cciMaContainer_H4.signalAge <= maxCciSignalAge) {
      return true;
   }
   //if(cciMaContainer_H4.cciBuySignal && !cciMaContainer_H4.cciAboveChannelUp()) {
   //   return true;
   //}
   //if(cciBelowChannelUpH1 && !tradeClosedOnCciDownSignal) {
   //   return true;
  // }
   //if(tradeClosedOnCciDownSignal && cciGoAboveChannelDownH1) {
   //   tradeClosedOnCciDownSignal = false;
   //   return true;
  // }
   return false;
}

bool TradeExecutor::cciAllowSellTrade() {
   //if(!cciAboveMaH1) {
   //   return true;
   //}
   if(cciMaContainer_H4.cciSellSignal && cciMaContainer_H4.signalAge <= maxCciSignalAge) {
      return true;
   }
   //if(cciMaContainer_H4.cciSellSignal && !cciMaContainer_H4.cciBelowChannelDown()) {
   //   return true;
   //}
   return false;
}