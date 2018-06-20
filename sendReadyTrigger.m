function sendReadyTrigger(s,p_sec);


outputSingleScan(s,[1])
pause(p_sec);
outputSingleScan(s,[0])
