%% Automated version considering the Hip joint angles

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MAIN_LOWERLIMBANGLES.M
%
% Automated Lower Limb Joint Angle Computation (Hip & Knee 3D Angles)
% Using Case-Insensitive Matching and Calibration Data
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% clear
% clc
% close all
% 
% Fs = 60;
% 
% %% ===================================================================== %%
% % INTERACTIVE FOLDER SELECTION & SETUP
% %% ===================================================================== %%
% 
% % 1. Prompt user to select the trial/session directory
% dataFolder = uigetdir(pwd, 'Select the folder containing CalibrationResults.mat and movement CSV files');
% if dataFolder == 0
%     error('No data folder selected. Script aborted.');
% end
% 
% % 2. Load the previously generated calibration results from that folder
% calibrationPath = fullfile(dataFolder, 'CalibrationResults.mat');
% if ~exist(calibrationPath, 'file')
%     error('Could not find CalibrationResults.mat in the selected folder. Please run calibration first.');
% end
% load(calibrationPath, 'Calibration');
% 
% %% ===================================================================== %%
% % LOAD ACQUISITION FILES (AUTOMATED MATCHING)
% %% ===================================================================== %%
% disp('-------------------------------------------')
% disp('LOADING MOVEMENT FILES (ROBUST MATCHING)')
% disp('-------------------------------------------')
% 
% % Suffix phrase expected in the filename 
% % movementKeyword = 'Hip_AA_movement'; 
% 
% movementKeyword = 'Knee_FE_movement'; 
% 
% % --- Pelvis ---
% targetFilePelvis = findFileCaseInsensitive(dataFolder, 'S2', {movementKeyword});
% fprintf('Loading Pelvis movement -> %s\n', targetFilePelvis);
% Pelvis = loadIMUcsv(fullfile(dataFolder, targetFilePelvis));
% 
% % --- Left Thigh ---
% targetFileLThigh = findFileCaseInsensitive(dataFolder, 'LThigh', {movementKeyword});
% fprintf('Loading LThigh movement -> %s\n', targetFileLThigh);
% LThigh = loadIMUcsv(fullfile(dataFolder, targetFileLThigh));
% 
% % --- Left Shank ---
% targetFileLShank = findFileCaseInsensitive(dataFolder, 'LShank', {movementKeyword});
% fprintf('Loading LShank movement -> %s\n', targetFileLShank);
% LShank = loadIMUcsv(fullfile(dataFolder, targetFileLShank));
% 
% disp('All relevant files matching movement criteria have been loaded.');
% 
% %% ===================================================================== %%
% % SEGMENT ORIENTATIONS (Converting Sensor to Anatomical Frames)
% %% ===================================================================== %%
% 
% % Compute Anatomical Pelvis Orientation
% Rpelvis = computeSegmentOrientation( ...
%     Pelvis.Quat,...
%     Calibration.S2.RsegSens); % Matches your commented reference structure
% 
% % Compute Anatomical Left Thigh Orientation
% RLthigh = computeSegmentOrientation( ...
%     LThigh.Quat,...
%     Calibration.LThigh.RsegSens);
% 
% % Compute Anatomical Left Shank Orientation
% RLshank = computeSegmentOrientation( ...
%     LShank.Quat,...
%     Calibration.LShank.RsegSens);
% 
% %% ===================================================================== %%
% % JOINT ANGLE COMPUTATION (HIP & KNEE)
% %% ===================================================================== %%
% 
% % 1. Compute 3D Hip Angles (Grood & Suntay / ISB standard sequence)
% % NOTE: If your computeHipJCS function requires Calibration inputs, use the commented line below instead.
% LHip = computeHipJCS(Rpelvis, RLthigh); 
% 
% % LHip = computeHipJCS(Rpelvis, RLthigh, Calibration.S2, Calibration.LThigh);
% 
% 
% % 2. Compute 3D Knee Angles 
% LKnee = computeKneeJCS(RLthigh, RLshank); 
% 
% %% ===================================================================== %%
% % VISUALIZATION & PLOTTING
% %% ===================================================================== %%
% N = size(RLthigh, 3);
% time = (0:N-1)'/Fs;
% 
% % Plot Left Hip Angles
% plotAngles(time, LHip, 'Left Hip')
% 
% % Plot Left Knee Angles
% plotAngles(time, LKnee, 'Left Knee')
% 
% %% ===================================================================== %%
% % DATA EXPORT
% %% ===================================================================== %%
% exportExcel(time, LHip, fullfile(dataFolder, 'LeftHip_Angles_Output'));
% exportExcel(time, LKnee, fullfile(dataFolder, 'LeftKnee_Angles_Output'));
% 
% disp('Processing completed successfully. Excel reports saved for Hip and Knee.');
% 
% 
% %% ===================================================================== %%
% % LOCAL HELPER FUNCTIONS (Bypasses OS Case-Sensitivity)
% %% ===================================================================== %%
% function filename = findFileCaseInsensitive(folder, sensorName, keywords)
%     allFiles = dir(fullfile(folder, '*.csv'));
% 
%     if isempty(allFiles)
%         error('The selected folder does not contain any CSV files.');
%     end
% 
%     matchedIndices = [];
%     for k = 1:length(allFiles)
%         currentName = allFiles(k).name;
% 
%         if contains(lower(currentName), lower(sensorName))
%             allKeywordsMatch = true;
%             for w = 1:length(keywords)
%                 if ~contains(lower(currentName), lower(keywords{w}))
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
%         error('Missing movement file: Could not find a CSV file for sensor "%s" matching keywords [%s] in the folder.', sensorName, kwString);
%     end
% 
%     filename = allFiles(matchedIndices(1)).name; 
% end
% 
% 



% %% ===================================================================== %%
% % COMPUTE ANATOMICAL ORIENTATIONS (GLOBAL IMU POSITION * SENSOR CALIBRATION)
% %% ===================================================================== %%
% N = size(LThigh.Gyr, 1); % Get length of tracking frames
% R_Pelvis_Global = zeros(3,3,N);
% R_Thigh_Global  = zeros(3,3,N);
% R_Shank_Global  = zeros(3,3,N);
% 
% for k = 1:N
%     % Construct the current orientation matrix from tracking orientations 
%     % and project into the segment frames using your saved calibration results
%     R_Pelvis_Global(:,:,k) = Pelvis.Quat(:,:,k) * Calibration.S2.RsegSens;
%     R_Thigh_Global(:,:,k)  = LThigh.Quat(:,:,k) * Calibration.LThigh.RsegSens;
%     R_Shank_Global(:,:,k)  = LShank.Quat(:,:,k) * Calibration.LShank.RsegSens;
% end
% 
% %% ===================================================================== %%
% % COMPUTE JOINT COORDINATE SYSTEM ANGLES
% %% ===================================================================== %%
% disp('Computing Hip Joint Angles...');
% LHip = computeHipJCS(R_Pelvis_Global, R_Thigh_Global);
% 
% disp('Computing Knee Joint Angles...');
% LKnee = computeKneeJCS(R_Thigh_Global, R_Shank_Global);
% 
% %% ===================================================================== %%
% % VISUALIZATION / PLOTTING
% %% ===================================================================== %%
% time = (0:N-1)/Fs;
% 
% figure('Name', 'Lower Limb 3D Joint Angles', 'NumberTitle', 'off');
% 
% % --- ROW 1: HIP ANGLES ---
% subplot(2,3,1)
% plot(time, LHip.FlexExt, 'r', 'LineWidth', 1.5)
% title('Hip Flexion / Extension')
% xlabel('Time (s)'); ylabel('Angle (deg)'); grid on;
% 
% subplot(2,3,2)
% plot(time, LHip.AddAbd, 'g', 'LineWidth', 1.5)
% title('Hip Adduction / Abduction')
% xlabel('Time (s)'); ylabel('Angle (deg)'); grid on;
% 
% subplot(2,3,3)
% plot(time, LHip.IntExt, 'b', 'LineWidth', 1.5)
% title('Hip Internal / External Rotation')
% xlabel('Time (s)'); ylabel('Angle (deg)'); grid on;
% 
% % --- ROW 2: KNEE ANGLES ---
% subplot(2,3,4)
% plot(time, LKnee.FlexExt, 'r', 'LineWidth', 1.5)
% title('Knee Flexion / Extension')
% xlabel('Time (s)'); ylabel('Angle (deg)'); grid on;
% 
% subplot(2,3,5)
% plot(time, LKnee.VarusValgus, 'g', 'LineWidth', 1.5)
% title('Knee Varus / Valgus')
% xlabel('Time (s)'); ylabel('Angle (deg)'); grid on;
% 
% subplot(2,3,6)
% plot(time, LKnee.IntExt, 'b', 'LineWidth', 1.5)
% title('Knee Internal / External Rotation')
% xlabel('Time (s)'); ylabel('Angle (deg)'); grid on;

%% new version for our file format
%% Automated version considering the Hip joint angles
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MAIN_LOWERLIMBANGLES.M
%
% Automated Lower Limb Joint Angle Computation (Hip & Knee 3D Angles)
% Using Case-Insensitive Matching and Calibration Data
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc
close all

Fs = 60;

%% ===================================================================== %%
% INTERACTIVE FOLDER SELECTION & SETUP
%% ===================================================================== %%
% 1. Prompt user to select the trial/session directory
dataFolder = uigetdir(pwd, 'Select the folder containing CalibrationResults.mat and movement CSV files');
if dataFolder == 0
    error('No data folder selected. Script aborted.');
end

% 2. Load the previously generated calibration results from that folder
calibrationPath = fullfile(dataFolder, 'CalibrationResults.mat');
if ~exist(calibrationPath, 'file')
    error('Could not find CalibrationResults.mat in the selected folder. Please run calibration first.');
end
load(calibrationPath, 'Calibration');

%% ===================================================================== %%
% LOAD ACQUISITION FILES (AUTOMATED MATCHING)
%% ===================================================================== %%
disp('-------------------------------------------')
disp('LOADING MOVEMENT FILES (ROBUST MATCHING)')
disp('-------------------------------------------')

% Suffix phrase expected in the filename 
% movementKeyword = 'Hip_AA_movement'; 
movementKeyword = 'Knee_FE_movement'; 

% --- Pelvis ---
targetFilePelvis = findFileCaseInsensitive(dataFolder, 'S2', {movementKeyword});
fprintf('Loading Pelvis movement -> %s\n', targetFilePelvis);
Pelvis = loadIMUcsv(fullfile(dataFolder, targetFilePelvis));

% --- Left Thigh ---
% Updated sensor query string to match 'LT' from your file naming format
targetFileLThigh = findFileCaseInsensitive(dataFolder, 'LT', {movementKeyword});
fprintf('Loading LThigh movement -> %s\n', targetFileLThigh);
LThigh = loadIMUcsv(fullfile(dataFolder, targetFileLThigh));

% --- Left Shank ---
targetFileLShank = findFileCaseInsensitive(dataFolder, 'LShank', {movementKeyword});
fprintf('Loading LShank movement -> %s\n', targetFileLShank);
LShank = loadIMUcsv(fullfile(dataFolder, targetFileLShank));

disp('All relevant files matching movement criteria have been loaded.');

%% ===================================================================== %%
% SEGMENT ORIENTATIONS (Converting Sensor to Anatomical Frames)
%% ===================================================================== %%
% Compute Anatomical Pelvis Orientation
Rpelvis = computeSegmentOrientation( ...
    Pelvis.Quat,...
    Calibration.S2.RsegSens); 

% Compute Anatomical Left Thigh Orientation
% Updated structure mapping to look for Calibration.LT matching your file
RLthigh = computeSegmentOrientation( ...
    LThigh.Quat,...
    Calibration.LT.RsegSens);

% Compute Anatomical Left Shank Orientation
RLshank = computeSegmentOrientation( ...
    LShank.Quat,...
    Calibration.LShank.RsegSens);

%% ===================================================================== %%
% JOINT ANGLE COMPUTATION (HIP & KNEE)
%% ===================================================================== %%
% 1. Compute 3D Hip Angles (Grood & Suntay / ISB standard sequence)
LHip = computeHipJCS(Rpelvis, RLthigh); 

% 2. Compute 3D Knee Angles 
LKnee = computeKneeJCS(RLthigh, RLshank); 

%% ===================================================================== %%
% VISUALIZATION & PLOTTING
%% ===================================================================== %%
N = size(RLthigh, 3);
time = (0:N-1)'/Fs;

% Plot Left Hip Angles
plotAngles(time, LHip, 'Left Hip')

% Plot Left Knee Angles
plotAngles(time, LKnee, 'Left Knee')

%% ===================================================================== %%
% DATA EXPORT
%% ===================================================================== %%
exportExcel(time, LHip, fullfile(dataFolder, 'LeftHip_Angles_Output'));
exportExcel(time, LKnee, fullfile(dataFolder, 'LeftKnee_Angles_Output'));
disp('Processing completed successfully. Excel reports saved for Hip and Knee.');

%% ===================================================================== %%
% LOCAL HELPER FUNCTIONS (Bypasses OS Case-Sensitivity)
%% ===================================================================== %%
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
                kw = lower(keywords{w});
                % Flexibly handles keywords containing underscores, hyphens or spaces
                if ~contains(lower(currentName), kw) && ...
                   ~contains(lower(currentName), strrep(kw, '_', '')) && ...
                   ~contains(lower(currentName), strrep(kw, '_', '-'))
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
        error('Missing movement file: Could not find a CSV file for sensor "%s" matching keywords [%s] in the folder.', sensorName, kwString);
    end
    
    filename = allFiles(matchedIndices(1)).name; 
end

function Data = loadIMUcsv(filePath)
% Reads the custom CSV file layout and extracts standard Quaternions
opts = detectImportOptions(filePath);
opts.VariableNamingRule = 'preserve'; 
opts.TextType = 'string';

tbl = readtable(filePath, opts);

% Extract Quaternions matching your data tracking layout (Q0, Q1, Q2, Q3)
if all(ismember({'Q0', 'Q1', 'Q2', 'Q3'}, tbl.Properties.VariableNames))
    Data.Quat = [tbl.Q0, tbl.Q1, tbl.Q2, tbl.Q3];
else
    error('The file %s does not contain columns Q0, Q1, Q2, and Q3.', filePath);
end
end