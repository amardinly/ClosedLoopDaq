function [ExpStruct2 OutputSignal neuronsToShoot] = postHocTest(ExpStruct,ExpStruct2,OS,i);
%% Close Loop master function
persistent holoRequest LaserPower
tic

debugFlag = 0;
OutputSignal=OS;

%load HoloRequest once, on the first  run
if isempty(holoRequest);
    loc=FrankenScopeRigFile;
    load(['/mnt/inhibition/holography/FrankenRig/HoloRequest/holoRequest.mat'],'holoRequest');
    load('/mnt/inhibition/holography/FrankenRig/Calibration Parameters/20X_Objective_Calibration_LaserPower.mat','LaserPower');
end

ExpStruct2.dFF(i,:)=ExpStruct.dFF(i,:);

ExpStruct2.StimulusData(i) = ExpStruct.StimulusData(i) ;

ExpStruct2.BehaviorOutcomes(i) = ExpStruct.BehaviorOutcomes(i);
ExpStruct2.dataIn{i}=ExpStruct.dataIn{i};

%% science happens here
 [neuronsToShoot StimParams ExpStruct2]=chooseStimuli(ExpStruct2,i);
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

ExpStruct2.stimParams{i}=StimParams;
ExpStruct2.neuronsToShoot{i}=neuronsToShoot;


%if we're going to make new holograms
if ~isnan(neuronsToShoot);
    %remove DE
    DE_list = ones(size(neuronsToShoot));  %reset DE list
    
    %new holorequest!
    theListofHolos = num2str(neuronsToShoot); %change to string
    theListofHolos = ['[' theListofHolos ']'];
    rois=HI3Parse(theListofHolos);
    [listOfPossibleHolos convertedSequence] = convertSequence(rois);
    
    holoRequest.rois     =  listOfPossibleHolos;
    holoRequest.Sequence = {convertedSequence};
    
    %send new holorequest to hologram computer
%     mssend(HoloSocket,holoRequest);
    
    disp('Sent New Hologram Command - waiting on DE list');
    
%     while isempty(DE_list);
%         DE_list=msrecv(HoloSocket);
%     end
    disp('Got DE_list, now making triggers');
    
    
    
    
    %% Maker Stimulation Triggers
    
    thisTarget=holoRequest.Sequence{1}(1);
    targets=holoRequest.rois{thisTarget};
    LaserOutput=zeros(size(OS,1),1);
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
    
    LaserOutput(LaserOutput==0)=-.15;  %apply offset
    OutputSignal(:,1) = LaserOutput;
    OutputSignal(:,4) =  NextHoloOutput;
else
    %if neuronstoShoot is nan, send nothing on the stim laser
    LaserOutput=zeros(size(OS,1),1);
    LaserOutput(LaserOutput==0)=-.15;  %apply offset
    OutputSignal(:,1) = LaserOutput;

end

toc
fprintf('\n')
fprintf('\n')
fprintf('\n')

end
