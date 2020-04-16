//+------------------------------------------------------------------+
//|                                          StochasticContainer.mqh |
//|                                                         SteelRat |
//|                                                             none |
//+------------------------------------------------------------------+
#property copyright "SteelRat"
#property link      "none"
#property version   "1.00"
class StochasticContainer : public CObject
  {
private:
            double Stoch_Main_Buffer[];
            double Stoch_Sig_Buffer[];
            
            int stochHandle;
            
            

public:
                     StochasticContainer(string commodity, ENUM_TIMEFRAMES per,ENUM_INDEXBUFFER_TYPE data);
                    ~StochasticContainer();
                    bool copyBuffers();
                    bool stochasticBuySignal(void);
                    bool stochasticSellSignal(void);
                    
                    bool mainAboveSignal();
                    bool mainBelowSignal();
                    
                    
                    bool mainLineAbove80Hit;
                     bool mainLineBelow20Hit;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
StochasticContainer::StochasticContainer(string commodity, ENUM_TIMEFRAMES per,ENUM_INDEXBUFFER_TYPE data) : mainLineAbove80Hit(false),mainLineBelow20Hit(false)
  {
      SetIndexBuffer(0,Stoch_Main_Buffer,INDICATOR_DATA);
      SetIndexBuffer(1,Stoch_Sig_Buffer,INDICATOR_DATA);
      
      ArraySetAsSeries(Stoch_Main_Buffer,true);
      ArraySetAsSeries(Stoch_Sig_Buffer,true);
      
      stochHandle = iStochastic(commodity,per,5,4,3,MODE_SMA,STO_LOWHIGH);  
  
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
StochasticContainer::~StochasticContainer()
  {
  }
//+------------------------------------------------------------------+
bool StochasticContainer::copyBuffers() {

   //--- Get the details of the latest 3 bars
 
    if(CopyBuffer(stochHandle,0,0,3,Stoch_Main_Buffer)<0 || CopyBuffer(stochHandle,1,0,3,Stoch_Sig_Buffer)<0)
    {
      Alert("Error copying Stochastic indicator Buffers - error:",GetLastError(),"!!");
      ResetLastError();
      return false;
     }
     
     if(Stoch_Main_Buffer[1] > 80) {
         mainLineAbove80Hit = true;
         mainLineBelow20Hit = false;
     }
     if(Stoch_Main_Buffer[1] < 20) {
         mainLineAbove80Hit = false;
         mainLineBelow20Hit = true;
     }
          
   return true;
}

bool StochasticContainer::stochasticBuySignal(void) {
   return (Stoch_Main_Buffer[1] > Stoch_Sig_Buffer[1]) && (Stoch_Main_Buffer[2] < Stoch_Sig_Buffer[2]); 
}

bool StochasticContainer::stochasticSellSignal(void) {
   return (Stoch_Main_Buffer[1] < Stoch_Sig_Buffer[1]) && (Stoch_Main_Buffer[2] > Stoch_Sig_Buffer[2]); 
}

bool StochasticContainer::mainAboveSignal(){
   return Stoch_Main_Buffer[1] > Stoch_Sig_Buffer[1];
}

bool StochasticContainer::mainBelowSignal(){
   return Stoch_Main_Buffer[1] < Stoch_Sig_Buffer[1];
}