% =========================================================================
% P600 Data Extractor: From Cleaned EEGLAB sets to Master CSV
% =========================================================================
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% 1. אזור הגדרות (שנה נתיבים בהתאם למחשב שלך)
% -------------------------------------------------------------------------
base_dir = 'C:\Users\wechs\OneDrive\المستندات\sagol project\proccessed data - cleansed files'; % התיקייה שבה נמצאות כל התיקיות של המעבדות
labs = {'BIRM', 'BRIS' 'EDIN', 'GLAS', 'KENT', 'LOND', 'OXFO', 'STIR', 'YORK'}; % רשימת המעבדות
output_csv = 'C:\Users\wechs\OneDrive\المستندات\sagol project\Master_P600_Data_correct_trial_number.csv'; % איפה לשמור את הטבלה הסופית

time_window = [0, 500]; % חלון הזמן של ה-P600 (באלפיות שניה)
roi_channels = {'Pz', 'Cz', 'CP1', 'CP2', 'P3', 'P4', 'C3', 'C4', 'P7', 'P8', 'O1', 'O2'};
target_triggers = {'s201', 's202', 'S201', 'S202', '201', '202'}; % הטריגרים שלנו
% -------------------------------------------------------------------------

% יצירת מבנה נתונים לאחסון כל התוצאות
results = {};
header = {'Lab', 'Subject', 'Condition', 'Trial', 'Electrode', 'Mean_Amplitude_uV'};
results(1,:) = header;

fprintf('\nStarting Global Data Extraction...\n');

% לולאה שעוברת על כל המעבדות
for l = 1:length(labs)
    lab_name = labs{l};
    lab_dir = fullfile(base_dir, [lab_name ' clean']);
    
    % מציאת כל קבצי ה-SET הנקיים בתיקיית המעבדה
    files = dir(fullfile(lab_dir, '*_cleaned.set'));
    
    if isempty(files)
        fprintf('No cleaned files found for %s. Skipping...\n', lab_name);
        continue;
    end
    
    for f = 1:length(files)
        filename = files(f).name;
        [~, sub_name, ~] = fileparts(filename);
        sub_name = strrep(sub_name, '_cleaned', ''); % ניקוי שם הנבדק
        
        fprintf('Extracting %s -> %s...\n', lab_name, sub_name);
        
        try
            % טעינת הקובץ
            EEG = pop_loadset('filename', filename, 'filepath', lab_dir);
            
            % איתור האינדקסים של חלון הזמן (500 עד 1000 ms)
            time_idx = find(EEG.times >= time_window(1) & EEG.times <= time_window(2));
            
            % מעבר על כל האפוקים (משפטים/Trials) ששרדו את הניקוי
            for ep = 1:EEG.trials
                
                ep_events = EEG.epoch(ep).eventtype;
                cond = '';
                item_num = NaN; % נשמור כאן את מספר המשפט האמיתי
                
                if iscell(ep_events)
                    for ev = 1:length(ep_events)
                        % המרה לטקסט אחיד
                        if ischar(ep_events{ev}) || isstring(ep_events{ev})
                            ev_str = char(ep_events{ev});
                        elseif isnumeric(ep_events{ev})
                            ev_str = num2str(ep_events{ev});
                        else
                            continue;
                        end
                        
                        % 1. זיהוי תנאי (201 / 202)
                        if any(strcmpi(ev_str, target_triggers))
                            cond = ev_str;
                        end
                        
                        % 2. זיהוי מספר המשפט (101 עד 180)
                        % נוריד את האות 's' או 'S' ונהפוך למספר
                        num_val = str2double(strrep(lower(ev_str), 's', ''));
                        if ~isnan(num_val) && num_val >= 101 && num_val <= 180
                            item_num = num_val - 100; % הופך את 111 ל-11, את 180 ל-80 וכו'
                        end
                    end
                else
                    % למקרה הנדיר שזה לא תא (cell) אלא ערך בודד
                    ev_str = num2str(ep_events);
                    if any(strcmpi(ev_str, target_triggers))
                        cond = ev_str;
                    end
                    num_val = str2double(strrep(lower(ev_str), 's', ''));
                    if ~isnan(num_val) && num_val >= 101 && num_val <= 180
                        item_num = num_val - 100;
                    end
                end
                
                % יישור שמות הטריגרים כדי שלא יהיה לנו בטבלה גם 201 וגם S201
                if contains(cond, '201'), cond_clean = 'Violation_201'; 
                elseif contains(cond, '202'), cond_clean = 'Control_202';
                else, cond_clean = cond; 
                end
                
                % חילוץ האמפליטודה לכל אלקטרודה ב-ROI
                for c = 1:length(roi_channels)
                    chan_label = roi_channels{c};
                    chan_idx = find(strcmpi({EEG.chanlocs.labels}, chan_label));
                    
                    if ~isempty(chan_idx)
                        % חישוב הממוצע של חלון הזמן
                        mean_amp = mean(EEG.data(chan_idx, time_idx, ep));
                        
                        % הוספת השורה לטבלה המרכזית (שמנו את item_num במקום ep!)
                        results(end+1, :) = {lab_name, sub_name, cond_clean, item_num, chan_label, mean_amp};
                    end
                end
            end
            
        catch ME
            fprintf('[!] Error extracting from %s: %s\n', sub_name, ME.message);
        end
    end
end

% המרת המערך לטבלה ושמירה כ-CSV
final_table = cell2table(results(2:end,:), 'VariableNames', results(1,:));
writetable(final_table, output_csv);

fprintf('\n=======================================================\n');
fprintf('EXTRACTION COMPLETE! Master file saved to:\n%s\n', output_csv);
fprintf('=======================================================\n');