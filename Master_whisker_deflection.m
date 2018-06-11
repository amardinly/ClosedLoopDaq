clear all; close all force; clc;
rmpath(genpath('C:\Users\MOM2\Documents\MATLAB\'));
rmpath(genpath('C:\Users\MOM2\Documents\MATLAB\'));
addpath(genpath('C:\Users\MOM2\Documents\GitHub\msocket'));
addpath(genpath('C:\Users\MOM2\Documents\GitHub\ClosedLoopDaq\'));

useSockets = 0;

%using matlab data acquisition toolbox, set up daq and connection
s = daq.createSession('ni'); %ni is company name
addAnalogInputChannel(s,'Dev3',0,'Voltage');                    %LASER EOM
addAnalogOutputChannel(s,'Dev3',2,'Voltage');                    %LASER EOM
addTriggerConnection(s,'External','Dev3/PFI4','StartTrigger');  %trigger connection from Arduino 
addDigitalChannel(s,'Dev3','Port0/Line0:5','OutputOnly');  

s.Rate=20000;
s.ExternalTriggerTimeout=3000; %basically never time out

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
[ ExperimentName ] = autoExptname1(savePath);
%%


%initialize UDP camera trigger
try; echoudp('on',55000); catch; disp('error initializing UDP - if already running, ignore');  end;
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
% connect to arduino
ard=serial('COM7','BaudRate',9600);
fopen(ard);
readData=fscanf(ard) %reads "A"
flushinput(ard);fprintf(ard,'%s\n','fff','sync');
fprintf(ard,'%s\n','1','sync');readData=fscanf(ard)

while  i>0; %run forever
disp(['waiting for trigger to start trial ' num2str(i)]);    

queueOutputData(s,outputSignal);  %get ready to run a sweep

dataIn = s.startForeground;   %run a sweep

ExpStruct.outputs{i} = downsample(outputSignal,10); 

[ExpStruct outputSignal] = closeLoopMaster(dataIn,ExpStruct,myUDP,HoloSocket,defaultOutputSignal,eomOffset,i);

displayTriggers(outputSignal,i);

save([savePath ExperimentName],'ExpStruct');
disp('saved!');
%send ready to go trigger back to arduino
sendReadyTrigger(k,25);

i = i + 1;  %incriment trial number

end
