function api = step_data(tab, state, nav)
%STEP_DATA ステップ1「データを理解」の画面
%
%   参加者と記録を選んで読み込み、波形を見たり、実験を再生したりする。

cfg = state.cfg;

% ---- Layout --------------------------------------------------------------
guide = struct('title', ['STEP ' mooc_ui_step_names(1)], 'picture', 1, 'lines', {{ ...
    'このステップでは、1人の参加者の脳波を読み込み、どんなデータかを確かめます。', ...
    '・参加者と、使う記録を選ぶ（1回の記録は 約2分・合図 約15回）', ...
    '・同じ動作（例：左右の拳を動かすところを想像する）を行っている記録をつなげて、合図の回数を増やす', ...
    '・波形を見たり、合図に合わせて再生したりする', ...
    'ここで読み込んだデータを、この後のすべてのステップで使います（画面上部の「解析中のデータ」）。'}});
ui = mooc_ui_page_layout(tab, state, nav, ...
    ['・① 記録を選ぶ：つなげる記録を選び、読み込む' newline ...
     '・② 脳波を見る：波形を見たり、実験を再生したりする' newline newline ...
     '観察：合図（左・右・休憩）によって、波形が変わるか'], ...
    'ControlRows', {28, 40}, 'DescriptionHeight', 175, ...
    'NextStep', 3, 'Guide', guide, ...
    'HistoryGroup', mooc_ui_step_names(1));

% Only the participants whose recordings were downloaded (setup.m, section 4).
subjects = localDownloadedSubjects(cfg);
uilabel(ui.controls, 'Text', '参加者');
if isempty(subjects)
    subjectDropDown = uidropdown(ui.controls, 'Items', {'（脳波データがありません）'}, ...
        'Enable', 'off');          % setup.m, section 4 downloads the recordings
else
    subjectDropDown = uidropdown(ui.controls, 'Items', compose('S%03d', subjects), ...
        'ItemsData', subjects, 'Value', subjects(1), ...
        'ValueChangedFcn', @(~, ~) updateSelectionLabel());
end
loadButton = uibutton(ui.controls, 'Text', 'チェックした記録を読み込んでつなげる', 'Tag', 'stage:raw', ...
    'FontWeight', 'bold', 'WordWrap', 'on', ...
    'ButtonPushedFcn', @(~, ~) loadRuns(subjectDropDown.Value, checkedRuns()));
loadButton.Layout.Column = [1 2];

pages = uitabgroup(uigridlayout(ui.plotArea, [1 1], 'Padding', [0 0 0 0]), ...
    'SelectionChangedFcn', @(~, ~) playIfShown());
selectPage = uitab(pages, 'Title', '① 記録を選ぶ');
viewPage = uitab(pages, 'Title', '② 脳波を見る');

% Page ①: the recordings table, why they are joined, and the joined result.
records = localRecordTable(cfg);
selectGrid = uigridlayout(selectPage, [3 2], 'RowHeight', {'1x', 26, 170}, ...
    'ColumnWidth', {'1x', 360}, 'ColumnSpacing', 14, 'RowSpacing', 8);
recordTable = uitable(selectGrid, 'Data', records.table, ...
    'ColumnEditable', [true false false false], 'ColumnWidth', {50, 60, 'auto', 140}, ...
    'RowName', {}, 'CellEditCallback', @(~, ~) updateSelectionLabel());
whyPanel = uipanel(selectGrid, 'Title', '記録の選び方', 'FontWeight', 'bold');
uilabel(uigridlayout(whyPanel, [1 1]), 'WordWrap', 'on', 'VerticalAlignment', 'top', ...
    'FontSize', 12.5, 'Text', { ...
    '【記録をつなげる理由】', ...
    '・1回の記録は約2分で、合図は約15回（左右それぞれ7〜8回）', ...
    '・脳波の変化は小さく、1回分の記録では見えにくい', ...
    '・同じ動作をしている記録をつなげて、合図を増やす（3回分で約45回）', ...
    '', ...
    '【この6つの記録だけを使う理由】', ...
    '・この演習の目的は「左拳と右拳で、脳の反応がどう違うか」を調べること', ...
    '・参加者は14回記録しているが、左拳・右拳の合図があるのは、R03・R07・R11（実際に動かす）と、R04・R08・R12（動かすところを想像する）の6回だけ（ほかは安静や、両拳・両足の課題）', ...
    '・動かすときと想像するときでは脳の働き方が違うので、混ぜない', ...
    '・そのため、「動かす」か「想像する」のどちらか一方から、1〜3回分を選ぶ'});
selectionLabel = uilabel(selectGrid, 'Text', '', 'FontWeight', 'bold');
selectionLabel.Layout.Column = [1 2];
timelineAxes = uiaxes(selectGrid);
timelineAxes.Layout.Column = [1 2];
mooc_ui_placeholder(timelineAxes, '記録を選ぶと、つなげた結果がここに表示されます');

% Page ②: the waveforms and the replay of the experiment.
player = mooc_ui_wave_player(viewPage);

% ---- Variables shared by the callbacks -------------------------------------
runEEGs = {};          % runs imported but not yet joined
runSeconds = [];       % length of each joined run (s)
cueEvents = struct('onset', {}, 'duration', {}, 'label', {});

api = struct('refresh', @refresh, 'setNextEnabled', ...
    @(flag) set(ui.nextButton, 'Enable', matlab.lang.OnOffSwitchState(flag)), ...
    'loadData', @loadData, 'loadRuns', @loadRuns, 'playFrame', player.playFrame, ...
    'stop', player.stop, ...
    'showPage', @showPage, 'guide', ui.guide);
checkConditionRuns(1);    % the imagery runs are ticked at first

% ---- Callbacks: loading --------------------------------------------------
    function loadData(subject, conditionIndex)
        % Load the three runs of one task (used by tests and as a shortcut).
        checkConditionRuns(conditionIndex);
        loadRuns(subject, checkedRuns());
    end

    function loadRuns(subject, runs)
        [conditionIndex, message] = localConditionOf(cfg, runs);
        if isempty(conditionIndex)
            uialert(ancestor(tab, 'figure'), message, '記録の選び方');
            return;
        end
        player.stop();
        runEEGs = cell(1, numel(runs));

        steps = struct('stage', {}, 'label', {}, 'fn', {}, 'run', {}, 'code', {});
        for k = 1:numel(runs)
            fileName = sprintf('S%03dR%02d.edf', subject, runs(k));
            steps(end + 1) = mooc_ui_step('raw', ...
                sprintf('%d回目の記録（%s）を読み込む', k, fileName), 'pop_biosig', ...
                @() importRun(subject, runs, k), ...
                {sprintf('EEG%d = pop_biosig(''%s'');', k, fileName)}); %#ok<AGROW>
        end
        joinCode = [{'EEG = EEG1;'}, ...
            compose('EEG = pop_mergeset(EEG, EEG%d);', 2:numel(runs))];
        joinLabel = sprintf('%d回分の記録を1つにつなげる', numel(runs));
        if isscalar(runs)
            joinLabel = '記録は1回分なので、そのまま使う';
        end
        steps(end + 1) = mooc_ui_step('raw', joinLabel, 'pop_mergeset', @joinRuns, joinCode);
        steps(end + 1) = mooc_ui_step('raw', '電極の名前から頭の上の位置を割り当てる', ...
            'pop_chanedit', @() assignPositions(subject, runs), ...
            {'EEG = pop_chanedit(EEG, ''lookup'', ''standard_1005.elc'');'});
        steps(end + 1) = mooc_ui_step('raw', 'pop_eegplot', ...
            {'pop_eegplot(EEG, 1, 1, 1);   % 波形（スクロールして見る）'});

        state.subject = subject;
        state.conditionIndex = conditionIndex;
        state.runs = runs;
        if ~mooc_ui_run_steps(state, mooc_ui_step_names(1), steps, tab)
            nav.update();
            return;
        end
        cueEvents = mooc_cue_events(state.rawEEG);
        mooc_plot_run_timeline(timelineAxes, runs, runSeconds, cueEvents);
        player.setData(state.rawEEG);
        pages.SelectedTab = viewPage;
        nav.update();
        player.play();             % start the replay right away
    end

    function detail = importRun(subject, runs, k)
        runEEGs{k} = mooc_import_run(subject, runs(k), cfg);
        detail = sprintf('%dチャンネル × %d点、合図 %d回', ...
            runEEGs{k}.nbchan, runEEGs{k}.pnts, ...
            nnz(ismember({runEEGs{k}.event.type}, {'T1', 'T2'})));
    end

    function detail = joinRuns()
        runSeconds = cellfun(@(EEG) EEG.pnts / EEG.srate, runEEGs);
        joined = runEEGs{1};
        for k = 2:numel(runEEGs)
            joined = pop_mergeset(joined, runEEGs{k}, 0);
        end
        state.rawEEG = joined;
        runEEGs = {};
        detail = sprintf('合計 %d点（%.1f分）', joined.pnts, ...
            joined.pnts / joined.srate / 60);
    end

    function detail = assignPositions(subject, runs)
        joined = pop_chanedit(state.rawEEG, 'lookup', cfg.paths.channelLocationFile);
        joined.setname = sprintf('S%03d_R%s', subject, strjoin(compose('%02d', runs), '_'));
        joined.etc.mooc.subject = subject;
        joined.etc.mooc.runs = runs;
        state.rawEEG = joined;
        located = nnz(~cellfun(@isempty, {state.rawEEG.chanlocs.X}));
        detail = sprintf('%d個中 %d個の電極に位置を設定', state.rawEEG.nbchan, located);
    end

% ---- Callbacks: choosing recordings -----------------------------------------
    function checkConditionRuns(conditionIndex)
        % Tick exactly the runs of one task.
        recordTable.Data.('使う') = ismember(records.runs, cfg.data.conditions(conditionIndex).runs);
        updateSelectionLabel();
    end

    function showPage(page)
        % 1 = ① 記録を選ぶ, 2 = ② 脳波を見る (used by tests)
        allPages = [selectPage viewPage];
        pages.SelectedTab = allPages(page);
    end

    function runs = checkedRuns()
        runs = records.runs(recordTable.Data.('使う'))';
    end

    function updateSelectionLabel()
        runs = checkedRuns();
        [conditionIndex, message] = localConditionOf(cfg, runs);
        loadButton.Enable = ~isempty(conditionIndex) && ~isempty(subjects);
        mooc_ui_style_buttons(ancestor(tab, 'figure'), state);
        if isempty(conditionIndex)
            selectionLabel.Text = ['⚠ ' message];
            selectionLabel.FontColor = [0.75 0.2 0.1];
        else
            selectionLabel.Text = sprintf('選んだ記録：%s（%s、%d回分・合図 約%d回）', ...
                strjoin(compose('R%02d', runs), '、'), ...
                cfg.data.conditions(conditionIndex).displayName, numel(runs), 15 * numel(runs));
            selectionLabel.FontColor = [0.15 0.15 0.15];
        end
        previewTimeline(runs, ~isempty(conditionIndex));
    end

    function previewTimeline(runs, isValid)
        % The checked recordings joined along one time axis, before they are
        % loaded. Recordings already on this computer show their cues;
        % the others are drawn with their usual length only.
        if ~isValid
            mooc_ui_placeholder(timelineAxes, 'つなげられる記録を選ぶと、ここに表示されます');
            return;
        end
        [plannedSeconds, cues, isLocal] = localRunPreview(subjectDropDown.Value, runs);
        if all(isLocal)
            titleText = sprintf('つなげた記録（予定）：合計 %.1f分、合図 %d回（青：左拳、橙：右拳）', ...
                sum(plannedSeconds) / 60, numel(cues));
        else
            titleText = sprintf(['つなげた記録（予定）：合計 約%.0f分' ...
                '（合図の位置は、読み込むと表示されます）'], sum(plannedSeconds) / 60);
        end
        mooc_plot_run_timeline(timelineAxes, runs, plannedSeconds, cues, titleText);
    end

    function refresh()
        if isempty(state.rawEEG)
            player.clear('「読み込む」を押すと、ここに脳波が表示されます');
        else
            playIfShown();
        end
    end

    function playIfShown()
        % The replay runs whenever page ② is on screen.
        if pages.SelectedTab == viewPage && ~isempty(state.rawEEG)
            player.play();
        else
            player.stop();
        end
    end
end

% ---- Local functions -----------------------------------------------------
function records = localRecordTable(cfg)
% The recordings used in this exercise: the left / right fist tasks (moving
% and imagining), in run order. The other recordings of the dataset
% (rest, both fists / feet) are not used and not downloaded by setup.m.
runs = sort([cfg.data.conditions.runs])';
task = strings(numel(runs), 1);
cues = strings(numel(runs), 1);
for k = 1:numel(runs)
    info = cfg.data.runInfo(runs(k));
    task(k) = info.task;
    cues(k) = mooc_style('label', info.t1) + "／" + mooc_style('label', info.t2);
end
records.runs = runs;
records.table = table(false(numel(runs), 1), compose('R%02d', runs), task, cues, ...
    'VariableNames', {'使う', '記録', '課題', '合図の内容（T1／T2）'});
end

function [conditionIndex, message] = localConditionOf(cfg, runs)
% The task (index into cfg.data.conditions) all RUNS belong to, or [] and
% the reason why they cannot be used together.
conditionIndex = [];
message = '';
if isempty(runs)
    message = '記録を1つ以上選んでください。';
    return;
end
owner = arrayfun(@(run) find(arrayfun(@(c) ismember(run, c.runs), cfg.data.conditions), 1), runs);
if numel(unique(owner)) > 1
    message = '実動作と運動イメージが混ざっています。どちらか一方だけを選んでください。';
else
    conditionIndex = owner(1);
end
end

function [runSeconds, cues, isLocal] = localRunPreview(subject, runs)
% Length (s) and left / right cues of each run, read from the small event
% files when the recording is already on this computer. Other runs get
% the usual length of about 2 minutes and no cues (nothing is downloaded).
srate = 160;                 % all EEGMMIDB recordings
cueNames = struct('T1', 'left_fist', 'T2', 'right_fist');   % runs 3, 4, 7, 8, 11, 12
runSeconds = 125 * ones(1, numel(runs));
isLocal = false(1, numel(runs));
cues = struct('onset', {}, 'duration', {}, 'label', {});
offset = 0;
for k = 1:numel(runs)
    try
        edfFile = mooc_find_edf(subject, runs(k));
        events = mooc_read_wfdb_events([edfFile '.event'], srate);
        isLocal(k) = true;
        runSeconds(k) = (events(end).latency - 1 + events(end).duration) / srate;
        for event = events(ismember({events.type}, {'T1', 'T2'}))
            cues(end + 1) = struct('onset', offset + (event.latency - 1) / srate, ...
                'duration', event.duration / srate, 'label', cueNames.(event.type)); %#ok<AGROW>
        end
    catch
        % not downloaded yet
    end
    offset = offset + runSeconds(k);
end
end

function subjects = localDownloadedSubjects(cfg)
% Participants with at least one recording in external/PhysioNet (the
% excluded ones are left out even when present).
subjects = [];
for subject = setdiff(1:109, cfg.data.excludedSubjects)
    subjectId = sprintf('S%03d', subject);
    if ~isempty(dir(fullfile(cfg.paths.rawDir, subjectId, [subjectId 'R*.edf'])))
        subjects(end + 1) = subject; %#ok<AGROW>
    end
end
end
