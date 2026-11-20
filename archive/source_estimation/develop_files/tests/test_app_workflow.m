%TEST_APP_WORKFLOW Drive the teaching app through all steps without clicks.
%
%   Uses subject 1 (imagery) and computes its ICA (a few minutes),
%   exercises the replay, the ICA stages and their save points, the
%   component types, the processing history, the time slider of the
%   scalp maps and the export, and saves a screenshot of every step to
%   develop/screenshots/app_<n>_<step>.png so the layout can be checked by eye.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % develop/<folder>/ -> project
addpath(fullfile(projectRoot, 'src'));
setup_eeglab();

app = mooc_app('Visible', 'on');
cleanup = onCleanup(@() localClose(app.figure));
state = app.state;
steps = app.steps;
outputDir = fullfile(projectRoot, 'develop', 'screenshots');
% Opening a tab starts its replay (and analyses start some too). A replay
% must never run while an analysis computes, so every analysis below is
% preceded by app.stopReplays(), and every screenshot ends with it.
shoot = @(index, name) localShoot(app, index, fullfile(outputDir, ...
    sprintf('app_%d_%s.png', index - 1, name)));

shoot(1, 'intro_before');
assert(steps.intro.checkEnvironment(), 'Environment check failed.');
done = state.completedSteps();
assert(done(1));
shoot(1, 'intro');

shoot(2, 'data_guide');           % the guide screen covers the tab at first
steps.data.guide.hide();
shoot(2, 'data_preview');         % the checked recordings, before loading
% Recordings that cannot be joined are refused (nothing is loaded).
app.stopReplays();
steps.data.loadRuns(1, [3 4]);    % movement and imagery mixed
assert(isempty(state.rawEEG));
app.stopReplays();
steps.data.loadRuns(1, [4 8]);    % two imagery runs
assert(isequal(state.runs, [4 8]) && state.rawEEG.pnts == 2 * 20000);
app.stopReplays();
steps.data.loadData(1, 1);        % the three imagery runs (the replay starts)
steps.data.showPage(1);
shoot(2, 'data_select');
assert(~isempty(state.rawEEG) && state.rawEEG.nbchan == 64);
assert(isequal(state.rawEEG.etc.mooc.runs, [4 8 12]));
steps.data.showPage(2);
steps.data.playFrame(9);          % replay: red line at 19 s (20 s view)
shoot(2, 'data');

steps.filter.guide.hide();
app.stopReplays();
steps.filter.applyFilters();      % default: filters only (the replay starts)
assert(state.filteredEEG.srate == state.rawEEG.srate);
assert(~strcmp(state.filteredEEG.ref, 'average'));
shoot(3, 'filter');
% Downsampled and average-referenced, as in the course data (faster ICA).
app.stopReplays();
steps.filter.applyFilters(struct('resample', true, 'reref', true));
assert(state.filteredEEG.srate == state.cfg.resample.targetHz);
assert(strcmp(state.filteredEEG.ref, 'average'));

shoot(4, 'ica_guide');            % the guide screen with the ICA picture
steps.ica.guide.hide();
app.goTo(4);
shoot(4, 'ica_before');
app.stopReplays();
steps.ica.runIca();
assert(state.isDone('decomposition'));
% After ② the maps can be inspected; the types appear only after ③.
steps.ica.selectComponent(1);
tic;
for k = 2:11
    steps.ica.selectComponent(k);     % clicking through must be quick
end
drawnow;
fprintf('10 component clicks: %.2f s\n', toc);
shoot(4, 'ica_components');
app.stopReplays();
steps.ica.runIclabel();
app.stopReplays();
steps.ica.runSelection();
assert(numel(state.rejectMask) == size(state.icaEEG.icaweights, 1));
steps.ica.selectComponent(1);
steps.ica.pointAt(4);             % pointing at a map highlights its type
shoot(4, 'ica');
app.stopReplays();
steps.ica.runRebuild();
assert(~isempty(state.cleanEEG));
shoot(4, 'ica_compare');
steps.ica.showPage(1);

% Save points: redoing ③ keeps ①-② and clears only ④ (and its history).
app.stopReplays();
steps.ica.runSelection();
assert(state.isDone('decomposition') && state.isDone('iclabel'));
assert(~state.isDone('clean'));
assert(~any(strcmp({state.history.entries.stage}, 'clean')));
app.stopReplays();
steps.ica.runRebuild();

shoot(5, 'erd_guide');            % the guide screen of step 4
steps.erd.guide.hide();
shoot(5, 'erd_before');           % the recordings with their cues
app.stopReplays();
assert(steps.erd.cutEpochs());
shoot(5, 'erd_epochs');           % lines from the cues, and the epochs of C3
app.stopReplays();
steps.erd.computeErd();           % the replay starts
assert(~isempty(state.erd));
assert(isequal(state.erd.classes, {'left_fist', 'right_fist'}));
steps.erd.showFrame(1.0);
% Stepping through time (as the animation does) must not shrink the maps.
allAxes = findall(app.figure, 'Type', 'axes');
mapAxes = allAxes(arrayfun(@(a) startsWith(string(a.Title.String), "左拳：合図から"), allAxes));
before = mapAxes(1).InnerPosition;
for t = 0:0.25:3
    steps.erd.showFrame(t);
end
drawnow;
assert(isequal(mapAxes(1).InnerPosition, before), 'The scalp map changed size.');
steps.erd.showFrame(1.0);
shoot(5, 'erd');

% Signal source estimation from the epochs of step 4.
steps.source.guide.hide();
app.stopReplays();
steps.source.computeSources();
assert(state.isDone('regionErd'));
assert(isequal(size(state.sourceEEG.roi.source_roi_data), [68, state.epochEEG.pnts, state.epochEEG.trials]));
assert(isequal(size(state.regionErd.percent, 1), 68));
shoot(6, 'source');

% Export: one EEGLAB dataset (.set), in the same form as external/mooc_dataset.
app.stopReplays();
assert(isempty(steps.export.exportData(fullfile(projectRoot, 'src'))));   % refused
exportParent = fullfile(tempdir, 'mooc_export_test');
if ~isfolder(exportParent)
    mkdir(exportParent);
end
app.stopReplays();
exportFile = steps.export.exportData(exportParent);
assert(endsWith(exportFile, '.set'));
saved = pop_loadset(exportFile);
assert(isequal(size(saved.data), size(state.epochEEG.data)));
assert(max(abs(saved.data - state.epochEEG.data), [], 'all') < 1e-3);
assert(isequal(size(saved.roi.source_roi_data), [68, state.epochEEG.pnts, state.epochEEG.trials]));
assert(numel(saved.roi.atlas.Scouts) == 68);
assert(numel(saved.etc.mooc.labels) == state.epochEEG.trials);
assert(isequal(saved.etc.mooc.labels, string(state.trialLabels)));
assert(all(ismember(saved.etc.mooc.runs, state.runs)));
assert(height(saved.etc.mooc.info) > 0 && contains(saved.history, 'pop_runica'));
assert(~isfield(saved.dipfit.sourcemodel, 'leadfield'));   % not saved (8 MB)

shoot(7, 'export');
% The whole history can be shown in place of the plots.
for button = findall(app.figure, 'Type', 'uibutton', 'Text', '右側に全体を表示')'
    button.ButtonPushedFcn(button, []);     % one button per tab
end
shoot(7, 'export_history');

assert(isequal(state.completedSteps(), true(1, 7)));
% The history lists every stage done to the dataset, in order.
stagesInHistory = unique({state.history.entries.stage}, 'stable');
assert(isequal(stagesInHistory, state.Stages));

% Redoing an earlier step must clear the later results and their history.
app.stopReplays();
steps.filter.applyFilters();
assert(isempty(state.icaEEG) && isempty(state.cleanEEG) && isempty(state.erd));
assert(isequal(state.completedSteps(), [true true true false false false false]));
assert(isequal(unique({state.history.entries.stage}, 'stable'), {'raw', 'filtered'}));

% Unusual filter settings must still work and give finite key numbers.
unusual = {
    struct('notchHz', 50, 'lowHz', 8, 'highHz', 30, 'resample', false, 'reref', false)
    struct('notch', false, 'lowHz', 0.5, 'highHz', 79, 'resample', true, 'reref', true)
    struct('notch', true, 'notchHz', 60, 'lowHz', 20, 'highHz', 25, 'resample', true, 'reref', false)
    };
for k = 1:numel(unusual)
    app.stopReplays();
    steps.filter.applyFilters(unusual{k});
    assert(~isempty(state.filteredEEG), 'Filter settings %d failed.', k);
    expectedRate = state.cfg.resample.targetHz;
    if ~unusual{k}.resample
        expectedRate = state.rawEEG.srate;
    end
    assert(state.filteredEEG.srate == expectedRate);
end
shoot(3, 'filter_unusual');

% Plots must stay inside the app window (no stray figures).
assert(numel(findall(groot, 'Type', 'figure')) == 1, 'A plot opened a separate window.');
fprintf('App workflow test passed. Screenshots: %s\n', outputDir);

function localClose(fig)
if isvalid(fig)
    close(fig);
end
end

function localShoot(app, index, file)
% Opening a tab starts its replay. It is stopped before the picture is
% taken: exportapp redraws the whole window, and a replay redrawing every
% 0.1 s at the same time makes it take minutes. The picture then shows the
% first frame of the replay.
app.goTo(index);
app.stopReplays();
drawnow;
pause(1.5);
exportapp(app.figure, file);
end
