function [ExpStruct OutputSignal] = closeLoopMaster(dataIn,ExpStruct,myUDP,HoloSocket,defaultOutputSignal,eomOffset,i);
%% Close Loop master function
persistent holoRequest LaserPower
tic

debugFlag = 0;
debugSLM = 0;


%remove DE

OutputSignal=defaultOutputSignal;

%load HoloRequest once, on the first  run
if isempty(holoRequest) && ExpStruct.getSIdata;
    loc=FrankenScopeRigFile;
    load([loc.HoloRequest 'holoRequest.mat'],'holoRequest');
    load(loc.PowerCalib,'LaserPower');
    ExpStruct.holoRequest = holoRequest;
end

%send UDP trigger to Camera to save frames and open next file
fwrite(myUDP,num2str(i+1));
%disp('UDP signal sent to camera');

%1) grab calcium data
loadPath = 'X:\holography\Data\Alan\DataTransferNode\';
newDataDir = dir([loadPath '*mat']);


if ExpStruct.getSIdata;
    if debugSLM == 1
        ExpStruct.dFF(i,:) = randi(300, 1, 10);
    else
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

            try
                load([loadPath newDataDir(1).name]);  %load new calcium data
            catch
              FUCK = 1;
                while FUCK == 1;
                  pause(0.01);
                  try
                  load([loadPath newDataDir(1).name]);  %load new calcium data
                  FUCK = 2; 
                  catch
                  disp('its that weird .txt loading error for calcium data???');
                  end
              end  
            end

            delete([loadPath newDataDir(1).name]); %delete old calcium data
            dataFlag = true;                       %flag new data

            try
            ExpStruct.dFF(i,:)=dff;
            catch
            ExpStruct.dFF(i,:)=dff';
            end
            clear dff;
            disp('LOADED CALCIUM DATA');
        end
    end
end
%analyze sweeps{thisTrial}(1,:) for analog data, and we'll see about
%digital data.  remember to undo the delta from CC
%assignin('base','dataIn',dataIn)


%NEW: grab stimulus data based on digital pin
%the number of up changes in the first 20k is the index of the stim
nextTrialStimIdx = length(find(diff(dataIn(1:20000,2))>0));

ExpStruct.StimulusData(i) = ExpStruct.StimVoltages(nextTrialStimIdx);

%and the number of up changes in last 20k is the outcome
outcome = length(find(diff(dataIn(20000:end,2))>0));
ExpStruct.BehaviorOutcomes(i) = outcome;

%get the stim on and off times
stim_on = find(diff(dataIn(:,3))==1);
stim_off = find(diff(dataIn(:,3))==-1);
if isempty(stim_on)
    stim_on = 0;
    stim_off = 0;
end
ExpStruct.StimTimes(i,:) = [stim_on stim_off];
%disp(['last trial was a type ' num2str(indx)]);
disp(['next trial the stim will be ' num2str(ExpStruct.StimVoltages(nextTrialStimIdx))]);

ExpStruct.dataIn{i}=dataIn;
%% science happens here
if ExpStruct.getSIdata;
    if ~debugSLM || i==1
        [neuronsToShoot StimParams ExpStruct]=chooseStimuli(ExpStruct,i);
    else
        neuronsToShoot = randi(3);
        
    StimParams=ExpStruct.stimParams{i-1};
    end
elseif ExpStruct.doOnePhoton
     %run neurons to shoot, but set baseline trials to 0 and just start
     %with stimming
     [neuronsToShoot StimParams ExpStruct]=chooseStimuli(ExpStruct,i);
     
%disp('close loop analysis function completed.  We have stimulation parameters');
else
    debugFlag = 1;
end
if ExpStruct.doOnePhoton && i>40
    figure(1) 
perfPerStimLight = [];
perfPerStim = [];

    for j=1:length(ExpStruct.StimVoltages)
        stim = ExpStruct.StimVoltages(j);
        manLog = ExpStruct.manipulationLog; manLog(end) = [];
        lightBehOut = ExpStruct.BehaviorOutcomes(find(manLog==1));
        noLightBehOut = ExpStruct.BehaviorOutcomes(find(manLog==0));
        %change FA to be same as hit
        lightBehOut(find(lightBehOut==1))=4;
        noLightBehOut(find(noLightBehOut==1))=4;
        stimDat = [nan ExpStruct.StimulusData];
        stimDat(end) = [];
        lightStim = stimDat(find(manLog==1));
        noLightStim = stimDat(find(manLog==0));
        nhitsLight = length(find(lightBehOut(find(lightStim==stim))==4));
        totalLight = length(find(lightStim==stim));
        nhits = length(find(noLightBehOut(find(noLightStim==stim))==4));
        total = length(find(noLightStim==stim));
        if total>=1
            perfPerStim(j) = nhits/total;
        else
            perfPerStim(j) = -.1;
        end
        if totalLight>=1
            perfPerStimLight(j) = nhitsLight/totalLight;
        else
            perfPerStimLight(j) = -.1;
        end
    end  
    plot(ExpStruct.StimVoltages, perfPerStim, 'ko-'); hold on;
    plot(ExpStruct.StimVoltages, perfPerStimLight, 'ro-'); hold off;
elseif i > 10
perfPerStim = [];
    for j=1:length(ExpStruct.StimVoltages)
        stim = ExpStruct.StimVoltages(j);
        nhits = length(find(ExpStruct.BehaviorOutcomes(find(ExpStruct.StimulusData(1:end-1)==stim)+1)==4));
        total = length(find(ExpStruct.StimulusData(1:end-1)==stim));
        if total>=1
            perfPerStim(j) = nhits/total;
        else
            perfPerStim(j) = -.1;
        end
    end
    plot(ExpStruct.StimVoltages, perfPerStim,'ko-');

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


ExpStruct.stimParams{i}=StimParams;
ExpStruct.neuronsToShoot{i}=neuronsToShoot;


%if we're going to make new holograms
if ~isnan(neuronsToShoot) && ~ExpStruct.doOnePhoton;
    if isempty(ExpStruct.DE_list); %if we havent computer holograms yet.
        %new holorequest!
        if ~debugSLM
            theListofHolos=[];
            sequence = {};
            count_ensembles = 0;
            for jjv = 1:numel(ExpStruct.targetEnsembles);
                %so we have to extract n_ensembles from each ensemble and
                %add it to list of holos
                %also it should always have n_ensembles neurons
                %assert(length(ExpStruct.targetEnsembles{jjv} == ensembleSelectParams.n_ensembles));
                aseq = [];
                for i_ensemb = 1:length(ExpStruct.targetEnsembles{jjv})
                    theListofHolosA = num2str(ExpStruct.targetEnsembles{jjv}{i_ensemb}); %change to string
                    theListofHolos = [theListofHolos '[' theListofHolosA '],'];
                    count_ensembles = count_ensembles+1;
                    aseq = [aseq, count_ensembles];
                end
                sequence{jjv} = aseq;
            end
            theListofHolos(end)=[];  %delete the comma
        else debugSLM
            theListofHolos = '[1:5],[6:10],[4:8]'
        end
        %CONCERN: we don't want to adjust the sequence, because we want to
        %stay in order, since the order is meaningful
        rois=HI3Parse(theListofHolos);
        %[listOfPossibleHolos convertedSequence] = convertSequence(rois);
        
        
        holoRequest.rois     = rois;% listOfPossibleHolos;
        
        %or actually make each set its own sequence! Revolutionary.
        
        holoRequest.Sequence = sequence;%{1:length(listOfPossibleHolos)};
        
        %send new holorequest to hologram computer
        mssend(HoloSocket,holoRequest);
        
        disp('Sent New Hologram Command - waiting on DE list');
        
        while isempty(ExpStruct.DE_list);
           ExpStruct.DE_list=msrecv(HoloSocket,.5);
        end
        disp('Got DE_list, now making triggers');
        
        
    end
    
    %% Maker Stimulation Triggers
    
    %now for multi ensemble it needs to be multiple powers
    %thisTarget=holoRequest.Sequence{1}(neuronsToShoot);
    theseTargets=holoRequest.Sequence{neuronsToShoot};
    %what is this for?
    %targets=holoRequest.rois{thisTarget};
    %HAYLEY: THIS IS WHERE YOU LEFT OFF.
    n_targets_list = {holoRequest.rois{theseTargets}};
    LaserOutput=zeros(size(defaultOutputSignal,1),1);
    
    NextHoloOutput = LaserOutput; % zeros
  
    % based on next stimulus and stimulus history, make Laser EOM and holo triggers for stimulus
    if ~debugSLM
         % for j=1:numel(holoRequest.Sequence{1});
            PowerRequest = (StimParams.avgPower*numel(targets))/ ExpStruct.DE_list(thisTarget);
            Volt = function_EOMVoltage(LaserPower.EOMVoltage,LaserPower.PowerOutputTF,PowerRequest);
            LaserOutput=makepulseoutputs(StimParams.startTime,StimParams.pulseNumber,StimParams.pulseDuration,Volt,StimParams.stimFreq,20000,size(LaserOutput,1)/20000);
%             LaserOutput=LaserOutput+Q;
%             StimParams.startTime=StimParams.startTime+StimParams.unitLength;
%         end
             LaserOutput(LaserOutput==0)=eomOffset;  %apply offset
    else
        LaserOutput = makepulseoutputs(StimParams.startTime,1,300,1.5,1,20000,size(LaserOutput,1)/20000);
    end
    
    NextHoloOutput=makepulseoutputs(StimParams.startTime-50,2,10,1,1,20000,size(LaserOutput,1)/20000);
    
    disp([num2str(neuronsToShoot) ' gonna fire next trial']);
    
    OutputSignal(:,1) = LaserOutput;
    OutputSignal(:,4) =  NextHoloOutput;
    
    
    invar=[];
    while ~strcmp(invar,'C');
       invar = msrecv(HoloSocket);
    end
    disp('recieved handshake from SLM');
    
    mssend(HoloSocket, neuronsToShoot);
elseif  ~isnan(neuronsToShoot) && ExpStruct.doOnePhoton;
    LaserOutput=zeros(size(defaultOutputSignal,1),1);
    Volt = ExpStruct.onePhotonVolt;
    LaserOutput=makepulseoutputs(StimParams.startTime,StimParams.pulseNumber,StimParams.pulseDuration,Volt,StimParams.stimFreq,20000,size(LaserOutput,1)/20000);
    OutputSignal(:,1) = LaserOutput;
    disp('going to one-photon stim');
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
