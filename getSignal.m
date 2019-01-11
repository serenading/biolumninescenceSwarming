function signal = getSignal(filename,medianFilterOption,binOption,binning,backgroundSubtractOption,backgroundSubtractMethod)

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


%% get info
info = imfinfo(filename);
numImages = numel(info);
signal = NaN(1,numImages);
if strcmp(binning, '2x2') % pre-acquisition binning
    binFactor = 4; % post-acquisition binning
end

%% get background signal from one sample frame
% three methods for getting signal from sample frame

if backgroundSubtractOption
    %% select a sample frame
        % read the last frame for method 1 (works if all food is depleted at the end; doesn't work for controls)
    if backgroundSubtractMethod == 1
        if contains(filename,'75hr') & contains(filename,'60sInt')
            image = double(imread(filename, 600)); % read the frame corresponding to 10th hour at 1fpm
        elseif contains(filename,'16hr')
            image = double(imread(filename, 120));
        else
            image = double(imread(filename, numImages)); % read the last frame
        end
        % read 30th image frame for methods 2 and 3 (select 30 because background seems to vary at the start)
    else
        sampleFrame = 30; % 30
        if contains(filename,'multiSample_20181219')
            sampleFrame = 20; % 30th frame is weird for this set of recordings
        end
        if  numImages<=sampleFrame
            sampleFrame = numImages;
        end
        image = double(imread(filename, sampleFrame));
    end
    
    %% apply border crop, despeckle and bin options to sample image, if selected
    % crop out the bordering 3% from all four sides
    [imageHeight,imageWidth] = size(image);
    image = image(round(0.03*imageHeight):round(0.97*imageHeight), round(0.03*imageWidth):round(0.97*imageWidth));
    % median filter to despeckle
    if medianFilterOption
        image = medfilt2(image);
    end
    if backgroundSubtractMethod == 1 | backgroundSubtractMethod == 3
        % bin image
        if binOption
            if ~strcmp(binning,'8x8')
                image = bin_matrix(image, binFactor);
            end
        end
    end
    
    %% get signal from sample frame
    % method one: use signal from the final image
    if backgroundSubtractMethod == 1
        backgroundSignal = sum(image(:));
    % method two: use ROI mask
    elseif backgroundSubtractMethod == 2
        % get roi mask
        figure;imshow(image,[]);%0 512]);
        ROImask = double(roipoly);
    % method three: sample one frame towards (but isn't) the beginning of the recording and use signal from two corners
    elseif backgroundSubtractMethod == 3
        % get new image dimensions
        [croppedImageHeight,croppedImageWidth] = size(image);
        % get signal from two corners
        topRightCorner = image(1:round(0.05*croppedImageHeight),round(0.95*croppedImageWidth):croppedImageWidth); % top right 5% of image
        bottomRightCorner = image(round(0.95*croppedImageHeight):croppedImageHeight,round(0.95*croppedImageWidth):croppedImageWidth); % bottom right 5% of image
        topRightSignal = sum(topRightCorner(:))/numel(topRightCorner);
        bottomRightSignal = sum(bottomRightCorner(:))/numel(bottomRightCorner);
        % get average background signal for those two sample sqaures
        backgroundSignal = mean([topRightSignal bottomRightSignal]);
        % display warning if the two regions differ significantly
        if abs(topRightSignal - bottomRightSignal) > min([topRightSignal bottomRightSignal])*0.1
            warning(['background subtraction sample region signals differ by more than 10% for ' filename])
        end
    end
end

%% calculate signal from all frames
for imageCtr = 1:numImages
    % read image frame
    image = double(imread(filename, imageCtr,'Info',info));
    % crop out the bordering 3% from all four sides
    if ~backgroundSubtractOption
        [imageHeight,imageWidth] = size(image);
    end
    image = image(round(0.03*imageHeight):round(0.97*imageHeight), round(0.03*imageWidth):round(0.97*imageWidth));
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
    % subtract background
    if backgroundSubtractOption
        if backgroundSubtractMethod == 2
        % select ROI (subtract background method 2)
        image = image.*ROImask;
        elseif backgroundSubtractMethod == 3
            % (subtract background method 1)
            image = image-backgroundSignal;
        end
    end
    % get total signal from the whole image
    signal(imageCtr) = sum(image(:));
    % subtract background (method 1)
    if backgroundSubtractOption & backgroundSubtractMethod == 1
        signal(imageCtr) = signal(imageCtr) - backgroundSignal;
    end
end