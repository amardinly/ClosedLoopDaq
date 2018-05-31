function functionCustomHoloRequest(theListofHolos);
persistent init loc holoRequest
theListofHolos = num2str(theListofHolos);

%load HoloRequest once, on the first  run
if isempty(init);
    loc=FrankenScopeRigFile;
    load([loc.HoloRequest 'holoRequest.mat'],'holoRequest');
    init = 1;
end

%change the rois and sequence (all other data should be the same(
%locations, etch)
rois=HI3Parse(theListofHolos);
[listOfPossibleHolos convertedSequence] = convertSequence(rois);
holoRequest.rois=listOfPossibleHolos;
holoRequest.Sequence = {convertedSequence};

%save to server
save([loc.HoloRequest 'holoRequest.mat'],'holoRequest');
save([loc.HoloRequest_DAQ 'holoRequest.mat'],'holoRequest');