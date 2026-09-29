% =========================================================================
% Automated EEGLAB Pipeline for P600 Analysis - YORK LAB (BrainVision)
% =========================================================================
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% --- שינוי נתיבים למעבדת YORK ---
input_dir  = 'C:\Users\wechs\OneDrive\المستندات\sagol project\newland etal OSF\Raw data\YORK';    % נתיב לקבצי ה-VHDR שחילצת
output_dir = 'C:\Users\wechs\OneDrive\المستندات\sagol project\proccessed data - cleansed files\YORK clean';  % תיקיית השמירה

files = dir(fullfile(input_dir, '*.vhdr'));

for i = 1:length(files)
    
    filename = files(i).name;
    [~, sub_name, ~] = fileparts(filename); 
    
    fprintf('\n=======================================================\n');
    fprintf('Processing Subject: %s (%d out of %d)\n', sub_name, i, length(files));
    fprintf('=======================================================\n');

    expected_file = fullfile(output_dir, [sub_name '_cleaned.set']);
    if isfile(expected_file)
        fprintf('\n[Skipping] %s is already cleaned and exists in the output folder.\n', sub_name);
        continue; 
    end

    try 
        % 1. טעינת קובץ BrainVision
        EEG = pop_loadbv(input_dir, filename);
        
        % 2. טעינת קואורדינטות (השמות סטנדרטיים אז זה יעבוד חלק)
        EEG = pop_chanedit(EEG, 'lookup','standard_1005.elc');
        
        % 3. Downsampling ל-250 הרץ
        EEG = pop_resample(EEG, 250);
        
        % 4. סינון תדרים
        EEG = pop_eegfiltnew(EEG, 'locutoff', 0.1, 'hicutoff', 40);
        
        % 5. רפרנס מחדש למסטואידים (M1 ו-M2)
        EEG = pop_reref(EEG, {'M1','M2'});
        
        % 6. אפוקינג ותיקון קו בסיס
        EEG = pop_epoch(EEG, {'s201', 's202', 'S201', 'S202', '201', '202'}, [-1, 0.5], 'epochinfo', 'yes');
        EEG = pop_rmbase(EEG, [-1000, -500]);
        
        % 7. הרצת ICA
        EEG = pop_runica(EEG, 'icatype', 'runica', 'pca', EEG.nbchan-2);
        
        % 8. סיווג וניקוי רעשי עיניים (ICLabel) עם סף 60%
        EEG = iclabel(EEG);
        EEG = pop_icflag(EEG, [NaN NaN; NaN NaN; 0.6 1; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);
        EEG = pop_subcomp(EEG, find(EEG.reject.gcompreject), 0);
        
        % 9. ניקוי ערכים קיצוניים באזור ה-ROI
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
        
        % 10. שמירת הקובץ הנקי
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
disp('YORK BATCH PROCESSING COMPLETE!');
disp('=======================================================');