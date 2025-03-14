% This script is used to check parameters for analysis. Should be used
% before the Bubble Detection code

videoFilePath = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-21-Ni-Nimesh-0p5Na2SO4-10mlmin-new_cell_footagealignment\0p5_Na2SO4_10mlmin_CA_3V_Backlighting_500fps.mov'; % Replace with your video file path
outputFolder = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-21-Ni-Nimesh-0p5Na2SO4-10mlmin-new_cell_footagealignment\Bubble Analysis'; % Replace with your output folder path

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Read the video file
video = VideoReader(videoFilePath);
frameRate = video.FrameRate; % Get the frame rate of the video
numFrames = floor(video.Duration * frameRate); % Calculate the total number of frames

%% ---------------------- Parameter Inputs --------------------- %%

% Specify video properties
cropRect = [335, 650, 585, 140];  % crop rect = [x, y, a, b], where crop starts from pixels (x,y) with a width of a and height of b
fps = 500;
timestep = 1/fps;
length_per_pixel = 2.1915e-5; %length/pixel

% Binary video threshold
thresh =0.15;
% frame = readFrame(video);
% frames = zeros(100,size(frame,1),size(frame,2));
% means = uint8(squeeze(mean(frames,1)));

%% -------------------- Check Parameters -------------------------% %

for frameNum = 1:numFrames
    frame = read(video, frameNum);
    i = frameNum;

    % ----- Check Crop ----- %
   
    % % Check crop position %
    % imshow(frame)
    % hold on
    % rectangle('Position', cropRect, 'EdgeColor', 'b', 'LineWidth', 2);
    % hold off
    % % saveas(gcf, fullfile(outputFolder, sprintf('0p5_Na2SO4_10mlmin_CA_3V_500fps_%d.png', frameNum))); % Save image

    % % Check cropped frame
    % cropped_frame = imcrop(frame, cropRect);
    % imshow(cropped_frame)

    % ---- Check Binarization ---- %
    gray_frame = rgb2gray(frame);
    gray_frame = gray_frame-means;
    binary_frame = imbinarize(gray_frame, thresh); 
    binary_frame = imcrop(binary_frame, cropRect);
    % imshow(binary_frame)

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

    % ---- Visualize image ----% 
    imshow(imcrop(read(video, i), cropRect))
    hold on;
    viscircles(centers, radii,'Color','b');
    hold off

    % 
    % visualization_subfolder = 'Bubble Tracking Visualization';
    % visualization_subfolder = fullfile(DataAnalysisFolder, visualization_subfolder);  
    % 
    % if ~exist(visualization_subfolder, 'dir')
    %     mkdir(visualization_subfolder);
    % end
    % 
    % saveas(gcf, fullfile(visualization_subfolder, sprintf('0p5_Na2SO4_10mlmin_CA_3V_500fps_%d.png', frameNum)));



end
