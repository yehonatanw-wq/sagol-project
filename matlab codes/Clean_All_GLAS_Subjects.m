% =========================================================================
% Automated EEGLAB Pipeline for P600 Analysis - GLAS LAB (Final)
% =========================================================================
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

input_dir  = 'C:\Users\wechs\OneDrive\المستندات\sagol project\newland etal OSF\Raw data\GLAS';    % שנה לנתיב האמיתי
output_dir = 'C:\Users\wechs\OneDrive\المستندات\sagol project\proccessed data - cleansed files\GLAS clean';  % שנה לנתיב האמיתי

files = dir(fullfile(input_dir, '*.bdf'));

for i = 1:length(files)
    
    filename = files(i).name;
    [~, sub_name, ~] = fileparts(filename); 
    
    fprintf('\n=======================================================\n');
    fprintf('Processing Subject: %s (%d out of %d)\n', sub_name, i, length(files));
    fprintf('=======================================================\n');
    
    expected_file = fullfile(output_dir, [sub_name '_cleaned.set']);
    if isfile(expected_file)
        fprintf('\n[Skipping] %s is already cleaned.\n', sub_name);
        continue; 
    end
    
    try 
        EEG = pop_biosig(fullfile(input_dir, filename));
        
        for e = 1:length(EEG.event)
            if isnumeric(EEG.event(e).type)
                EEG.event(e).type = num2str(EEG.event(e).type);
            end
        end
        
        EEG = pop_resample(EEG, 250);
        
        % הרפרנס התקין למסטואידים ב-BioSemi (ולא לעיניים!)
        EEG = pop_reref(EEG, {'EXG5','EXG6'});
        
        % מילון התרגום המדויק ל-24 האלקטרודות שאנחנו צריכים
        chan_map = { ...
            'A1', 'Cz'; 'A3', 'C3'; 'B2', 'C4'; 'A19', 'Pz'; 'A21', 'P3'; ...
            'B19', 'P4'; 'A23', 'P7'; 'B21', 'P8'; 'A17', 'CP1'; 'B16', 'CP2'; ...
            'A27', 'O1'; 'B27', 'O2'; 'C22', 'Fp1'; 'C24', 'Fp2'; 'C21', 'Fz'; ...
            'C13', 'F7'; 'D13', 'F8'; 'C11', 'F3'; 'D11', 'F4'; ...
            'A7', 'CP5'; 'B6', 'CP6'; 'A5', 'T7'; 'B4', 'T8'; 'A32', 'Oz' ...
        };
        
        % חיתוך דרמטי: שומרים *אך ורק* את 24 האלקטרודות הללו לפי שמן המקורי
        EEG = pop_select(EEG, 'channel', chan_map(:, 1));
        
        % תרגום לשמות 10-20 התקינים עכשיו כשאין סכנה לכפילויות
        for c = 1:size(chan_map, 1)
            idx = find(strcmpi({EEG.chanlocs.labels}, chan_map{c, 1}));
            if ~isempty(idx)
                EEG.chanlocs(idx).labels = chan_map{c, 2};
            end
        end
        
        % טעינת קואורדינטות (עכשיו לכל 24 האלקטרודות יהיה מיקום מושלם במרחב)
        EEG = pop_chanedit(EEG, 'lookup','standard_1005.elc');
        
        EEG = pop_eegfiltnew(EEG, 'locutoff', 0.1, 'hicutoff', 40);
        EEG = pop_epoch(EEG, {'s201', 's202', 'S201', 'S202', '201', '202'}, [-1, 0.5], 'epochinfo', 'yes');
        EEG = pop_rmbase(EEG, [-1000, -500]);
        
        % ICA מהיר ומדויק
        EEG = pop_runica(EEG, 'icatype', 'runica', 'pca', EEG.nbchan-1);
        
        EEG = iclabel(EEG);
        EEG = pop_icflag(EEG, [NaN NaN; NaN NaN; 0.6 1; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);
        EEG = pop_subcomp(EEG, find(EEG.reject.gcompreject), 0);
        
        roi_channels = {'Pz', 'Cz', 'CP1', 'CP2', 'P3', 'P4', 'C3', 'C4', 'P7', 'P8', 'O1', 'O2'}; 
        chan_idx = [];
        for c = 1:length(roi_channels)
            idx = find(strcmpi({EEG.chanlocs.labels}, roi_channels{c}));
            if ~isempty(idx)
                chan_idx = [chan_idx, idx];
            end
        end
        if isempty(chan_idx)
            chan_idx = 1:EEG.nbchan; 
        end
        
        EEG = pop_eegthresh(EEG, 1, chan_idx, -100, 100, -1, 0.49, 0, 1);
        
        EEG = pop_saveset(EEG, 'filename', [sub_name '_cleaned.set'], 'filepath', output_dir);
        
    catch ME
        fprintf('\n*******************************************************\n');
        fprintf('FAILED TO PROCESS %s! Skipping to the next subject.\n', sub_name);
        fprintf('Error Reason: %s\n', ME.message);
        fprintf('*******************************************************\n');
    end
    
    ALLEEG = []; EEG = []; CURRENTSET = 0;
end
disp('=======================================================');
disp('GLAS BATCH PROCESSING COMPLETE!');
disp('=======================================================');