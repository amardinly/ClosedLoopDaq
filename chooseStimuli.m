function [neuronsToShoot StimParamsOut ExpStruct]=chooseStimuli(ExpStruct,i);
%% initialize persistent variables
persistent StimParams baselineTrials pcnt_manipulation makeBlankStim targetEnsemble;


%if this is the first run, define all persistent as blanik
if i == 1;
    StimParams=[];
    baselineTrials=[];
    pcnt_manipulation=[];
    makeBlankStim=[];
    targetEnsemble=[];
end


%load default settings
if isempty(StimParams);  %on first run...
    
    %if we defined targeting defaults, load them, if not use function
    %defaults
    if ~isfield(ExpStruct,'targeting_Defaults');
        %load defaults
        baselineTrials = 50;
        pcnt_manipulation = 30;
    else  %
        baselineTrials = ExpStruct.targeting_Defaults.baseLineSweeps;
        pcnt_manipulation = ExpStruct.targeting_Defaults.pcnt_manipulation;
    end
        
    %if we gave the exp stimparams, use them, else use defualts
    if ~isfield(ExpStruct,'StimParams');
        StimParams.pulseDuration=100; %ms
        StimParams.stimFreq=1; %hz
        StimParams.avgPower = .05; %W  0.05 0.1 0.15 0.2
        StimParams.unitLength=200; %ms
        StimParams.startTime=100; %ms;
        StimParams.pulseNumber=1 ;%10 18       
    else
        %load information passed in from setup
   
        
        StimParams.pulseDuration=ExpStruct.StimParams.pulseDuration; %ms
        StimParams.stimFreq=ExpStruct.StimParams.stimFreq; %hz
        StimParams.avgPower=ExpStruct.StimParams.avgPower; %W  0.05 0.1 0.15 0.2
        StimParams.unitLength=ExpStruct.StimParams.unitLength; %ms
        StimParams.startTime=ExpStruct.StimParams.startTime; %ms;
        StimParams.pulseNumber= ExpStruct.StimParams.pulseNumber ;%10 18
        
    end
    
    %make output triggers to not stimulate anything so we dont accidentally
    %zap cells
    makeBlankStim.pulseDuration=0; %ms
    makeBlankStim.stimFreq=0; %hz
    makeBlankStim.avgPower = 0; %W  0.05 0.1 0.15 0.2
    makeBlankStim.unitLength=0; %ms
    makeBlankStim.startTime=100; %ms;
    makeBlankStim.pulseNumber=0 ;%10 18
    
    targetEnsemble = nan;
    
end

%%  Check if we're in baseline period
%if the next trial is still during baseline, then just return and get more data!
if i + 1 <= baselineTrials;
    
    %if we're in baseline, we dont stimulate, we stimulate nan neurons, and
    %we output no laser power
    neuronsToShoot = nan;
    ExpStruct.manipulationLog(i+1) = 0;
    StimParamsOut=makeBlankStim;
    
    %if we are OUT of baseline period, we check to see if the target
    %ensemble is still a nan.  if it's not a cell, we run this code, which
    %will define the target ensembles;
    
elseif ~iscell(targetEnsemble);   %if we're done with baseline but we haven't defined a target ensemble yet....best do that
    [targetEnsemble AUC] = chooseTargetEnsemble(ExpStruct);   %run the function that determinens ther neurons to shoot
    ExpStruct.AUC = AUC;  %save the online AUC calculation
    ExpStruct.targetEnsembles = targetEnsemble;  %save the target ensembles
end
%% decide if we're shooting this trial
if i + 1 > baselineTrials;  %if we're out of the basleine period

    %I think I fixed the off by one error here.  Difficulty is that stimulus
    %data is telling me whats happening on the NEXT
    nextStimValue = ExpStruct.StimulusData(i);  %get stim value for nex trial
    
    stimsSoFar =  ExpStruct.StimulusData; %get all previous stims
    stimsSoFar = [nan stimsSoFar]; %justify so trial indexes match (recall, this previously referred to stim on trial i + 1;
    stimsSoFar(end) = [];
    
    stimsOfThisValue=find(stimsSoFar==nextStimValue);  %find all the preivous stims of this value
    stimsOfThisValue(stimsOfThisValue<baselineTrials)=[]; %dont considere the baseline period
    
    % find how many whisker stims after baseline
    % have been stimmed for each opto condition
    for jjj = 1:numel((ExpStruct.ensembleSelectParams.stimFlag))   %for each ensemble we're stimulating
    
    manip = ExpStruct.manipulationLog(stimsOfThisValue);   %find the manipulation log values for trials of thiswhisker stim type       
    numberOfStims(jjj)=numel(find(manip==jjj));            %find the number of them that equal the current index
    
    
    end
    
    fractionOpto = numberOfStims / numel(stimsOfThisValue);%calculate the fraction of the post-baseline period trials have been
    fractionOpto = fractionOpto *100;
    
    
    %this commeneted code stimulates ensembles if above threshold and not
    %if below threshold
    
    %produced highly undesirble 'clumpy' behaevior where we stimulated in
    %bursts instead of sporadically throughout experiment
     
    %if we've stimulated on too many trials, dont stimulate!
%     if min(fractionOpto) >= pcnt_manipulation || any(isnan(fractionOpto));
%         neuronsToShoot = nan;
%         ExpStruct.manipulationLog(i+1) = 0;
%         StimParamsOut=makeBlankStim;
%         
%     else %otherwise - shoot!
%         
%         FO = (fractionOpto < pcnt_manipulation);
%         ensemblesNeedStimming = find(FO);
%         
%         if numel(ensemblesNeedStimming)==1;
%             ExpStruct.manipulationLog(i+1)=ensemblesNeedStimming;
%             neuronsToShoot=ensemblesNeedStimming;
%             StimParamsOut=StimParams;
%         else
%             
%             stimThisOne = randi([min(ensemblesNeedStimming) max(ensemblesNeedStimming)]);
%             ExpStruct.manipulationLog(i+1)=stimThisOne;
%             neuronsToShoot=stimThisOne;
%             StimParamsOut=StimParams;
%             
%             
%         end
%     end
%     

% Try randomization to smooth out manipulatino

    if min(fractionOpto) >= pcnt_manipulation || any(isnan(fractionOpto)); %all trial types have been stimulation more than the right % of time
        shoot = randi(10)<2;  %10% chance of stim
    else
        shoot = randi(10)>2;  %otherwise 80% chance of stim
    end
    
    if ~shoot;  %if we arent stimulating, set everything to zero
        neuronsToShoot = nan;
        ExpStruct.manipulationLog(i+1) = 0;
        StimParamsOut=makeBlankStim;       
    else %if we sare stimulating, choose an ensemble!
        
        
        FO = (fractionOpto < pcnt_manipulation);   
        ensemblesNeedStimming = find(FO);
        
        if numel(ensemblesNeedStimming)==1;  %if only one ensemble is undersampled, stim it
            ExpStruct.manipulationLog(i+1)=ensemblesNeedStimming;
            neuronsToShoot=ensemblesNeedStimming;
            StimParamsOut=StimParams;
        else   %otherwise choose one ensemble out of the ones needed stimming        
            try
            stimThisOne = randi([min(ensemblesNeedStimming) max(ensemblesNeedStimming)]);
            catch
            stimThisOne=randi([numel((ExpStruct.ensembleSelectParams.stimFlag))]);
            end
            ExpStruct.manipulationLog(i+1)=stimThisOne;
            neuronsToShoot=stimThisOne;
            StimParamsOut=StimParams;
        end
    end
   
else
    neuronsToShoot = nan;
    ExpStruct.manipulationLog(i+1) = 0;
    StimParamsOut=makeBlankStim;
end



%key for reading behavior outcome:
%1: FALSE ALARM
%2: MISS
%3: CORRECT REJECT
%4: HIT







function [targetEnsemble AUC] = chooseTargetEnsemble(ExpStruct);

% look for ensemble Select Params...if not there load defaults    
if ~isfield(ExpStruct,'ensembleSelectParams');
    flag = 'stim';
    threshold = .80;
    minthreshold = .35;

    maxCells = 40;
    sensitivity = 'max';
else
    %if they are there, load them....
    sensitivity=ExpStruct.ensembleSelectParams.sensitivity;
    flag=ExpStruct.ensembleSelectParams.stimFlag;
    threshold=ExpStruct.ensembleSelectParams.threshold;
    maxCells=ExpStruct.ensembleSelectParams.maxCells;  
    minthreshold=ExpStruct.ensembleSelectParams.minthreshold;
end

%adjust stim data to equal dff
stimData=[nan ExpStruct.StimulusData];
stimData(end)=[];

clear AUC;  %just in case

A=unique(stimData); %
B=sort(A);         %sort stim data in qunieu roder


switch sensitivity; 
    case 'max'
    %choose neurons that best discriminate between max stimulus and 0
    goTrials  = find(stimData == max(stimData));
    case 'min'
    %choose neurons that best discriminate between min stimulus and zero
    goTrials  = find(stimData == B(2));
    
    case 'mid'
    %choose neurons that best discriminate between a min stimulus and zero
    goTrials  = find(stimData == B(round(numel(B))/2));
   
        
end


%look for trials where stimw as 0
catchTrails = find(stimData == 0);

tic;
for n=1:size(ExpStruct.dFF,2);  %for each cell
    clear DVn DVg nogoCa goCa 
    goCa = ExpStruct.dFF(goTrials,n);   %load the DFF response to go tgrials
    nogoCa = ExpStruct.dFF(catchTrails,n); %load the DFF resposne to catch trials
    for g = 1:numel(goCa);  %for each go trial
        goCopy = goCa;      %make a copy of all go trials
        goCopy(g)=[];       %delete current trails
        DVg(g) = goCa(g) .* (nanmean(goCopy)-nanmean(nogoCa)); %computer decision variable
    end
    
    %same for nogo trials
    for g = 1:numel(nogoCa);
        nogoCopy = nogoCa;
        nogoCopy(g)=[];
        DVn(g) = nogoCa(g) .* (nanmean(goCa)-nanmean(nogoCa));
    end
    
    %get min max and number of itnerations for criterai calciulation
    Cmin = min([DVn DVg]);
    Cmax = max([DVn DVg]);
    CritIter = 25;
    
    CritVar = linspace(Cmin,Cmax,CritIter);
    %for each Criteria Var compute Prob of being greater than that var for
    %each trial type
    for c = 1:numel(CritVar);
        go(c)= mean(DVn>CritVar(c));
        nogo(c) = mean(DVg>CritVar(c));
    end
    %compute AUC
    AUC(n)=1-abs(trapz(nogo,go));
    
    
end

%sort AUC to get the ranked indexes and compute each ensemble
[trash AUCIndx] = sort(AUC,'descend');
flag = ExpStruct.ensembleSelectParams.stimFlag
for flagIdx = 1:numel(flag)
    aflag = flag{flagIdx};
    switch aflag
        case 'stim'
              aTargetEnsemble = AUCIndx(1:maxCells);
              aTargetEnsemble(AUC(aTargetEnsemble)<threshold)=[];
    %         aTargetEnsemble = find(AUC>=prctile(AUC,threshold));
         case 'catch'
    %         aTargetEnsemble = find(AUC<=prctile(AUC,100-threshold));
              aTargetEnsemble = AUCIndx(end-maxCells:end);
              aTargetEnsemble(AUC(aTargetEnsemble)>minthreshold)=[];
         case 'nonSelective'
              AA=abs(AUC-.5);
              [AA sortIndx]=sort(AA,'ascend');
              aTargetEnsemble = sortIndx(1:maxCells);
              aTargetEnsemble(AUC(aTargetEnsemble)>.6)=[];
              aTargetEnsemble(AUC(aTargetEnsemble)<.4)=[];
    %         aTargetEnsemble = intersect(find(AUC>=prctile(AUC,45)),find(AUC<=prctile(AUC,55)));
    end

   targetEnsemble{flagIdx} = aTargetEnsemble;
end


