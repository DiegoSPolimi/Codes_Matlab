function plotCalibrationFrames(Calibration)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Plot the IMU reference frame together with the anatomical segment frame
% obtained after calibration.
%
% Sensor frame:
%
% X : Up
% Y : Forward
% Z : Lateral
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Segments = {'S2','LThigh','LShank','LFoot'};

Segments = {'LT','S2'};


figure('Name','Calibration Reference Frames',...
       'Color','w',...
       'Position',[100 100 1200 900]);

for i = 1:length(Segments)

    subplot(2,2,i)
    hold on
    grid on
    axis equal

    view(3)

    xlabel('Up (+X)')
    ylabel('Forward (+Y)')
    zlabel('Lateral (+Z)')

    title(Segments{i},'FontWeight','bold')

    xlim([-1.2 1.2])
    ylim([-1.2 1.2])
    zlim([-1.2 1.2])

    %% -------------------------------------------------------------
    % Sensor reference frame (known)
    %% -------------------------------------------------------------

    quiver3(0,0,0,1,0,0,...
        0,...
        'k--',...
        'LineWidth',2,...
        'MaxHeadSize',0.4);

    quiver3(0,0,0,0,1,0,...
        0,...
        'k--',...
        'LineWidth',2,...
        'MaxHeadSize',0.4);

    quiver3(0,0,0,0,0,1,...
        0,...
        'k--',...
        'LineWidth',2,...
        'MaxHeadSize',0.4);

    text(1.05,0,0,'Sensor X','FontSize',10)
    text(0,1.05,0,'Sensor Y','FontSize',10)
    text(0,0,1.05,'Sensor Z','FontSize',10)

    %% -------------------------------------------------------------
    % Anatomical reference frame
    %% -------------------------------------------------------------

    R = Calibration.(Segments{i}).RsegSens;

    quiver3(0,0,0,...
        R(1,1),R(2,1),R(3,1),...
        0,...
        'r',...
        'LineWidth',3,...
        'MaxHeadSize',0.4);

    quiver3(0,0,0,...
        R(1,2),R(2,2),R(3,2),...
        0,...
        'g',...
        'LineWidth',3,...
        'MaxHeadSize',0.4);

    quiver3(0,0,0,...
        R(1,3),R(2,3),R(3,3),...
        0,...
        'b',...
        'LineWidth',3,...
        'MaxHeadSize',0.4);

    text(R(1,1)*1.1,R(2,1)*1.1,R(3,1)*1.1,'ML',...
        'Color','r','FontWeight','bold')

    text(R(1,2)*1.1,R(2,2)*1.1,R(3,2)*1.1,'AP',...
        'Color','g','FontWeight','bold')

    text(R(1,3)*1.1,R(2,3)*1.1,R(3,3)*1.1,'Long',...
        'Color','b','FontWeight','bold')

    %% -------------------------------------------------------------
    % Origin
    %% -------------------------------------------------------------

    plot3(0,0,0,'ko','MarkerFaceColor','k','MarkerSize',6)

    legend({'Sensor X','Sensor Y','Sensor Z',...
            'ML','AP','Long'},...
            'Location','best')

end

sgtitle('Comparison between Sensor and Anatomical Reference Frames')

end