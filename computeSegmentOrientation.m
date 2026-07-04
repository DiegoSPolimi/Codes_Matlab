% function RsegGlobal = computeSegmentOrientation(Quat,RsegSens)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %
% % INPUTS
% %
% % Quat      : Nx4 quaternion matrix [w x y z]
% %
% % RsegSens  : 3x3 calibration matrix
% %
% % OUTPUT
% %
% % RsegGlobal(:,:,k)
% %
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% N = size(Quat,1);
% 
% RsegGlobal = zeros(3,3,N);
% 
% for k = 1:N
% 
%     q = quaternion(Quat(k,:));
% 
%     RsensGlobal = rotmat(q,'frame');
% 
%     RsegGlobal(:,:,k) = RsensGlobal * RsegSens; % we get the global orientation of the segment from the global orientation of the IMU on the segment and knowing the rotational offset between the segment and the IMU
% 
% end
% 
% end

function RsegGlobal = computeSegmentOrientation(Quat,RsegSens)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INPUTS
% Quat      : Nx4 quaternion matrix [w x y z]
% RsegSens  : 3x3 calibration matrix (Segment axes relative to Sensor)
%
% OUTPUT
% RsegGlobal(:,:,k) : Matrix whose COLUMNS are the segment axes in Global coordinates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
N = size(Quat,1);
RsegGlobal = zeros(3,3,N);
for k = 1:N
    q = quaternion(Quat(k,:));
    
    % 'point' outputs the Sensor -> Global matrix
    RsensGlobal = rotmat(q, 'point'); 
    
    % (Sensor -> Global) * (Segment -> Sensor) = Segment -> Global
    RsegGlobal(:,:,k) = RsensGlobal * RsegSens; 
end
end