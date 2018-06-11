function displayTriggers(outputSignal,i);
t=size(outputSignal,1);
t2 =[1:t]/20000;

% title(['Sweep ' num2str(i)]);
figure(1);
subplot(5,1,1)
plot(t2,outputSignal(:,1),'r');
title('Laser EOM')

subplot(5,1,2)
plot(t2,outputSignal(:,2),'m');
title('SI Trigger')

subplot(5,1,3)
plot(t2,outputSignal(:,4),'g');
title('Holo Trigger')

subplot(5,1,4)
plot(t2,outputSignal(:,5),'c');
title('Next Sequence Trigger')

subplot(5,1,5)
plot(t2,outputSignal(:,7),'y');
title('Camera')
xlabel('seconds')