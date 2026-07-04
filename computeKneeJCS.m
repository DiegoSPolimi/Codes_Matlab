% function Knee = computeKneeJCS(RThigh,RShank)
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %
% % Computes knee angles using the Grood & Suntay Joint Coordinate System.
% %
% % INPUT
% %
% % RThigh(:,:,N) : Anatomical orientation of the thigh
% % RShank(:,:,N) : Anatomical orientation of the shank
% %
% % OUTPUT
% %
% % Knee.FlexExt
% % Knee.VarusValgus
% % Knee.IntExt
% %
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% N = size(RThigh,3);
% 
% Knee.FlexExt     = zeros(N,1);
% Knee.VarusValgus = zeros(N,1);
% Knee.IntExt      = zeros(N,1);
% 
% for k = 1:N
% 
%     Rt = RThigh(:,:,k); % quaternion (i.e. global position) of the segment at time step t 
%     Rs = RShank(:,:,k);
% 
%     %--------------------------------------------------------------
%     % Anatomical axes
%     %--------------------------------------------------------------
% 
% 
% 
%     It = Rt(:,1);      % Mediolateral (thigh FE axis) 
% 
%     Jt = Rt(:,2);      % AP
% 
%     Kt = Rt(:,3);      % Long axis
% 
%     Is = Rs(:,1);      % Mediolateral shank
% 
%     Js = Rs(:,2);      % AP shank
% 
%     Ks = Rs(:,3);      % Long axis shank
% 
%     %--------------------------------------------------------------
%     % Floating axis
%     %--------------------------------------------------------------
% 
%     e2 = cross(Ks,It);
% 
%     e2 = e2./norm(e2); 
% 
%     %--------------------------------------------------------------
%     % FLEXION / EXTENSION
%     %--------------------------------------------------------------
% 
%     Knee.FlexExt(k) = atan2( ...
%         dot(cross(It,Ks),e2), ...
%         dot(It,Ks));
% 
%     %--------------------------------------------------------------
%     % VARUS / VALGUS
%     %--------------------------------------------------------------
% 
%     Knee.VarusValgus(k) = asin(dot(It,Ks));
% 
%     %--------------------------------------------------------------
%     % INTERNAL / EXTERNAL ROTATION
%     %--------------------------------------------------------------
% 
%     Knee.IntExt(k) = atan2( ...
%         dot(cross(Jt,Js),Ks), ...
%         dot(Jt,Js));
% 
%   % Joint angles computed with the floating axis, computed at each time
%   % frame. 
% 
% 
% end
% 
% Knee.FlexExt     = rad2deg(Knee.FlexExt);
% Knee.VarusValgus = rad2deg(Knee.VarusValgus);
% Knee.IntExt      = rad2deg(Knee.IntExt);
% 
% end

%% Corrected version to respect the methodology used in the literature
% 
% function Knee = computeKneeJCS(RFemur,RTibia)
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % COMPUTEKNEEJCS
% %
% % Joint Coordinate System (Grood & Suntay / ISB)
% %
% % Segment coordinate system:
% %
% % Column 1 = ML axis
% % Column 2 = AP axis
% % Column 3 = Longitudinal axis
% %
% % R(:,:,k)
% %
% % Rows    = Global coordinates
% % Columns = Segment axes
% %
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% N = size(RFemur,3);
% 
% FlexExt     = zeros(N,1);
% VarusValgus = zeros(N,1);
% IntExt      = zeros(N,1);
% 
% for k=1:N
% 
%     %% ---------------------------------------------------------------
%     % Segment frames
%     %% ---------------------------------------------------------------
% 
%     Rt = RFemur(:,:,k);
% 
%     Rs = RTibia(:,:,k);
% 
%     %% ---------------------------------------------------------------
%     % Anatomical axes
%     %% ---------------------------------------------------------------
% 
%     % Femur ML axis
%     e1 = Rt(:,1);
% 
%     % Tibia Longitudinal axis
%     e3 = Rs(:,3);
% 
%     %% ---------------------------------------------------------------
%     % Floating axis
%     %% ---------------------------------------------------------------
% 
%     e2 = cross(e3,e1);
% 
%     if norm(e2) < 1e-8
% 
%         continue
% 
%     end
% 
%     e2 = e2/norm(e2);
% 
%     %% ---------------------------------------------------------------
%     % FLEXION / EXTENSION
%     %
%     % Rotation of tibia around femoral ML axis
%     %% ---------------------------------------------------------------
% 
%     FlexExt(k) = atan2d( ...
%         dot(cross(Rt(:,3),Rs(:,3)),e1), ...
%         dot(Rt(:,3),Rs(:,3)));
% 
%     %% ---------------------------------------------------------------
%     % VARUS / VALGUS
%     %
%     % Angle between femur ML axis and tibia longitudinal axis
%     % around floating axis
%     %% ---------------------------------------------------------------
% 
%     VarusValgus(k) = asind( ...
%         dot(e1,e3));
% 
%     %% ---------------------------------------------------------------
%     % INTERNAL / EXTERNAL ROTATION
%     %
%     % Rotation around tibial longitudinal axis
%     %% ---------------------------------------------------------------
% 
%     IntExt(k) = atan2d( ...
%         dot(cross(Rt(:,2),Rs(:,2)),e3), ...
%         dot(Rt(:,2),Rs(:,2)));
% 
% end
% 
% %% --------------------------------------------------------------------
% % Offset removal
% %
% % First frame = anatomical reference posture
% %% --------------------------------------------------------------------
% 
% FlexExt     = FlexExt     - FlexExt(1);
% VarusValgus = VarusValgus - VarusValgus(1);
% IntExt      = IntExt      - IntExt(1);
% 
% %% --------------------------------------------------------------------
% % Output
% %% --------------------------------------------------------------------
% 
% Knee.FlexExt     = FlexExt;
% Knee.VarusValgus = VarusValgus;
% Knee.IntExt      = IntExt;
% 
% end

%% Reproduction of the exact published JCS computation + joint angle exactly
% function Knee = computeKneeJCS(RThigh,RShank)
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %
% % Computes knee angles using the classic Grood & Suntay (1983) 
% % Joint Coordinate System (JCS) algorithm to prevent kinematic cross-talk.
% %
% % INPUT
% %
% % RThigh(:,:,N) : Anatomical orientation matrix of the thigh (3x3xN)
% % RShank(:,:,N) : Anatomical orientation matrix of the shank (3x3xN)
% %
% % OUTPUT
% %
% % Knee.FlexExt
% % Knee.VarusValgus
% % Knee.IntExt
% %
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% N = size(RThigh,3);
% 
% FlexExt     = zeros(N,1);
% VarusValgus = zeros(N,1);
% IntExt      = zeros(N,1);
% 
% for k = 1:N
% 
%     Rt = RThigh(:,:,k); 
%     Rs = RShank(:,:,k);
% 
%     %--------------------------------------------------------------
%     % Extract Anatomical Axes from Orientation Matrices
%     %--------------------------------------------------------------
%     It = Rt(:,1);      % Thigh Mediolateral (ML) axis
%     Jt = Rt(:,2);      % Thigh Anterior-Posterior (AP) axis
%     Kt = Rt(:,3);      % Thigh Longitudinal axis
% 
%     Is = Rs(:,1);      % Shank Mediolateral (ML) axis
%     Js = Rs(:,2);      % Shank Anterior-Posterior (AP) axis
%     Ks = Rs(:,3);      % Shank Longitudinal axis
% 
%     %--------------------------------------------------------------
%     % Define the Joint Coordinate System (JCS) Axes
%     %--------------------------------------------------------------
%     e1 = It;           % Joint Axis 1: Fixed to the Femur (ML Axis)
%     e3 = Ks;           % Joint Axis 3: Fixed to the Tibia (Long Axis)
% 
%     % Joint Axis 2: The Floating Axis (perpendicular to both e1 and e3)
%     e2 = cross(e3, e1);
%     e2 = e2 / norm(e2); 
% 
%     %% ---------------------------------------------------------------
%     % FLEXION / EXTENSION
%     % Rotation around the femoral ML axis (e1). 
%     % Measured as the angle between the Thigh AP axis (Jt) and the floating axis (e2).
%     %% ---------------------------------------------------------------
%     FlexExt(k) = atan2d(dot(cross(Jt, e2), e1), dot(Jt, e2));
% 
%     %% ---------------------------------------------------------------
%     % VARUS / VALGUS
%     % Out-of-plane adduction/abduction angle.
%     % Measured between the femoral ML axis (e1) and tibial longitudinal axis (e3).
%     %% ---------------------------------------------------------------
%     VarusValgus(k) = asind(dot(e1, e3));
% 
%     %% ---------------------------------------------------------------
%     % INTERNAL / EXTERNAL ROTATION
%     % Rotation around the tibial longitudinal axis (e3).
%     % Measured as the angle between the floating axis (e2) and the Shank AP axis (Js).
%     %% ---------------------------------------------------------------
%     IntExt(k) = atan2d(dot(cross(e2, Js), e3), dot(e2, Js));
% 
% end
% 
% %% --------------------------------------------------------------------
% % Offset removal
% % First frame = anatomical reference posture (sets baseline to 0 deg)
% %% --------------------------------------------------------------------
% 
% FlexExt     = FlexExt     - FlexExt(1);
% VarusValgus = VarusValgus - VarusValgus(1);
% IntExt      = IntExt      - IntExt(1);
% 
% %% --------------------------------------------------------------------
% % Output Structure
% %% --------------------------------------------------------------------
% 
% Knee.FlexExt     = FlexExt;
% Knee.VarusValgus = VarusValgus;
% Knee.IntExt      = IntExt;
% 
% end


%% MAYBE BETTER VESRION FROM MODIFIED VERSION COF COMPUTE SEGMENT ORIENTATION 
function Knee = computeKneeJCS(RThigh,RShank)
N = size(RThigh,3);

FlexExt     = zeros(N,1);
VarusValgus = zeros(N,1);
IntExt      = zeros(N,1);

for k = 1:N
    Rt = RThigh(:,:,k); 
    Rs = RShank(:,:,k);

    % 1. Extract Segment Unit Axes from the Segment->Global matrices
    It = Rt(:,1);      % Thigh Mediolateral (ML) axis
    Jt = Rt(:,2);      % Thigh Anterior-Posterior (AP) axis
    Kt = Rt(:,3);      % Thigh Longitudinal axis

    Is = Rs(:,1);      % Shank Mediolateral (ML) axis
    Js = Rs(:,2);      % Shank Anterior-Posterior (AP) axis
    Ks = Rs(:,3);      % Shank Longitudinal axis

    % 2. Establish the Grood & Suntay Joint Coordinate System Axes
    e1 = It;           % Joint Axis 1: Fixed to Femur (ML Axis)
    e3 = Ks;           % Joint Axis 3: Fixed to Tibia (Longitudinal Axis)

    % Joint Axis 2: Floating Axis (Perpendicular to both e1 and e3)
    e2 = cross(e3, e1);
    e2 = e2 / norm(e2); 

    % 3. Calculate Angles using the Floating Axis (e2) to prevent cross-talk

    % Flexion/Extension: Angle between Thigh AP (Jt) and Floating Axis (e2) around e1
    FlexExt(k) = atan2d(dot(cross(Jt, e2), e1), dot(Jt, e2));

    % Varus/Valgus: Inclinational angle between e1 and e3
    VarusValgus(k) = asind(dot(e1, e3));

    % Internal/External Rotation: Angle between Floating Axis (e2) and Shank AP (Js) around e3
    IntExt(k) = atan2d(dot(cross(e2, Js), e3), dot(e2, Js));
end

%% ===================================================================== %%
% OFFSET REMOVAL STRATEGIES (Select ONE by uncommenting it)
%% ===================================================================== %%

% STRATEGY A: Zero at Maximum Extension (Recommended for this specific trial)
% This shifts the peak extension value to 0, correcting the +25° floating offset.
offset_FE = max(FlexExt); 
offset_VV = VarusValgus(1); % Keep standard first frame for out-of-plane
offset_IE = IntExt(1);

% STRATEGY B: Mean of the First 30 Frames (0.5 seconds of static standing)
% numStaticFrames = min(30, N);
% offset_FE = mean(FlexExt(1:numStaticFrames));
% offset_VV = mean(VarusValgus(1:numStaticFrames));
% offset_IE = mean(IntExt(1:numStaticFrames));

% STRATEGY C: Global Mean Subtraction (Your literal request)
% offset_FE = mean(FlexExt);
% offset_VV = mean(VarusValgus);
% offset_IE = mean(IntExt);


%% Apply Selected Offset Correction
Knee.FlexExt     = FlexExt     - offset_FE;
Knee.VarusValgus = VarusValgus - offset_VV;
Knee.IntExt      = IntExt      - offset_IE;
end

%% Using the relative rotation matrix directly

% function Knee = computeKneeJCS(RThigh, RShank)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % COMPUTEKNEEJCS
% %
% % Computes 3D knee joint angles by decomposing the relative rotation 
% % matrix using an XYZ Cardan sequence (equivalent to Grood & Suntay / ISB).
% %
% % INPUT:
% %   RThigh(:,:,N) : Global orientation of the thigh (3x3xN)
% %   RShank(:,:,N) : Global orientation of the shank (3x3xN)
% %
% % OUPUT:
% %   Knee structure containing FlexExt, VarusValgus, and IntExt profiles.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% N = size(RThigh, 3);
% 
% FlexExt     = zeros(N, 1);
% VarusValgus = zeros(N, 1);
% IntExt      = zeros(N, 1);
% 
% for k = 1:N
%     Rt = RThigh(:, :, k); 
%     Rs = RShank(:, :, k);
% 
%     % 1. Compute relative rotation matrix (Shank relative to Thigh)
%     R_rel = Rt' * Rs; 
% 
%     % 2. Direct Cardan XYZ extraction (Fast, no toolbox required)
%     % Ry (Varus/Valgus) around the floating axis
%     VarusValgus(k) = asind(R_rel(1, 3));
% 
%     % Rx (Flexion/Extension) around the femoral ML axis
%     FlexExt(k)     = atan2d(-R_rel(2, 3), R_rel(3, 3));
% 
%     % Rz (Internal/External Rotation) around the tibial longitudinal axis
%     IntExt(k)      = atan2d(-R_rel(1, 2), R_rel(1, 1));
% end
% 
% %% --------------------------------------------------------------------
% % Reference Offset Removal
% % WARNING: Ensure frame 1 is a true static, neutral standing posture!
% %% --------------------------------------------------------------------
% Knee.FlexExt     = FlexExt     - FlexExt(1);
% Knee.VarusValgus = VarusValgus - VarusValgus(1);
% Knee.IntExt      = IntExt      - IntExt(1);
% 
% % Knee.FlexExt     = FlexExt;
% % Knee.VarusValgus = VarusValgus;
% % Knee.IntExt      = IntExt;
% 
% % Knee.FlexExt     = FlexExt     - FlexExt(1)-25;
% % Knee.VarusValgus = VarusValgus - VarusValgus(1);
% % Knee.IntExt      = IntExt      - IntExt(1);
% end
% 
% 
% 

%% TO remove the rotational offset 

% function Knee = computeKneeJCS(RThigh, RShank)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % COMPUTEKNEEJCS
% %
% % Computes 3D knee joint angles by decomposing the relative rotation 
% % matrix using an XYZ Cardan sequence (equivalent to Grood & Suntay / ISB).
% %
% % INPUT:
% %   RThigh(:,:,N) : Global orientation of the thigh (3x3xN)
% %   RShank(:,:,N) : Global orientation of the shank (3x3xN)
% %
% % OUPUT:
% %   Knee structure containing FlexExt, VarusValgus, and IntExt profiles.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% N = size(RThigh, 3);
% 
% FlexExt     = zeros(N, 1);
% VarusValgus = zeros(N, 1);
% IntExt      = zeros(N, 1);
% 
% for k = 1:N
%     Rt = RThigh(:, :, k); 
%     Rs = RShank(:, :, k);
% 
%     % 1. Compute relative rotation matrix (Shank relative to Thigh)
%     R_rel = Rt' * Rs; 
% 
%     % 2. Pure Cardan XYZ decomposition (No hand-made vector projections)
%     % Ry (Varus/Valgus) around the floating axis
%     VarusValgus(k) = asind(R_rel(1, 3));
% 
%     % Rx (Flexion/Extension) around the femoral ML axis
%     FlexExt(k)     = atan2d(-R_rel(2, 3), R_rel(3, 3));
% 
%     % Rz (Internal/External Rotation) around the tibial longitudinal axis
%     IntExt(k)      = atan2d(-R_rel(1, 2), R_rel(1, 1));
% end
% 
% %% ===================================================================== %%
% % OFFSET REMOVAL STRATEGIES (Select ONE by uncommenting it)
% %% ===================================================================== %%
% 
% % STRATEGY A: Zero at Maximum Extension (Recommended for this specific trial)
% % This shifts the peak extension value to 0, correcting the +25° floating offset.
% offset_FE = max(FlexExt); 
% offset_VV = VarusValgus(1); % Keep standard first frame for out-of-plane
% offset_IE = IntExt(1);
% 
% % STRATEGY B: Mean of the First 30 Frames (0.5 seconds of static standing)
% % numStaticFrames = min(30, N);
% % offset_FE = mean(FlexExt(1:numStaticFrames));
% % offset_VV = mean(VarusValgus(1:numStaticFrames));
% % offset_IE = mean(IntExt(1:numStaticFrames));
% 
% % STRATEGY C: Global Mean Subtraction (Your literal request)
% % offset_FE = mean(FlexExt);
% % offset_VV = mean(VarusValgus);
% % offset_IE = mean(IntExt);
% 
% 
% %% Apply Selected Offset Correction
% Knee.FlexExt     = FlexExt     - offset_FE;
% Knee.VarusValgus = VarusValgus - offset_VV;
% Knee.IntExt      = IntExt      - offset_IE;
% 
% end