function player = mooc_ui_wave_player(parent, options)
%MOOC_UI_WAVE_PLAYER 波形を見ながら実験を再生する部品
%
%   ステップ1〜3で使う。真ん中の赤い線の時刻に、参加者が見ていた画面を
%   合わせて表示する。処理の前と後の2つのデータを重ねて表示することもできる。
%     player = mooc_ui_wave_player(parent)
%     player.setData(EEG) または player.setData(処理前, 処理後)
%     player.play() / player.stop() / player.clear(文字)

arguments
    parent
    options.Names cell = {'処理前', '処理後'}
    options.Placeholder char = '「読み込む」を押すと、ここに脳波が表示されます'
    options.Group (1, 1) double = 1
end

% ---- Layout --------------------------------------------------------------
grid = uigridlayout(parent, [2 2], 'RowHeight', {'1x', 46}, 'ColumnWidth', {'1x', 300}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 14, 'RowSpacing', 6);
signalAxes = uiaxes(grid);
signalAxes.Layout.Row = 1;
signalAxes.Layout.Column = 1;
sideGrid = uigridlayout(grid, [2 1], 'RowHeight', {140, '1x'}, 'Padding', [0 0 0 0]);
sideGrid.Layout.Row = 1;
sideGrid.Layout.Column = 2;
cueHolder = uigridlayout(sideGrid, [1 3], 'ColumnWidth', {'1x', 210, '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 0);
cue = mooc_ui_cue_display(cueHolder, '参加者の画面（赤線の時刻）', 26);
cue.panel.Layout.Column = 2;
electrodeAxes = uiaxes(sideGrid);
disableDefaultInteractivity(electrodeAxes);
axis(electrodeAxes, 'off');

% The controls come in groups (replay | electrodes | width | time), each
% label right next to its control and wider gaps between the groups.
bar = uigridlayout(grid, [1 4], 'Padding', [0 0 0 0], 'ColumnSpacing', 24, ...
    'ColumnWidth', {218, 232, 150, '1x'});
bar.Layout.Row = 2;
bar.Layout.Column = [1 2];
replayGroup = uigridlayout(bar, [1 2], 'ColumnWidth', {130, 80}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 6);
playButton = uibutton(replayGroup, 'Text', '▶ 実験を再生', 'Enable', 'off', 'Tag', 'option', ...
    'ButtonPushedFcn', @(~, ~) togglePlayback());
speedDropDown = uidropdown(replayGroup, 'Items', {'等速', '2倍速', '4倍速'}, ...
    'ItemsData', [1 2 4], 'Value', 1);
groupGroup = uigridlayout(bar, [1 2], 'ColumnWidth', {72, '1x'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 4);
uilabel(groupGroup, 'Text', '表示する電極', 'HorizontalAlignment', 'right');
groups = localChannelGroups();
groupDropDown = uidropdown(groupGroup, 'Items', {groups.name}, 'ItemsData', 1:numel(groups), ...
    'Value', options.Group, 'ValueChangedFcn', @(~, ~) redraw());
widthGroup = uigridlayout(bar, [1 2], 'ColumnWidth', {72, '1x'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 4);
uilabel(widthGroup, 'Text', '表示の幅', 'HorizontalAlignment', 'right');
widthDropDown = uidropdown(widthGroup, 'Items', {'5秒', '10秒', '20秒'}, ...
    'ItemsData', [5 10 20], 'Value', 20, 'ValueChangedFcn', @(~, ~) updateSlider());
startSlider = uislider(bar, 'Limits', [0 1], 'Value', 0, ...
    'MajorTicks', [], 'MinorTicks', [], 'Enable', 'off', ...
    'ValueChangedFcn', @(slider, ~) showMoment(slider.Value));

mooc_ui_placeholder(signalAxes, options.Placeholder);
cue.show('データがまだありません', NaN);

% ---- Variables shared by the callbacks -------------------------------------
EEG = [];              % the data shown (the "before" data when two are given)
afterEEG = [];         % the data after the processing ([] = only one dataset)
cueEvents = struct('onset', {}, 'duration', {}, 'label', {});
playTimer = [];        % timer driving the replay
chunk = [NaN NaN];     % time range currently plotted (s)
spacing = [];          % vertical distance between channels (uV)
shownCue = '';
nowLine = gobjects(0); % the red line marking "now"

player = struct('setData', @setData, 'play', @play, 'stop', @stopPlayback, ...
    'playFrame', @playFrame, 'clear', @clearData, 'isPlaying', @isPlaying);

% ---- Data ------------------------------------------------------------------
    function setData(newEEG, newAfterEEG)
        stopPlayback();
        EEG = newEEG;
        afterEEG = [];
        if nargin > 1
            afterEEG = newAfterEEG;
        end
        cueEvents = mooc_cue_events(EEG);
        playButton.Enable = 'on';
        updateSlider();
    end

    function clearData(text)
        stopPlayback();
        EEG = [];
        afterEEG = [];
        playButton.Enable = 'off';
        startSlider.Enable = 'off';
        mooc_ui_placeholder(signalAxes, text);
        cla(electrodeAxes);
        cue.show('データがまだありません', NaN);
    end

% ---- Drawing ---------------------------------------------------------------
    function updateSlider()
        if isempty(EEG)
            return;
        end
        maxStart = max(1, EEG.pnts / EEG.srate - widthDropDown.Value);
        startSlider.Limits = [0 maxStart];
        startSlider.Value = min(startSlider.Value, maxStart);
        startSlider.MajorTicks = 0:60:maxStart;
        startSlider.MajorTickLabels = compose('%d分', (0:60:maxStart) / 60);
        startSlider.Enable = 'on';
        redraw();
    end

    function redraw()
        if isempty(EEG)
            return;
        end
        chunk = [NaN NaN];
        spacing = [];
        showMoment(startSlider.Value);
        mooc_topoplot(electrodeAxes, [], EEG.chanlocs, 'Highlight', selectedChannels());
        title(electrodeAxes, '表示中の電極（赤）', 'FontWeight', 'normal');
    end

    function showMoment(startSec)
        % The view starting at STARTSEC, and the cue under the red line.
        showWindow(startSec);
        nowSec = startSec + widthDropDown.Value / 2;
        label = localCueAt(cueEvents, nowSec);
        key = sprintf('%s/%d', label, floor(nowSec));
        if ~strcmp(key, shownCue)       % update the panel only when it changes
            shownCue = key;
            cue.show(label, nowSec);
        end
    end

    function showWindow(startSec)
        % A 60 s chunk is plotted once and the view scrolls inside it, which
        % keeps the replay smooth.
        width = widthDropDown.Value;
        if startSec >= chunk(1) && startSec + width <= chunk(2)
            xlim(signalAxes, [startSec, startSec + width]);
            markNow(startSec + width / 2);
            return;
        end
        channels = selectedChannels();
        if isempty(spacing)
            spacing = localSpacing(EEG, channels);
        end
        chunk = [startSec, startSec + max(60, 2 * width)];
        if isempty(afterEEG)
            mooc_plot_signals(signalAxes, EEG, channels, chunk(1), diff(chunk), ...
                'View', [startSec, startSec + width], 'Spacing', spacing);
        else
            mooc_plot_signals(signalAxes, EEG, channels, chunk(1), diff(chunk), ...
                'View', [startSec, startSec + width], 'Spacing', spacing, ...
                'Compare', afterEEG, 'Names', options.Names);
        end
        markNow(startSec + width / 2);
    end

    function markNow(nowSec)
        % A red line in the middle of the view: the moment whose cue is shown
        % on the participant's screen. It is created once per plotted chunk
        % (plotting a chunk clears the axes) and then only moved.
        if isempty(nowLine) || ~isvalid(nowLine)
            nowLine = xline(signalAxes, nowSec, 'Color', [0.85 0.1 0.1], ...
                'LineWidth', 2.5, 'HitTest', 'off', 'HandleVisibility', 'off');
        end
        nowLine.Value = nowSec;
    end

    function channels = selectedChannels()
        allGroups = localChannelGroups(EEG.chanlocs);
        channels = allGroups(groupDropDown.Value).channels;
    end

% ---- Replay ------------------------------------------------------------------
    function playing = isPlaying()
        playing = ~isempty(playTimer);
    end

    function play()
        if isempty(playTimer) && ~isempty(EEG)
            togglePlayback();
        end
    end

    function togglePlayback()
        if ~isempty(playTimer)
            stopPlayback();
            return;
        end
        playTimer = timer('ExecutionMode', 'fixedRate', 'Period', 0.1, ...
            'BusyMode', 'drop', 'Tag', 'mooc_app_timer', ...
            'TimerFcn', @(~, ~) playFrame(startSlider.Value + 0.1 * speedDropDown.Value));
        playButton.Text = '■ 停止';
        start(playTimer);
    end

    function stopPlayback()
        if ~isempty(playTimer) && isvalid(playTimer)
            stop(playTimer);
            delete(playTimer);
        end
        playTimer = [];
        playButton.Text = '▶ 実験を再生';
    end

    function playFrame(startSec)
        if isempty(EEG) || ~isvalid(signalAxes)
            stopPlayback();
            return;
        end
        if startSec >= startSlider.Limits(2)
            stopPlayback();
            return;
        end
        startSlider.Value = startSec;
        showMoment(startSec);
        drawnow limitrate;
    end
end

% ---- Local functions -----------------------------------------------------
function label = localCueAt(events, timeSec)
label = 'rest';
for event = events
    if timeSec >= event.onset && timeSec < event.onset + event.duration
        label = event.label;
    end
end
end

function spacing = localSpacing(EEG, channels)
% Six times the typical channel standard deviation over the first minute.
rows = ismember(lower({EEG.chanlocs.labels}), lower(channels));
sample = double(EEG.data(rows, 1:min(EEG.pnts, round(60 * EEG.srate))));
spacing = max(10, 6 * median(std(sample, 0, 2)));
end

function groups = localChannelGroups(chanlocs)
% Named channel sets to choose from: a struct array with fields name and
% channels. Channel names are matched case-insensitively (EEGMMIDB uses
% labels such as 'Fc3' and 'Afz'); with CHANLOCS, the last set holds all
% of its channels.

groups = struct( ...
    'name', {'運動野のまわり', '前頭（目に近い）', '後頭（視覚野）', '全64チャンネル'}, ...
    'channels', { ...
        {'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C5', 'C3', 'C1', 'Cz', 'C2', ...
         'C4', 'C6', 'CP3', 'CP1', 'CPz', 'CP2', 'CP4'}, ...
        {'Fp1', 'Fpz', 'Fp2', 'AF7', 'AF3', 'AFz', 'AF4', 'AF8', 'F7', 'F3', ...
         'Fz', 'F4', 'F8'}, ...
        {'P7', 'P3', 'Pz', 'P4', 'P8', 'PO7', 'PO3', 'POz', 'PO4', 'PO8', ...
         'O1', 'Oz', 'O2'}, ...
        {}});
if nargin > 0
    groups(end).channels = {chanlocs.labels};
end
end
