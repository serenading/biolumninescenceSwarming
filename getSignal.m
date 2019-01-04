function signal = getSignal(filename,backgroundSubtractOption,medianFilterOption,binOption,binning)

%% function takes a .tif stack and returns overall signal.
% steps performed:
% 1. select a frame to get background signal
% 2. go through each frame, use median-filter to despeckle, bin image,
% subtract background, and get signal

% INPUT
% filename: string, specifying .tif file path
% backgroundSubtractionOption: true or false
% medianFilterOption: true or false
% binOption: true or false
% binning: string, specifying binng method at acquisition e.g. '2x2', '8x8'

% OUTPUT
% signal: vector the length of tiff frames containing signal from each frame

% FUNCTION

%% specify missing input arguments
if nargin <5
    binning = '2x2';
    if nargin <4
        binOption = false;
        if nargin <3
            medianFilterOption = false;
            if nargin <2
                backgroundSubtractOption = true;
            end
        end
    end
end


%% get info
info = imfinfo(filename);
numImages = numel(info);
signal = NaN(1,numImages);
if strcmp(binning, '2x2') % pre-acquisition binning
    binFactor = 4; % post-acquisition binning
end

%% get background signal from one sample frame
% % two methods for getting signal from sample frame
if backgroundSubtractOption
    
    % % method one: take median signal from the last frame (works if all food is depleted at the end; doesn't work for controls)
    % image = imread(filename, numImages-2); % read second to the last frame
    % backgroundSignal = median(image(:));
    
    % method two: sample one frame towards (but isn't) the beginning of the recording and use signal from two corners
    % read 30th image frame (select 30 because background seems to vary at the start)
    sampleFrame = 30; % 30
    if contains(filename,'multiSample_20181219')
        sampleFrame = 20; % 30th frame is weird for this set of recordings
    end
    if  numImages<=sampleFrame
        sampleFrame = numImages;
    end
    image = imread(filename, sampleFrame);
    % median filter to despeckle
    if medianFilterOption
        image = medfilt2(image);
    end
    % bin image
    if binOption
        if ~strcmp(binning,'8x8')
            image = bin_matrix(image, binFactor);
        end
    end
    % get signal from two corners
    [imageHeight,imageWidth] = size(image);
    topRightCorner = image(1:round(0.1*imageHeight),round(0.9*imageWidth):imageWidth); % top right 10% of image
    bottomRightCorner = image(round(0.9*imageHeight):imageHeight,round(0.9*imageWidth):imageWidth); % bottom right 10% of image
    topRightSignal = sum(topRightCorner(:))/numel(topRightCorner);
    bottomRightSignal = sum(bottomRightCorner(:))/numel(bottomRightCorner);
    % get average background signal for those two sample sqaures
    backgroundSignal = mean([topRightSignal bottomRightSignal]);
    % display warning if the two regions differ significantly
    if abs(topRightSignal - bottomRightSignal) > min([topRightSignal bottomRightSignal])*0.1
        warning(['background subtraction sample region signals differ by more than 10% for ' filename])
    end
end

%% calculate signal from all frames
for imageCtr = 1:numImages
    % read image frame
    image = imread(filename, imageCtr);
    % median filter to despeckle
    if medianFilterOption
        image = medfilt2(image); % median filter to despeckle
    end
    % bin image
    if binOption
        if ~strcmp(binning,'8x8')
            image = bin_matrix(image, binFactor);
        end
    end
    if backgroundSubtractOption
        % subtract background
        image = image-backgroundSignal;
    end
    % get total signal from the whole image
    signal(imageCtr) = sum(image(:));
end