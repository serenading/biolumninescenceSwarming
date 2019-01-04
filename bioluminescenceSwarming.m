clear
close all

%% script takes a list of tiff stack images from bioluminescence swarming experiments and plots signal over time

%% set parameters
directory = '/Volumes/behavgenom$/Serena/bioluminescenceSwarming/gly001Test/multiSample/20181221_Gly001_20uL_30sExp300sInt_2x2bin_10hr_overnightbac/';
binning = '2x2'; % '8x8' or '2x2'
duration = '10hr';
bgSubtractOption = false;
medianFilterOption = true;
binOption = false;
saveResults = false;

% set up
addpath('../AggScreening/auxiliary/')
signalQuantFig = figure; hold on
if contains(directory,'multiSample') % need to generate metadata file and read this from there
    date = strsplit(directory,'/');
    date = date{end-1};
    date = strsplit(date,'_');
    date = date{1};
    if strcmp(date, '20181218')
        legends = {'controlPos0','controlPos1','N2Pos2','DA609Pos3','DA609Pos4','DA609Pos5'};
    else
        legends = {'controlPos0','controlPos1','N2Pos2','N2Pos3','DA609Pos4','DA609Pos5'};
    end
else
    legends = {};
end

exportOptions = struct('Format','eps2',...
    'Color','rgb',...
    'Width',30,...
    'Resolution',300,...
    'FontMode','fixed',...
    'FontSize',25,...
    'LineWidth',3);

%% get file names
% get a list of tif files
[fileList, ~] = dirSearch(directory,[binning '*' duration '*.tif']);
if contains(directory,'multiSample')
    filenamesAll = fileList;
else
    % separate files according to strains
    DA609Files = {};
    N2Files = {};
    controlFiles = {};
    for fileCtr = 1:length(fileList)
        filename = fileList{fileCtr};
        if ~contains(filename,'multiSample')
            if contains(filename,'DA609')
                DA609Files = vertcat(DA609Files,{filename});
            elseif contains(filename,'N2')
                N2Files = vertcat(N2Files,{filename});
            else
                controlFiles = vertcat(controlFiles,{filename});
            end
        end
    end
    filenamesAll = vertcat(DA609Files, N2Files, controlFiles);
end
 
%% go through each file
numFiles = numel(filenamesAll);
for fileCtr = 1:numFiles
    fileCtr
    % get filename
    filename = filenamesAll{fileCtr};
    % get signal
    signal{fileCtr} = getSignal(filename,bgSubtractOption,medianFilterOption,binOption);
    % plot signal
    set(0,'CurrentFigure',signalQuantFig)
    plot(smoothdata(signal{fileCtr}))
    % add to figure legend
    if ~contains(directory, 'multiSample')
        date = strsplit(filename,'/');
        date = date{end};
        date = strsplit(date,'_');
        date = date{1};
        if fileCtr<= numel(DA609Files)
            legends = vertcat(legends,['DA609_' date]);
        elseif fileCtr<= numel(DA609Files)+numel(N2Files)
            legends = vertcat(legends,['N2_' date]);
        else
            legends = vertcat(legends,['control_' date]);
        end
    end
end 

% format figure
if strcmp(binning,'8x8')
    xlim([0 1200])
    ylim([0 1e7])
    xlabel('frames (@2fpm)')
elseif strcmp(binning,'2x2')
    if contains(directory,'multiSample')
        xlim([3 120])
        if bgSubtractOption
            ylim([2e6 4.5e6])
        else
            ylim([6.5e7 7.5e7])
        end
        xlabel('frame number (@12fph)')
    else
        xlim([0 600])
        xlabel('time(min)')
    end
end
ylabel('signal (a.u.)')
L = legend(legends,'Location','eastoutside');
set(L,'Interpreter', 'none')

% export figure
figurename = ['results/bioluminescenceQuant_' binning '_' duration];
if contains(directory,'multiSample')
    figurename = [figurename '_multiSample_' date];
end
if contains(directory,'overnightbac')
    figurename = [figurename '_overnightbac'];
end
if ~bgSubtractOption
    figurename = [figurename '_noBgSubtraction'];
end
if saveResults
    exportfig(signalQuantFig,[figurename '.eps'],exportOptions)
end