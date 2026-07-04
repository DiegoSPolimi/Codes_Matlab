%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 01_CALIBRATION (MANUAL SELECTION WITH S2 AXIS CORRECTION)
%
% Static calibration according to the Movella DOT methodology.
% Incorporates manual file selection and axis fixes for S2.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc
close all
%% ===================================================================== %%
% SENSOR MAP SETUP
%% ===================================================================== %%
% Sensors = {'S2', 'LT', 'RT', 'LShank'};
Sensors = {'S2', 'LT', 'RT'};
Calibration = struct;
%% ===================================================================== %%
% MANUAL STATIC FILE SELECTION
%% ===================================================================== %%
disp('Select the STATIC calibration CSV file(s)...')
[files, pathStr] = uigetfile('*.csv',...
    'Select Static Calibration CSV File(s)',...
    'MultiSelect','on');
if isequal(files,0)
    disp('No files selected. Calibration aborted.');
    return;
end
% Handle single vs multiple files selection consistently
if ischar(files)
    files = {files};
end
nFiles = length(files);
%% ===================================================================== %%
% PROCESS CALIBRATIONS
%% ===================================================================== %%
disp(' ')
disp('==============================================')
disp('PROCESSING STATIC SELECTIONS & AXIS MAPPINGS')
disp('==============================================')
for f = 1:nFiles
    filename = files{f};
    fullPath = fullfile(pathStr, filename);
    
    % Dynamically associate the selected file to its target segment
    if contains(lower(filename), 's2')
        sensor = 'S2';
    elseif contains(lower(filename), 'lt')
        sensor = 'LT';
    elseif contains(lower(filename), 'rt')
        sensor = 'RT';
    elseif contains(lower(filename), 'lshank')
        sensor = 'LShank';
    else
        fprintf('Skipping unrecognized file: %s (Must contain S2, LT, RT, or LShank)\n', filename);
        continue;
    end
    
    fprintf('\nProcessing Segment [%s] from file: %s\n', sensor, filename);
    
    % Load, Reorder, and Extract Data cleanly
    Data = loadAndReorderIMUcsv(fullPath);
    
    % Compute the standard baseline static calibration matrix
    R = computeStaticCalibration(Data.Quat);
    
    % --- S2 SPECIFIC AXIS INVERSION CORRECTION ---
    if strcmp(sensor, 'S2')
        disp('-> Applying axis correction for S2: Swapping and correcting ML (Col 1) and Long (Col 3) axes...');
        
        % Extract original columns
        Col1_ML   = R(:, 1);
        Col2_AP   = R(:, 2);
        Col3_Long = R(:, 3);
        
        % Swap Column 1 and Column 3. 
        % We invert one axis (-Col1_ML) to preserve the right-hand rule system (det = +1)
        R_corrected = [Col3_Long, Col2_AP, -Col1_ML];
        
        % Reassign corrected rotation matrix
        R = R_corrected;
    end
    
    % --- OPTIONAL: RT SPECIFIC AXIS CORRECTION ---
    % Note: If your Right Thigh sensor is mounted flipped relative to the Left Thigh,
    % you can add an axis inversion block here similar to the S2 block above.
    
    Calibration.(sensor).RsegSens = R;
end
%% ===================================================================== %%
% SAVE
%% ===================================================================== %%
if ~isempty(fieldnames(Calibration))
    save(fullfile(pathStr,'CalibrationResults.mat'),'Calibration')
    disp(' ')
    disp('Calibration successfully completed and saved.');
else
    error('No valid sensor calibrations could be generated.');
end
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