% ------------------------------ Specify System Variables ------------------------------ %
% Specify the path to your video file and the output folder
videoFilePath = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-21-Ni-Nimesh-0p5Na2SO4-10mlmin-new_cell_footagealignment\0p5_Na2SO4_10mlmin_CA_3V_Backlighting_500fps.mov'; % Replace with your video file path
outputFolder = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-21-Ni-Nimesh-0p5Na2SO4-10mlmin-new_cell_footagealignment\Bubble Analysis'; % Replace with your output folder path
DataAnalysisFolder = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-21-Ni-Nimesh-0p5Na2SO4-10mlmin-new_cell_footagealignment\Data Analysis';

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

if ~exist(DataAnalysisFolder, 'dir')
    mkdir(DataAnalysisFolder);
end

% Specify video properties
cropRect = [335, 0, 585, 790];  % crop rect = [x, y, a, b], where crop starts from pixels (x,y) with a width of a and height of b
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

tracker = multiObjectTracker();


% % ---------------------------- Bubble Detection and tracking---------------------------- %
% 
for frameNum = 1:numFrames
    frame = read(video, frameNum);
    i = frameNum;

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

    if ~isempty(centers)
        detections = cell(size(centers, 1), 1);
        for j = 1:size(centers, 1)
            detections{j} = objectDetection(0, centers(j, :), ...
                'MeasurementNoise', 10 * eye(2), ...
                'ObjectAttributes', struct('BoundingBox', bboxes(j, :)));
        end
        tracks = tracker(detections, 0); % Update tracks
    else
        tracks = tracker([], 0); % No detections in this frame
    end

     

    % % ---- Circular Hough Transform method (this is pretty shit keep it commented) ---- %
    % [centers, radii, metric] = imfindcircles(img,[1 10], 'ObjectPolarity','bright');
    
%     % ---- Visualize image ----% 
%     imshow(imcrop(read(video, i), cropRect))
%     hold on;
%     viscircles(centers, radii,'Color','b');
%     hold off
% 
%     visualization_subfolder = 'Bubble Tracking Visualization';
%     visualization_subfolder = fullfile(DataAnalysisFolder, visualization_subfolder);  
% 
%     if ~exist(visualization_subfolder, 'dir')
%         mkdir(visualization_subfolder);
%     end
% 
%     saveas(gcf, fullfile(visualization_subfolder, sprintf('0p5_Na2SO4_10mlmin_CA_3V_500fps_%d.png', frameNum)));


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
% 


% ---------------------------- Bubble Tracking ---------------------------- %

% Point Tracker
% % imageFiles = dir(fullfile(outputFolder, '*.png')); 
% % numFiles = length(imageFiles);
% 
% initial_frame = read(video, 1);
% initial_frame = imcrop(initial_frame, cropRect);
% 
% PointTracker = vision.PointTracker;
% initialize(PointTracker, centroid_data{1}, initial_frame);
% 
% for i = 2:numFrames
%     frame = read(video, i);
%     frame = imcrop(frame, cropRect);
% 
%     [points, validity] = step(PointTracker, frame);
%     dx = diff(points(:,1));
%     dy = diff(points(:,2));
%     velocity = sqrt(dx.^2 + dy.^2) / 0.002;  % timeStep depends on frame rate
% 
%     frame = insertMarker(frame, points, 'color', 'red', 'size', 1);
% 
%     velocity_data{i-1} = velocity;
% 
%     imshow(frame);
% 
%     pause
% 
% end
