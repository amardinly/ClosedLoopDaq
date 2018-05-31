function displayTriggers(outputSignal,i);
t=size(outputSignal,1);
t2 =[1:t]/20000;


figure(1);
title(['Sweep ' num2str(i)]);
subplot(5,1,1)
plot(t2,outputSignal(:,1),'r');
subplot(5,1,2)
plot(t2,outputSignal(:,2),'m');
subplot(5,1,3)
plot(t2,outputSignal(:,4),'g');
subplot(5,1,4)
plot(t2,outputSignal(:,5),'c');
subplot(5,1,5)
plot(t2,outputSignal(:,7),'y');
