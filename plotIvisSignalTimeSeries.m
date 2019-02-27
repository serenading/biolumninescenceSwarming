clear
close all

%% script plots bioluminescence signal acquired on the IVIS spectrum, 
% and plots signal over time for selected ROI's.
% Signal is measured either by Living Image 4.3.1 software (plotLivingImageSignal = true; photos/sec/cm^2/sr; local function 2),
% or measured directly from exported tiff's (plotLivingImageSignal = false; arbitrary units; local function 3).

%% set up
% set analysis parameters
baseDir = '/Volumes/behavgenom$/Serena/IVIS/';
date = '20190221'; % string in yyyymmdd format
numROI = 9;
plotLivingImageSignal = false; % true: signal measured with LivingImage software; false: signal measured from tiff's
if plotLivingImageSignal
    varName = 'AvgRadiance_p_s_cm__sr_'; % or 'TotalFlux_p_s_';
else
    varName = 'signal (a.u.)';
    matchROI = true;
    exportTiffStack = true;
end
pixeltocm =1920/13.2; % 1920 pixels is 13.2 cm
binFactor = 4;
saveResults = false;


% set figure export options
exportOptions = struct('Format','eps2',...
    'Color','rgb',...
    'Width',30,...
    'Resolution',300,...
    'FontMode','fixed',...
    'FontSize',25,...
    'LineWidth',3);

% extract info from metadata 
[directory,bacDays,frameRate,numFrames] = getMetadata(baseDir,date,numROI);

% initialise
addpath('./AggScreening/auxiliary/')
colorMap = parula(numROI);
signalFig = figure; hold on

%% get signal
if plotLivingImageSignal
    signal = getLivingImageSignal(directory,numROI,varName);
else
    [signal,lumTiffStack] = getIvisSignal(directory,numROI,numFrames,binFactor,matchROI);
end

%% plot and format
legends = cell(1,numROI);
for ROICtr = 1:numROI
    set(0,'CurrentFigure',signalFig)
    plot(signal(ROICtr,:),'Color',colorMap(ROICtr,:))
    legends{ROICtr} = ['ROI ' num2str(ROICtr) ', ' num2str(bacDays(ROICtr)) ' day'];
end
legend(legends)
xTick = get(gca, 'XTick');
set(gca,'XTick',xTick','XTickLabel',xTick*60/frameRate) % rescale x-axis for according to acquisition frame rate
xlabel('minutes')
ylabel(varName)

%% export figure
figurename = ['results/' date '_signal'];
if plotLivingImageSignal
    figurename = [figurename 'LivingImage'];
end
if saveResults
    exportfig(signalFig,[figurename '.eps'],exportOptions)
end

%% export tiff stack if it doesn't exist
if ~plotLivingImageSignal && exportTiffStack
    tiffStackname = strsplit(figurename,'/');
    tiffStackname = [directory tiffStackname{3} '.tiff'];
    if ~exist(tiffStackname,'file')
        for frameCtr = 1:numFrames
            imwrite(lumTiffStack(:,:,frameCtr),tiffStackname, 'WriteMode','append','Compression','none');
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% local functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%% function 1: extract info from metadata %%%%%%
function [directory,bacDays,frameRate,numFrames] = getMetadata(baseDir,date,numROI)

% read metadata
metadata = readtable([baseDir 'metadata_IVIS.xls']);
% find row index for the experiment
expRowIdx = find(strcmp(string(metadata.date),date));
% get directory name
subDirName = char(metadata.subDirName(expRowIdx));
directory = [fullfile(baseDir,subDirName) '/'];
% get row indices to extract bacteria age information
startBacDatesColIdx = find(strcmp(metadata.Properties.VariableNames,'sample_bac_date_1'));
endBacDatesColIdx = find(strcmp(metadata.Properties.VariableNames,['sample_bac_date_',num2str(numROI)]));
bacDates = string(table2array(metadata(expRowIdx,startBacDatesColIdx:endBacDatesColIdx)));
bacDays = datenum(date,'yyyymmdd')- datenum(bacDates,'yyyymmdd');
% get additional information
frameRate = 60/metadata.frameInterval_min(expRowIdx); % frames per hour
numFrames = metadata.numFrames(expRowIdx);
end

%%%%%%% function 2: get signal from LivingImage measurements %%%%%%%%%%%%%%
function signal = getLivingImageSignal(directory,numROI,varName)

[ROIMeasurementList, ~] = dirSearch([directory 'measurements/'],'.txt');
assert(length(ROIMeasurementList) == numROI,'numROI incorrectly specified');
% go through each ROI measurement .txt file
for ROICtr = numROI:-1:1
    filename = ROIMeasurementList{ROICtr};
    signalTable = readtable(filename,'ReadVariableNames',1,'delimiter','\t');
    if isa(signalTable.(varName),'double')
        signal(ROICtr,:) = signalTable.(varName);
    else
        warning('N/A values exist for some measurements')
    end
end
end

%%%%%%% function 3: get signal from raw tiff's %%%%%%%%%%%%%%%%%%
function [signal,lumTiffStack] = getIvisSignal(directory,numROI,numFrames,binFactor,matchROI)

[lumFileList, ~] = dirSearch(directory,'luminescent.TIF');
[darkFileList, ~] = dirSearch(directory,'AnalyzedClickInfo.txt');
% [darkFileList, ~] = dirSearch(directory,'readbiasonly.TIF');
assert(length(lumFileList) == numFrames,'numFrames incorrectly specified');
assert(length(lumFileList) == length(darkFileList),'luminescence vs. dark charge file numbers do not match');
sampleImage = imread(lumFileList{1});
% load or create ROI masks
if matchROI
    % use ROI coordinates from LivingImage measurement files
    [ROIMeasurementList, ~] = dirSearch([directory 'measurements/'],'.txt');
    assert(length(ROIMeasurementList) == numROI,'numROI incorrectly specified');
    frameDims = size(sampleImage);
    % go through each ROI measurement .txt file
    for ROICtr = numROI:-1:1
        filename = ROIMeasurementList{ROICtr};
        signalTable = readtable(filename,'ReadVariableNames',1,'delimiter','\t');
        % get circular ROI coordinates
        ROIx = signalTable.Xc_pixels_(1)/binFactor;
        ROIy = signalTable.Yc_pixels_(1)/binFactor;
        ROIr = signalTable.Width_pixels_(1)/binFactor;
        % generate ROI mask
        ROImask(:,:,ROICtr) = createCirclesMask([frameDims(1),frameDims(2)],[ROIx ROIy],ROIr);
    end 
else
    % load or free draw ROI's
    if exist(fullfile(directory,'ROImask.mat'),'file')
        load(fullfile(directory,'ROImask.mat'),'ROImask')
    else
        % draw ROI masks from the first image
        sampleFig = figure;imshow(sampleImage,[]);
        for ROICtr = numROI:-1:1
            disp(['draw ROI ' num2str(ROICtr)])
            ROImask(:,:,ROICtr) = roipoly; % roipoly function requires manual selection of ROI from the sample image
            assert(sum(sum(ROImask(:,:,ROICtr)))>0,['ROI ' num2str(ROICtr) ' contains no pixel']) % check that ROI contains pixels
        end
        disp('all ROIs drawn')
        save([directory 'ROImask.mat'],'ROImask')
    end
end

% create luminescence TIFF stack and subtract dark charge background
for frameCtr = numFrames:-1:1
    % read background level from text file
    analyzedClickInfo = readtable(darkFileList{frameCtr},'delimiter','\t');
    biasInd = find(arrayfun(@(x) strcmp(x,'Read Bias Level:'), analyzedClickInfo{:,1}));
    biasLevel = str2double(analyzedClickInfo{biasInd(1),2});
    % read frame and subtract background
    lumTiffStack(:,:,frameCtr) = imread(lumFileList{frameCtr})-biasLevel; % uint16
%     darkTiffStack(:,:,frameCtr) = imread(darkFileList{frameCtr});
%     lumTiffStack(:,:,frameCtr) = lumTiffStack(:,:,frameCtr)-darkTiffStack(:,:,frameCtr);
end

% go through each ROI to apply mask and extract signal
for ROICtr = numROI:-1:1
    maskedTiffStack = lumTiffStack.*uint16(ROImask(:,:,ROICtr));
    signal(ROICtr,:) = squeeze(sum(sum(maskedTiffStack,1),2));
end
end