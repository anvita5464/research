% ------------------------------ Specify System Variables ------------------------------ %
% Specify the path to your video file and the output folder
videoFilePath = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-21-Ni-Nimesh-0p5Na2SO4-10mlmin-new_cell_footagealignment\0p5_Na2SO4_10mlmin_CA_3V_Backlighting_500fps.mov'; % Replace with your video file path
outputFolder = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-21-Ni-Nimesh-0p5Na2SO4-10mlmin-new_cell_footagealignment\Bubble Analysis smol'; % Replace with your output folder path
DataAnalysisFolder = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-21-Ni-Nimesh-0p5Na2SO4-10mlmin-new_cell_footagealignment\Data Analysis smol';

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

if ~exist(DataAnalysisFolder, 'dir')
    mkdir(DataAnalysisFolder);
end

% Specify video properties
% cropRect = [335, 0, 585, 790];  % crop rect = [x, y, a, b], where crop starts from pixels (x,y) with a width of a and height of b
cropRect = [335, 650, 585, 140];  % crop rect = [x, y, a, b], where crop starts from pixels (x,y) with a width of a and height of b
fps = 500;
timestep = 1/fps;
length_per_pixel = 2.1915e-5; %length/pixel

% Read the video file
video = VideoReader(videoFilePath);
trackPlayer = vision.VideoPlayer(Position=cropRect);
frameRate = video.FrameRate; % Get the frame rate of the video
numFrames = floor(video.Duration * frameRate); % Calculate the total number of frames

% Binary video threshold
thresh =0.15;
frame = readFrame(video);
frames = zeros(100,size(frame,1),size(frame,2));
means = uint8(squeeze(mean(frames,1)));

%% ----------------------------- Tracker Setup ----------------------------- %%
function costMatrix = calculateCostMatrix(tracks, detections)
    % Initialize cost matrix
    numTracks = numel(tracks);
    numDetections = numel(detections);
    costMatrix = inf(numTracks, numDetections);

    % Extract track and detection positions and radii
    trackPositions = zeros(numTracks, 2);
    trackRadii = zeros(numTracks, 1);
    for i = 1:numTracks
        trackPositions(i, :) = tracks(i).Position; % Track position
        trackRadii(i) = tracks(i).ObjectAttributes.radius; % Track radius
    end

    detectionPositions = zeros(numDetections, 2);
    detectionRadii = zeros(numDetections, 1);
    for j = 1:numDetections
        detectionPositions(j, :) = detections{j}.Position; % Detection position
        detectionRadii(j) = detections{j}.ObjectAttributes.radius; % Detection radius
    end

    % Calculate position-based cost (Euclidean distance)
    positionCost = pdist2(trackPositions, detectionPositions);

    % Calculate size-based cost (absolute difference in radius)
    sizeCost = pdist2(trackRadii, detectionRadii, @(x, y) abs(x - y));

    % Combine position and size costs
    sizeWeight = 0.1; % Adjust this weight based on your application
    costMatrix = positionCost + sizeWeight * sizeCost;
end

function [assignments, unassignedTracks, unassignedDetections] = associateDetectionsToTracks(costMatrix, assignmentThreshold)
    % Use the Hungarian algorithm (or similar) for assignment
    [assignments, unassignedTracks, unassignedDetections] = ...
        assignDetectionsToTracks(costMatrix, assignmentThreshold);
end

function tracks = updateTracks(tracks, detections, assignments, unassignedTracks, unassignedDetections)
    % Update assigned tracks
    for i = 1:size(assignments, 1)
        trackIdx = assignments(i, 1);
        detectionIdx = assignments(i, 2);
        tracks(trackIdx).Position = detections{detectionIdx}.Position;
        tracks(trackIdx).Radius = detections{detectionIdx}.Radius;
        tracks(trackIdx).Age = tracks(trackIdx).Age + 1;
        tracks(trackIdx).TotalVisibleCount = tracks(trackIdx).TotalVisibleCount + 1;
    end

    % Delete unassigned tracks
    tracks(unassignedTracks) = [];

    % Create new tracks for unassigned detections
    for i = 1:numel(unassignedDetections)
        newTrack.Position = detections{unassignedDetections(i)}.Position;
        newTrack.Radius = detections{unassignedDetections(i)}.Radius;
        newTrack.Age = 1;
        newTrack.TotalVisibleCount = 1;
        tracks = [tracks; newTrack];
    end
end


function displayTrackingResults(videoPlayer,confirmedTracks,frame)
    if ~isempty(confirmedTracks)
        % Display the objects. If an object has not been detected
        % in this frame, display its predicted bounding box.
        numRelTr = numel(confirmedTracks);
        boxes = zeros(numRelTr,4);
        ids = zeros(numRelTr,1, 'int32');
        predictedTrackInds = zeros(numRelTr,1);
        for tr = 1:numRelTr
            % Get bounding boxes.
            boxes(tr,:) = confirmedTracks(tr).ObjectAttributes.BoundingBox;

            % Get IDs.
            ids(tr) = confirmedTracks(tr).TrackID;

            if confirmedTracks(tr).IsCoasted
                predictedTrackInds(tr) = tr;
            end
        end

        predictedTrackInds = predictedTrackInds(predictedTrackInds > 0);

        % Create labels for objects that display the predicted rather
        % than the actual location.
        labels = cellstr(int2str(ids));

        isPredicted = cell(size(labels));
        isPredicted(predictedTrackInds) = {' predicted'};
        labels = strcat(labels,isPredicted);

        % Draw the objects on the frame.
        frame = insertObjectAnnotation(frame,"rectangle",boxes,labels);
    end
    videoPlayer.step(frame);
end

tracker = multiObjectTracker('MaxNumTracks', 1500, 'AssignmentThreshold', 50,  'ConfirmationThreshold', [40 50], DeletionThreshold= 50);

%% ---------------------------- Bubble Detection and tracking---------------------------- %
% 
for frameNum = 1:numFrames
    frame = read(video, frameNum);
    i = frameNum;
    cropped_frame = imcrop(frame, cropRect);

    % ---- Crop/Binarize Image ---- %
    gray_frame = rgb2gray(frame);
    gray_frame = gray_frame-means;
    binary_frame = imbinarize(gray_frame, thresh); 
    binary_frame = imcrop(binary_frame, cropRect);

    % ---- Regionprops method ----- %
    labeledImage = bwlabel(binary_frame);
    stats = regionprops(labeledImage, 'Centroid', 'MajorAxisLength','MinorAxisLength','Area', 'BoundingBox');

    centers = cat(1, stats.Centroid);
    bboxes = cat(1, stats.BoundingBox);
    MajorAxisLength = [stats.MajorAxisLength].';
    MinorAxisLength = [stats.MinorAxisLength].';
    radii = (mean([MajorAxisLength MinorAxisLength], 2)/2);
    area = [stats.Area].';
    volume = (sum((4*pi*radii.^3)/3)).*(length_per_pixel^3);

    centroid_data{i} = centers;
    radii_data{i} = radii;
    area_data{i} = area;
    volume_data{i} = volume;

    % % ---- Circular Hough Transform method (this is pretty shit keep it commented) ---- %
    % [centers, radii, metric] = imfindcircles(img,[1 10], 'ObjectPolarity','bright');
    
    % % ---- Visualize image ----% 
    % imshow(imcrop(read(video, i), cropRect))
    % hold on;
    % viscircles(centers, radii,'Color','b');
    % hold off
    % 
    % visualization_subfolder = 'Bubble Tracking Visualization';
    % visualization_subfolder = fullfile(DataAnalysisFolder, visualization_subfolder);  
    % 
    % if ~exist(visualization_subfolder, 'dir')
    %     mkdir(visualization_subfolder);
    % end
    % 
    % saveas(gcf, fullfile(visualization_subfolder, sprintf('0p5_Na2SO4_10mlmin_CA_3V_500fps_%d.png', frameNum)));


    time = frameNum * timestep;
    if ~isempty(centers)
        detections = cell(size(centers, 1), 1);
        for j = 1:size(centers, 1)
            detections{j} = objectDetection(time, centers(j, :), ...
                'MeasurementNoise', 10 * eye(2), ...
                'ObjectAttributes', struct('BoundingBox', bboxes(j, :), 'radius', radii(j)));
        end
        tracks = tracker(detections, time); % Update tracks
    else
        tracks = tracker([], time); % No detections in this frame
    end

    % step(trackPlayer, frame);
    displayTrackingResults(trackPlayer,tracks,cropped_frame);


    % % --- I'll choose to display a random track --- %
    % track_ID = 57;
    % if ~isempty(tracks) &&  track_ID <= size(tracks, 1)
    %     track = tracks([tracks.TrackID] == track_ID);
    %     x = track.State(1);
    %     y = track.State(3);
    %     box = tracks(track_ID).ObjectAttributes.BoundingBox;
    %     length = track.ObjectAttributes.radius;
    % 
    % 
    %     imshow(cropped_frame)
    %     hold on
    % 
    %     if track.IsCoasted
    %         % viscircles([x,y], 10,'Color','b');
    %         rectangle('Position', [x - length, y - length, length*2, length*2], 'EdgeColor', 'b', 'LineWidth', 0.5, 'FaceAlpha', 0.3)
    %     else
    %         % viscircles([x,y], 10,'Color','r');
    %         rectangle('Position', [x - length, y - length, length*2, length*2], 'EdgeColor', 'r', 'LineWidth', 0.5, 'FaceAlpha', 0.3)
    %     end
    % 
    %     % visualization_subfolder = 'Bubble Tracking Visualization 2'; 
    %     % visualization_subfolder = fullfile(DataAnalysisFolder, visualization_subfolder);  
    %     % 
    %     % if ~exist(visualization_subfolder, 'dir')
    %     %     mkdir(visualization_subfolder);
    %     % end
    %     % 
    %     % saveas(gcf, fullfile(visualization_subfolder, sprintf('0p5_Na2SO4_10mlmin_CA_3V_500fps_%d.png', frameNum)));
    % 
    %     hold off
    % end


end




% % ---------------------------- Save Data to CSV file ---------------------------- %

% % --- volume data --- %
% % volume_data = cell2mat(volume_data);
% OutputFilePath = fullfile(DataAnalysisFolder, 'Volume_data.csv');
% writematrix(volume_data', OutputFilePath)
% 
% % --- Centroid, Radii, Area data --- %
% for i = 1:numFrames
%     OutputFilePath = fullfile(DataAnalysisFolder, sprintf('Centroid_radii_area_frame_%d.csv', i));
%     combined_data = [centroid_data{i}, radii_data{i}, area_data{i}];
%     writematrix(combined_data, OutputFilePath)
% end


% % ----------- Data Analysis ------------- %
% % volume_data = cell2mat(volume_data);
% 
% % plot Histogram
% histogram(volume_data)
% hold on
% xlabel('Total Volume')
% ylabel('Frequency')
% title('Histogram of Volume of bubbles')
% hold off
% saveas(gcf, fullfile(DataAnalysisFolder, 'Volume_histogram.png'));
% 
% % % Plot graph
% time = 1:length(volume_data);
% time = time * timestep;
% 
% scatter(time, volume_data, 5, 'filled');
% hold on
% xlabel('Time (s)')
% ylabel('Volume (m^3)')
% title('Time vs Volume')
% hold off
% saveas(gcf, fullfile(DataAnalysisFolder, 'Volume_scatter_plot.png'));
% 
