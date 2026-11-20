function view = mooc_ui_erd_view(parent, cfg, guideLines)
%MOOC_UI_ERD_VIEW 合図の前後で脳波の強さがどう変わるかを、時間を追って見る画面
%
%   ステップ4（電極）とステップ5（脳の領域）で使う。上に時間変化のグラフ、
%   下に分布の図（頭皮または脳）、右に読み方と参加者の画面、下に再生のバー。
%     view = mooc_ui_erd_view(parent, cfg, 読み方の文)
%     view.show(data)   結果を表示する（data の中身は show の中に書いた）
%     view.play() / view.stop() / view.showFrame(秒) / view.clear(文字)

% ---- Layout --------------------------------------------------------------
grid = uigridlayout(parent, [2 2], 'RowHeight', {'1x', 46}, ...
    'ColumnWidth', {'1x', 300}, 'ColumnSpacing', 14, 'RowSpacing', 8);
figureGrid = uigridlayout(grid, [2 2], 'Padding', [0 0 0 0], 'RowSpacing', 12);
courseAxes = [uiaxes(figureGrid), uiaxes(figureGrid)];
mapAxes = [uiaxes(figureGrid), uiaxes(figureGrid)];
sideGrid = uigridlayout(grid, [3 1], 'RowHeight', {'1x', 22, 170}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 4);
guidePanel = uipanel(sideGrid, 'Title', 'グラフの読み方', 'FontWeight', 'bold');
uilabel(uigridlayout(guidePanel, [1 1], 'Padding', [8 6 8 6]), 'WordWrap', 'on', ...
    'VerticalAlignment', 'top', 'FontSize', 12, 'Text', guideLines);
uilabel(sideGrid, 'Text', '参加者が見ていた画面（下の図の時刻）', 'FontWeight', 'bold');
cueGrid = uigridlayout(sideGrid, [1 2], 'Padding', [0 0 0 0], 'ColumnSpacing', 6);
cues = [mooc_ui_cue_display(cueGrid, '左拳の試行'), mooc_ui_cue_display(cueGrid, '右拳の試行')];

timeBar = uigridlayout(grid, [1 3], 'ColumnWidth', {130, 80, '1x'}, 'Padding', [0 0 0 0]);
timeBar.Layout.Column = [1 2];
movieButton = uibutton(timeBar, 'Text', '▶ 再生', 'Enable', 'off', 'Tag', 'option', ...
    'ButtonPushedFcn', @(~, ~) toggleMovie());
speedDropDown = uidropdown(timeBar, 'Items', {'等速', '1/2倍速', '1/4倍速', '1/8倍速'}, ...
    'ItemsData', [1 0.5 0.25 0.125], 'Value', 0.25, 'ValueChangedFcn', @(~, ~) speedChanged());
timeSlider = uislider(timeBar, 'Limits', [-1 4], 'Value', 0, 'Enable', 'off', ...
    'MajorTicks', -1:4, 'MajorTickLabels', {'-1秒', '0（合図）', '1秒', '2秒', '3秒', '4秒'}, ...
    'ValueChangingFcn', @(~, event) seek(event.Value), ...
    'ValueChangedFcn', @(slider, ~) seek(slider.Value));

% ---- Variables shared by the callbacks -------------------------------------
data = [];            % the results shown (given to show)
cursors = gobjects(0);
movieTimer = [];
movieClock = [];      % tic when the replay started, and the time it started at
movieStart = 0;
basis = [];           % the map of each electrode (region) alone, as columns (prepareMaps)
basisKey = {};        % the electrodes (regions) basis was made for
mapSize = [];         % size of one interpolated scalp map

view = struct('show', @show, 'play', @play, 'stop', @stopMovie, ...
    'showFrame', @showFrame, 'clear', @clearView);
clearView('結果がここに表示されます');

% ---- Drawing ---------------------------------------------------------------
    function show(newData)
        stopMovie();
        data = newData;
        for k = 1:2
            mooc_plot_erd_timecourse(courseAxes(k), data.courses, data.courseLabels, ...
                data.courseRows{k}, cfg.epoch.taskSec);
            title(courseAxes(k), data.courseTitles{k}, 'FontWeight', 'normal');
        end
        cursors = arrayfun(@(ax) xline(ax, 0, 'Color', [0.85 0.1 0.1], 'LineWidth', 1.5, ...
            'HandleVisibility', 'off'), courseAxes);

        % One color scale for both maps and all times, set by the typical
        % size of the changes so a few extreme values do not dominate.
        sortedValues = sort(abs(data.erd.percent(:)));
        limit = min(100, max(20, ceil(sortedValues(ceil(0.85 * end)) / 10) * 10));
        for k = 1:2
            if strcmp(data.map, 'scalp')
                mooc_topoplot(mapAxes(k), data.erd.percent(:, 1, k), data.chanlocs, ...
                    'ColorLimits', [-limit limit], 'Highlight', data.highlight, ...
                    'ColorbarLabel', '%', 'ShowSides', true);
            else
                mooc_plot_brain(mapAxes(k), data.brain, data.erd.percent(:, 1, k), limit, ...
                    'Highlight', data.highlight, 'ColorbarLabel', '%');
            end
        end
        prepareMaps();
        timeSlider.Limits = data.erd.times([1 end]);
        timeSlider.Value = data.erd.times(1);
        timeSlider.Enable = 'on';
        movieButton.Enable = 'on';
        showFrame(timeSlider.Value);
    end

    function prepareMaps()
        % A map is linear in the electrode (region) values, so the map of any
        % values is a weighted sum of the maps of each electrode (region)
        % alone. These are made once; then every frame of the replay is one
        % matrix product, fast enough to change the colors gradually.
        if strcmp(data.map, 'scalp')
            key = {data.chanlocs.labels};
        else
            key = data.brain.regionNames;
        end
        if isequal(key, basisKey)
            return;
        end
        if strcmp(data.map, 'scalp')
            progress = uiprogressdlg(ancestor(parent, 'figure'), 'Title', '準備中', ...
                'Indeterminate', 'on', 'Message', '頭皮上の分布のアニメーションを準備しています（数秒）');
            closeProgress = onCleanup(@() delete(progress));
            maps = mooc_topoplot([], eye(numel(key)), data.chanlocs, 'GridOnly', true);
            mapSize = [size(maps, 1), size(maps, 2)];
            basis = reshape(maps, [], numel(key));
        else
            % Each point of the cortex takes the value of its region (points
            % in no region stay 0 = white).
            inRegion = find(data.brain.region > 0);
            basis = sparse(inRegion, data.brain.region(inRegion), 1, ...
                numel(data.brain.region), numel(key));
        end
        basisKey = key;
    end

    function showFrame(timeSec)
        % Maps, time cursors and participant's screens at TIMESEC. Between two
        % computed time points the values are interpolated, so the maps
        % change smoothly.
        if isempty(data)
            return;
        end
        erd = data.erd;
        timeSec = min(max(timeSec, erd.times(1)), erd.times(end));
        column = min(find(erd.times <= timeSec, 1, 'last'), numel(erd.times) - 1);
        weight = (timeSec - erd.times(column)) / (erd.times(column + 1) - erd.times(column));
        for k = 1:2
            values = (1 - weight) * erd.percent(:, column, k) + weight * erd.percent(:, column + 1, k);
            % The map is drawn once (show); here only its colors change, which
            % is fast and leaves the axes as they are.
            if strcmp(data.map, 'scalp')
                surface = findobj(mapAxes(k), 'Type', 'surface');
                surface(1).CData = reshape(basis * values, mapSize);
            else
                brainPatch = findobj(mapAxes(k), 'Type', 'patch');
                brainPatch(1).FaceVertexCData = full(basis * values);
            end
            title(mapAxes(k), sprintf('%s：合図から %+.2f 秒', ...
                mooc_style('label', erd.classes{k}), timeSec), 'FontWeight', 'normal');
        end
        set(cursors(isvalid(cursors)), 'Value', timeSec);
        inTask = timeSec >= cfg.epoch.taskSec(1) && timeSec < cfg.epoch.taskSec(2);
        if inTask
            cues(1).show('left_fist', NaN);
            cues(2).show('right_fist', NaN);
        else
            cues(1).show('rest', NaN);
            cues(2).show('rest', NaN);
        end
    end

    function clearView(text)
        stopMovie();
        data = [];
        mooc_ui_placeholder(courseAxes(1), text);
        mooc_ui_placeholder(courseAxes(2), '');
        mooc_ui_placeholder(mapAxes(1), '');
        mooc_ui_placeholder(mapAxes(2), '');
        movieButton.Enable = 'off';
        timeSlider.Enable = 'off';
        cues(1).show('rest', NaN);
        cues(2).show('rest', NaN);
    end

% ---- Replay in real time ----------------------------------------------------
    function play()
        if isempty(movieTimer) && ~isempty(data)
            toggleMovie();
        end
    end

    function toggleMovie()
        if ~isempty(movieTimer)
            stopMovie();
            return;
        end
        if timeSlider.Value >= timeSlider.Limits(2) - 0.1
            timeSlider.Value = timeSlider.Limits(1);
        end
        movieStart = timeSlider.Value;
        movieClock = tic;
        movieTimer = timer('ExecutionMode', 'fixedRate', 'Period', 0.05, ...
            'BusyMode', 'drop', 'Tag', 'mooc_app_timer', 'TimerFcn', @(~, ~) nextFrame());
        movieButton.Text = '■ 停止';
        start(movieTimer);
    end

    function seek(timeSec)
        % Moving the slider (or changing the speed) shows that time; during
        % the replay, the replay goes on from there.
        if ~isempty(movieTimer)
            movieStart = timeSec;
            movieClock = tic;
        end
        showFrame(timeSec);
    end

    function speedChanged()
        seek(timeSlider.Value);
    end

    function nextFrame()
        % The time follows the clock, so the replay runs in real time even
        % when drawing a frame takes longer than the timer period.
        next = movieStart + toc(movieClock) * speedDropDown.Value;
        if next > timeSlider.Limits(2)
            stopMovie();
            return;
        end
        timeSlider.Value = next;
        showFrame(next);
        drawnow limitrate;
    end

    function stopMovie()
        if ~isempty(movieTimer) && isvalid(movieTimer)
            stop(movieTimer);
            delete(movieTimer);
        end
        movieTimer = [];
        movieButton.Text = '▶ 再生';
    end
end
