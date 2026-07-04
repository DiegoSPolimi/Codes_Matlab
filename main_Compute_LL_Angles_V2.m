% %% Automated version considering the Hip joint angles
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % MAIN_LOWERLIMBANGLES.M
% %
% % Automated Lower Limb Joint Angle Computation (Hip & Knee 3D Angles)
% % With Built-in Sorting and Alignment Pipeline
% %
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% clear
% clc
% close all
% 
% Fs = 60;
% 
% %% ===================================================================== %%
% % INTERACTIVE FOLDER SELECTION & SETUP
% %% ===================================================================== %%
% dataFolder = uigetdir(pwd, 'Select the folder containing CalibrationResults.mat and movement CSV files');
% if dataFolder == 0
%     error('No data folder selected. Script aborted.');
% end
% 
% calibrationPath = fullfile(dataFolder, 'CalibrationResults.mat');
% if ~exist(calibrationPath, 'file')
%     error('Could not find CalibrationResults.mat in the selected folder. Please run calibration first.');
% end
% load(calibrationPath, 'Calibration');
% 
% %% ===================================================================== %%
% % LOAD ACQUISITION FILES (AUTOMATED MATCHING & REORDERING)
% %% ===================================================================== %%
% disp('-------------------------------------------')
% disp('LOADING & REORDERING MOVEMENT FILES')
% disp('-------------------------------------------')
% 
% movementKeyword = 'Bike_test_1'; 
% 
% % --- Pelvis ---
% targetFilePelvis = findFileCaseInsensitive(dataFolder, 'S2', {movementKeyword});
% fprintf('Processing Pelvis movement -> %s\n', targetFilePelvis);
% Pelvis = loadAndReorderIMUcsv(fullfile(dataFolder, targetFilePelvis));
% 
% % --- Left Thigh ---
% targetFileLThigh = findFileCaseInsensitive(dataFolder, 'LT', {movementKeyword});
% fprintf('Processing LThigh movement -> %s\n', targetFileLThigh);
% LThigh = loadAndReorderIMUcsv(fullfile(dataFolder, targetFileLThigh));
% 
% % --- Left Shank ---
% % targetFileLShank = findFileCaseInsensitive(dataFolder, 'LShank', {movementKeyword});
% % fprintf('Processing LShank movement -> %s\n', targetFileLShank);
% % LShank = loadAndReorderIMUcsv(fullfile(dataFolder, targetFileLShank));
% % 
% % disp('All files successfully reordered and loaded.');
% 
% %% ===================================================================== %%
% % SEGMENT ORIENTATIONS (Converting Sensor to Anatomical Frames)
% %% ===================================================================== %%
% Rpelvis = computeSegmentOrientation(Pelvis.Quat, Calibration.S2.RsegSens); 
% RLthigh = computeSegmentOrientation(LThigh.Quat, Calibration.LT.RsegSens);
% % RLshank = computeSegmentOrientation(LShank.Quat, Calibration.LShank.RsegSens);
% 
% %% ===================================================================== %%
% % JOINT ANGLE COMPUTATION (HIP & KNEE)
% %% ===================================================================== %%
% LHip = computeHipJCS(Rpelvis, RLthigh); 
% % LKnee = computeKneeJCS(RLthigh, RLshank); 
% 
% %% ===================================================================== %%
% % VISUALIZATION & PLOTTING
% %% ===================================================================== %%
% N = size(RLthigh, 3);
% time = (0:N-1)'/Fs;
% 
% plotAngles(time, LHip, 'Left Hip')
% % plotAngles(time, LKnee, 'Left Knee')
% 
% %% ===================================================================== %%
% % DATA EXPORT
% %% ===================================================================== %%
% exportExcel(time, LHip, fullfile(dataFolder, 'LeftHip_Angles_Output'));
% % exportExcel(time, LKnee, fullfile(dataFolder, 'LeftKnee_Angles_Output'));
% disp('Processing completed successfully.');
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %% LOCAL HELPER FUNCTIONS
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% function filename = findFileCaseInsensitive(folder, sensorName, keywords)
%     allFiles = dir(fullfile(folder, '*.csv'));
%     if isempty(allFiles)
%         error('The selected folder does not contain any CSV files.');
%     end
% 
%     matchedIndices = [];
%     for k = 1:length(allFiles)
%         currentName = allFiles(k).name;
%         if contains(currentName, 'reordered') || contains(currentName, 'REORDERED')
%             continue; 
%         end
% 
%         if contains(lower(currentName), lower(sensorName))
%             allKeywordsMatch = true;
%             for w = 1:length(keywords)
%                 kw = lower(keywords{w});
%                 if ~contains(lower(currentName), kw) && ...
%                    ~contains(lower(currentName), strrep(kw, '_', '')) && ...
%                    ~contains(lower(currentName), strrep(kw, '_', '-'))
%                     allKeywordsMatch = false;
%                     break;
%                 end
%             end
%             if allKeywordsMatch
%                 matchedIndices = [matchedIndices, k]; %#ok<AGROW>
%             end
%         end
%     end
% 
%     if isempty(matchedIndices)
%         kwString = strjoin(keywords, ', ');
%         error('Missing movement file for sensor "%s" with keywords [%s].', sensorName, kwString);
%     end
%     filename = allFiles(matchedIndices(1)).name; 
% end
% 
% function Data = loadAndReorderIMUcsv(filename)
% opts = detectImportOptions(filename, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
% opts.VariableNamesLine = 1;
% opts.DataLine = 2;
% 
% T = readtable(filename, opts);
% 
% if ~ismember('Timestamp_Arduino', T.Properties.VariableNames)
%     error('Column "Timestamp_Arduino" not found in %s.', filename);
% end
% 
% nWrong = sum(diff(T.Timestamp_Arduino) < 0);
% if nWrong > 0
%     fprintf('-> Rows out of order before sorting: %d. Sorting rows...\n', nWrong);
%     T = sortrows(T, 'Timestamp_Arduino');
% end
% 
% [pathStr, name, ext] = fileparts(filename);
% if ~contains(name, '_REORDERED')
%     newFile = fullfile(pathStr, [name '_REORDERED' ext]);
%     writetable(T, newFile);
% end
% 
% if all(ismember({'Q0', 'Q1', 'Q2', 'Q3'}, T.Properties.VariableNames))
%     Data.Quat = [T.Q0, T.Q1, T.Q2, T.Q3];
% else
%     error('The file does not contain columns Q0, Q1, Q2, and Q3.');
% end
% end

%% Automated version considering the Hip joint angles
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MAIN_LOWERLIMBANGLES_SYNCHRONIZED.M
%
% Automated Lower Limb Joint Angle Computation (Hip & Knee 3D Angles)
% Tailored for pre-aligned files containing the '_SYNCHRONIZED' suffix.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc
close all

Fs = 60;

%% ===================================================================== %%
% INTERACTIVE FOLDER SELECTION & SETUP
%% ===================================================================== %%
dataFolder = uigetdir(pwd, 'Select the folder containing CalibrationResults.mat and SYNCHRONIZED movement CSV files');
if dataFolder == 0
    error('No data folder selected. Script aborted.');
end

calibrationPath = fullfile(dataFolder, 'CalibrationResults.mat');
if ~exist(calibrationPath, 'file')
    error('Could not find CalibrationResults.mat in the selected folder. Run calibration first.');
end
load(calibrationPath, 'Calibration');

%% ===================================================================== %%
% LOAD SYNCHRONIZED MOVEMENT FILES
%% ===================================================================== %%
disp('-------------------------------------------')
disp('LOADING PRE-SYNCHRONIZED MOVEMENT FILES')
disp('-------------------------------------------')

% We expect files processed by the sync script to contain '_SYNCHRONIZED'
movementKeyword = 'REORDERED'; 

% --- Pelvis ---
targetFilePelvis = findFileCaseInsensitive(dataFolder, 'S2', {movementKeyword});
fprintf('Loading Synchronized Pelvis -> %s\n', targetFilePelvis);
Pelvis = loadCleanIMUcsv(fullfile(dataFolder, targetFilePelvis));

% --- Left Thigh ---
targetFileLThigh = findFileCaseInsensitive(dataFolder, 'LT', {movementKeyword});
fprintf('Loading Synchronized LThigh -> %s\n', targetFileLThigh);
LThigh = loadCleanIMUcsv(fullfile(dataFolder, targetFileLThigh));

% --- Left Shank ---
% targetFileLShank = findFileCaseInsensitive(dataFolder, 'LShank', {movementKeyword});
% fprintf('Loading Synchronized LShank -> %s\n', targetFileLShank);
% LShank = loadCleanIMUcsv(fullfile(dataFolder, targetFileLShank));

disp('All synchronized segments successfully loaded.');

%% ===================================================================== %%
% SEGMENT ORIENTATIONS (Converting Sensor to Anatomical Frames)
%% ===================================================================== %%
% Compute Anatomical Pelvis Orientation
Rpelvis = computeSegmentOrientation(Pelvis.Quat, Calibration.S2.RsegSens); 

% Compute Anatomical Left Thigh Orientation (Matches 'LT' mapping structure)
RLthigh = computeSegmentOrientation(LThigh.Quat, Calibration.LT.RsegSens);

% Compute Anatomical Left Shank Orientation
% RLshank = computeSegmentOrientation(LShank.Quat, Calibration.LShank.RsegSens);

%% ===================================================================== %%
% JOINT ANGLE COMPUTATION (HIP & KNEE)
%% ===================================================================== %%
disp('Computing Hip and Knee Joint Kinematics...');

LHip = computeHipJCS(Rpelvis, RLthigh); 
% LKnee = computeKneeJCS(RLthigh, RLshank); 

%% ===================================================================== %%
% VISUALIZATION & PLOTTING
%% ===================================================================== %%
N = size(RLthigh, 3);
time = (0:N-1)'/Fs;

% Plot Left Hip Angles
plotAngles(time, LHip, 'Left Hip')

% Plot Left Knee Angles
% plotAngles(time, LKnee, 'Left Knee')

%% ===================================================================== %%
% DATA EXPORT
%% ===================================================================== %%
exportExcel(time, LHip, fullfile(dataFolder, 'LeftHip_Angles_Output'));
% exportExcel(time, LKnee, fullfile(dataFolder, 'LeftKnee_Angles_Output'));
disp('Processing completed successfully. Kinematic Excel sheets saved.');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOCAL HELPER FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function filename = findFileCaseInsensitive(folder, sensorName, keywords)
    allFiles = dir(fullfile(folder, '*.csv'));
    if isempty(allFiles)
        error('The selected folder does not contain any CSV files.');
    end
    
    matchedIndices = [];
    for k = 1:length(allFiles)
        currentName = allFiles(k).name;
        
        if contains(lower(currentName), lower(sensorName))
            allKeywordsMatch = true;
            for w = 1:length(keywords)
                if ~contains(lower(currentName), lower(keywords{w}))
                    allKeywordsMatch = false;
                    break;
                end
            end
            if allKeywordsMatch
                matchedIndices = [matchedIndices, k]; %#ok<AGROW>
            end
        end
    end
    
    if isempty(matchedIndices)
        kwString = strjoin(keywords, ', ');
        error('Could not find a CSV file for sensor "%s" matching keywords [%s].', sensorName, kwString);
    end
    filename = allFiles(matchedIndices(1)).name; 
end

function Data = loadCleanIMUcsv(filePath)
% Reads the clean, pre-sorted, and pre-synchronized CSV file layout
opts = detectImportOptions(filePath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
opts.VariableNamesLine = 1;
opts.DataLine = 2;

T = readtable(filePath, opts);

% Extract Quaternions directly from the safe columns
if all(ismember({'Q0', 'Q1', 'Q2', 'Q3'}, T.Properties.VariableNames))
    Data.Quat = [T.Q0, T.Q1, T.Q2, T.Q3];
else
    error('The file %s is missing the required columns Q0, Q1, Q2, or Q3.', filePath);
end
end