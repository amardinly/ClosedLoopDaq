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
disp('UDP signal sent to camera');

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
disp(['next trial the stim will be ' num2str(nextTrialStimData)]);

ExpStruct.dataIn{i}=dataIn;
%% science happens here
if ExpStruct.getSIdata;
    if ~debugSLM || i==1
[neuronsToShoot StimParams ExpStruct]=chooseStimuli(ExpStruct,i);
    else
        neuronsToShoot = randi(3);
        
    StimParams=ExpStruct.stimParams{i-1};
    end
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
    if isempty(ExpStruct.DE_list); %if we havent computer holograms yet.
        %new holorequest!
        if ~debugSLM
            theListofHolos=[];
            for jjv = 1:numel(ExpStruct.targetEnsembles);

                theListofHolosA = num2str(ExpStruct.targetEnsembles{jjv}); %change to string
                theListofHolos = [theListofHolos '[' theListofHolosA '],'];


            end
            theListofHolos(end)=[];  %delete the comma
        else debugSLM
            theListofHolos = '[1:5],[6:10],[4:8]'
        end
        rois=HI3Parse(theListofHolos);
        [listOfPossibleHolos convertedSequence] = convertSequence(rois);
        
        
        holoRequest.rois     =  listOfPossibleHolos;
        holoRequest.Sequence = {convertedSequence};
        
        %send new holorequest to hologram computer
        mssend(HoloSocket,holoRequest);
        
        disp('Sent New Hologram Command - waiting on DE list');
        
        while isempty(ExpStruct.DE_list);
           ExpStruct.DE_list=msrecv(HoloSocket);
        end
        disp('Got DE_list, now making triggers');
        
        
    end
    
    %% Maker Stimulation Triggers
    
    thisTarget=holoRequest.Sequence{1}(neuronsToShoot);
        
    targets=holoRequest.rois{thisTarget};
    
    LaserOutput=zeros(size(defaultOutputSignal,1),1);
    
    NextHoloOutput = LaserOutput; % zeros
  
    % based on next stimulus and stimulus history, make Laser EOM and holo triggers for stimulus
    if ~debugSLM
%         for j=1:numel(holoRequest.Sequence{1});
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
    disp('recieved handshake from SLM ');
    
    mssend(HoloSocket, neuronsToShoot);
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
