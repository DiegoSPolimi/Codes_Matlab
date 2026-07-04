%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MAIN_LOWERLIMBANGLES_MANUAL.M
%
% Manual Lower Limb Joint Angle Computation (Hip & Pelvis 3D Angles)
% Tailored for manual selection of movement CSV files with pedalling cycle 
% segmentation, time-normalization, and ensemble plotting.
% Updated to process BOTH Left and Right Thigh configurations.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc
close all
Fs = 60;
%% ===================================================================== %%
% INTERACTIVE FOLDER SELECTION & SETUP
%% ===================================================================== %%
dataFolder = uigetdir(pwd, 'Select the folder containing CalibrationResults.mat');
if dataFolder == 0
    error('No data folder selected. Script aborted.');
end
calibrationPath = fullfile(dataFolder, 'CalibrationResults.mat');
if ~exist(calibrationPath, 'file')
    error('Could not find CalibrationResults.mat in the selected folder. Run calibration first.');
end
load(calibrationPath, 'Calibration');
%% ===================================================================== %%
% LOAD MOVEMENT FILES MANUALLY
%% ===================================================================== %%
disp('-------------------------------------------')
disp('MANUALLY SELECTING MOVEMENT FILES')
disp('-------------------------------------------')
% --- Pelvis ---
[filePelvis, pathPelvis] = uigetfile(fullfile(dataFolder, '*.csv'), 'Select the Pelvis (S2) Synchronized CSV File');
if filePelvis == 0, error('Pelvis file selection canceled. Script aborted.'); end
fprintf('Loading Manual Pelvis -> %s\n', filePelvis);
Pelvis = loadCleanIMUcsv(fullfile(pathPelvis, filePelvis));

% --- Left Thigh ---
[fileLThigh, pathLThigh] = uigetfile(fullfile(dataFolder, '*.csv'), 'Select the Left Thigh (LT) Synchronized CSV File');
if fileLThigh == 0, error('Left Thigh file selection canceled. Script aborted.'); end
fprintf('Loading Manual LThigh -> %s\n', fileLThigh);
LThigh = loadCleanIMUcsv(fullfile(pathLThigh, fileLThigh));

% --- Right Thigh ---
[fileRThigh, pathRThigh] = uigetfile(fullfile(dataFolder, '*.csv'), 'Select the Right Thigh (RT) Synchronized CSV File');
if fileRThigh == 0, error('Right Thigh file selection canceled. Script aborted.'); end
fprintf('Loading Manual RThigh -> %s\n', fileRThigh);
RThigh = loadCleanIMUcsv(fullfile(pathRThigh, fileRThigh));

disp('All selected segments successfully loaded.');

%% ===================================================================== %%
% SEGMENT ORIENTATIONS (Converting Sensor to Anatomical Frames)
%% ===================================================================== %%
% Compute Anatomical Pelvis Orientation
Rpelvis = computeSegmentOrientation(Pelvis.Quat, Calibration.S2.RsegSens); 
% Compute Anatomical Left Thigh Orientation (Matches 'LT' mapping structure)
RLthigh = computeSegmentOrientation(LThigh.Quat, Calibration.LT.RsegSens);
% Compute Anatomical Right Thigh Orientation (Matches 'RT' mapping structure)
RRthigh = computeSegmentOrientation(RThigh.Quat, Calibration.RT.RsegSens);

%% ===================================================================== %%
% RESOLVE LENGTH MISMATCHES (Minimum Common Row Length Strategy)
%% ===================================================================== %%
% Determine the minimum length among orientation matrix frames across ALL segments
N_min = min([size(Rpelvis, 3), size(RLthigh, 3), size(RRthigh, 3)]);
% Crop orientation segments to the shared minimum window
Rpelvis = Rpelvis(:, :, 1:N_min);
RLthigh = RLthigh(:, :, 1:N_min);
RRthigh = RRthigh(:, :, 1:N_min);
% Establish the uniform sample master clock
time = (0:N_min-1)'/Fs;

%% ===================================================================== %%
% JOINT ANGLE COMPUTATION (HIP & PELVIS GLOBAL)
%% ===================================================================== %%
disp('Computing Hip and Pelvis Kinematics...');
LHip = computeHipJCS(Rpelvis, RLthigh); 
RHip = computeHipJCS(Rpelvis, RRthigh); 

% Compute Pelvis Angles relative to Global Frame
PelvisGlobal = computePelvisGlobalAngles(Rpelvis);

% Double-check structure field slicing consistency with N_min
LHip.FlexExt = LHip.FlexExt(1:N_min);
LHip.AbdAdd  = LHip.AbdAdd(1:N_min);
LHip.IntExt  = LHip.IntExt(1:N_min);

RHip.FlexExt = RHip.FlexExt(1:N_min);
RHip.AbdAdd  = RHip.AbdAdd(1:N_min);
RHip.IntExt  = RHip.IntExt(1:N_min);

PelvisGlobal.Tilt      = PelvisGlobal.Tilt(1:N_min);
PelvisGlobal.Obliquity = PelvisGlobal.Obliquity(1:N_min);
PelvisGlobal.Rotation  = PelvisGlobal.Rotation(1:N_min);


%% ===================================================================== %%
% VISUALIZATION & PLOTTING (CONTINUOUS PROFILE TIME CLOCK)
%% ===================================================================== %%
% Plot pelvis angle 
plotAngles(time, PelvisGlobal, 'Pelvis')
% Plot Left Hip Angles
plotAngles(time, LHip, 'Left Hip')
% Plot Right Hip Angles
plotAngles(time, RHip, 'Right Hip')



%% ===================================================================== %%
% CYCLE SEGMENTATION & TIME-NORMALIZATION (PEDALLING)
%% ===================================================================== %%
% Extract Hip Flexion for cycle segmentation (Using Left Hip as master reference)
hipFlexion = double(LHip.FlexExt); 
% Find local minima (maximum flexion points)
[~, troughIndices] = findpeaks(-hipFlexion, 'MinPeakDistance', 40, 'MinPeakProminence', 2);
numCycles = length(troughIndices) - 1;
if numCycles < 2
    error('Not enough pedalling cycles detected. Check the findpeaks settings.');
end
% Initialize normalized matrices (0 to 100% cycle, sampled at 101 points)
tNorm = linspace(0, 100, 101)';
xConf = [tNorm'; flipud(tNorm)']; 

normHip.FlexExt = zeros(101, numCycles);
normHip.AbdAdd  = zeros(101, numCycles);
normHip.IntExt  = zeros(101, numCycles);

normRHip.FlexExt = zeros(101, numCycles);
normRHip.AbdAdd  = zeros(101, numCycles);
normRHip.IntExt  = zeros(101, numCycles);

normPelvis.Tilt      = zeros(101, numCycles);
normPelvis.Obliquity = zeros(101, numCycles);
normPelvis.Rotation  = zeros(101, numCycles);

% Extract and interpolate each individual cycle
for c = 1:numCycles
    idxStart = troughIndices(c);
    idxEnd = troughIndices(c+1);
    cycleLen = idxEnd - idxStart + 1;
    
    % Raw cycle timeline
    tRaw = linspace(0, 100, cycleLen)';
    
    % Interpolate Left Hip Angles structural fields
    normHip.FlexExt(:, c) = interp1(tRaw, double(LHip.FlexExt(idxStart:idxEnd)), tNorm, 'spline');
    normHip.AbdAdd(:, c)  = interp1(tRaw, double(LHip.AbdAdd(idxStart:idxEnd)), tNorm, 'spline');
    normHip.IntExt(:, c)  = interp1(tRaw, double(LHip.IntExt(idxStart:idxEnd)), tNorm, 'spline');
    
    % Interpolate Right Hip Angles structural fields
    normRHip.FlexExt(:, c) = interp1(tRaw, double(RHip.FlexExt(idxStart:idxEnd)), tNorm, 'spline');
    normRHip.AbdAdd(:, c)  = interp1(tRaw, double(RHip.AbdAdd(idxStart:idxEnd)), tNorm, 'spline');
    normRHip.IntExt(:, c)  = interp1(tRaw, double(RHip.IntExt(idxStart:idxEnd)), tNorm, 'spline');
    
    % Interpolate Pelvis Angles structural fields
    normPelvis.Tilt(:, c)      = interp1(tRaw, double(PelvisGlobal.Tilt(idxStart:idxEnd)), tNorm, 'spline');
    normPelvis.Obliquity(:, c) = interp1(tRaw, double(PelvisGlobal.Obliquity(idxStart:idxEnd)), tNorm, 'spline');
    normPelvis.Rotation(:, c)  = interp1(tRaw, double(PelvisGlobal.Rotation(idxStart:idxEnd)), tNorm, 'spline');
end

% Compute Means and Standard Deviations across the columns (dimension 2)
meanHip.FlexExt = mean(normHip.FlexExt, 2); stdHip.FlexExt = std(normHip.FlexExt, 0, 2);
meanHip.AbdAdd  = mean(normHip.AbdAdd, 2);  stdHip.AbdAdd  = std(normHip.AbdAdd, 0, 2);
meanHip.IntExt  = mean(normHip.IntExt, 2);  stdHip.IntExt  = std(normHip.IntExt, 0, 2);

meanRHip.FlexExt = mean(normRHip.FlexExt, 2); stdRHip.FlexExt = std(normRHip.FlexExt, 0, 2);
meanRHip.AbdAdd  = mean(normRHip.AbdAdd, 2);  stdRHip.AbdAdd  = std(normRHip.AbdAdd, 0, 2);
meanRHip.IntExt  = mean(normRHip.IntExt, 2);  stdRHip.IntExt  = std(normRHip.IntExt, 0, 2);

meanPelvis.Tilt      = mean(normPelvis.Tilt, 2);      stdPelvis.Tilt      = std(normPelvis.Tilt, 0, 2);
meanPelvis.Obliquity = mean(normPelvis.Obliquity, 2); stdPelvis.Obliquity = std(normPelvis.Obliquity, 0, 2);
meanPelvis.Rotation  = mean(normPelvis.Rotation, 2);  stdPelvis.Rotation  = std(normPelvis.Rotation, 0, 2);
%% ===================================================================== %%
% VISUALIZATION & PLOTTING (JOURNAL QUALITY - CYCLES)
%% ===================================================================== %%
% --- Plot Left Hip Angles ---
figure('Name', 'Left Hip Joint Kinematics (Pedalling Cycles)', 'Color', 'w');
hipFields = {'FlexExt', 'AbdAdd', 'IntExt'};
hipLabels = {'Flexion (+)/Extension (-)', 'Adduction (+)/Abduction (-)', 'Internal (+)/External (-) Rotation'};
for i = 1:3
    subplot(3, 1, i);
    hold on;
    fName = hipFields{i};
    
    plot(tNorm, normHip.(fName), 'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
    curve1 = meanHip.(fName) + stdHip.(fName);
    curve2 = meanHip.(fName) - stdHip.(fName);
    yConf = [curve1'; flipud(curve2)'];
    fill(xConf, yConf, [0.85 0.85 0.85], 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(tNorm, meanHip.(fName), 'k', 'LineWidth', 2.5);
    
    title(['Left Hip: ' hipLabels{i}]);
    xlabel('Pedalling Cycle (%)');
    ylabel('Angle (deg)');
    xlim([0 100]);
    grid on;
    if i == 1, legend('Individual Cycles', 'Mean Cycle', 'Location', 'best'); end
end

% --- Plot Right Hip Angles ---
figure('Name', 'Right Hip Joint Kinematics (Pedalling Cycles)', 'Color', 'w');
for i = 1:3
    subplot(3, 1, i);
    hold on;
    fName = hipFields{i};
    
    plot(tNorm, normRHip.(fName), 'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
    curve1 = meanRHip.(fName) + stdRHip.(fName);
    curve2 = meanRHip.(fName) - stdRHip.(fName);
    yConf = [curve1'; flipud(curve2)'];
    fill(xConf, yConf, [0.85 0.85 0.85], 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(tNorm, meanRHip.(fName), 'b', 'LineWidth', 2.5); % Blue line color for differentiation
    
    title(['Right Hip: ' hipLabels{i}]);
    xlabel('Pedalling Cycle (%)');
    ylabel('Angle (deg)');
    xlim([0 100]);
    grid on;
    if i == 1, legend('Individual Cycles', 'Mean Cycle', 'Location', 'best'); end
end

% --- Plot Pelvis Global Angles ---
figure('Name', 'Pelvis Global Kinematics (Pedalling Cycles)', 'Color', 'w');
pelvisFields = {'Tilt', 'Obliquity', 'Rotation'};
pelvisLabels = {'Pelvic Tilt (Anterior/Posterior)', 'Pelvic Obliquity (Lateral Drop)', 'Pelvic Rotation'};
for i = 1:3
    subplot(3, 1, i);
    hold on;
    fName = pelvisFields{i};
    
    plot(tNorm, normPelvis.(fName), 'Color', [0.75 0.75 0.75], 'LineWidth', 0.5);
    curve1 = meanPelvis.(fName) + stdPelvis.(fName);
    curve2 = meanPelvis.(fName) - stdPelvis.(fName);
    yConf = [curve1'; flipud(curve2)'];
    fill(xConf, yConf, [0.85 0.85 0.85], 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(tNorm, meanPelvis.(fName), 'k', 'LineWidth', 2.5);
    
    title(pelvisLabels{i});
    xlabel('Pedalling Cycle (%)');
    ylabel('Angle (deg)');
    xlim([0 100]);
    grid on;
end
%% ===================================================================== %%
% DATA EXPORT
%% ===================================================================== %%
LHip_Matrix = [double(LHip.FlexExt), double(LHip.AbdAdd), double(LHip.IntExt)];
exportExcel(time, LHip_Matrix, fullfile(dataFolder, 'LeftHip_Angles_Output'));

RHip_Matrix = [double(RHip.FlexExt), double(RHip.AbdAdd), double(RHip.IntExt)];
exportExcel(time, RHip_Matrix, fullfile(dataFolder, 'RightHip_Angles_Output'));

disp('Processing completed successfully. Kinematic plots generated.');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOCAL HELPER FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Data = loadCleanIMUcsv(filePath)
    opts = detectImportOptions(filePath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    opts.VariableNamesLine = 1;
    opts.DataLine = 2;
    T = readtable(filePath, opts);
    if all(ismember({'Q0', 'Q1', 'Q2', 'Q3'}, T.Properties.VariableNames))
        Data.Quat = [T.Q0, T.Q1, T.Q2, T.Q3];
    else
        error('The file %s is missing the required columns Q0, Q1, Q2, or Q3.', filePath);
    end
end
function PelvisGlobal = computePelvisGlobalAngles(Rpelvis)
    N = size(Rpelvis, 3);
    PelvisGlobal.Tilt      = zeros(N, 1);
    PelvisGlobal.Obliquity = zeros(N, 1);
    PelvisGlobal.Rotation  = zeros(N, 1);
    
    for i = 1:N
        R = Rpelvis(:, :, i);
        [yaw, pitch, roll] = ea2euler(R); 
        
        PelvisGlobal.Tilt(i)      = pitch * (180/pi); 
        PelvisGlobal.Obliquity(i) = roll * (180/pi);  
        PelvisGlobal.Rotation(i)  = yaw * (180/pi);   
    end
end
function [yaw, pitch, roll] = ea2euler(R)
    pitch = -asin(R(3,1));
    if cos(pitch) > 1e-4
        yaw   = atan2(R(2,1), R(1,1));
        roll  = atan2(R(3,2), R(3,3));
    else
        yaw   = 0;
        roll  = atan2(-R(1,2), R(2,2));
    end
end