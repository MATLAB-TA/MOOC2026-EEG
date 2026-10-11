function api = step_filter(tab, state, nav)
%STEP_FILTER ステップ2「ノイズを除去」の画面
%
%   フィルタで電源ノイズなどを除き、前後の周波数ごとの強さと波形を比べる。

cfg = state.cfg;

% ---- Layout --------------------------------------------------------------
guide = struct('title', ['STEP ' mooc_ui_step_names(2)], 'picture', 2, 'lines', {{ ...
    'このステップでは、ステップ1で読み込んだデータから、脳波以外の揺れ（ノイズ）を除きます。', ...
    '・電源ノイズ（60 Hz）を削る（ノッチフィルタ）', ...
    '・脳波に必要な範囲（例：0.5〜45 Hz）だけを残す（バンドパスフィルタ）', ...
    '・データを間引いて軽くし、全電極の平均を基準にそろえる', ...
    '前後の「周波数ごとの強さ」と「波形」を比べて、何が減ったか確かめます。'}});
ui = mooc_ui_page_layout(tab, state, nav, ...
    ['フィルタで、脳波に混ざったノイズを除きます。' newline ...
     '・電源ノイズ：60 Hz（米国の電源の周波数）' newline ...
     '・ゆっくりした揺れ：0.5 Hz未満（汗や体の動き）' newline newline ...
     '観察：フィルタの前後で、波形と周波数ごとの強さがどう変わるか'], ...
    'ControlRows', {24, 28, 28, 28, 24, 24, 34}, 'DescriptionHeight', 165, ...
    'NextStep', 4, 'Guide', guide, ...
    'HistoryGroup', mooc_ui_step_names(2));

notchCheck = uicheckbox(ui.controls, 'Text', '電源ノイズを除く（ノッチフィルタ）', ...
    'Value', cfg.notch.enabled);
notchCheck.Layout.Column = [1 2];
uilabel(ui.controls, 'Text', '電源の周波数');
notchDropDown = uidropdown(ui.controls, 'Items', {'50 Hz', '60 Hz'}, ...
    'ItemsData', [50 60], 'Value', cfg.notch.frequencyHz);
uilabel(ui.controls, 'Text', '残す範囲の下限');
lowField = uieditfield(ui.controls, 'numeric', 'Value', cfg.bandpass.lowHz, ...
    'Limits', [0.1 30], 'ValueDisplayFormat', '%.1f Hz');
uilabel(ui.controls, 'Text', '残す範囲の上限');
highField = uieditfield(ui.controls, 'numeric', 'Value', cfg.bandpass.highHz, ...
    'Limits', [5 79], 'ValueDisplayFormat', '%.1f Hz');
% Resampling and re-referencing start unchecked: students first see the
% effect of the filters alone. (The course data, build_course_dataset,
% uses both, as set in mooc_default_config.)
resampleCheck = uicheckbox(ui.controls, 'Value', false, ...
    'Text', sprintf('1秒あたり%d回に間引く（計算を軽く）', cfg.resample.targetHz));
resampleCheck.Layout.Column = [1 2];
rerefCheck = uicheckbox(ui.controls, 'Value', false, ...
    'Text', '全電極の平均を引く（平均参照）');
rerefCheck.Layout.Column = [1 2];
applyButton = uibutton(ui.controls, 'Text', 'フィルタをかける', 'FontWeight', 'bold', ...
    'Tag', 'stage:filtered', ...
    'ButtonPushedFcn', @(~, ~) applyFilters());
applyButton.Layout.Column = [1 2];

plotGrid = uigridlayout(ui.plotArea, [2 1], 'RowHeight', {'0.8x', '1.2x'}, 'RowSpacing', 10);
psdGrid = uigridlayout(plotGrid, [1 2], 'ColumnWidth', {'1x', 380}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 12);
psdAxes = uiaxes(psdGrid);
localBandList(psdGrid);
player = mooc_ui_wave_player(plotGrid, 'Names', {'フィルタ前', 'フィルタ後'}, ...
    'Placeholder', '「フィルタをかける」を押すと、前後の波形が表示されます');
mooc_ui_placeholder(psdAxes, '「フィルタをかける」を押すと表示されます');

shownKey = {};       % fingerprint of the data the plots were drawn for

api = struct('refresh', @refresh, 'setNextEnabled', ...
    @(flag) set(ui.nextButton, 'Enable', matlab.lang.OnOffSwitchState(flag)), ...
    'applyFilters', @applyFilters, 'stop', player.stop, 'guide', ui.guide);

% ---- Callbacks -----------------------------------------------------------
    function applyFilters(overrides)
        % OVERRIDES (optional, used by tests) sets the controls first, e.g.
        % struct('notchHz', 50, 'lowHz', 8, 'highHz', 30, 'resample', false).
        if nargin == 1
            setControls(overrides);
        end
        fig = ancestor(tab, 'figure');
        if isempty(state.rawEEG)
            uialert(fig, '先に「1. データを理解」で脳波を読み込んでください。', '確認');
            return;
        end
        if lowField.Value >= highField.Value
            uialert(fig, '下限は上限より小さくしてください。', '確認');
            return;
        end
        settings = readSettings();
        working = state.rawEEG;    % modified stage by stage below

        steps = struct('stage', {}, 'label', {}, 'fn', {}, 'run', {}, 'code', {});
        if settings.notch.enabled
            stopBand = settings.notch.frequencyHz + [-1 1] * settings.notch.halfWidthHz;
            steps(end + 1) = mooc_ui_step('filtered', ...
                sprintf('%d Hzの電源ノイズを削る', settings.notch.frequencyHz), ...
                'pop_eegfiltnew', @notchStage, ...
                {sprintf('EEG = pop_eegfiltnew(EEG, %g, %g, [], 1);  %% 1 = その範囲を削る', stopBand)});
        end
        steps(end + 1) = mooc_ui_step('filtered', ...
            sprintf('%.1f〜%.1f Hzだけを通す', settings.bandpass.lowHz, settings.bandpass.highHz), ...
            'pop_eegfiltnew', @bandpassStage, ...
            {sprintf('EEG = pop_eegfiltnew(EEG, %g, %g);', ...
                settings.bandpass.lowHz, settings.bandpass.highHz)});
        if settings.resample.enabled
            steps(end + 1) = mooc_ui_step('filtered', ...
                sprintf('1秒あたり%d回に間引く', settings.resample.targetHz), ...
                'pop_resample', @resampleStage, ...
                {sprintf('EEG = pop_resample(EEG, %d);', settings.resample.targetHz)});
        end
        if settings.reref.enabled
            steps(end + 1) = mooc_ui_step('filtered', '全電極の平均を基準にする', 'pop_reref', ...
                @rerefStage, {'EEG = pop_reref(EEG, []);  % [] = 平均参照'});
        end
        steps(end + 1) = mooc_ui_step('filtered', 'pop_spectopo', ...
            {'figure;', ...
             'pop_spectopo(EEG, 1, [EEG.xmin EEG.xmax] * 1000, ''EEG'', ''freqrange'', [0 80]);   % 周波数ごとの強さ'});

        if ~mooc_ui_run_steps(state, mooc_ui_step_names(2), steps, tab)
            nav.update();
            return;
        end
        working.etc.mooc.filterSettings = settings;
        state.filteredEEG = working;
        redraw();
        nav.update();
        player.play();             % start the replay right away

        function detail = notchStage()
            working = pop_eegfiltnew(working, stopBand(1), stopBand(2), [], 1);
            detail = sprintf('%g〜%g Hz を除去', stopBand);
        end

        function detail = bandpassStage()
            working = pop_eegfiltnew(working, settings.bandpass.lowHz, settings.bandpass.highHz);
            detail = sprintf('%.1f Hzより遅い揺れと %.1f Hzより速い揺れを除去', ...
                settings.bandpass.lowHz, settings.bandpass.highHz);
        end

        function detail = resampleStage()
            before = working.pnts;
            working = pop_resample(working, settings.resample.targetHz);
            detail = sprintf('%d点 → %d点', before, working.pnts);
        end

        function detail = rerefStage()
            working = pop_reref(working, []);
            detail = '各時刻で、全64電極の平均を引いた';
        end
    end

    function setControls(overrides)
        names = fieldnames(overrides);
        controls = struct('notch', notchCheck, 'notchHz', notchDropDown, ...
            'lowHz', lowField, 'highHz', highField, 'resample', resampleCheck, ...
            'reref', rerefCheck);
        for k = 1:numel(names)
            controls.(names{k}).Value = overrides.(names{k});
        end
    end

    function settings = readSettings()
        settings = struct('notch', cfg.notch, 'bandpass', cfg.bandpass, ...
            'resample', cfg.resample, 'reref', cfg.reref);
        settings.notch.enabled = notchCheck.Value;
        settings.notch.frequencyHz = notchDropDown.Value;
        settings.bandpass.lowHz = lowField.Value;
        settings.bandpass.highHz = highField.Value;
        settings.resample.enabled = resampleCheck.Value;
        settings.reref.enabled = rerefCheck.Value;
    end

% ---- Drawing ---------------------------------------------------------------
    function refresh()
        % The tab was opened: show the current data and replay it.
        redraw();
        if ~isempty(state.filteredEEG)
            player.play();
        end
    end

    function redraw()
        % Called after filtering and whenever the tab is opened. The spectra
        % (Welch's method over all channels) take a moment, so the plots are
        % only redone when the data changed since they were drawn.
        if isempty(state.rawEEG) || isempty(state.filteredEEG)
            return;
        end
        key = {localDataKey(state.rawEEG), localDataKey(state.filteredEEG)};
        if isequal(key, shownKey)
            return;
        end
        shownKey = key;
        passBand = state.filteredEEG.etc.mooc.filterSettings.bandpass;
        spectra = struct();
        [spectra.before, spectra.beforeHz] = localSpectrum(state.rawEEG);
        [spectra.after, spectra.afterHz] = localSpectrum(state.filteredEEG);
        mooc_plot_psd_comparison(psdAxes, spectra, ...
            'MaxFrequencyHz', state.rawEEG.srate / 2, 'BandZones', true, ...
            'PassBand', [passBand.lowHz passBand.highHz], ...
            'MarkHz', 60, 'MarkLabel', '電源ノイズ（60 Hz）', ...
            'Names', {'フィルタ前', 'フィルタ後'});
        player.setData(state.rawEEG, state.filteredEEG);
    end
end

% ---- Local functions -----------------------------------------------------
function localBandList(parent)
% The names of the EEG bands, in the colors of their areas in the spectrum
% plot (laid out like the component types of step 3).
bands = mooc_style('bands');
panel = uipanel(parent, 'Title', '脳波の周波数の呼び名（グラフの色の帯）', 'FontWeight', 'bold');
list = uigridlayout(panel, [numel(bands) 2], 'ColumnWidth', {118, '1x'}, ...
    'RowHeight', {'1x', '1x', '1.7x', '1x', '1x'}, 'RowSpacing', 3, 'ColumnSpacing', 6, ...
    'Padding', [8 6 8 6]);
for band = bands
    tint = 0.25 * band.color + 0.75;
    uilabel(list, 'Text', {band.name, sprintf('%g〜%g Hz', band.rangeHz)}, ...
        'FontWeight', 'bold', 'FontColor', band.color * 0.6, 'BackgroundColor', tint, ...
        'HorizontalAlignment', 'center', 'WordWrap', 'on', 'FontSize', 11.5);
    uilabel(list, 'Text', band.description, 'WordWrap', 'on', 'FontSize', 11.5, ...
        'BackgroundColor', tint);
end
end

function key = localDataKey(EEG)
% A cheap fingerprint of a dataset: its size, rate and first samples.
key = [size(EEG.data), EEG.srate, double(EEG.data(1, 1:min(EEG.pnts, 256)))];
end

function [psdDb, frequencies] = localSpectrum(EEG)
% Power spectrum averaged over the channels, from the first 2 minutes
% (Welch's method: 2-second Hann windows, half overlapping).
samples = min(EEG.pnts, 120 * EEG.srate);
window = 2 * EEG.srate;
[power, frequencies] = pwelch(double(EEG.data(:, 1:samples))', hann(window), window / 2, ...
    window, EEG.srate);
psdDb = 10 * log10(mean(power, 2));
end
