clear
clc
load('X:\holography\Data\Alan\180622_C.mat')
ExpStruct2 =[];

ExpStruct2.ensembleSelectParams.stimFlag ={'stim','nonSelective'}; %'catch'
ExpStruct2.ensembleSelectParams.threshold=.8;
ExpStruct2.ensembleSelectParams.minthreshold=.35;
ExpStruct2.ensembleSelectParams.maxCells=40;
ExpStruct2.ensembleSelectParams.sensitivity='max';  %'min','mid
ExpStruct2.targeting_Defaults.pcnt_manipulation=15;  %PCNT OF ALL TRIALS FOR EACH ENSEMBLE (e.g. 30% x 3 ensembles = OPTO 90% of the time!)
ExpStruct2.targeting_Defaults.baseLineSweeps=50;  %PCNT OF ALL TRIALS FOR EACH ENSEMBLE (e.g. 30% x 3 ensembles = OPTO 90% of the time!)

OS = function_load_default_Trigger(-.15);
for i = 1:500;
    ExpStruct2 = postHocTest(ExpStruct,ExpStruct2,OS,i);
end
plot(ExpStruct2.manipulationLog)

