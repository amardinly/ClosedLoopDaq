function [neuronsToShoot StimParamsOut ExpStruct]=chooseStimuli(ExpStruct,i);
%% initialize persistent variables 

persistent StimParams baselineTrials pcnt_manipulation makeBlankStim targetEnsemble;

%load default settings
if isempty(StimParams);  %on first run...   
    if ~isfield(ExpStruct,'targeting_Defaults');       
        %load defaults
        baselineTrials = 50;
        pcnt_manipulation = 30;
        
        StimParams.pulseDuration=100; %ms
        StimParams.stimFreq=1; %hz
        StimParams.avgPower = .05; %W  0.05 0.1 0.15 0.2
        StimParams.unitLength=200; %ms
        StimParams.startTime=100; %ms;
        StimParams.pulseNumber=1 ;%10 18

    else

        %load information passed in from setup
        baselineTrials = ExpStruct.targeting_Defaults;
        pcnt_manipulation = ExpStruct.pcnt_manipulation;        
        StimParams.pulseDuration=ExpStruct.StimParams.pulseDuration; %ms
        StimParams.stimFreq=ExpStruct.StimParams.stimFreq; %hz
        StimParams.avgPower=ExpStruct.StimParams.avgPower; %W  0.05 0.1 0.15 0.2
        StimParams.unitLength=ExpStruct.StimParams.unitLength; %ms
        StimParams.startTime=ExpStruct.StimParams.startTime; %ms;
        StimParams.pulseNumber= ExpStruct.StimParams.pulseNumber ;%10 18
    
    end
   
        %make output triggers to not stimulate anything
        makeBlankStim.pulseDuration=0; %ms
        makeBlankStim.stimFreq=0; %hz
        makeBlankStim.avgPower = 0; %W  0.05 0.1 0.15 0.2
        makeBlankStim.unitLength=0; %ms
        makeBlankStim.startTime=100; %ms;
        makeBlankStim.pulseNumber=0 ;%10 18
        
        targetEnsemble = nan;
    
end

%%  Check if we're in baseline 
%if the next trial is still during baseline, then just return and get more data!
if i + 1 <= baselineTrials;

    neuronsToShoot = nan;
    ExpStruct.manipulationLog(i+1) = 0;
    StimParamsOut=makeBlankStim;

elseif isnan(targetEnsemble);   %if we're done with baseline but we haven't defined a target ensemble yet....best do that

   targetEnsemble = chooseTargetEnsemble(ExpStruct);   %run the function that determinens ther neurons to shoot

end





%% decide if we're shooting this trial

%I think I fixed the off by one error here.  Difficulty is that stimulus
%data is telling me whats happening on the NEXT 
nextStimValue = ExpStruct.StimulusData(i);
stimsOfThisValue=find(ExpStruct.StimulusData==nextStimValue);
stimsOfThisValue(end)=[];  %dont consider next trial, since i havent decided to stim or not yet.
fractionOpto =  mean(ExpStruct.manipulationLog(stimsOfThisValue+1));

%if we've stimulated on too many trials, dont stimulate!
if fractionOpto >= pcnt_manipulation;
    neuronsToShoot = nan;
    ExpStruct.manipulationLog(i+1) = 0;
    StimParamsOut=makeBlankStim;

else %otherwise - shoot!    
    ExpStruct.manipulationLog(i+1) = 1;
    StimParamsOut=   StimParams;
    neuronsToShoot = targetEnsemble;
end





%key for reading behavior outcome:
%1: FALSE ALARM
%2: MISS
%3: CORRECT REJECT
%4: HIT



function targetEnsemble = chooseTargetEnsemble(ExpStruct,threshold,flag);
if nargin<3;
    flag = 'stim';
elseif nargin<2;
    flag = 'stim';
    threshold = 90;
end



%adjust stim data to equal dff 
stimData=[nan ExpStruct.StimulusData];
stimData(end)=[];

clear AUC;
goTrials  = find(stimData == V(T)); 
catchTrails = find(stimData == 0);

tic;
for n=1:size(ExpStruct.dFF,2);
        clear DVn DVg nogoCa goCa
        goCa = ExpStruct.dFF(goTrials,n);
        nogoCa = ExpStruct.dFF(catchTrails,n);
        for g = 1:numel(goCa);
            goCopy = goCa;
            goCopy(g)=[];
            DVg(g) = goCa(g) .* (nanmean(goCopy)-nanmean(nogoCa));
        end
        
        for g = 1:numel(nogoCa);
            nogoCopy = nogoCa;
            nogoCopy(g)=[];
            DVn(g) = nogoCa(g) .* (nanmean(goCa)-nanmean(nogoCa));
        end
            
        Cmin = min([DVn DVg]);
        Cmax = max([DVn DVg]);
        CritIter = 25;

        CritVar = linspace(Cmin,Cmax,CritIter);

        for c = 1:numel(CritVar);
        go(c)= mean(DVn>CritVar(c));
        nogo(c) = mean(DVg>CritVar(c));
        end

        AUC(n)=1-abs(trapz(nogo,go));
    

end

switch flag
    case 'stim'
    targetEnsemble = find(AUC>=prctile(AUC,threshold));
    case 'catch'
    targetEnsemble = find(AUC<=prctile(AUC,100-threshold));
    case 'neutral'
    targetEnsemble = intersect(find(AUC>=prctile(AUC,45)),find(AUC<=prctile(AUC,55)));

end
        


