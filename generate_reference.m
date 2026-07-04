%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GENERATE_REFERENCE.M
%
% Golden-reference generator for the MATLAB -> Python translation.
% Drives the repository's LIVE functions on the real sample data in
% Example_Acquisitions/ and writes reference CSVs to reference/.
%
% Run once in MATLAB from the repo root:  >> generate_reference
% Then launch the /loop; the Python tests diff against reference/*.csv.
%
% NOTE: knee angles are generated using LT as "thigh" and RT as "shank"
% purely as a NUMERIC regression of computeKneeJCS (there is no shank
% sensor in the sample data, so this is not biomechanically meaningful --
% it only locks the arithmetic so the Python port matches exactly).
%
% TOOLBOX-FREE: the repo's computeStaticCalibration/computeSegmentOrientation
% call quat2rotm/quaternion/rotmat (Robotics/Nav/UAV Toolbox). Those are
% reproduced here with local_q2R, which implements the standard ACTIVE
% rotation matrix from a SCALAR-FIRST [w x y z] unit quaternion. This is
% identical to quat2rotm(q) and to rotmat(quaternion(q),'point'). Python
% must match this exactly: scipy Rotation.from_quat([x,y,z,w]).as_matrix().
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; clc;

repoRoot = fileparts(mfilename('fullpath'));
addpath(repoRoot);
dataDir = fullfile(repoRoot,'Example_Acquisitions');
outDir  = fullfile(repoRoot,'reference');
if ~exist(outDir,'dir'); mkdir(outDir); end

readQ = @(f) local_readQuat(fullfile(dataDir,f));

%% 1. Static quaternions (raw input echoed back so Python reads the same values)
Q_S2_static = readQ('S2_20260703_172624_Static_N_Pose.csv');
Q_LT_static = readQ('LT_20260703_172624_Static_N_Pose.csv');
Q_RT_static = readQ('RT_20260703_172624_Static_N_Pose.csv');

%% 2. meanQuaternion  (feed LT static quats)
qMean_LT = meanQuaternion(Q_LT_static);           % 1x4
writematrix(qMean_LT, fullfile(outDir,'ref_meanQuaternion_LT.csv'));

%% 3. computeStaticCalibration -> RsegSens (3x3) per sensor
%    (local_staticCalib mirrors computeStaticCalibration.m without the toolbox)
R_S2 = local_staticCalib(Q_S2_static);
R_LT = local_staticCalib(Q_LT_static);
R_RT = local_staticCalib(Q_RT_static);
writematrix(R_S2, fullfile(outDir,'ref_RsegSens_S2.csv'));
writematrix(R_LT, fullfile(outDir,'ref_RsegSens_LT.csv'));
writematrix(R_RT, fullfile(outDir,'ref_RsegSens_RT.csv'));

%% 4. computeSegmentOrientation over a movement trial (S2 + LT + RT), cropped
Q_S2_mov = readQ('S2_20260703_172940.csv');
Q_LT_mov = readQ('LT_20260703_172940.csv');
Q_RT_mov = readQ('RT_20260703_172940.csv');
N = min([size(Q_S2_mov,1), size(Q_LT_mov,1), size(Q_RT_mov,1)]);
Q_S2_mov = Q_S2_mov(1:N,:);
Q_LT_mov = Q_LT_mov(1:N,:);
Q_RT_mov = Q_RT_mov(1:N,:);

% (local_segOrient mirrors computeSegmentOrientation.m 'point' path w/o toolbox)
Rpelvis = local_segOrient(Q_S2_mov, R_S2);   % 3x3xN
RLthigh = local_segOrient(Q_LT_mov, R_LT);
RRthigh = local_segOrient(Q_RT_mov, R_RT);

% Flatten 3x3xN -> Nx9 (row-major per frame: r11 r12 r13 r21 ... r33)
writematrix(local_flatten(Rpelvis), fullfile(outDir,'ref_RsegGlobal_S2.csv'));
writematrix(local_flatten(RLthigh), fullfile(outDir,'ref_RsegGlobal_LT.csv'));
writematrix(local_flatten(RRthigh), fullfile(outDir,'ref_RsegGlobal_RT.csv'));

%% 5. computeHipJCS  (pelvis S2 + thigh LT/RT) -> FlexExt/AbdAdd/IntExt
LHip = computeHipJCS(Rpelvis, RLthigh);
RHip = computeHipJCS(Rpelvis, RRthigh);
writematrix([LHip.FlexExt(:) LHip.AbdAdd(:) LHip.IntExt(:)], ...
    fullfile(outDir,'ref_LHip_angles.csv'));
writematrix([RHip.FlexExt(:) RHip.AbdAdd(:) RHip.IntExt(:)], ...
    fullfile(outDir,'ref_RHip_angles.csv'));

%% 6. computeKneeJCS  (LT as thigh, RT as shank -- numeric regression only)
Knee = computeKneeJCS(RLthigh, RRthigh);
writematrix([Knee.FlexExt(:) Knee.VarusValgus(:) Knee.IntExt(:)], ...
    fullfile(outDir,'ref_Knee_angles.csv'));

%% 7. Pelvis-vs-global angles  (mirrors the local functions in
%    main_Compute_Angles_MANUAL.m -- copied here because they are not on the path)
PG = local_pelvisGlobal(Rpelvis);
writematrix([PG.Tilt(:) PG.Obliquity(:) PG.Rotation(:)], ...
    fullfile(outDir,'ref_PelvisGlobal_angles.csv'));

fprintf('Reference files written to %s\n', outDir);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOCAL HELPERS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Q = local_readQuat(filePath)
    opts = detectImportOptions(filePath,'Delimiter',',','VariableNamingRule','preserve');
    opts.VariableNamesLine = 1; opts.DataLine = 2;
    T = readtable(filePath, opts);
    Q = [T.Q0, T.Q1, T.Q2, T.Q3];
end

function R = local_q2R(q)
    % Active rotation matrix from scalar-first unit quaternion q = [w x y z].
    % Identical to quat2rotm(q) and rotmat(quaternion(q),'point').
    q = q / norm(q);
    w = q(1); x = q(2); y = q(3); z = q(4);
    R = [1-2*(y^2+z^2), 2*(x*y-w*z),   2*(x*z+w*y);
         2*(x*y+w*z),   1-2*(x^2+z^2), 2*(y*z-w*x);
         2*(x*z-w*y),   2*(y*z+w*x),   1-2*(x^2+y^2)];
end

function RsegSens = local_staticCalib(Quat)
    % Mirrors computeStaticCalibration.m: mean quat -> R -> transpose.
    q = meanQuaternion(Quat);
    q = q / norm(q);
    RSL = local_q2R(q);
    RsegSens = RSL';
end

function RsegGlobal = local_segOrient(Quat, RsegSens)
    % Mirrors computeSegmentOrientation.m (the 'point' path).
    N = size(Quat,1);
    RsegGlobal = zeros(3,3,N);
    for k = 1:N
        RsensGlobal = local_q2R(Quat(k,:));
        RsegGlobal(:,:,k) = RsensGlobal * RsegSens;
    end
end

function M = local_flatten(R3)
    N = size(R3,3);
    M = zeros(N,9);
    for k = 1:N
        Rk = R3(:,:,k)';          % transpose so reshape gives row-major r11 r12 r13 ...
        M(k,:) = Rk(:)';
    end
end

function PG = local_pelvisGlobal(Rpelvis)
    N = size(Rpelvis,3);
    PG.Tilt = zeros(N,1); PG.Obliquity = zeros(N,1); PG.Rotation = zeros(N,1);
    for i = 1:N
        R = Rpelvis(:,:,i);
        pitch = -asin(R(3,1));
        if cos(pitch) > 1e-4
            yaw  = atan2(R(2,1), R(1,1));
            roll = atan2(R(3,2), R(3,3));
        else
            yaw = 0; roll = atan2(-R(1,2), R(2,2));
        end
        PG.Tilt(i)      = pitch*(180/pi);
        PG.Obliquity(i) = roll*(180/pi);
        PG.Rotation(i)  = yaw*(180/pi);
    end
end
