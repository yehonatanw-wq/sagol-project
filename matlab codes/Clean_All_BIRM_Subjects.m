% =========================================================================
% Automated EEGLAB Pipeline for P600 Analysis - WITH ERROR HANDLING
% =========================================================================

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% --- שינוי נתיבים ---
input_dir  = 'C:\Users\wechs\OneDrive\المستندات\sagol project\newland etal OSF\Raw data\BIRM';    
output_dir = 'C:\Users\wechs\OneDrive\المستندات\sagol project\proccessed data - cleansed files\BIRM clean';  

files = dir(fullfile(input_dir, '*.vhdr'));

for i = 1:length(files)
    
    filename = files(i).name;
    [~, sub_name, ~] = fileparts(filename); 
    
    fprintf('\n=======================================================\n');
    fprintf('Processing Subject: %s (%d out of %d)\n', sub_name, i, length(files));
    fprintf('=======================================================\n');

    % בדיקה אם הקובץ כבר עבר ניקוי בעבר
    expected_file = fullfile(output_dir, [sub_name '_cleaned.set']);
    if isfile(expected_file)
        fprintf('\n[Skipping] %s is already cleaned and exists in the output folder.\n', sub_name);
        continue; % פקודה שקופצת מיד לנבדק הבא בלולאה
    end

    % מנגנון הגנה: אם נבדק קורס, הקוד לא יעצור אלא ידלג הלאה
    try 
        EEG = pop_loadbv(input_dir, filename);
        EEG = pop_chanedit(EEG, 'lookup','standard_1005.elc');
        EEG = pop_eegfiltnew(EEG, 'locutoff', 0.1, 'hicutoff', 40);
        EEG = pop_reref(EEG, {'M1','M2'});
        EEG = pop_epoch(EEG, {'s201', 's202', 'S201', 'S202', '201', '202'}, [-1, 0.5], 'epochinfo', 'yes');
        EEG = pop_rmbase(EEG, [-1000, -500]);
        
        EEG = pop_runica(EEG, 'icatype', 'runica', 'pca', EEG.nbchan-2);
        
        EEG = iclabel(EEG);
        EEG = pop_icflag(EEG, [NaN NaN; NaN NaN; 0.6 1; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);
        EEG = pop_subcomp(EEG, find(EEG.reject.gcompreject), 0);
        
       % ---------------------------------------------------------
        % 9. ניקוי ערכים קיצוניים (Extreme Values) - גרסה חכמה
        % ---------------------------------------------------------
        % הגדרת האלקטרודות שחשובות לנו ל-P600 (מרכזיות-אחוריות):
        roi_channels = {'Pz', 'Cz', 'CP1', 'CP2', 'P3', 'P4', 'C3', 'C4', 'P7', 'P8', 'O1', 'O2'}; 
        chan_idx = [];
        
        % מציאת המספרי האינדקס של האלקטרודות האלו בתוך הקובץ
        for c = 1:length(roi_channels)
            idx = find(strcmpi({EEG.chanlocs.labels}, roi_channels{c}));
            if ~isempty(idx)
                chan_idx = [chan_idx, idx];
            end
        end
        
        % אם משום מה לא מצאנו אלקטרודות, נחזור לבדוק את כל הראש
        if isempty(chan_idx)
            chan_idx = 1:EEG.nbchan;
        end
        
        % הפעלת הסינון רק על האלקטרודות החשובות!
        % (הזמן שונה ל-0.49 כדי להעלים את אזהרת ה-endtime שראית)
        EEG = pop_eegthresh(EEG, 1, chan_idx, -100, 100, -1, 0.49, 0, 1);
        EEG = pop_saveset(EEG, 'filename', [sub_name '_cleaned.set'], 'filepath', output_dir);
        
    catch ME
        % מה קורה אם יש שגיאה (כמו קובץ ריק)
        fprintf('\n*******************************************************\n');
        fprintf('FAILED TO PROCESS %s! Skipping to the next subject.\n', sub_name);
        fprintf('Error Reason: %s\n', ME.message);
        fprintf('*******************************************************\n');
    end
    
    ALLEEG = []; EEG = []; CURRENTSET = 0;
end

disp('=======================================================');
disp('BATCH PROCESSING COMPLETE!');
disp('=======================================================');