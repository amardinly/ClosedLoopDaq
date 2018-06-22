function [ExpStruct OutputSignal] = closeLoopMaster(dataIn,ExpStruct,myUDP,HoloSocket,defaultOutputSignal,eomOffset,i);
%% Close Loop master function
persistent holoRequest LaserPower
tic

debugFlag = 1;

OutputSignal=defaultOutputSignal;

%load HoloRequest once, on the first  run
if isempty(holoRequest);
    loc=FrankenScopeRigFile;
    load([loc.HoloRequest 'holoRequest.mat'],'holoRequest');
    load(loc.PowerCalib,'LaserPower');
end

%send UDP trigger to Camera to save frames and open next file
fwrite(myUDP,num2str(i+1));
disp('UDP signal sent to camera');

%1) grab calcium data
loadPath = 'X:\holography\Data\Alan\DataTransferNode\';
newDataDir = dir([loadPath '*mat']);


if ExpStruct.getSIdata;
    if i == 1;
        
        ExpStruct.dFF(i,:) = nan(1,numel(holoRequest.rois));
        
    else
        
        %     if numel(newDataDir)== 3;
        %         load([loadPath newDataDir(3).name]);  %load new calcium data
        %         delete([loadPath newDataDir(3).name]); %delete old calcium data
        %         dataFlag = true;                       %flag new data
        %
        %         ExpStruct.dFF(i,:)=dff;
        %         clear dff;
        %         disp('YES SI DATA');
        %     else
        %         dataFlag = false;
        %
        %         ExpStruct.dFF(i,:) = nan(1,size(ExpStruct.dFF,2));  %nans cause we dont have infor for this trial
        %         disp('NO SI DATA');
        %
        %     end
        
        %wait for calcium data...
        while isempty(newDataDir);
            pause(0.05);
            newDataDir = dir([loadPath '*mat']);
        end
        
        
        load([loadPath newDataDir(1).name]);  %load new calcium data
        delete([loadPath newDataDir(1).name]); %delete old calcium data
        dataFlag = true;                       %flag new data
        
        ExpStruct.dFF(i,:)=dff;
        clear dff;
        disp('LOADED CALCIUM DATA');
    end
end
%analyze sweeps{thisTrial}(1,:) for analog data, and we'll see about
%digital data.  remember to undo the delta from CC
%assignin('base','dataIn',dataIn)

%2) grab stimulus data
offset = mean(dataIn(3000:4000,1));
nextTrialStimData = round((mean(dataIn(100:1000,1))-offset) * 78);

[m indx]= min(abs(ExpStruct.StimVoltages - nextTrialStimData));

ExpStruct.StimulusData(i) = ExpStruct.StimVoltages(indx);

%magnet stim value ON NEXT STIMULUS
% ExpStruct.StimulusData(i) = nextTrialStimData;

%3) grab behavior data
behOutcome =(mean(dataIn(31500:33400,1)) - offset) * 78;  %magnet stim value ON NEXT STIMULUS
outcomes = [0 64 191 255];
[m indx]= min(abs(outcomes - behOutcome));

ExpStruct.BehaviorOutcomes(i) = indx;
%disp(['last trial was a type ' num2str(indx)]);
%disp(['next trial the stim will be ' num2str(nextTrialStimData)]);

ExpStruct.dataIn{i}=dataIn;
%% science happens here
if ExpStruct.getSIdata;
[neuronsToShoot StimParams ExpStruct]=chooseStimuli(ExpStruct,i);
%disp('close loop analysis function completed.  We have stimulation parameters');
else
    debugFlag = 1;
end

%debug only
if debugFlag;
    neuronsToShoot =nan;  %
    StimParams.pulseDuration=5; %ms
    StimParams.stimFreq=30; %hz
    StimParams.avgPower = .15; %W  0.05 0.1 0.15 0.2
    StimParams.unitLength=200; %ms
    StimParams.startTime=500; %ms;
    StimParams.pulseNumber=6 ;%10 18
    DE_list = [ 1 1 1 1 1 1 1];
end;
%

ExpStruct.stimParams{i}=StimParams;
ExpStruct.neuronsToShoot{i}=neuronsToShoot;


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
else
    %if neuronstoShoot is nan, send nothing on the stim laser
    LaserOutput=zeros(size(defaultOutputSignal,1),1);
    LaserOutput(LaserOutput==0)=eomOffset;  %apply offset
    OutputSignal(:,1) = LaserOutput;

end

toc
fprintf('\n')
fprintf('\n')
fprintf('\n')

end
