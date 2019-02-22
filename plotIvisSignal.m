clear
close all

%% script plots bioluminescence signal acquired on the IVIS spectrum, 
% and plots signal over time for selected ROI's.
% Signal is measured either by Living Image 4.3.1 software (photos/second/cm^2/sr) (local function 1),
% or measured by FIJI (arbitrary units) (local function 2).

%% set up
% set analysis parameters
directory = '/Volumes/behavgenom$/Serena/IVIS/20190221/SD20190221185606_SEQ/';
plotLivingImageSignal = false; % true: signal measured with LivingImage software; false: signal measured with FIJI
saveResults = true;
% set default parameters
date = strsplit(directory,'/');
date = date{6};
if strcmp(date,'20190219')
    daysInoculation = [18 14 13 12 7 6 6 5 0];
elseif strcmp(date,'20190221')
    daysInoculation = [14 9 8 8 7 7 2 1 0];
end
frameRate = 10; % frames per hour
numFrames = 99;
numROI = 9;
assert(numROI == numel(daysInoculation),'check specified days of inoculation: does not match numROI')
if plotLivingImageSignal
    varName = 'AvgRadiance_p_s_cm__sr_'; % or 'TotalFlux_p_s_';
else
    varName = 'signal (a.u.)';
end
% set figure export options
exportOptions = struct('Format','eps2',...
    'Color','rgb',...
    'Width',30,...
    'Resolution',300,...
    'FontMode','fixed',...
    'FontSize',25,...
    'LineWidth',3);
% initialise
addpath('../AggScreening/auxiliary/')
colorMap = parula(numROI);
signal = NaN(numROI,numFrames);
signalFig = figure; hold on

%% get signal
if plotLivingImageSignal
    signal = getLivingImageSignal(directory,signal,numROI,varName);
else
    signal = getFIJISignal(directory,signal,numROI,numFrames);
end

%% plot and format
for ROICtr = 1:numROI
    set(0,'CurrentFigure',signalFig)
    plot(signal(ROICtr,:),'Color',colorMap(ROICtr,:))
    legends{ROICtr} = ['ROI ' num2str(ROICtr) ', ' num2str(daysInoculation(ROICtr)) ' day'];
end
legend(legends)
xTick = get(gca, 'XTick');
set(gca,'XTick',xTick','XTickLabel',xTick*60/frameRate) % rescale x-axis for according to acquisition frame rate
xlabel('minutes')
ylabel(varName)

%% export figure
figurename = ['results/IVIS/' date '_signal'];
if plotLivingImageSignal
    figurename = [figurename 'LivingImages'];
else
    figurename = [figurename 'FIJI'];
end
if saveResults
    exportfig(signalFig,[figurename '.eps'],exportOptions)
end

%% local functions
%%%%%%%%%%%% local function 1 %%%%%%%%%%%%%%
function signal = getLivingImageSignal(directory,signal,numROI,varName)

[ROIMeasurementList, ~] = dirSearch([directory 'measurements/'],'.txt');
assert(length(ROIMeasurementList) == numROI,'numROI incorrectly specified');
% go through each ROI measurement .txt file
for ROICtr = 1:numROI
    filename = ROIMeasurementList{ROICtr};
    signalTable = readtable(filename,'ReadVariableNames',1,'delimiter','\t');
    signal(ROICtr,:) = signalTable.(varName);
    %%%%% catch error here in case of N/A measurements %%%%
end
end

%%%%%%%%%%% local function 2 %%%%%%%%%%%%%%%%
function signal = getFIJISignal(directory,signal,numROI,numFrames)

[fileList, ~] = dirSearch(directory,'luminescent.TIF');
assert(length(fileList) == numFrames,'numFrames incorrectly specified');
sampleImage = imread(fileList{1});
frameDims = size(sampleImage);
% load or create ROI masks
if exist([directory 'ROImask.mat'])==2
    load([directory 'ROImask.mat'])
else
    % get roi masks using the first image
    sampleFig = figure;imshow(sampleImage,[]);
    ROImask = NaN(frameDims(1),frameDims(2),numROI);
    for ROICtr = 1:numROI
        disp(['draw ROI ' num2str(ROICtr)])
        ROImask(:,:,ROICtr) = roipoly; % roipoly function requires manual selection of ROI from the sample image
        assert(sum(sum(ROImask(:,:,ROICtr)))>0,['ROI ' num2str(ROICtr) ' contains no pixel']) % check that ROI contains pixels
    end
    disp('all ROIs drawn')
    save([directory 'ROImask.mat'],'ROImask')
end

% create TIFF stack for all bioluminescence frames
tiffStack = NaN(frameDims(1),frameDims(2),numFrames);
for frameCtr = 1:numFrames
    tiffStack(:,:,frameCtr) = imread(fileList{frameCtr});
end

% go through each ROI to extract and plot signal
for ROICtr = 1:numROI
    maskedTiffStack = tiffStack.*ROImask(:,:,ROICtr);
    signal(ROICtr,:) = squeeze(sum(sum(maskedTiffStack,1),2));
end
end