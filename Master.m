clear all; close all force; clc;

ExpStruct.doOnePhoton = 1;
ExpStruct.modifiedPeterson = 1;
useSockets = 0;
ExpStruct.getSIdata =0;
ExpStruct.StimVoltages = [0,100,138,175,213,250];

%the ensembles that we're going to stimulate
ExpStruct.ensembleSelectParams.stimFlag ={'stim'}; %'stim' 'catch' 'nonSelective'
ExpStruct.ensembleSelectParams.threshold=.3; %this is for stim selective neurons, must be greater than this
ExpStruct.ensembleSelectParams.minthreshold=.35; %this is for catch selective, must be less than this
ExpStruct.ensembleSelectParams.max_ensemble_stim = 1; %whether or not to just shoot as many neurons as we can
ExpStruct.ensembleSelectParams.n_ensembles = 4; %if doing max ensemble stim, how many ensembles to pick


ExpStruct.DE_list = [];  %reset DE list

ExpStruct.ensembleSelectParams.maxCells=40;
ExpStruct.ensembleSelectParams.sensitivity='max';  %'min','mid','max','mix'

ExpStruct.targeting_Defaults.baseLineSweeps=50;  %sweeps we run before defining ensembles
ExpStruct.targeting_Defaults.pcnt_manipulation=80;  %PCNT OF ALL TRIALS FOR EACH ENSEMBLE (e.g. 30% x 3 ensembles = OPTO 90% of the time!)

ExpStruct.StimParams.pulseDuration= 8; %ms
ExpStruct.StimParams.stimFreq= 30; %hz
ExpStruct.StimParams.avgPower = .1; %W  0.05 0.1 0.15 0.2
ExpStruct.StimParams.unitLength= 140; %ms
ExpStruct.StimParams.startTime=80; %ms;
ExpStruct.StimParams.pulseNumber=3 ;%   10 18       

%set some things we'll want if doing one photon
if ExpStruct.doOnePhoton
    ExpStruct.onePhotonVolt = 5;
    ExpStruct.targeting_Defaults.baseLineSweeps =25;
    ExpStruct.ensembleSelectParams.stimFlag ={'stim'};
end
ExpStruct.mouseID = input('please enter mouse ID: ','s');
ExpStruct.notes = input('please enter relevant info: ' ,'s');


rmpath(genpath('C:\Users\MOM2\Documents\MATLAB\'));
rmpath(genpath('C:\Users\MOM2\Documents\GitHub\'));
addpath(genpath('C:\Users\MOM2\Documents\GitHub\msocket'));
addpath(genpath('C:\Users\MOM2\Documents\GitHub\ClosedLoopDaq\'));


%using matlab data acquisition toolbox, set up daq and connection
s = daq.createSession('ni'); %ni is company name
addAnalogInputChannel(s,'Dev3',0,'Voltage');
if ExpStruct.doOnePhoton
    addAnalogOutputChannel(s,'Dev3',1,'Voltage');                     %LED
else
    addAnalogOutputChannel(s,'Dev3',2,'Voltage');                    %LASER EOM
end
addTriggerConnection(s,'External','Dev3/PFI4','StartTrigger');  %trigger connection from Arduino 
addDigitalChannel(s,'Dev3','Port0/Line0','OutputOnly');  
%for now add a placeholder meaningless channel to make numbers match up
addAnalogOutputChannel(s,'Dev3',3,'Voltage');                 

addDigitalChannel(s,'Dev3','Port0/Line2:5','OutputOnly');  
addDigitalChannel(s,'Dev3','port0/line6','InputOnly');  
addDigitalChannel(s,'Dev3','port0/line1','InputOnly');  


s.Rate=20000;
s.ExternalTriggerTimeout=30000000; %basically never time out

%setup readytogo trigger
k = daq.createSession('ni');
addDigitalChannel(k,'Dev3','Port1/Line3','OutputOnly');  

%% initialized vars
eomOffset = -0.15; 
i = 1; %formerly sweep number
defaultOutputSignal=function_load_default_Trigger(eomOffset);
outputSignal = defaultOutputSignal;  %initial output to defaults
ExpStruct.dFF=[];
savePath = 'C:\alan\';
[ ExperimentName ] = autoExptname1(savePath, ExpStruct.mouseID);
%%


%initialize UDP camera trigger
try; echoudp('on',55000); catch; disp('error initializing UDP - if already running, ignore');  end;
try; fclose(myUDP); end;
myUDP = udp('128.32.173.99',55000);
fopen(myUDP);


if useSockets
%initialize socket connection with the holography computer
disp('establishing socket connection');
disp('run closeLoopHoloRequest on holo computer to establish comms');
srvsock = mslisten(3002);   
HoloSocket = msaccept(srvsock);   
msclose(srvsock);           

sendVar= 'A';
mssend(HoloSocket,sendVar)

invar=[];
while ~strcmp(invar,'B');
    invar=msrecv(HoloSocket);
end
disp('input from hologram computer validated');

else
    HoloSocket = [];

end

%% Run DAQ
while  i>0; %run forever
fprintf(['waiting for trigger to start trial ' num2str(i) '.....']);    

queueOutputData(s,outputSignal);  %get ready to run a sweep

dataIn = s.startForeground;   %run a sweep
fprintf('sweep completed \n');
ExpStruct.outputs{i} = downsample(outputSignal,10); 

[ExpStruct outputSignal] = closeLoopMaster(dataIn,ExpStruct,myUDP,HoloSocket,defaultOutputSignal,eomOffset,i);

% displayTriggers(outputSignal,i);

save([savePath ExperimentName],'ExpStruct');

% disp('saved!');
%send ready to go trigger back to arduino
sendReadyTrigger(k,.06);

i = i + 1;  %incriment trial number

end
