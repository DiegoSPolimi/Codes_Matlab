function Hip = computeHipJCS(RPelvis, RThigh)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COMPUTEHIPJCS
%
% Computes hip angles using the Grood & Suntay Joint Coordinate System.
%
% INPUT
%   RPelvis(:,:,N) : Anatomical orientation matrix of the pelvis (S2)
%   RThigh(:,:,N)  : Anatomical orientation matrix of the thigh (LThigh)
%
% OUTPUT
%   Hip.FlexExt
%   Hip.AddAbd
%   Hip.IntExt
%
% Note: The segment orientation columns are assumed to be [ML, AP, Long]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

N = min(size(RPelvis, 3), size(RThigh, 3));

Hip.FlexExt = zeros(N, 1);
Hip.AbdAdd  = zeros(N, 1);
Hip.IntExt  = zeros(N, 1);

for k = 1:N
    Rp = RPelvis(:,:,k);  % Global matrix of the Pelvis (S2)
    Rt = RThigh(:,:,k);   % Global matrix of the Thigh

    % --------------------------------------------------------------
    % Anatomical Axes Extraction (Column 1 = ML, Column 3 = Long)
    % --------------------------------------------------------------
    Ip = Rp(:, 1);  % Mediolateral axis of Pelvis (Flexion/Extension Axis)
    Jp = Rp(:, 2);  % Anterior-Posterior axis of Pelvis
    Kp = Rp(:, 3);  % Longitudinal axis of Pelvis

    It = Rt(:, 1);  % Mediolateral axis of Thigh
    Jt = Rt(:, 2);  % Anterior-Posterior axis of Thigh
    Kt = Rt(:, 3);  % Longitudinal axis of Thigh (Internal/External Axis)

    % --------------------------------------------------------------
    % Floating Axis (Perpendicular to both body-fixed axes)
    % --------------------------------------------------------------
    % Floating axis H = Kt x Ip
    H = cross(Kt, Ip);
    if norm(H) > 1e-6
        H = H / norm(H);
    else
        H = [0; 1; 0]; % Fallback if perfectly aligned
    end

    % --------------------------------------------------------------
    % Angle Extraction (Grood & Suntay Convention)
    % --------------------------------------------------------------
    % 1. Flexion/Extension (around Pelvic ML axis Ip)
    % Alpha: Angle between Pelvic AP axis (Jp) and Floating Axis (H)
    cos_FE = dot(Jp, H);
    sin_FE = dot(cross(Jp, H), Ip);
    Hip.FlexExt(k) = atan2d(sin_FE, cos_FE);

    % 2. Adduction/Abduction (around Floating axis H)
    % Beta: Angle between Pelvic Long axis (Kp) and Thigh Long axis (Kt)
    cos_AA = dot(Kp, Kt);
    sin_AA = dot(cross(Kp, Kt), H);
    Hip.AbdAdd(k) = atan2d(sin_AA, cos_AA);

    % 3. Internal/External Rotation (around Thigh Longitudinal axis Kt)
    % Gamma: Angle between Floating Axis (H) and Thigh ML axis (It)
    cos_IE = dot(H, It);
    sin_IE = dot(cross(H, It), Kt);
    Hip.IntExt(k) = atan2d(sin_IE, cos_IE);
end

%% ===================================================================== %%
% OFFSET REMOVAL STRATEGY (Consistent with your Knee Strategy B)
%% ===================================================================== %%
% Shifting based on the mean of first 30 frames (static standing reference)
% numStaticFrames = min(30, N);
% offset_FE = mean(Hip.FlexExt(1:numStaticFrames));
% offset_AA = mean(Hip.AddAbd(1:numStaticFrames));
% offset_IE = mean(Hip.IntExt(1:numStaticFrames));
% 
% Hip.FlexExt = Hip.FlexExt - offset_FE;
% Hip.AddAbd  = Hip.AddAbd  - offset_AA;
% Hip.IntExt  = Hip.IntExt  - offset_IE;

end