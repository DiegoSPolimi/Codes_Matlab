% function plotAngles(time,Joint,JointName)
% 
% figure('Name',JointName);
% 
% subplot(3,1,1)
% 
% plot(time,Joint.FlexExt,'LineWidth',2)
% 
% grid on
% 
% ylabel('deg')
% 
% title([JointName ' Flexion / Extension'])
% 
% subplot(3,1,2)
% 
% if isfield(Joint,'AbdAdd')
% 
%     plot(time,Joint.AbdAdd,'LineWidth',2)
% 
%     title([JointName ' Abduction / Adduction'])
% 
% elseif isfield(Joint,'VarusValgus')
% 
%     plot(time,Joint.VarusValgus,'LineWidth',2)
% 
%     title([JointName ' Varus / Valgus'])
% 
% end
% 
% grid on
% 
% ylabel('deg')
% 
% subplot(3,1,3)
% 
% plot(time,Joint.IntExt,'LineWidth',2)
% 
% grid on
% 
% ylabel('deg')
% 
% xlabel('Time (s)')
% 
% title([JointName ' Internal / External Rotation'])
% 
% end

function plotAngles(time, Joint, JointName)
    figure('Name', JointName, 'Color', 'w');
    
    % --- Subplot 1: Flexion/Extension OR Pelvic Tilt ---
    subplot(3,1,1)
    if isfield(Joint, 'FlexExt')
        plot(time, Joint.FlexExt, 'LineWidth', 2)
        title([JointName ' Flexion (+) / Extension (-)'])
    elseif isfield(Joint, 'Tilt')
        plot(time, Joint.Tilt, 'LineWidth', 2)
        title([JointName ' Tilt (Anterior + / Posterior -)'])
    end
    grid on
    ylabel('Angle (deg)')
    
    % --- Subplot 2: Abduction/Adduction/Varus/Valgus OR Pelvic Obliquity ---
    subplot(3,1,2)
    if isfield(Joint, 'AbdAdd')
        plot(time, Joint.AbdAdd, 'LineWidth', 2)
        title([JointName ' Adduction (+) / Abduction (-)'])
    elseif isfield(Joint, 'VarusValgus')
        plot(time, Joint.VarusValgus, 'LineWidth', 2)
        title([JointName ' Varus (+) / Valgus (-)'])
    elseif isfield(Joint, 'Obliquity')
        plot(time, Joint.Obliquity, 'LineWidth', 2)
        title([JointName ' Obliquity (Lateral Drop)'])
    end
    grid on
    ylabel('Angle (deg)')
    
    % --- Subplot 3: Internal/External Rotation OR Pelvic Rotation ---
    subplot(3,1,3)
    if isfield(Joint, 'IntExt')
        plot(time, Joint.IntExt, 'LineWidth', 2)
        title([JointName ' Internal (+) / External (-) Rotation'])
    elseif isfield(Joint, 'Rotation')
        plot(time, Joint.Rotation, 'LineWidth', 2)
        title([JointName ' Rotation'])
    end
    grid on
    ylabel('Angle (deg)')
    xlabel('Time (s)')
end