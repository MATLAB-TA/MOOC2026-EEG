function api = step_erd(tab, state, nav)
%STEP_ERD ステップ4「左右の拳で脳の変化を比較」の画面
%
%   ① 合図ごとに切り出す（エポック）。② 選んだ周波数の強さが合図の後に
%   どう変わるかを、左拳と右拳で比べる。

cfg = state.cfg;
group = mooc_ui_step_names(4);      % heading in the processing history

% ---- Layout --------------------------------------------------------------
guide = struct('title', ['STEP ' group], 'picture', 4, 'lines', {{ ...
    'このステップでは、ノイズを除いたデータを使い、合図の前後で脳波がどう変わるかを調べます。', ...
    '・① 合図ごとに切り出す：左拳・右拳の合図のところを、それぞれ合図の1秒前〜4秒後だけ切り出して重ねる（エポック）', ...
    '・② 周波数帯を選んで解析する：その周波数の強さが合図の後にどう変わるかを、左拳・右拳ごとに平均して求める', ...
    '・体を動かす（想像する）と、反対側の運動野で、その強さが弱くなります（ERD：事象関連脱同期）', ...
    ['観察：左拳のときは右脳（C4）、右拳のときは左脳（C3）で弱くなるか。' ...
     'この左右の違いが、機械学習で左右を見分ける手がかりになります。']}});
ui = mooc_ui_page_layout(tab, state, nav, ...
    ['・① 合図ごとに切り出す（エポック）' newline ...
     '・② 周波数帯を選んで、合図の後に強さがどう変わるかを見る' newline newline ...
     '観察：左拳と右拳で、弱くなる場所が左右逆になるか'], ...
    'ControlRows', {108, 144, 'fit'}, 'DescriptionHeight', 165, ...
    'NextStep', 6, 'Guide', guide, 'HistoryGroup', group);

% Each stage has its own box: its settings, then its button.
epochPanel = uipanel(ui.controls, 'Title', '① 合図ごとに切り出す', 'FontWeight', 'bold');
epochPanel.Layout.Column = [1 2];
epochControls = uigridlayout(epochPanel, [2 2], 'RowHeight', {28, 34}, ...
    'ColumnWidth', {'1x', '1.4x'}, 'Padding', [8 6 8 8]);
uilabel(epochControls, 'Text', '図で見る電極');
channelDropDown = uidropdown(epochControls, 'Items', {'C3（左脳の運動野）', 'Cz（頭のてっぺん）', ...
    'C4（右脳の運動野）'}, 'ItemsData', {'C3', 'Cz', 'C4'}, 'Value', 'C3', ...
    'ValueChangedFcn', @(~, ~) drawEpochs());
epochButton = uibutton(epochControls, 'Text', 'エポックに分ける', 'Tag', 'stage:epoch', ...
    'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) cutEpochs());
epochButton.Layout.Column = [1 2];

analysisPanel = uipanel(ui.controls, 'Title', '② 周波数帯を選んで解析する', 'FontWeight', 'bold');
analysisPanel.Layout.Column = [1 2];
analysisControls = uigridlayout(analysisPanel, [3 2], 'RowHeight', {28, 28, 34}, ...
    'ColumnWidth', {'1x', '1.4x'}, 'Padding', [8 6 8 8]);
bandPicker = mooc_ui_band_picker(analysisControls, cfg, @() recomputeIfShown());
analyzeButton = uibutton(analysisControls, 'Text', '解析する', 'Tag', 'stage:erd', ...
    'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) computeErd());
analyzeButton.Layout.Column = [1 2];
sourceLabel = uilabel(ui.controls, 'Text', '', 'WordWrap', 'on', 'FontColor', [0.4 0.4 0.4]);
sourceLabel.Layout.Column = [1 2];

pages = uitabgroup(uigridlayout(ui.plotArea, [1 1], 'Padding', [0 0 0 0]), ...
    'SelectionChangedFcn', @(~, ~) playIfShown());
epochPage = uitab(pages, 'Title', '① 合図ごとに切り出す');
changePage = uitab(pages, 'Title', '② 脳の変化を見る');

% Page ①: the recordings with the cues, and the epochs below.
epochGrid = uigridlayout(epochPage, [2 2], 'RowHeight', {230, '1x'}, 'RowSpacing', 6, ...
    'ColumnSpacing', 16);
flowAxes = uiaxes(epochGrid);
flowAxes.Layout.Column = [1 2];
leftEpochAxes = uiaxes(epochGrid);
rightEpochAxes = uiaxes(epochGrid);
mooc_ui_placeholder(leftEpochAxes, '①の「エポックに分ける」を押すと表示されます');
mooc_ui_placeholder(rightEpochAxes, '');

% Page ②: band-power change at C3 / C4 and over the scalp, replayed in time.
erdView = mooc_ui_erd_view(changePage, cfg, localGuideLines());

% ---- Variables shared by the callbacks -------------------------------------
api = struct('refresh', @refresh, 'setNextEnabled', ...
    @(flag) set(ui.nextButton, 'Enable', matlab.lang.OnOffSwitchState(flag)), ...
    'cutEpochs', @cutEpochs, 'computeErd', @computeErd, 'showFrame', erdView.showFrame, ...
    'showPage', @showPage, 'stop', erdView.stop, 'guide', ui.guide);
refresh();

% ---- Callbacks: the two stages -------------------------------------------
    function ok = cutEpochs()
        ok = false;
        if isempty(state.rawEEG)
            uialert(ancestor(tab, 'figure'), '先に「1. データを理解」で脳波を読み込んでください。', '確認');
            return;
        end
        erdView.stop();
        stage = mooc_ui_step('epoch', '合図ごとに切り出す（エポック化）', 'pop_epoch', @cut, ...
            {'EEG = pop_epoch(EEG, {''T1'', ''T2''}, [-1 4], ''epochinfo'', ''yes'');  % T1 = 左拳、T2 = 右拳', ...
                 '% 各試行の合図：合図の時刻（0 ミリ秒）に T1 があれば左拳、なければ右拳', ...
                 'isLeft = ~isnan(eeg_getepochevent(EEG, ''type'', ''T1'', ''timewin'', [0 0])));', ...
                 'labels = categorical(isLeft(:), [true false], {''left_fist'', ''right_fist''});   % 試行 × 1'});
        stage = [stage, mooc_ui_step('epoch', 'pop_eegplot', ...
            {'pop_eegplot(EEG, 1, 1, 1);   % 切り出した試行を1つずつ見る'})];
        ok = mooc_ui_run_steps(state, group, stage, tab);
        refresh();
        pages.SelectedTab = epochPage;
        nav.update();

        function detail = cut()
            state.epochEEG = pop_epoch(state.latestContinuous(), {'T1', 'T2'}, ...
                cfg.epoch.windowSec, 'epochinfo', 'yes');
            % left / right fist: is there a T1 cue at time 0 of the epoch?
            isLeft = ~isnan(eeg_getepochevent(state.epochEEG, 'type', 'T1', 'timewin', [0 0]));
            state.trialLabels = categorical(isLeft(:), [true false], {'left_fist', 'right_fist'});
            detail = sprintf('%d回分 × %dチャンネル × %d点', state.epochEEG.trials, ...
                state.epochEEG.nbchan, state.epochEEG.pnts);
        end
    end

    function computeErd()
        if ~state.isDone('epoch') && ~cutEpochs()
            return;
        end
        erdView.stop();
        band = bandPicker.band();
        c3 = find(strcmpi({state.epochEEG.chanlocs.labels}, 'C3'), 1);
        windowLength = round(cfg.erd.windowSec * state.epochEEG.srate);
        steps = [ ...
            mooc_ui_step('erd', sprintf('%s の強さを時間ごとに計算（時間周波数解析）', band.displayName), ...
                'pop_newtimef', @computePower, ...
                {'% 左拳・右拳ごと、64電極それぞれに pop_newtimef を行う（例：左拳の試行の C3）', ...
                 'EEGleft = pop_select(EEG, ''trial'', find(labels == ''left_fist''));', ...
                 sprintf(['[ersp, ~, powbase, times] = pop_newtimef(EEGleft, 1, %d, %s, 0, ' ...
                    '''freqs'', [%g %g], ''winsize'', %d, ''timesout'', %d, ''baseline'', [-1000 0], ' ...
                    '''plotersp'', ''off'', ''plotitc'', ''off'');'], c3, ...
                    mat2str(round([state.epochEEG.xmin state.epochEEG.xmax] * 1000)), band.rangeHz, ...
                    windowLength, cfg.erd.timePoints), ...
                 sprintf('P = mean(powbase(:) .* 10 .^ (ersp / 10), 1);   %% %g〜%g Hz の強さ（時間ごと）', ...
                    band.rangeHz)}), ...
            mooc_ui_step('erd', '左拳・右拳ごとに、休憩中と比べた変化にする', 'mooc_compute_erd', @summarize, ...
                {'% 合図前の1秒間（休憩中）を基準にした変化率（全電極・左右をまとめて計算）', ...
                 sprintf('erd = mooc_compute_erd(EEG, labels, [%g %g], [-1 0], cfg);', band.rangeHz), ...
                 '% ERD = (P - P_rest) ./ P_rest * 100'}), ...
            mooc_ui_step('erd', 'pop_newtimef', ...
                {'figure;', ...
                 sprintf(['pop_newtimef(EEGleft, 1, %d, %s, 0, ''freqs'', [3 40], ' ...
                    '''baseline'', [-1000 0]);   %% C3 の時間周波数の図（左拳）'], c3, ...
                    mat2str(round([state.epochEEG.xmin state.epochEEG.xmax] * 1000)))})];
        if mooc_ui_run_steps(state, group, steps, tab)
            showResults();
            pages.SelectedTab = changePage;
        end
        refresh();
        nav.update();

        function detail = computePower()
            state.erd = mooc_compute_erd(state.epochEEG, state.trialLabels, band.rangeHz, ...
                cfg.epoch.baselineSec, cfg);
            detail = sprintf('%dチャンネル × 左右 × %d時点', state.epochEEG.nbchan, numel(state.erd.times));
        end

        function detail = summarize()
            detail = sprintf('左拳 %d回・右拳 %d回の平均（基準：合図前の1秒間）', ...
                state.erd.trialCount);
        end
    end

    function recomputeIfShown()
        if ~isempty(state.erd)
            computeErd();
        end
    end

% ---- Drawing: page ① -------------------------------------------------------
    function drawFlow()
        % The recordings with their cues; after cutting, a line from every
        % cue to the plot of its kind.
        EEG = state.latestContinuous();
        if isempty(EEG)
            mooc_ui_placeholder(flowAxes, '先に「1. データを理解」で脳波を読み込んでください');
            return;
        end
        cueEvents = mooc_cue_events(EEG);
        mooc_plot_run_timeline(flowAxes, state.runs, localRunSeconds(EEG), cueEvents);
        if ~state.isDone('epoch')
            return;
        end
        totalMinutes = EEG.pnts / EEG.srate / 60;
        targets = struct('left_fist', 0.25 * totalMinutes, 'right_fist', 0.75 * totalMinutes);
        hold(flowAxes, 'on');
        for event = cueEvents
            if ~isfield(targets, event.label)
                continue;
            end
            [~, color] = mooc_style('label', event.label);
            plot(flowAxes, [event.onset / 60, targets.(event.label)], [0.1 -1.25], ...
                'Color', [color 0.35], 'LineWidth', 0.8, 'HitTest', 'off');
        end
        for label = fieldnames(targets)'
            [name, color] = mooc_style('label', label{1});
            plot(flowAxes, targets.(label{1}), -1.35, 'v', 'MarkerSize', 12, ...
                'Color', color, 'MarkerFaceColor', color, 'HitTest', 'off');
            text(flowAxes, targets.(label{1}), -1.55, sprintf('%sの合図 → 下の図', name), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                'Color', color, 'FontWeight', 'bold', 'HitTest', 'off');
        end
        hold(flowAxes, 'off');
        ylim(flowAxes, [-1.9 1.6]);
    end

    function drawEpochs()
        if ~state.isDone('epoch')
            mooc_ui_placeholder(leftEpochAxes, '①の「エポックに分ける」を押すと表示されます');
            mooc_ui_placeholder(rightEpochAxes, '');
            return;
        end
        channel = channelDropDown.Value;
        epochAxes = [leftEpochAxes rightEpochAxes];
        labels = {'left_fist', 'right_fist'};
        rows = ismember(state.trialLabels, labels);
        row = find(strcmpi({state.epochEEG.chanlocs.labels}, channel), 1);
        values = sort(abs(reshape(double(state.epochEEG.data(row, :, rows)), 1, [])));
        limit = values(ceil(0.99 * end));          % the same scale for left and right
        for k = 1:2
            localPlotEpochs(epochAxes(k), state.epochEEG, state.trialLabels, labels{k}, ...
                channel, limit, cfg.epoch.taskSec);
        end
    end

% ---- Drawing: page ② -------------------------------------------------------
    function showResults()
        % ERD at C3 / C4 and over the scalp; showing new results replays them
        % from the beginning.
        band = bandPicker.band();
        erdView.show(struct('erd', state.erd, 'courses', state.erd, ...
            'courseLabels', {{state.epochEEG.chanlocs.labels}}, 'courseRows', {{'C3', 'C4'}}, ...
            'courseTitles', {{['左脳の運動野（C3）の ' band.displayName], ...
                ['右脳の運動野（C4）の ' band.displayName]}}, ...
            'map', 'scalp', 'chanlocs', state.epochEEG.chanlocs, 'highlight', {{'C3', 'C4'}}));
    end

    function showPage(page)
        % 1 = ① 合図ごとに切り出す, 2 = ② 脳の変化を見る (used by tests)
        allPages = [epochPage changePage];
        pages.SelectedTab = allPages(page);
    end

    function refresh()
        sourceLabel.Text = localSourceText(state);
        analyzeButton.Enable = ~isempty(state.rawEEG);
        drawFlow();
        drawEpochs();
        if isempty(state.erd)
            erdView.clear('②の「解析する」を押すと表示されます');
        else
            playIfShown();
        end
    end

    function playIfShown()
        % The replay runs whenever page ② is on screen (from where it was).
        if pages.SelectedTab == changePage && ~isempty(state.erd)
            erdView.play();
        else
            erdView.stop();
        end
    end
end

% ---- Local functions -----------------------------------------------------
function localPlotEpochs(ax, epochEEG, trialLabels, label, channel, limit, taskSec)
% Every epoch of LABEL at CHANNEL (thin gray) and their average (thick).
row = find(strcmpi({epochEEG.chanlocs.labels}, channel), 1);
members = trialLabels == label;
times = epochEEG.times / 1000;
trials = squeeze(double(epochEEG.data(row, :, members)));
[name, color] = mooc_style('label', label);
cla(ax, 'reset');
hold(ax, 'on');
patch(ax, taskSec([1 2 2 1]), limit * [-1 -1 1 1], [0.93 0.93 0.93], ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, times, trials, 'Color', [0.55 0.55 0.55 0.35], 'LineWidth', 0.5, ...
    'HandleVisibility', 'off');
plot(ax, times, mean(trials, 2), 'Color', color, 'LineWidth', 2.5, ...
    'DisplayName', sprintf('%d回の平均', nnz(members)));
xline(ax, 0, '--', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
hold(ax, 'off');
xlim(ax, times([1 end]));
ylim(ax, limit * [-1 1]);
xlabel(ax, '合図からの時間 (秒)　（点線＝合図、灰色＝拳を動かす4秒間）');
ylabel(ax, '電位 (µV)');
title(ax, sprintf('%sの合図（%d回）：%s の波形（灰色＝1回ずつ）', name, nnz(members), channel), ...
    'FontWeight', 'normal', 'Color', color);
legend(ax, 'Location', 'northeast');
box(ax, 'on');
disableDefaultInteractivity(ax);
end

function runSeconds = localRunSeconds(EEG)
% Length of each joined recording (s), from the boundary events of the join.
boundaries = EEG.event(strcmp({EEG.event.type}, 'boundary'));
edges = [0, sort((double([boundaries.latency]) - 0.5) / EEG.srate), EEG.pnts / EEG.srate];
runSeconds = diff(edges);
end

function text = localSourceText(state)
if ~isempty(state.cleanEEG)
    text = '使うデータ：ICAでノイズを除いた信号';
elseif ~isempty(state.filteredEEG)
    text = '使うデータ：フィルタ後の信号（ICAはまだ）';
elseif ~isempty(state.rawEEG)
    text = '使うデータ：読み込んだままの信号';
else
    text = '';
end
end

function lines = localGuideLines()
% How to read the four plots.
lines = { ...
    '【上：時間の変化】', ...
    '・横軸：合図からの時間（灰色の範囲が、拳を動かす4秒間）', ...
    '・縦軸：休憩中（緑）を0%とした強さ', ...
    '・0より下は休憩中より弱くなったことを表し、その場所が働いていたと考える', ...
    '・青線：左拳、橙線：右拳', ...
    '【下：頭皮上の分布】', ...
    '・頭を上から見た図（上が鼻）。青いほど弱くなった', ...
    '【見るポイント】', ...
    '・左拳のとき、右脳（C4）で下がるか', ...
    '・右拳のとき、左脳（C3）で下がるか'};
end
