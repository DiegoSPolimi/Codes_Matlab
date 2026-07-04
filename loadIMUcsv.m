% function Data = loadIMUcsv(filename)
% 
% T = readtable(filename);
% 
% Data.Time = T.SampleTimeFine;
% 
% Data.Quat = [ ...
%     T.Quat_W ...
%     T.Quat_X ...
%     T.Quat_Y ...
%     T.Quat_Z ];
% 
% Data.Acc = [ ...
%     T.Acc_X ...
%     T.Acc_Y ...
%     T.Acc_Z ];
% 
% Data.Gyr = [ ...
%     T.Gyr_X ...
%     T.Gyr_Y ...
%     T.Gyr_Z ];
% 
% end

% function Data = loadIMUcsv(filePath)
% % Reads the custom CSV file layout cleanly using default import rules
% opts = detectImportOptions(filePath);
% opts.VariableNamingRule = 'preserve'; 
% 
% % Read the table using safe configurations
% tbl = readtable(filePath, opts);
% 
% % Extract Quaternions matching your exact columns: Q0, Q1, Q2, Q3
% if all(ismember({'Q0', 'Q1', 'Q2', 'Q3'}, tbl.Properties.VariableNames))
%     Data.Quat = [tbl.Q0, tbl.Q1, tbl.Q2, tbl.Q3];
% else
%     error('The file %s does not contain the columns Q0, Q1, Q2, and Q3.', filePath);
% end
% end

function Data = loadIMUcsv(filePath)
% Reads the custom CSV file layout cleanly using default import rules
opts = detectImportOptions(filePath);
opts.VariableNamingRule = 'preserve'; 

% Read the table using safe configurations
tbl = readtable(filePath, opts);

% Extract Quaternions matching your exact columns: Q0, Q1, Q2, Q3
if all(ismember({'Q0', 'Q1', 'Q2', 'Q3'}, tbl.Properties.VariableNames))
    Data.Quat = [tbl.Q0, tbl.Q1, tbl.Q2, tbl.Q3];
else
    error('The file %s does not contain the columns Q0, Q1, Q2, and Q3.', filePath);
end
end