function [ExpStruct OutputSignal] = closeLoopMaster(dataIn,ExpStruct,myUDP,HoloSocket,defaultOutputSignal,eomOffset,i);
%% Close Loop master function
persistent holoRequest LaserPower

tic
OutputSignal=defaultOutputSignal;

%send UDP trigger to Camera to save frames and open next file
fwrite(myUDP,num2str(i+1));
disp('UDP signal sent to camera');

%1) grab calcium data
loadPath = 'X:\holography\Data\Alan\DataTransferNode\';
newDataDir = dir(loadPath);

if numel(newDataDir)== 3;
    load([loadPath newDataDir(3).name]);  %load new calcium data
    delete([loadPath newDataDir(3).name]); %delete old calcium data
    dataFlag = true;                       %flag new data
    
    ExpStruct.dFF(i,:)=dff;
    clear dff;
    disp('Calcium data grabbed from SI');
else
    dataFlag = false;
    try
    ExpStruct.dFF(i,:) = nan(size(ExpStruct.dFF,2));  %nans cause we dont have infor for this trial
    disp('no data from SI this time');
    end
end


%analyze sweeps{thisTrial}(1,:) for analog data, and we'll see about
%digital data.  remember to undo the delta from CC

%2) grab stimulus data
offset = mean(dataIn(3000:4000,1));
nextTrialStimData = round((mean(dataIn(100:1000,1))-offset) * 78);

%magnet stim value ON NEXT STIMULUS
ExpStruct.StimulusData(i) = nextTrialStimData;

%3) grab behavior data
behOutcome =(mean(dataIn(31500:33400,1)) - offset) * 78;  %magnet stim value ON NEXT STIMULUS
outcomes = [0 64 191 255];
[m indx]= min(abs(outcomes - behOutcome));

ExpStruct.BehaviorOutcomes(i) = indx;
disp(['last trial was a type ' num2str(indx)]);
disp(['next trial the stim will be ' num2str(nextTrialStimData)]);

%% science happens here

% [neuronsToShoot StimParams]=complicatedFunction(ExpStruct);
disp('close loop analysis function completed.  We have stimulation parameters');


%debug only
neuronsToShoot =nan;  %
StimParams.pulseDuration=5; %ms
StimParams.stimFreq=30; %hz
StimParams.avgPower = .15; %W  0.05 0.1 0.15 0.2
StimParams.unitLength=200; %ms
StimParams.startTime=500; %ms;
StimParams.pulseNumber=6 ;%10 18
DE_list = [ 1 1 1 1 1 1 1];

%

ExpStruct.stimParams{i}=StimParams;
ExpStruct.neuronsToShoot{i}=neuronsToShoot;

%load HoloRequest once, on the first  run
if isempty(holoRequest);
    loc=FrankenScopeRigFile;
    load([loc.HoloRequest 'holoRequest.mat'],'holoRequest');
    load(loc.PowerCalib,'LaserPower');
end

%if we're going to make new holograms
if ~isnan(neuronsToShoot);
%remove DE 
DE_list = [];  %reset DE list
    
%new holorequest!    
theListofHolos = num2str(neuronsToShoot); %change to string
rois=HI3Parse(theListofHolos);
[listOfPossibleHolos convertedSequence] = convertSequence(rois);

holoRequest.rois     =  listOfPossibleHolos;
holoRequest.Sequence = {convertedSequence};

%send new holorequest to hologram computer
mssend(HoloSocket,holoRequest);

disp('Sent New Hologram Command - waiting on DE list');

while isempty(DE_list);
    DE_list=msrecv(HoloSocket);
end
disp('Got DE_list, now making triggers');




    %% Maker Stimulation Triggers
       
    thisTarget=holoRequest.Sequence{1}(1);
    targets=holoRequest.rois{thisTarget};
    LaserOutput=zeros(size(defaultOutputSignal,1),1);
    NextHoloOutput = LaserOutput; % zeros
    
    % outputSignal(:,1)=LaserTrigger; %verified
    % outputSignal(:,2)=SI_Trigger; %verified
    % outputSignal(:,3)=Puffer;
    % outputSignal(:,4)=NextHolo;%verified
    % outputSignal(:,5)=NextSeq; %verified
    % outputSignal(:,6)=Puffer;
    % outputSignal(:,7)=CameraTrigger;%verified

    % based on next stimulus and stimulus history, make Laser EOM and holo triggers for stimulus
    for j=1:numel(holoRequest.Sequence{1});
        PowerRequest = (StimParams.avgPower*numel(targets))/DE_list(thisTarget);
        Volt = function_EOMVoltage(LaserPower.EOMVoltage,LaserPower.PowerOutputTF,PowerRequest);
        Q=makepulseoutputs(StimParams.startTime,StimParams.pulseNumber,StimParams.pulseDuration,Volt,StimParams.stimFreq,20000,size(LaserOutput,1)/20000);      
        R=makepulseoutputs(StimParams.startTime-10,1,StimParams.pulseDuration,1,StimParams.stimFreq,20000,size(LaserOutput,1)/20000);
        LaserOutput=LaserOutput+Q;
        NextHoloOutput=NextHoloOutput+R;
        StimParams.startTime=StimParams.startTime+StimParams.unitLength;
    end
    
    LaserOutput(LaserOutput==0)=eomOffset;  %apply offset
    OutputSignal(:,1) = LaserOutput;
    OutputSignal(:,4) =  NextHoloOutput;
end

toc
end
