clear all; close all force; clc;
%using matlab data acquisition toolbox, set up daq and connection
s = daq.createSession('ni'); %ni is company name
addAnalogInputChannel(s,'Dev3',0,'Voltage');                    %LASER EOM
addAnalogOutputChannel(s,'Dev3',2,'Voltage');                    %LASER EOM
addTriggerConnection(s,'External','Dev3/PFI4','StartTrigger');  %trigger connection from Arduino 
addDigitalChannel(s,'Dev3','Port0/Line0:5','OutputOnly');  

s.Rate=20000;
s.ExternalTriggerTimeout=3000; %basically never time out

%% StartUp Code
i = 1;
%Q: Does this mean its always the same laser triggers and such?
defaultOutputSignal=function_load_default_Trigger();
outputSignal = defaultOutputSignal;  %initial output to defaults
ExpStruct.dFF=[];
%initialize UDP camera trigger
echoudp('on',55000);
myUDP = udp('128.32.173.99',55000);
fopen(myUDP);

savePath = 'C:\alan\';
[ ExperimentName ] = autoExptname1(savePath);

%% Run DAQ
while  sweepNumber>0;
disp(['waiting for trigger to start trial ' num2str(i)]);    
queueOutputData(s,outputSignal);  %get ready to run a sweep
dataIn = startForeground(s);      %run a sweep when triggered
ExpStruct.outputs{i} = downsample(outputSignal,10); 
[ExpStruct outputSignal] = closeLoopMaster(dataIn,ExpStruct,myUDP,defaultOutputSignal,i);
displayTriggers(outputSignal,i);
save([savePath ExperimentName],'ExpStruct');
i = i + 1;  %incriment trial number
end
