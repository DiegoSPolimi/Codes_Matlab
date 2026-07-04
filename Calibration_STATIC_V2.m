% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %
% % 01_CALIBRATION (With Automated Reordering Included)
% %
% % Static calibration according to the Movella DOT methodology.
% %
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% clear
% clc
% close all
% 
% %% ===================================================================== %%
% % SENSOR LIST
% %% ===================================================================== %%
% Sensors = { ...
%     'S2',...
%     'LT',... 
%     'LShank'};
% nSensors = length(Sensors);
% Calibration = struct;
% 
% %% ===================================================================== %%
% % SELECT FOLDER
% %% ===================================================================== %%
% dataFolder = uigetdir( ...
%     pwd,...
%     'Select the folder containing the STATIC calibration files');
% if dataFolder==0
%     error('No folder selected.')
% end
% 
% %% ===================================================================== %%
% % STATIC POSTURE
% %% ===================================================================== %%
% disp(' ')
% disp('Select the static posture')
% Choice = menu( ...
%     'Static posture',...
%     'Static (N-Pose)',...
%     'Supine',...
%     'Seated');
% switch Choice
%     case 1
%         StaticKeywords = {'static','n_pose'};
%     case 2
%         StaticKeywords = {'static','supine'};
%     case 3
%         StaticKeywords = {'static','seated'};
%     otherwise
%         error('Calibration cancelled.')
% end
% 
% %% ===================================================================== %%
% % STATIC CALIBRATION
% %% ===================================================================== %%
% disp(' ')
% disp('==============================================')
% disp('STATIC CALIBRATION WITH ON-THE-FLY REORDERING')
% disp('==============================================')
% for i=1:nSensors
%     sensor = Sensors{i};
% 
%     try
%         filename = findFileCaseInsensitive( ...
%             dataFolder,...
%             sensor,...
%             StaticKeywords);
%     catch ME
%         warning('%s. Skipping this sensor.', ME.message);
%         continue;
%     end
% 
%     fprintf('\nProcessing Sensor: %s (%s)\n', sensor, filename);
% 
%     % Load, Reorder, and Extract Data cleanly using your reordering logic
%     Data = loadAndReorderIMUcsv(fullfile(dataFolder, filename));
% 
%     Calibration.(sensor).RsegSens = ...
%         computeStaticCalibration( ...
%         Data.Quat);
% end
% 
% %% ===================================================================== %%
% % SAVE
% %% ===================================================================== %%
% save(fullfile(dataFolder,'CalibrationResults.mat'),'Calibration')
% disp(' ')
% disp('Calibration successfully completed.')
% 
% %% ===================================================================== %%
% % VISUALIZATION
% %% ===================================================================== %%
% if ~isempty(fieldnames(Calibration))
%     plotCalibrationFrames(Calibration)
% else
%     disp('No calibration data available to plot.')
% end
% 
% %% ===================================================================== %%
% % VERIFY ORTHOGONALITY
% %% ===================================================================== %%
% disp(' ')
% disp('Verification of rotation matrices')
% fields = fieldnames(Calibration);
% for i=1:length(fields)
%     sensor = fields{i};
%     R = Calibration.(sensor).RsegSens;
%     fprintf('\n%s\n',sensor)
%     fprintf('det(R) = %.4f\n',det(R))
%     fprintf('Orthogonality error = %.6f\n', ...
%         norm(R'*R-eye(3),'fro'));
% end
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %% LOCAL FUNCTIONS
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% function filename = findFileCaseInsensitive(folder,sensorName,keywords)
% files = dir(fullfile(folder,'*.csv'));
% matches = [];
% for k=1:length(files)
%     name = lower(files(k).name);
%     % Ignore already processed "_REORDERED" files to avoid double matching
%     if contains(name, 'reordered')
%         continue;
%     end
%     if contains(name,lower(sensorName))
%         ok = true;
%         for w=1:length(keywords)
%             kw = lower(keywords{w});
%             if ~contains(name, kw) && ~contains(name, strrep(kw, '_', '')) && ~contains(name, strrep(kw, '_', '-'))
%                 ok = false;
%             end
%         end
%         if ok
%             matches(end+1)=k;
%         end
%     end
% end
% if isempty(matches)
%     error('No calibration file found for %s.',sensorName)
% end
% filename = files(matches(1)).name;
% end
% 
% function Data = loadAndReorderIMUcsv(filename)
% % Imports and Reorders data matching your exact reordering script parameters
% opts = detectImportOptions(filename, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
% opts.VariableNamesLine = 1;
% opts.DataLine = 2;
% 
% T = readtable(filename, opts);
% 
% % Check required columns
% if ~ismember('Timestamp_Arduino', T.Properties.VariableNames)
%     error('Column "Timestamp_Arduino" not found in %s.', filename);
% end
% 
% % Sort WHOLE ROWS according to Arduino timestamp
% nWrong = sum(diff(T.Timestamp_Arduino) < 0);
% if nWrong > 0
%     fprintf('-> Rows out of order before sorting: %d. Sorting rows...\n', nWrong);
%     T = sortrows(T, 'Timestamp_Arduino');
% end
% 
% % Optional: Automatically save the reordered version to disk
% [pathStr, name, ext] = fileparts(filename);
% if ~contains(name, '_REORDERED')
%     newFile = fullfile(pathStr, [name '_REORDERED' ext]);
%     writetable(T, newFile);
% end
% 
% % Extract Quaternions
% if all(ismember({'Q0', 'Q1', 'Q2', 'Q3'}, T.Properties.VariableNames))
%     Data.Quat = [T.Q0, T.Q1, T.Q2, T.Q3];
% else
%     error('The file does not contain the columns Q0, Q1, Q2, and Q3.');
% end
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 01_CALIBRATION (With Axis Swapping for S2)
%
% Static calibration according to the Movella DOT methodology.
% Incorporates correction for inverted ML and Long axes on S2.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc
close all

%% ===================================================================== %%
% SENSOR LIST
%% ===================================================================== %%
Sensors = { ...
    'S2',...
    'LT',... 
    'LShank'};
nSensors = length(Sensors);
Calibration = struct;

%% ===================================================================== %%
% SELECT FOLDER
%% ===================================================================== %%
dataFolder = uigetdir( ...
    pwd,...
    'Select the folder containing the STATIC calibration files');
if dataFolder==0
    error('No folder selected.')
end

%% ===================================================================== %%
% STATIC POSTURE
%% ===================================================================== %%
disp(' ')
disp('Select the static posture')
Choice = menu( ...
    'Static posture',...
    'Static (N-Pose)',...
    'Supine',...
    'Seated');
switch Choice
    case 1
        StaticKeywords = {'static','n_pose'};
    case 2
        StaticKeywords = {'static','supine'};
    case 3
        StaticKeywords = {'static','seated'};
    otherwise
        error('Calibration cancelled.')
end

%% ===================================================================== %%
% STATIC CALIBRATION
%% ===================================================================== %%
disp(' ')
disp('==============================================')
disp('STATIC CALIBRATION WITH ON-THE-FLY REORDERING')
disp('==============================================')
for i=1:nSensors
    sensor = Sensors{i};
    
    try
        filename = findFileCaseInsensitive( ...
            dataFolder,...
            sensor,...
            StaticKeywords);
    catch ME
        warning('%s. Skipping this sensor.', ME.message);
        continue;
    end
    
    fprintf('\nProcessing Sensor: %s (%s)\n', sensor, filename);
    
    % Load, Reorder, and Extract Data cleanly
    Data = loadAndReorderIMUcsv(fullfile(dataFolder, filename));
    
    % Compute the standard baseline static calibration matrix
    R = computeStaticCalibration(Data.Quat);
    
    % % --- S2 SPECIFIC AXIS INVERSION CORRECTION ---
    % if strcmp(sensor, 'S2')
    %     disp('-> Applying axis correction for S2: Swapping and correcting ML (Col 1) and Long (Col 3) axes...');
    % 
    %     % Extract original columns
    %     Col1_ML   = R(:, 1);
    %     Col2_AP   = R(:, 2);
    %     Col3_Long = R(:, 3);
    % 
    %     % Swap Column 1 and Column 3. 
    %     % We invert one axis (-Col1_ML) to preserve the right-hand rule system (det = +1)
    %     R_corrected = [Col3_Long, Col2_AP, -Col1_ML];
    % 
    %     % Reassign corrected rotation matrix
    %     R = R_corrected;
    % end
    
    Calibration.(sensor).RsegSens = R;
end

%% ===================================================================== %%
% SAVE
%% ===================================================================== %%
save(fullfile(dataFolder,'CalibrationResults.mat'),'Calibration')
disp(' ')
disp('Calibration successfully completed.')

%% ===================================================================== %%
% VISUALIZATION
%% ===================================================================== %%
if ~isempty(fieldnames(Calibration))
    plotCalibrationFrames(Calibration)
else
    disp('No calibration data available to plot.')
end

%% ===================================================================== %%
% VERIFY ORTHOGONALITY & DETERMINANT
%% ===================================================================== %%
disp(' ')
disp('Verification of rotation matrices')
fields = fieldnames(Calibration);
for i=1:length(fields)
    sensor = fields{i};
    R = Calibration.(sensor).RsegSens;
    fprintf('\n%s\n',sensor)
    fprintf('det(R) = %.4f (Should be +1.0000)\n',det(R))
    fprintf('Orthogonality error = %.6f\n', ...
        norm(R'*R-eye(3),'fro'));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOCAL FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function filename = findFileCaseInsensitive(folder,sensorName,keywords)
files = dir(fullfile(folder,'*.csv'));
matches = [];
for k=1:length(files)
    name = lower(files(k).name);
    if contains(name, 'reordered')
        continue;
    end
    if contains(name,lower(sensorName))
        ok = true;
        for w=1:length(keywords)
            kw = lower(keywords{w});
            if ~contains(name, kw) && ~contains(name, strrep(kw, '_', '')) && ~contains(name, strrep(kw, '_', '-'))
                ok = false;
            end
        end
        if ok
            matches(end+1)=k;
        end
    end
end
if isempty(matches)
    error('No calibration file found for %s.',sensorName)
end
filename = files(matches(1)).name;
end

function Data = loadAndReorderIMUcsv(filename)
opts = detectImportOptions(filename, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
opts.VariableNamesLine = 1;
opts.DataLine = 2;

T = readtable(filename, opts);

if ~ismember('Timestamp_Arduino', T.Properties.VariableNames)
    error('Column "Timestamp_Arduino" not found in %s.', filename);
end

nWrong = sum(diff(T.Timestamp_Arduino) < 0);
if nWrong > 0
    fprintf('-> Rows out of order before sorting: %d. Sorting rows...\n', nWrong);
    T = sortrows(T, 'Timestamp_Arduino');
end

[pathStr, name, ext] = fileparts(filename);
if ~contains(name, '_REORDERED')
    newFile = fullfile(pathStr, [name '_REORDERED' ext]);
    writetable(T, newFile);
end

if all(ismember({'Q0', 'Q1', 'Q2', 'Q3'}, T.Properties.VariableNames))
    Data.Quat = [T.Q0, T.Q1, T.Q2, T.Q3];
else
    error('The file does not contain the columns Q0, Q1, Q2, and Q3.');
end
end