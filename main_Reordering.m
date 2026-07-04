% %% Reorder IMU CSV files
% clear;
% clc;
% close all;
% 
% %% Select files
% [files,path] = uigetfile('*.csv',...
%     'Select CSV file(s)',...
%     'MultiSelect','on');
% 
% if isequal(files,0)
%     return;
% end
% 
% if ischar(files)
%     files = {files};
% end
% 
% %% Process each file
% for f = 1:length(files)
% 
%     filename = fullfile(path,files{f});
% 
%     fprintf('\nProcessing %s\n',files{f});
% 
%     %% Import exactly like your plotting script
%     opts = detectImportOptions(filename,...
%         'Delimiter',',',...
%         'VariableNamingRule','preserve');
% 
%     opts.VariableNamesLine = 1;
%     opts.DataLine = 2;
% 
%     T = readtable(filename,opts);
% 
%     %% Check required columns
%     if ~ismember('Timestamp_Arduino',T.Properties.VariableNames)
%         error('Column "Timestamp_Arduino" not found.');
%     end
% 
%     %% Count unordered timestamps before sorting
%     nWrong = sum(diff(T.Timestamp_Arduino) < 0);
% 
%     fprintf('Rows out of order before sorting : %d\n',nWrong);
% 
%     %% Sort WHOLE ROWS according to Arduino timestamp
%     T = sortrows(T,'Timestamp_Arduino');
% 
%     %% Verify
%     nWrongAfter = sum(diff(T.Timestamp_Arduino) < 0);
% 
%     fprintf('Rows out of order after sorting  : %d\n',nWrongAfter);
% 
%     %% Save
%     [~,name,ext] = fileparts(filename);
% 
%     newFile = fullfile(path,[name '_REORDERED' ext]);
% 
%     writetable(T,newFile);
% 
%     fprintf('Saved: %s\n',newFile);
% 
% end
% 
% disp('Done.')


%% 

% %% Reordering+synchronization PEAK DETECTION END START
% %% Reorder & Synchronize IMU CSV Files (Peak-to-Peak Alignment)
% clear;
% clc;
% close all;
% 
% %% 1. SELECT FILES MANUALLY
% [files, path] = uigetfile('*.csv', ...
%     'Select ALL CSV files to synchronize together', ...
%     'MultiSelect', 'on');
% 
% if isequal(files, 0)
%     disp('Selection canceled.');
%     return;
% end
% if ischar(files)
%     files = {files};
% end
% 
% numFiles = length(files);
% DataStorage = cell(numFiles, 1);
% CroppedData = cell(numFiles, 1);
% 
% % Define search windows for the peaks (in terms of frame buffers)
% % Adjust these if your sync hits happen further into the file
% startWindowFrames = 500; % Look into the first 500 rows for the initial sync hit
% endWindowFrames = 500;   % Look into the last 500 rows for the final sync hit
% 
% %% 2. STAGE 1: REORDER AND FIND SYNC PEAKS
% for f = 1:numFiles
%     filename = fullfile(path, files{f});
%     fprintf('\n--- Processing Stage 1: %s ---\n', files{f});
% 
%     opts = detectImportOptions(filename, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
%     opts.VariableNamesLine = 1;
%     opts.DataLine = 2;
%     T = readtable(filename, opts);
% 
%     % Verify mandatory synchronization headers
%     requiredCols = {'Timestamp_Arduino', 'Ax', 'Ay', 'Az'};
%     if ~all(ismember(requiredCols, T.Properties.VariableNames))
%         error('Missing required columns. File must contain Timestamp_Arduino, Ax, Ay, and Az.');
%     end
% 
%     % Sort structural rows sequentially according to Arduino internal clock
%     T = sortrows(T, 'Timestamp_Arduino');
% 
%     % Compute Accelerometer Vector Magnitude (Norm) for peak tracking
%     accMag = sqrt(double(T.Ax).^2 + double(T.Ay).^2 + double(T.Az).^2);
%     N_total = height(T);
% 
%     % --- Find Initial Sync Peak (Start of Acquisition) ---
%     searchStartEnd = min(startWindowFrames, N_total);
%     [~, localStartIdx] = max(accMag(1:searchStartEnd));
%     idxStart = localStartIdx;
% 
%     % --- Find Final Sync Peak (End of Acquisition) ---
%     searchEndStart = max(1, N_total - endWindowFrames + 1);
%     [~, localEndIdx] = max(accMag(searchEndStart:end));
%     idxEnd = searchEndStart + localEndIdx - 1;
% 
%     fprintf('Detected Start Sync Index: %d | End Sync Index: %d\n', idxStart, idxEnd);
% 
%     if idxStart >= idxEnd
%         error('Sync tracking failed. Start peak found after or at the end peak.');
%     end
% 
%     % Store sorted table data and crop coordinates
%     DataStorage{f}.Table = T;
%     DataStorage{f}.idxStart = idxStart;
%     DataStorage{f}.idxEnd = idxEnd;
%     DataStorage{f}.croppedLength = idxEnd - idxStart + 1;
% end
% 
% %% 3. STAGE 2: SYNCHRONIZE AND EQUALIZE ROW COUNT
% % Determine target uniform length baseline (using the longest cropped file)
% targetLength = max(cellfun(@(x) x.croppedLength, DataStorage));
% fprintf('\nTarget normalized row length for all outputs: %d rows\n', targetLength);
% 
% for f = 1:numFiles
%     T_raw = DataStorage{f}.Table;
%     iStart = DataStorage{f}.idxStart;
%     iEnd = DataStorage{f}.idxEnd;
% 
%     % Extract the physically aligned region (from initial hit to final hit)
%     T_cropped = T_raw(iStart:iEnd, :);
%     N_cropped = height(T_cropped);
% 
%     % Allocate a new table with the target synchronized layout
%     T_sync = table();
% 
%     % Original coordinate query grids for interpolation scaling
%     x_old = (1:N_cropped)';
%     x_new = linspace(1, N_cropped, targetLength)';
% 
%     % Re-sample variable contents across the uniform grid array
%     varNames = T_cropped.Properties.VariableNames;
%     for v = 1:length(varNames)
%         colName = varNames{v};
%         colData = T_cropped.(colName);
% 
%         if isnumeric(colData)
%             % Uniformly interpolate physical numbers across the synchronized sample block
%             T_sync.(colName) = interp1(x_old, double(colData), x_new, 'linear');
%         else
%             % Categorical/String variables are resized by nearest neighbor mapping
%             nearestIdx = round(interp1(x_old, 1:N_cropped, x_new, 'linear', 'extrap'));
%             nearestIdx = max(1, min(N_cropped, nearestIdx)); % Boundary safeguard
%             T_sync.(colName) = colData(nearestIdx);
%         end
%     end
% 
%     % Save data using the specified naming convention
%     [~, originalName, ext] = fileparts(files{f});
%     newFilename = fullfile(path, [originalName '_REORDERED' ext]);
%     writetable(T_sync, newFilename);
%     fprintf('Saved Aligned Matrix -> %s\n', [originalName '_REORDERED' ext]);
% end
% 
% disp('-----------------------------------------------------------');
% disp('Processing complete! All files match the exact same rows.');
% disp('-----------------------------------------------------------');


%% 
%% Reorder & Synchronize IMU CSV Files (Kinematic Cycle Alignment)
clear;
clc;
close all;

%% 1. SELECT FILES MANUALLY
[files, path] = uigetfile('*.csv', ...
    'Select ALL CSV files to synchronize together', ...
    'MultiSelect', 'on');

if isequal(files, 0)
    disp('Selection canceled.');
    return;
end
if ischar(files)
    files = {files};
end

numFiles = length(files);
DataStorage = cell(numFiles, 1);

% Cycle detection parameters
minDistanceFrames = 40; % Minimum frames between pedalling peaks (~1.5Hz max cadence at 60Hz)

%% 2. STAGE 1: REORDER AND DETECT CYCLES VIA QUATERNIONS
for f = 1:numFiles
    filename = fullfile(path, files{f});
    fprintf('\n--- Processing Stage 1 (Kinematics): %s ---\n', files{f});
    
    opts = detectImportOptions(filename, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    opts.VariableNamesLine = 1;
    opts.DataLine = 2;
    T = readtable(filename, opts);
    
    % Verify mandatory quaternion columns are present
    requiredQuats = {'Timestamp_Arduino', 'Q0', 'Q1', 'Q2', 'Q3'};
    if ~all(ismember(requiredQuats, T.Properties.VariableNames))
        error('Missing required columns. File must contain Timestamp_Arduino and Q0-Q3 fields.');
    end
    
    % Sort rows based on the internal Arduino clock sequence
    T = sortrows(T, 'Timestamp_Arduino');
    N_total = height(T);
    
    % --- Compute Orientation Displacement Angle ---
    % Track how far the segment rotates from its starting orientation frame
    q0 = [T.Q0, T.Q1, T.Q2, T.Q3];
    
    % Normalize quaternions just in case
    q0_norm = q0 ./ sqrt(sum(q0.^2, 2));
    
    % Reference quaternion (first valid frame orientation)
    q_ref = q0_norm(1, :);
    
    % Compute the relative rotation angle (theta) for every frame
    % cos(theta/2) = qA . qB
    dotProduct = sum(q0_norm .* q_ref, 2);
    dotProduct = max(-1, min(1, dotProduct)); % Avoid numerical floating clipping outside [-1, 1]
    rotAngle = 2 * acosd(abs(dotProduct));     % Symmetrical angular displacement in degrees
    
    % --- Identify Pedalling Cycle Boundaries (Troughs/Valleys) ---
    % Smooth slightly to remove any high-frequency IMU jitter before findpeaks
    rotAngleSmooth = movmean(rotAngle, 5);
    
    [~, troughIdx] = findpeaks(-rotAngleSmooth, 'MinPeakDistance', minDistanceFrames, 'MinPeakProminence', 3);
    
    if length(troughIdx) < 2
        error('Could not track distinctive movement cycles. Verify sensor data quality.');
    end
    
    % Define the synchronized active region: From the FIRST detected trough to the LAST one
    idxStart = troughIdx(1);
    idxEnd = troughIdx(end);
    
    fprintf('Detected Movement Window -> Start Row: %d | End Row: %d (Total Cycles: %d)\n', ...
        idxStart, idxEnd, length(troughIdx)-1);
    
    DataStorage{f}.Table = T;
    DataStorage{f}.idxStart = idxStart;
    DataStorage{f}.idxEnd = idxEnd;
    DataStorage{f}.croppedLength = idxEnd - idxStart + 1;
end

%% 3. STAGE 2: RESAMPLE AND SAVE SYNCHRONIZED REORDERED DATA
% Use the longest active data file duration as our uniform grid size baseline
targetLength = max(cellfun(@(x) x.croppedLength, DataStorage));
fprintf('\nTarget uniform row length for matching datasets: %d rows\n', targetLength);

for f = 1:numFiles
    T_raw = DataStorage{f}.Table;
    iStart = DataStorage{f}.idxStart;
    iEnd = DataStorage{f}.idxEnd;
    
    % Crop between the uniform movement cycle landmarks
    T_cropped = T_raw(iStart:iEnd, :);
    N_cropped = height(T_cropped);
    
    T_sync = table();
    x_old = (1:N_cropped)';
    x_new = linspace(1, N_cropped, targetLength)';
    
    varNames = T_cropped.Properties.VariableNames;
    for v = 1:length(varNames)
        colName = varNames{v};
        colData = T_cropped.(colName);
        
        if isnumeric(colData)
            % Resample numeric kinematic tracking parameters uniformly
            T_sync.(colName) = interp1(x_old, double(colData), x_new, 'linear');
        else
            % Map categorical strings using nearest-neighbor index adjustments
            nearestIdx = round(interp1(x_old, 1:N_cropped, x_new, 'linear', 'extrap'));
            nearestIdx = max(1, min(N_cropped, nearestIdx));
            T_sync.(colName) = colData(nearestIdx);
        end
    end
    
    % Save with the standard '_REORDERED' suffix
    [~, originalName, ext] = fileparts(files{f});
    newFilename = fullfile(path, [originalName '_REORDERED' ext]);
    writetable(T_sync, newFilename);
    fprintf('Saved Aligned Movement Matrix -> %s\n', [originalName '_REORDERED' ext]);
end

disp('-----------------------------------------------------------');
disp('Sync complete! Datasets match down to the exact same rows.');
disp('-----------------------------------------------------------');