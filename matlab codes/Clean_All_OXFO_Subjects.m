% =========================================================================
% Automated EEGLAB Pipeline for P600 Analysis - OXFO LAB (BioSemi 64)
% =========================================================================
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% --- שינוי נתיבים למעבדת OXFO ---
input_dir  = 'C:\Users\wechs\OneDrive\المستندات\sagol project\newland etal OSF\Raw data\OXFO';    
output_dir = 'C:\Users\wechs\OneDrive\المستندات\sagol project\proccessed data - cleansed files\OXFO clean';  

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
        % 1. טעינה
        EEG = pop_biosig(fullfile(input_dir, filename));
        
        % 2. המרת הטריגרים ממספרים לטקסט
        for e = 1:length(EEG.event)
            if isnumeric(EEG.event(e).type)
                EEG.event(e).type = num2str(EEG.event(e).type);
            end
        end
        
        % 3. טעינת קואורדינטות לאלקטרודות
        EEG = pop_chanedit(EEG, 'lookup','standard_1005.elc');
        
        % 4. הורדת קצב דגימה (Downsampling) ל-250Hz - קריטי פה! חוסך 87% מכמות הנתונים לחישוב
        EEG = pop_resample(EEG, 250);
        
        % 5. פילטר
        EEG = pop_eegfiltnew(EEG, 'locutoff', 0.1, 'hicutoff', 40);
        
        % 6. רפרנס מחדש למסטואידים (EXG1 ו-EXG2)
        EEG = pop_reref(EEG, {'EXG1','EXG2'});
        
        % 7. חיתוך: שומרים רק את 64 אלקטרודות הקרקפת וזורקים את ה-EXGs הנותרים
        EEG = pop_select(EEG, 'channel', 1:64);
        
        % 8. אפוקינג ותיקון קו בסיס
        EEG = pop_epoch(EEG, {'s201', 's202', 'S201', 'S202', '201', '202'}, [-1, 0.5], 'epochinfo', 'yes');
        EEG = pop_rmbase(EEG, [-1000, -500]);
        
        % 9. הרצת ICA (מספר האלקטרודות פחות 1 בגלל הרפרנס)
        EEG = pop_runica(EEG, 'icatype', 'runica', 'pca', EEG.nbchan-1);
        
        % 10. ניקוי רעשי עיניים (ICLabel) עם סף 60%
        EEG = iclabel(EEG);
        EEG = pop_icflag(EEG, [NaN NaN; NaN NaN; 0.6 1; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);
        EEG = pop_subcomp(EEG, find(EEG.reject.gcompreject), 0);
        
        % 11. ניקוי ערכים קיצוניים באזור ה-ROI
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
        
        % 12. שמירה
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
disp('OXFO BATCH PROCESSING COMPLETE!');
disp('=======================================================');