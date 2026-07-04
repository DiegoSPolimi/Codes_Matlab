%% MAIN_VISUALIZE_RAW_IMU_SYNCHRONIZED.M
%
% Visualizes raw data for manually selected IMU files by synchronizing them
% using the dominant acceleration peak detected within the first few seconds.
% Safely handles files with differing lengths and acquisition bounds.
% Includes interactive cropping based on Quaternion profiles to ensure all 
% output files have identical length and preserves exact original columns/structures.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear;
clc;
close all;
Fs = 60;              % Sampling frequency
SyncWindowSeconds = 5; % Look for the sync peak only within the first 5 seconds

%% ===================================================================== %%
% MANUAL FILE SELECTION
%% ===================================================================== %%
disp('Select the CSV file(s) you wish to synchronize and visualize...')
[files, pathStr] = uigetfile('*.csv',...
    'Select CSV file(s) to synchronize',...
    'MultiSelect','on');
if isequal(files,0)
    disp('No files selected. Script aborted.');
    return;
end
if ischar(files)
    files = {files};
end
nFiles = length(files);
RawData = struct;
FullTables = cell(nFiles, 1); % Store the complete uncropped tables
sensorLabels = cell(nFiles, 1);
peakIndices = zeros(nFiles, 1);

%% ===================================================================== %%
% LOAD & FIND ACCELERATION PEAK INDICES
%% ===================================================================== %%
disp('--------------------------------------------------')
disp('LOADING, SORTING, AND SEARCHING FOR SYNC PEAKS...')
disp('--------------------------------------------------')
maxWindowSamples = SyncWindowSeconds * Fs;
for f = 1:nFiles
    filename = files{f};
    fullPath = fullfile(pathStr, filename);
    
    % Track sensor identity names
    if contains(lower(filename), 's2'),     label = 'S2';
    elseif contains(lower(filename), 'lt'), label = 'LT';
    elseif contains(lower(filename), 'lshank'), label = 'LShank';
    else
        [~, namePart, ~] = fileparts(filename);
        label = namePart(1:min(8, length(namePart)));
    end
    sensorLabels{f} = label;
    
    % Import and sort rows by Arduino timestamp
    [DataStruct, T] = loadRawIMUcsv(fullPath);
    FullTables{f} = T; % Cache original table reference
    
    % --- SYNC PEAK DETECTION ---
    accMag = sqrt(sum(DataStruct.Acc.^2, 2));
    searchLimit = min(maxWindowSamples, length(accMag));
    [~, localPeakIdx] = max(accMag(1:searchLimit));
    
    peakIndices(f) = localPeakIdx;
    fprintf('Sensor [%s]: Primary peak detected at frame %d (~%.2fs)\n', ...
        label, localPeakIdx, localPeakIdx/Fs);
    
    % Save data into our structured variable
    RawData.(label) = DataStruct;
end

%% ===================================================================== %%
% SYNCHRONIZE AND TRUNCATE ARRAYS (SAFE BOUNDS CALCULATION)
%% ===================================================================== %%
disp('--------------------------------------------------')
disp('SYNCHRONIZING DATA STREAMS...')
disp('--------------------------------------------------')
trailingSamplesAvailable = zeros(nFiles, 1);
for f = 1:nFiles
    label = sensorLabels{f};
    totalRowsInFile = size(RawData.(label).Acc, 1);
    trailingSamplesAvailable(f) = totalRowsInFile - peakIndices(f) + 1;
end

minRemainingSamples = min(trailingSamplesAvailable);
SyncData = struct;
for f = 1:nFiles
    label = sensorLabels{f};
    startIdx = peakIndices(f); 
    endIdx = startIdx + minRemainingSamples - 1; 
    
    SyncData.(label).Acc  = RawData.(label).Acc(startIdx:endIdx, :);
    SyncData.(label).Gyr  = RawData.(label).Gyr(startIdx:endIdx, :);
    SyncData.(label).Quat = RawData.(label).Quat(startIdx:endIdx, :);
end

time = (0:minRemainingSamples-1)' / Fs;
fprintf('Synchronization complete. Aligned timeline length: %d frames (%.2fs)\n', ...
    minRemainingSamples, minRemainingSamples/Fs);

%% ===================================================================== %%
% INTERACTIVE CROP SELECTION (BASED ON QUATERNIONS)
%% ===================================================================== %%
disp('--------------------------------------------------')
disp('INTERACTIVE FILE CROPPING (QUATERNION GUIDE)...')
disp('--------------------------------------------------')
firstLabel = sensorLabels{1};

cropFig = figure('Name', 'Interactive Crop Selection: Click Start and End Points', 'Color', 'w');
plot(time, SyncData.(firstLabel).Quat, 'LineWidth', 1.5);
grid on; xlabel('Time (s)'); ylabel('Quaternion Value');
title({['Interactive Crop Guide (Sensor: ' firstLabel ')'], ...
       'Click TWICE on the plot to select your crop window', ...
       '1st click = START boundary | 2nd click = END boundary'});
legend('Q0', 'Q1', 'Q2', 'Q3', 'Location', 'best');

[xClicks, ~] = ginput(2);
close(cropFig);

cropStartTime = min(xClicks);
cropEndTime = max(xClicks);

cropStartIdx = max(1, round(cropStartTime * Fs) + 1);
cropEndIdx   = min(minRemainingSamples, round(cropEndTime * Fs) + 1);

% Finalize plots sync views window bounds updates
time = time(cropStartIdx:cropEndIdx);
for f = 1:nFiles
    label = sensorLabels{f};
    SyncData.(label).Acc  = SyncData.(label).Acc(cropStartIdx:cropEndIdx, :);
    SyncData.(label).Gyr  = SyncData.(label).Gyr(cropStartIdx:cropEndIdx, :);
    SyncData.(label).Quat = SyncData.(label).Quat(cropStartIdx:cropEndIdx, :);
end

time = time - time(1);
newTotalRows = length(time);
fprintf('Cropping complete. All data vectors successfully cropped uniformly to %d rows.\n', newTotalRows);

%% ===================================================================== %%
% EXPORT CROPPED FILES (PRESERVING INITIAL CSV STRUCTURE)
%% ===================================================================== %%
disp('--------------------------------------------------')
disp('SAVING UNIFORMLY CROPPED INITIAL CSV STRUCTURES...')
disp('--------------------------------------------------')
for f = 1:nFiles
    filename = files{f};
    label = sensorLabels{f};
    
    % Access the complete cached original table
    T_original = FullTables{f};
    
    % Track original file synchronization slice indices bounds
    actualStartRow = peakIndices(f) + cropStartIdx - 1;
    actualEndRow   = peakIndices(f) + cropEndIdx - 1;
    
    % Crop the original table directly
    T_cropped = T_original(actualStartRow:actualEndRow, :);
    
    % File naming layout settings
    [~, namePart, extPart] = fileparts(filename);
    croppedFilename = [namePart '_CROPPED' extPart];
    exportPath = fullfile(pathStr, croppedFilename);
    
    % Write exact table copy
    writetable(T_cropped, exportPath);
    fprintf('Saved structurally identical file: %s (%d rows)\n', croppedFilename, size(T_cropped, 1));
end

%% ===================================================================== %%
% PLOTTING METRICS (SUBPLOTS PER CATEGORY)
%% ===================================================================== %%
% --- FIGURE 1: ACCELEROMETER DATA ---
figure('Name', 'Synchronized & Cropped Accelerometer Data (g)', 'NumberTitle', 'off', 'Units', 'normalized', 'Position', [0.05 0.5 0.4 0.4]);
for f = 1:nFiles
    label = sensorLabels{f};
    subplot(nFiles, 1, f);
    plot(time, SyncData.(label).Acc, 'LineWidth', 1.2);
    title(['Cropped Accelerometer: ' label]);
    xlabel('Time (s)'); ylabel('Acc (g)'); grid on;
    if f == 1, legend('X', 'Y', 'Z', 'Location', 'best'); end
end

% --- FIGURE 2: GYROSCOPE DATA ---
figure('Name', 'Synchronized & Cropped Gyroscope Data (deg/s)', 'NumberTitle', 'off', 'Units', 'normalized', 'Position', [0.5 0.5 0.4 0.4]);
for f = 1:nFiles
    label = sensorLabels{f};
    subplot(nFiles, 1, f);
    plot(time, SyncData.(label).Gyr, 'LineWidth', 1.2);
    title(['Cropped Gyroscope: ' label]);
    xlabel('Time (s)'); ylabel('Ang. Vel (deg/s)'); grid on;
    if f == 1, legend('X', 'Y', 'Z', 'Location', 'best'); end
end

% --- FIGURE 3: QUATERNION ORIENTATIONS ---
figure('Name', 'Synchronized & Cropped Quaternions', 'NumberTitle', 'off', 'Units', 'normalized', 'Position', [0.25 0.05 0.5 0.4]);
for f = 1:nFiles
    label = sensorLabels{f};
    subplot(nFiles, 1, f);
    plot(time, SyncData.(label).Quat, 'LineWidth', 1.2);
    title(['Cropped Quaternions: ' label]);
    xlabel('Time (s)'); ylabel('Value'); grid on;
    if f == 1, legend('Q0', 'Q1', 'Q2', 'Q3', 'Location', 'best'); end
end

%% ===================================================================== %%
% LOCAL FILE READING FUNCTION
%% ===================================================================== %%
function [Data, T] = loadRawIMUcsv(filename)
    opts = detectImportOptions(filename, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    opts.VariableNamesLine = 1;
    opts.DataLine = 2;
    
    T = readtable(filename, opts);
    
    if ismember('Timestamp_Arduino', T.Properties.VariableNames)
        T = sortrows(T, 'Timestamp_Arduino');
    end
    
    vars = T.Properties.VariableNames;
    
    if all(ismember({'Ax', 'Ay', 'Az'}, vars))
        accCols = {'Ax', 'Ay', 'Az'};
    elseif all(ismember({'AccX', 'AccY', 'AccZ'}, vars))
        accCols = {'AccX', 'AccY', 'AccZ'};
    else
        accCols = {'Acc_X', 'Acc_Y', 'Acc_Z'};
    end
    Data.Acc = T{:, accCols};
    
    if all(ismember({'Gx', 'Gy', 'Gz'}, vars))
        gyrCols = {'Gx', 'Gy', 'Gz'};
    elseif all(ismember({'GyrX', 'GyrY', 'GyrZ'}, vars))
        gyrCols = {'GyrX', 'GyrY', 'GyrZ'};
    else
        gyrCols = {'Gyr_X', 'Gyr_Y', 'Gyr_Z'};
    end
    Data.Gyr = T{:, gyrCols};
    
    quatCols = {'Q0', 'Q1', 'Q2', 'Q3'};
    Data.Quat = T{:, quatCols};
end