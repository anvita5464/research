% This script is used to check parameters for analysis. Should be used
% before the Bubble Detection code

videoFilePath = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-28-Ni-Nimesh-0p5Na2SO4-test-camera-for-varying-flow-rates\500FPS_10s_1000usExp_0.5MNa2SO4_40mL_min_5mACP_take6.mp4'; % Replace with your video file path
outputFolder = 'C:\Users\ameyo\OneDrive\Desktop\Research\Data\Flow through electrolyzer\Cell v2 - bigger windows\2025-02-28-Ni-Nimesh-0p5Na2SO4-test-camera-for-varying-flow-rates\Bubble Analysis'; % Replace with your output folder path

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Read the video file
video = VideoReader(videoFilePath);
frameRate = video.FrameRate; % Get the frame rate of the video
numFrames = floor(video.Duration * frameRate); % Calculate the total number of frames

% ---------------------- Parameter Inputs --------------------- %

% Specify video properties
cropRect = [335, 0, 585, 790];  % crop rect = [x, y, a, b], where crop starts from pixels (x,y) with a width of a and height of b
fps = 500;
timestep = 1/fps;
length_per_pixel = 2.1915e-5; %length/pixel

% Binary video threshold
thresh =0.15;
% frame = readFrame(video);
% frames = zeros(100,size(frame,1),size(frame,2));
% means = uint8(squeeze(mean(frames,1)));

% -------------------- Check Parameters ------------------------- %

for frameNum = 1:numFrames
    frame = read(video, frameNum);

    % ----- Check Crop ----- %
    cropped_frame = imcrop(frame, cropRect);
    imshow(cropped_frame)

    % % ---- Check Binarization ---- %
    % gray_frame = rgb2gray(frame);
    % gray_frame = gray_frame-means;
    % binary_frame = imbinarize(gray_frame, thresh); 
    % binary_frame = imcrop(binary_frame, cropRect);

    break

end