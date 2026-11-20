%MAKE_README_GIFS Record the GIF animations shown in README.md (for TAs).
%
%   Drives the teaching app through all steps with subject 1 (imagery),
%   as develop/tests/test_app_workflow.m does, takes a picture of the
%   window after each operation and joins the pictures into GIFs:
%     docs/images/app_tour.gif     steps 0-6, one operation after another
%     docs/images/app_erd.gif      step 4: the scalp maps from -1 s to 4 s
%     docs/images/app_source.gif   step 5: the brain maps from -1 s to 4 s
%   It takes about 15 minutes (the ICA and the source estimation).

projectRoot = fileparts(fileparts(mfilename('fullpath')));   % develop/ -> project
addpath(fullfile(projectRoot, 'src'));
setup_eeglab();

outputDir = fullfile(projectRoot, 'docs', 'images');
if ~isfolder(outputDir)
    mkdir(outputDir);
end
gifWidth = 960;          % pixels; the window is about 1680 wide

app = mooc_app('Visible', 'on');
cleanup = onCleanup(@() localClose(app.figure));
steps = app.steps;
tour = {};               % pictures of the tour, with how long each is shown
tourDelay = [];
snap = @(index) localShoot(app, index, gifWidth);

% ---- Tour of the steps ------------------------------------------------------
tour{end + 1} = snap(1); tourDelay(end + 1) = 2;
steps.intro.checkEnvironment();
tour{end + 1} = snap(1); tourDelay(end + 1) = 2;

tour{end + 1} = snap(2); tourDelay(end + 1) = 2.5;                                 % the guide screen of step 1
steps.data.guide.hide();
tour{end + 1} = snap(2); tourDelay(end + 1) = 1.5;
app.stopReplays();
steps.data.loadData(1, 1);                    % the three imagery runs
steps.data.showPage(1);
tour{end + 1} = snap(2); tourDelay(end + 1) = 2;
steps.data.showPage(2);
steps.data.playFrame(9);
tour{end + 1} = snap(2); tourDelay(end + 1) = 2.5;

steps.filter.guide.hide();
app.stopReplays();
steps.filter.applyFilters(struct('resample', true, 'reref', true));
tour{end + 1} = snap(3); tourDelay(end + 1) = 2.5;

steps.ica.guide.hide();
app.stopReplays();
steps.ica.runIca();
steps.ica.selectComponent(1);
tour{end + 1} = snap(4); tourDelay(end + 1) = 2;
app.stopReplays();
steps.ica.runIclabel();
app.stopReplays();
steps.ica.runSelection();
steps.ica.selectComponent(1);
steps.ica.pointAt(4);
tour{end + 1} = snap(4); tourDelay(end + 1) = 2.5;
app.stopReplays();
steps.ica.runRebuild();
tour{end + 1} = snap(4); tourDelay(end + 1) = 2;
steps.ica.showPage(1);

steps.erd.guide.hide();
app.stopReplays();
steps.erd.cutEpochs();
tour{end + 1} = snap(5); tourDelay(end + 1) = 2;
app.stopReplays();
steps.erd.computeErd();
steps.erd.showFrame(1.0);
tour{end + 1} = snap(5); tourDelay(end + 1) = 2.5;

steps.source.guide.hide();
app.stopReplays();
steps.source.computeSources();
steps.source.showFrame(1.0);
tour{end + 1} = snap(6); tourDelay(end + 1) = 2.5;

app.stopReplays();
exportParent = fullfile(tempdir, 'mooc_readme_export');
if ~isfolder(exportParent)
    mkdir(exportParent);
end
steps.export.exportData(exportParent);
tour{end + 1} = snap(7); tourDelay(end + 1) = 3;
localWriteGif(fullfile(outputDir, 'app_tour.gif'), tour, tourDelay);

% ---- The maps from -1 s to 4 s (as the replay shows them) -------------------
times = -1:0.1:4;
for name = ["erd", "source"]
    index = 5 + (name == "source");
    app.goTo(index);
    app.stopReplays();
    frames = cell(1, numel(times));
    for k = 1:numel(times)
        steps.(name).showFrame(times(k));
        frames{k} = localShoot(app, index, gifWidth);
    end
    delays = 0.12 * ones(1, numel(times));
    delays([1 end]) = 1.5;                     % pause at the start and the end
    localWriteGif(fullfile(outputDir, sprintf('app_%s.gif', name)), frames, delays);
end
fprintf('GIFs saved: %s\n', outputDir);

% ---- Local functions -----------------------------------------------------
function picture = localShoot(app, index, width)
% The window as an image, WIDTH pixels wide. The replay of the tab is
% stopped first (exportapp redraws the whole window; see test_app_workflow).
app.goTo(index);
app.stopReplays();
drawnow;
pause(0.3);
file = [tempname '.png'];
exportapp(app.figure, file);
picture = imresize(imread(file), [NaN width]);
delete(file);
end

function localWriteGif(file, pictures, delays)
for k = 1:numel(pictures)
    [indexed, map] = rgb2ind(pictures{k}, 128, 'nodither');
    if k == 1
        imwrite(indexed, map, file, 'gif', 'LoopCount', Inf, 'DelayTime', delays(k));
    else
        imwrite(indexed, map, file, 'gif', 'WriteMode', 'append', 'DelayTime', delays(k));
    end
end
end

function localClose(fig)
if isvalid(fig)
    close(fig);
end
end
