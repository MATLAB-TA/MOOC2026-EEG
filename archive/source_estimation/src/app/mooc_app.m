function app = mooc_app(options)
%MOOC_APP アプリの画面を作り、ステップ0〜6のタブを並べる
%
%     app = mooc_app()            画面を開く
%     app = mooc_app('Visible', 'off')   画面を出さずに作る（テスト用）

arguments
    options.Visible (1, :) char = 'on'
end

stepNames = mooc_ui_step_names();
stepKeys = {'intro', 'data', 'filter', 'ica', 'erd', 'source', 'export'};
builders = {@step_intro, @step_data, @step_filter, @step_ica, @step_erd, @step_source, @step_export};

state = MoocAppState(mooc_default_config());
fig = uifigure('Name', '脳波解析演習 — EEG Motor Movement/Imagery Dataset', ...
    'Position', localWindowPosition(), 'Visible', options.Visible);
fig.CloseRequestFcn = @(~, ~) closeApp();
% The bar on top is set apart from the tabs by a gap of the window color.
layout = uigridlayout(fig, [2 1], 'RowHeight', {64, '1x'}, 'Padding', [0 0 0 0], ...
    'RowSpacing', 8);
pipelineBar = mooc_ui_pipeline_bar(layout);
tabGroup = uitabgroup(layout);

% Each step receives "nav" so it can switch tabs and update the tab titles.
nav = struct('goTo', @goTo, 'update', @updateTitles);
tabs = gobjects(1, numel(stepNames));
for index = 1:numel(stepNames)
    tabs(index) = uitab(tabGroup);
    app.steps.(stepKeys{index}) = builders{index}(tabs(index), state, nav);
end
tabGroup.SelectionChangedFcn = @(~, event) onTabChanged(event.NewValue);
updateTitles();

app.figure = fig;
app.state = state;
app.goTo = @goTo;
app.stopReplays = @() stopReplays([]);

    function goTo(index)
        tabGroup.SelectedTab = tabs(index);
        onTabChanged(tabs(index));
    end

    function onTabChanged(selectedTab)
        index = find(tabs == selectedTab, 1);
        stopReplays(index);       % a replay left running on another tab stops
        app.steps.(stepKeys{index}).refresh();   % and the new tab's replay starts
        updateTitles();
        state.history.redraw();   % the history view of a hidden tab may be blank
    end

    function updateTitles()
        % "✓" marks finished steps; the next button opens once a step is done.
        % The bar above the tabs shows the state of the dataset.
        pipelineBar.update(state, find(tabs == tabGroup.SelectedTab, 1));
        done = state.completedSteps();
        for k = 1:numel(tabs)
            mark = '';
            if done(k)
                mark = ' ✓';
            end
            tabs(k).Title = sprintf('%d. %s%s', k - 1, stepNames{k}, mark);
            app.steps.(stepKeys{k}).setNextEnabled(done(k));
        end
        mooc_ui_style_buttons(fig, state);   % color the buttons by their role now
    end

    function stopReplays(except)
        % Stop the replays of all tabs but EXCEPT (tab index, [] = none).
        for k = setdiff(1:numel(stepKeys), except)
            if isfield(app.steps.(stepKeys{k}), 'stop')
                app.steps.(stepKeys{k}).stop();
            end
        end
    end

    function closeApp()
        % Stop the replay / movie timers before the figure disappears.
        timers = timerfindall('Tag', 'mooc_app_timer');
        if ~isempty(timers)
            stop(timers);
            delete(timers);
        end
        delete(fig);
    end
end

function position = localWindowPosition()
% Fill most of the screen, but never smaller than the layout needs.
screen = get(groot, 'ScreenSize');
width = max(1360, min(1680, screen(3) - 60));
height = max(780, min(880, screen(4) - 100));
position = [30, max(30, screen(4) - height - 60), width, height];
end
