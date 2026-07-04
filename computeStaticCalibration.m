function RsegSens = computeStaticCalibration(Quat)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Computes the sensor-to-segment rotation matrix
% according to the Movella DOT static calibration.
%
% INPUT
%
% Quat : Nx4 quaternion
%
% OUTPUT
%
% RsegSens : 3x3
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Average quaternion

q = meanQuaternion(Quat);

%% Normalize

q = q/norm(q);

%% Quaternion -> rotation matrix

RSL = quat2rotm(q);

%% Sensor-to-segment

RsegSens = RSL';

end