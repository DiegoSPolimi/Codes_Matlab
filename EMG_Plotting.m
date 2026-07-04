% %% Load CSV file
% clear; clc; close all;
% 
% filename = 'Live_AA92DDD35720_20260702_160623.csv';
% data = readtable(filename);
% 
% %% Time vector
% % Arduino timestamp (ms)
% time = data.Timestamp_Arduino;
% 
% % Convert to seconds starting at 0
% time = (time - time(1))/1000;
% 
% %% Extract EMG envelopes
% Right_TFL = data.Env1;
% Left_TFL  = data.Env2;
% Right_GMed = data.Env3;
% Left_GMed  = data.Env4;
% 
% %% Plot
% figure('Color','w','Position',[100 100 1000 700]);
% 
% subplot(4,1,1)
% plot(time, Right_TFL,'b','LineWidth',1.5)
% grid on
% ylabel('EMG')
% title('Right Tensor Fasciae Latae (TFL)')
% xlim([time(1) time(end)])
% 
% subplot(4,1,2)
% plot(time, Left_TFL,'r','LineWidth',1.5)
% grid on
% ylabel('EMG')
% title('Left Tensor Fasciae Latae (TFL)')
% xlim([time(1) time(end)])
% 
% subplot(4,1,3)
% plot(time, Right_GMed,'g','LineWidth',1.5)
% grid on
% ylabel('EMG')
% title('Right Gluteus Medius')
% xlim([time(1) time(end)])
% 
% subplot(4,1,4)
% plot(time, Left_GMed,'m','LineWidth',1.5)
% grid on
% xlabel('Time (s)')
% ylabel('EMG')
% title('Left Gluteus Medius')
% xlim([time(1) time(end)])
% 
% sgtitle('EMG Envelope Signals')

%% Load CSV file
%% Select CSV file
clear; clc; close all;

[file,path] = uigetfile('*.csv','Select the EMG CSV file');

if isequal(file,0)
    error('No file selected.');
end

filename = fullfile(path,file);

%% Import options
opts = detectImportOptions(filename,...
    'Delimiter',',',...
    'VariableNamingRule','preserve');

% Tell MATLAB that the first row contains the headers
opts.VariableNamesLine = 1;
opts.DataLine = 2;

% Read the table
data = readtable(filename,opts);

% Display imported variable names
disp(data.Properties.VariableNames)
%% Time vector
% Arduino timestamp (ms)
time = data.Timestamp_Arduino;

% Convert to seconds starting at 0
% time = (time - time(1))/1000;

%% Extract EMG envelopes
Right_TFL  = data.Env1;
Right_GMed    = data.Env2;
Left_TFL= data.Env3;
Left_GMed  = data.Env4;

%% Plot
% figure('Color','w','Position',[100 100 1000 700]);
% 
% subplot(4,1,1)
% plot(time, Right_TFL,'b','LineWidth',1.5)
% grid on
% ylabel('EMG')
% title('Right Tensor Fasciae Latae (TFL)')
% xlim([time(1) time(end)])
% 
% subplot(4,1,2)
% plot(time, Left_TFL,'r','LineWidth',1.5)
% grid on
% ylabel('EMG')
% title('Left Tensor Fasciae Latae (TFL)')
% xlim([time(1) time(end)])
% 
% subplot(4,1,3)
% plot(time, Right_GMed,'g','LineWidth',1.5)
% grid on
% ylabel('EMG')
% title('Right Gluteus Medius')
% xlim([time(1) time(end)])
% 
% subplot(4,1,4)
% plot(time, Left_GMed,'m','LineWidth',1.5)
% grid on
% xlabel('Time (s)')
% ylabel('EMG')
% title('Left Gluteus Medius')
% xlim([time(1) time(end)])
% 
% sgtitle(sprintf('EMG Envelope Signals\n%s', file))




figure();

subplot(4,1,1)
plot(Right_TFL,'b','LineWidth',1.5)
grid on
ylabel('EMG')
title('Right Tensor Fasciae Latae (TFL)')


subplot(4,1,2)
plot(Left_TFL,'r','LineWidth',1.5)
grid on
ylabel('EMG')
title('Left Tensor Fasciae Latae (TFL)')

subplot(4,1,3)
plot(Right_GMed,'g','LineWidth',1.5)
grid on
ylabel('EMG')
title('Right Gluteus Medius')

subplot(4,1,4)
plot(Left_GMed,'m','LineWidth',1.5)
grid on
xlabel('Time (s)')
ylabel('EMG')
title('Left Gluteus Medius')

