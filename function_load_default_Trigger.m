function outputSignal = function_load_default_Trigger(eomOffset);


SI_Trigger=makepulseoutputs(100,1,20,1,1,20000,2);

LaserTrigger=zeros(size(SI_Trigger));
LaserGateTrigger = LaserTrigger;
NextHolo = LaserTrigger;
Puffer = LaserTrigger;

CameraTrigger=makepulseoutputs(1,150,.5,1,300,20000,2);

NextSeqTrigger1=makepulseoutputs(1,0,20,1,1,20000,2);
NextSeqTrigger2=makepulseoutputs(1500,1,50,1,10,20000,2);
NextSeq = NextSeqTrigger1 + NextSeqTrigger2;
%NextSeq = zeros(length(Puffer),1);

outputSignal(:,1)=LaserTrigger+eomOffset; %verified
outputSignal(:,2)=SI_Trigger; %verified
outputSignal(:,3)=Puffer;
outputSignal(:,4)=NextHolo;%verified
outputSignal(:,5)=NextSeq; %verified
outputSignal(:,6)=Puffer;
outputSignal(:,7)=CameraTrigger;%verified
