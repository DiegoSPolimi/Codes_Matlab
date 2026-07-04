%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 01_CALIBRATION
%
% Static calibration modified for custom CSV format.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc
close all

%% ===================================================================== %%
% SENSOR LIST
%% ===================================================================== %%
% Updated to match the prefix 'LT' found in your attached file name
Sensors = { ...
    'S2',...
    'LT',... 
    'RT'};
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
        StaticKeywords = {'static','n_pose'}; % Adjusted 'npose' to 'n_pose' to match your filename
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
disp('STATIC CALIBRATION')
disp('==============================================')
for i=1:nSensors
    sensor = Sensors{i};
    
    % Skip or handle missing files dynamically if you don't have all sensors yet
    try
        filename = findFileCaseInsensitive( ...
            dataFolder,...
            sensor,...
            StaticKeywords);
    catch ME
        warning('%s. Skipping this sensor.', ME.message);
        continue;
    end
    
    fprintf('\n%s\n',sensor)
    disp(filename)
    
    % Using the custom reader function defined below
    Data = loadIMUcsv(fullfile(dataFolder,filename));
    
    Calibration.(sensor).RsegSens = ...
        computeStaticCalibration( ...
        Data.Quat);
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
% VERIFY ORTHOGONALITY
%% ===================================================================== %%
disp(' ')
disp('Verification of rotation matrices')
fields = fieldnames(Calibration);
for i=1:length(fields)
    sensor = fields{i};
    R = Calibration.(sensor).RsegSens;
    fprintf('\n%s\n',sensor)
    fprintf('det(R) = %.4f\n',det(R))
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
    if contains(name,lower(sensorName))
        ok = true;
        for w=1:length(keywords)
            % Replaced underscores with hyphens/spaces check for flexibility
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

function Data = loadIMUcsv(filePath)
% Reads the custom CSV file with a single header row and extracts Quaternions
opts = detectImportOptions(filePath);
opts.VariableNamingRule = 'preserve'; 
opts.TextType = 'string';

tbl = readtable(filePath, opts);

% Extract Quaternions matching your exact columns: Q0, Q1, Q2, Q3
if all(ismember({'Q0', 'Q1', 'Q2', 'Q3'}, tbl.Properties.VariableNames))
    Data.Quat = [tbl.Q0, tbl.Q1, tbl.Q2, tbl.Q3];
else
    error('The file %s does not contain the columns Q0, Q1, Q2, and Q3.', filePath);
end
end