%so I want it to just give me as many neurons as possible out of choose
%stimuli.

%then say max neurons per ensemble = 40.

n_neurons = numel(holoRequest.rois);
%I can do up to 4 ensembles
max_per_holo=40;
n_ensembles = 4;
if n_neurons/max_per_holo < n_ensembles
    n_per_holo = floor(n_neurons/n_ensembles);
    ensembles = [];
    for i=0:(n_ensembles-1)
        ensembles = [ensembles '[' num2str(n_per_holo*i+1) ':' ...
            num2str(n_per_holo*(i+1)) '],'];
    end
else
    n_per_holo = max_per_holo;
    ensembles = []
    for i=1:(n_ensembles-1)
        ensembles = [ensembles '[' num2str(n_per_holo*i+1) ':' ...
            num2str(n_per_holo*(i+1)) '],'];
    end
end

%then 