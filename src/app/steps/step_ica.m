function api = step_ica(tab, state, nav)
%STEP_ICA ステップ3「独立成分分析（ICA）」の画面
%
%   ICA で波形を成分に分け、ICLabel で成分の種類を判定し、ノイズの成分を
%   除いて電極の波形に組み立て直す。

cfg = state.cfg;
types = localComponentTypes();      % the 7 ICLabel classes and their features
group = mooc_ui_step_names(3);      % heading in the processing history

% ---- Layout: left column -----------------------------------------------------
guide = struct('title', ['STEP ' group], 'picture', @mooc_plot_ica_concept, ...
    'pictureHeight', 330, 'width', 1180, 'lines', {{ ...
    '・手元のデータは、いろいろな信号が混ざって電極に記録された波形（図の左から2列目）', ...
    '・① ICA：混ざった波形を、互いに独立な「成分」にほどく（この時点では、何の信号かは分からない）', ...
    '・② ICLabel：各成分の要因（脳・眼・筋肉など）を自動で分類する', ...
    '・③ 除去するノイズの成分を選ぶ', ...
    '・④ 残した成分だけで電極の波形に組み立て直す → ノイズの少ない波形', ...
    '左の「操作」のボタンを①から順に押します。済んだ段階には ✔ が付き、途中からやり直せます。'}});
ui = mooc_ui_page_layout(tab, state, nav, ...
    ['・ICAで、電極の波形を独立な「成分」にほどく' newline ...
     '・ICLabelで、各成分の要因（脳・眼・筋肉など）を分類する' newline ...
     '・ノイズの成分を除き、電極の波形に組み立て直す'], ...
    'ControlRows', {28, 28, 28, 26, 26, 28}, 'DescriptionHeight', 150, ...
    'NextStep', 5, 'Guide', guide, ...
    'HistoryGroup', group);
ui.controls.ColumnWidth = {'1x', 120};

stageNames = {'decomposition', 'iclabel', 'selection', 'clean'};
stageTexts = {'① ICAで成分に分ける', '② ICLabelで分類する', ...
    '③ 除去する成分を決める', '④ 64電極の信号に組み立て直す'};
stageLabels = gobjects(1, 4);
stageLabels(1) = uilabel(ui.controls, 'Text', stageTexts{1});
icaButton = uibutton(ui.controls, 'Text', '実行（数分）', 'Tag', 'stage:decomposition', ...
    'ButtonPushedFcn', @(~, ~) runIca());
stageLabels(2) = uilabel(ui.controls, 'Text', stageTexts{2});
iclabelButton = uibutton(ui.controls, 'Text', '実行', 'Tag', 'stage:iclabel', ...
    'ButtonPushedFcn', @(~, ~) runIclabel());
stageLabels(3) = uilabel(ui.controls, 'Text', stageTexts{3});
selectButton = uibutton(ui.controls, 'Text', '決定', 'Tag', 'stage:selection', ...
    'ButtonPushedFcn', @(~, ~) runSelection());
uilabel(ui.controls, 'Text', '　　除去する成分', 'FontColor', [0.4 0.4 0.4]);
policyDropDown = uidropdown(ui.controls, ...
    'Items', {'脳・その他以外', '脳以外', 'ノイズの確率が高い成分', '脳の確率が低い成分'}, ...
    'ItemsData', {'brain_other', 'not_brain', 'artifact_threshold', 'brain_only'}, ...
    'Value', cfg.ica.selectionPolicy, 'ValueChangedFcn', @(~, ~) settingsChanged());
uilabel(ui.controls, 'Text', '　　確率のしきい値', 'FontColor', [0.4 0.4 0.4]);
thresholdField = uieditfield(ui.controls, 'numeric', 'Value', cfg.ica.threshold, ...
    'Limits', [0.05 0.99], 'ValueChangedFcn', @(~, ~) settingsChanged());
stageLabels(4) = uilabel(ui.controls, 'Text', stageTexts{4});
rebuildButton = uibutton(ui.controls, 'Text', '実行', 'FontWeight', 'bold', 'Tag', 'stage:clean', ...
    'ButtonPushedFcn', @(~, ~) runRebuild());

% ---- Layout: plot area ---------------------------------------------------
plotGrid = uigridlayout(ui.plotArea, [1 2], 'ColumnWidth', {'1x', 370}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 14);

% Left: the result pages, shown once ① is done.
resultTabs = uitabgroup(plotGrid, 'Visible', 'off', ...
    'SelectionChangedFcn', @(~, ~) updateSideColumn());
inspectTab = uitab(resultTabs, 'Title', '① 成分を調べる');
compareTab = uitab(resultTabs, 'Title', '② 除去の前後を比べる');

% Page ①: all scalp maps, and below them the clicked component's details.
inspectGrid = uigridlayout(inspectTab, [3 2], 'RowHeight', {22, '1.5x', '1x'}, ...
    'ColumnWidth', {'1x', '0.8x'}, 'RowSpacing', 6);
hintLabel = uilabel(inspectGrid, 'FontColor', [0.15 0.35 0.6], 'FontWeight', 'bold', 'Text', ...
    ['使い方：成分の図をクリックすると、下にその成分の時間変化と周波数の内訳、' ...
     '右の「成分の要因」に ICLabel の判定（②の後）が表示されます']);
hintLabel.Layout.Column = [1 2];
gridAxes = uiaxes(inspectGrid);
gridAxes.Layout.Column = [1 2];
disableDefaultInteractivity(gridAxes);
activityAxes = uiaxes(inspectGrid);
spectrumAxes = uiaxes(inspectGrid);

% Page ②: before / after comparison, with the replay of the experiment.
comparePlayer = mooc_ui_wave_player(compareTab, 'Names', {'除去前', '除去後'}, ...
    'Group', 2, 'Placeholder', '④を実行すると、除去の前後の波形が表示されます');

% Right: what ICLabel is, and (after ②) the 7 component types.
sideGrid = uigridlayout(plotGrid, [2 1], 'RowHeight', {215, '1x'}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 10);
localIclabelPanel(sideGrid);
typePanel = uipanel(sideGrid, 'Title', '成分の要因', 'FontWeight', 'bold', 'Visible', 'off');
typeGrid = uigridlayout(typePanel, [numel(types) + 3, 2], 'ColumnWidth', {92, '1x'}, ...
    'RowHeight', [{20, '1x'}, repmat({42}, 1, numel(types)), {24}], ...
    'RowSpacing', 3, 'ColumnSpacing', 4, 'Padding', [8 6 8 6]);
selectedLabel = uilabel(typeGrid, 'FontWeight', 'bold', ...
    'Text', '左の図の成分をクリックすると、ICLabelの判定が表示されます');
selectedLabel.Layout.Column = [1 2];
pieAxes = uiaxes(typeGrid);           % ICLabel's probabilities of the clicked component
pieAxes.Layout.Column = [1 2];
disableDefaultInteractivity(pieAxes);
axis(pieAxes, 'off');
typeNames = gobjects(1, numel(types));
typeTexts = gobjects(1, numel(types));
for k = 1:numel(types)
    [~, color] = mooc_style('icClass', types(k).class);
    typeNames(k) = uilabel(typeGrid, 'Text', types(k).name, 'FontWeight', 'bold', ...
        'FontColor', color, 'HorizontalAlignment', 'center');
    typeTexts(k) = uilabel(typeGrid, 'WordWrap', 'on', 'FontSize', 11.5, ...
        'Text', {['頭皮上の分布：' types(k).map], ['波形：' types(k).wave]});
end
rejectCheck = uicheckbox(typeGrid, 'Text', 'この成分を除去する（×印）', 'Enable', 'off', ...
    'ValueChangedFcn', @(~, ~) toggleSelected());
rejectCheck.Layout.Column = [1 2];

% Pointing at a scalp map highlights its type (see highlightType).
fig = ancestor(tab, 'figure');
fig.WindowButtonMotionFcn = @(~, ~) pointerMoved();

% ---- Variables shared by the callbacks -------------------------------------
shownIca = [];       % ICA weights the grid belongs to
icaGrid = [];        % functions that restyle the grid (mooc_plot_ic_grid)
activations = [];    % signal of every component (rows), computed once per ICA
selected = [];       % component shown in the detail plots
pointed = [];        % component under the mouse pointer

api = struct('refresh', @refresh, 'setNextEnabled', ...
    @(flag) set(ui.nextButton, 'Enable', matlab.lang.OnOffSwitchState(flag)), ...
    'runIca', @runIca, ...
    'runIclabel', @runIclabel, 'runSelection', @runSelection, 'runRebuild', @runRebuild, ...
    'selectComponent', @selectComponent, 'pointAt', @pointAt, ...
    'showPage', @showPage, 'stop', comparePlayer.stop, 'guide', ui.guide);
refresh();

% ---- Callbacks: the four stages --------------------------------------------
% Each stage runs through mooc_ui_run_steps, which first clears that stage
% and the later ones, then adds the stage to the processing history.

    function runIca()
        stage = mooc_ui_step('decomposition', 'ICAで成分に分ける（数分かかります）', ...
            'pop_runica', @decompose, ...
            {'EEG = pop_runica(EEG, ''icatype'', ''runica'', ''extended'', 1, ''rndreset'', ''off'');', ...
             '% rndreset off：乱数を固定し、やり直しても同じ結果にする', ...
             '% 成分の数は、pop_runica が独立な信号の数（データの次元）に合わせて自動で決める'});
        runStage(stage);

        function detail = decompose()
            state.icaDecomposedEEG = pop_runica(state.filteredEEG, 'icatype', 'runica', ...
                'extended', 1, 'rndreset', 'off', 'interrupt', 'off');
            componentCount = size(state.icaDecomposedEEG.icaweights, 1);
            detail = sprintf('%d 個の成分に分けました', componentCount);
            if componentCount < state.filteredEEG.nbchan
                detail = sprintf('%s（%d電極より少ないのは、平均参照などで独立な信号の数が減るため）', ...
                    detail, state.filteredEEG.nbchan);
            end
        end
    end

    function runIclabel()
        stage = mooc_ui_step('iclabel', 'ICLabelで各成分の要因を推定する', 'pop_iclabel', ...
            @classify, {'EEG = pop_iclabel(EEG, ''default'');'});
        stage = [stage, mooc_ui_step('iclabel', 'pop_viewprops', ...
            {'pop_viewprops(EEG, 0, 1:35);   % 成分の頭皮上の分布と ICLabel の判定（35個まで）'})];
        runStage(stage);

        function detail = classify()
            state.icaEEG = pop_iclabel(state.icaDecomposedEEG, cfg.ica.iclabelVersion);
            detail = localClassCounts(state.icaEEG);
        end
    end

    function runSelection()
        [~, code, functionName] = localSelectComponents(state.icaEEG, policyDropDown.Value, ...
            thresholdField.Value);
        stage = mooc_ui_step('selection', '除去する成分を決める', functionName, @choose, code);
        runStage(stage);

        function detail = choose()
            state.rejectMask = localSelectComponents(state.icaEEG, policyDropDown.Value, ...
                thresholdField.Value);
            detail = sprintf('%s：%d 個を除去する（図の×印）', ...
                policyDropDown.Items{strcmp(policyDropDown.ItemsData, policyDropDown.Value)}, ...
                nnz(state.rejectMask));
        end
    end

    function runRebuild()
        stage = mooc_ui_step('clean', '×印の成分を除いて、64電極の信号に組み立て直す', ...
            'pop_subcomp', @rebuild, ...
            {sprintf('EEG = pop_subcomp(EEG, [%s]);', num2str(find(state.rejectMask)))});
        if runStage(stage)
            comparePlayer.setData(state.filteredEEG, state.cleanEEG);
            comparePlayer.playFrame(localBlinkStart(state.filteredEEG));   % a blink in the middle
            resultTabs.SelectedTab = compareTab;
            updateSideColumn();
        end

        function detail = rebuild()
            if all(state.rejectMask)
                error('mooc2026:AllComponentsRejected', ...
                    'すべての成分が除去対象です。③の選び方を見直してください。');
            end
            state.cleanEEG = pop_subcomp(state.icaEEG, find(state.rejectMask), 0);
            detail = sprintf('%d 個を除去し、%d 個を残しました', ...
                nnz(state.rejectMask), nnz(~state.rejectMask));
        end
    end

    function ok = runStage(stage)
        ok = mooc_ui_run_steps(state, group, stage, tab);
        refresh();
        nav.update();
    end

    function settingsChanged()
        % A new choice redoes only ③ (and clears ④); the ICA is kept.
        updateStageControls();
        if state.isDone('selection')
            runSelection();
        end
    end

% ---- Callbacks: looking at the components ---------------------------------
    function selectComponent(component)
        selected = component;
        icaGrid.setSelected(component);
        [name, color] = componentStyle(component);
        mooc_plot_ic_detail(activityAxes, spectrumAxes, activations(component, :), ...
            state.icaDecomposedEEG.srate, component, name, color);
        updateTypePanel();
    end

    function pointerMoved()
        % Called on every mouse move in the window; cheap unless the pointer
        % moves onto another scalp map of this tab.
        if isempty(icaGrid) || ~state.isDone('iclabel') || ...
                tab.Parent.SelectedTab ~= tab || resultTabs.SelectedTab ~= inspectTab
            return;
        end
        pointAt(icaGrid.componentAt(gridAxes.CurrentPoint(1, 1:2)));
    end

    function pointAt(component)
        % COMPONENT under the pointer ([] = none): highlight its type.
        if isequal(component, pointed)
            return;
        end
        pointed = component;
        highlightType([pointed selected]);
    end

    function highlightType(components)
        % Color the type of the first of COMPONENTS (pointed, else selected).
        tint = [];
        if ~isempty(components) && state.isDone('iclabel')
            tint = find(strcmpi({types.class}, localBestClass(state.icaEEG, components(1))));
        end
        background = typePanel.BackgroundColor;
        for k = 1:numel(types)
            color = background;
            if isequal(k, tint)
                [~, classColor] = mooc_style('icClass', types(k).class);
                color = 0.25 * classColor + 0.75;
            end
            typeNames(k).BackgroundColor = color;
            typeTexts(k).BackgroundColor = color;
        end
    end

    function toggleSelected()
        % Changing one component by hand changes ③, so ④ must be redone.
        if isempty(selected)
            return;
        end
        state.invalidateFrom('clean');
        state.rejectMask(selected) = rejectCheck.Value;
        state.history.appendNote('selection', '（その後、手動で変更あり）');
        refresh();
        nav.update();
    end

% ---- Drawing ---------------------------------------------------------------
    function refresh()
        updateStageControls();
        updateResultView();
        if state.isDone('decomposition')
            updateSideColumn();      % also starts the replay when ② is shown
        end
    end

    function updateStageControls()
        % ✔ on finished stages; a stage can run once the one before is done.
        for k = 1:numel(stageNames)
            mark = '　 ';
            if state.isDone(stageNames{k})
                mark = '✔ ';
            end
            stageLabels(k).Text = [mark stageTexts{k}];
        end
        icaButton.Enable = state.isDone('filtered');
        iclabelButton.Enable = state.isDone('decomposition');
        selectButton.Enable = state.isDone('iclabel');
        policyDropDown.Enable = state.isDone('iclabel');
        thresholdField.Enable = state.isDone('iclabel') && ...
            ~ismember(policyDropDown.Value, {'brain_other', 'not_brain'});
        rebuildButton.Enable = state.isDone('selection');
    end

    function updateResultView()
        % Nothing until ①; the scalp maps after ①; their types after ②.
        hasIca = state.isDone('decomposition');
        resultTabs.Visible = hasIca;
        typePanel.Visible = state.isDone('iclabel');
        if ~hasIca
            shownIca = [];
            selected = [];
            return;
        end
        EEG = state.icaDecomposedEEG;
        if ~isequal(shownIca, EEG.icaweights)
            % New ICA result: draw its maps once.
            shownIca = EEG.icaweights;
            activations = (EEG.icaweights * EEG.icasphere) * ...
                reshape(double(EEG.data(EEG.icachansind, :, :)), numel(EEG.icachansind), []);
            selected = [];
            icaGrid = mooc_plot_ic_grid(gridAxes, EEG, @selectComponent);
            resultTabs.SelectedTab = inspectTab;
            updateSideColumn();
            mooc_ui_placeholder(activityAxes, '上の図の成分をクリック');
            mooc_ui_placeholder(spectrumAxes, '');
        end
        for k = 1:size(shownIca, 1)
            [name, color] = componentStyle(k);
            labelText = sprintf('%d', k);
            if ~isempty(name)
                labelText = sprintf('%d: %s', k, name);
            end
            icaGrid.setCell(k, labelText, color);
        end
        icaGrid.showLegend(state.isDone('iclabel'));
        if state.isDone('selection')
            icaGrid.setRejected(state.rejectMask);
        else
            icaGrid.setRejected(false(1, size(shownIca, 1)));
        end
        if ~isempty(selected)
            selectComponent(selected);      % the colors may have changed with ②
        else
            updateTypePanel();
        end
        if ~state.isDone('clean')
            comparePlayer.clear('④を実行すると、除去の前後の波形が表示されます');
        end
    end

    function [name, color] = componentStyle(component)
        % ICLabel's class after ②; no name and gray before.
        if state.isDone('iclabel')
            [name, color] = mooc_style('icClass', localBestClass(state.icaEEG, component));
            name = char(name);
        else
            name = '';
            color = [0.55 0.55 0.55];
        end
    end

    function updateTypePanel()
        rejectCheck.Enable = ~isempty(selected) && state.isDone('selection');
        if rejectCheck.Enable
            rejectCheck.Value = state.rejectMask(selected);
        end
        if ~isempty(selected) && state.isDone('iclabel')
            probabilities = state.icaEEG.etc.ic_classification.ICLabel.classifications(selected, :);
            selectedLabel.Text = sprintf('成分 %d：ICLabelが判定した確率', selected);
            if max(probabilities) < 0.5
                selectedLabel.Text = [selectedLabel.Text '（50%未満：あいまい）'];
            end
            localPlotPie(pieAxes, probabilities, ...
                state.icaEEG.etc.ic_classification.ICLabel.classes, types);
        else
            cla(pieAxes);
        end
        highlightType([pointed selected]);
    end

    function updateSideColumn()
        % ② (before / after) uses the whole width, as the waveforms of step 1;
        % the ICLabel explanation on the right belongs to ① only.
        % The replay runs whenever ② is on screen.
        onCompare = resultTabs.SelectedTab == compareTab;
        sideGrid.Visible = ~onCompare;
        if onCompare
            plotGrid.ColumnWidth = {'1x', 0};
        else
            plotGrid.ColumnWidth = {'1x', 370};
        end
        if onCompare && state.isDone('clean')
            comparePlayer.play();
        else
            comparePlayer.stop();
        end
    end

    function showPage(page)
        % 1 = ① 成分を調べる, 2 = ② 除去の前後を比べる (used by tests)
        pages = [inspectTab compareTab];
        resultTabs.SelectedTab = pages(page);
        updateSideColumn();
    end

end

% ---- Local functions -----------------------------------------------------
function [rejectMask, code, functionName] = localSelectComponents(EEG, policy, threshold)
% Which components to remove (true = remove), from the ICLabel result, and
% the same in MATLAB code for the processing history:
%   'brain_other'        most likely class is not Brain or Other
%   'not_brain'          most likely class is not Brain
%   'artifact_threshold' a noise class has probability >= THRESHOLD (pop_icflag)
%   'brain_only'         P(Brain) < THRESHOLD                       (pop_icflag)
% ICLabel's classes: 1 Brain, 2 Muscle, 3 Eye, 4 Heart, 5 Line Noise,
% 6 Channel Noise, 7 Other.
probabilities = EEG.etc.ic_classification.ICLabel.classifications;
[~, best] = max(probabilities, [], 2);         % most likely class of each component
switch policy
    case 'brain_other'
        rejectMask = ~ismember(best, [1 7])';
        code = {'[~, best] = max(EEG.etc.ic_classification.ICLabel.classifications, [], 2);', ...
            'reject = ~ismember(best, [1 7]);  % 1 = 脳、7 = その他'};
        functionName = 'max';
    case 'not_brain'
        rejectMask = (best ~= 1)';
        code = {'[~, best] = max(EEG.etc.ic_classification.ICLabel.classifications, [], 2);', ...
            'reject = best ~= 1;  % 1 = 脳'};
        functionName = 'max';
    otherwise
        % pop_icflag: range [min max] of the probability of each class
        if strcmp(policy, 'artifact_threshold')
            ranges = [NaN NaN; repmat([threshold 1], 5, 1); NaN NaN];
        else
            ranges = [0 threshold; NaN(6, 2)];
        end
        EEG = pop_icflag(EEG, ranges);
        rejectMask = EEG.reject.gcompreject(:)';
        code = {sprintf('EEG = pop_icflag(EEG, %s);  %% 各種類の確率の範囲 [下限 上限]', ...
            mat2str(ranges, 3)), 'reject = EEG.reject.gcompreject;'};
        functionName = 'pop_icflag';
end
end

function className = localBestClass(EEG, component)
classes = EEG.etc.ic_classification.ICLabel.classes;
[~, best] = max(EEG.etc.ic_classification.ICLabel.classifications(component, :));
className = classes{best};
end

function localPlotPie(ax, probabilities, classes, types)
% Pie chart of the 7 class probabilities, in the order and colors of the
% rows below it. Slices under 5 % are drawn without a label.
order = cellfun(@(name) find(strcmpi(classes, name)), {types.class});
values = double(probabilities(order));
values = max(values, 1e-6) / sum(max(values, 1e-6));
labels = repmat({''}, 1, numel(types));
for k = find(values >= 0.05)
    labels{k} = sprintf('%s %.0f%%', types(k).name, values(k) * 100);
end
cla(ax);
handles = pie(ax, values, labels);
for k = 1:numel(types)
    [~, color] = mooc_style('icClass', types(k).class);
    handles(2 * k - 1).FaceColor = color;
    handles(2 * k - 1).EdgeColor = 'white';
    handles(2 * k).FontSize = 10;
end
axis(ax, 'equal', 'off');
end

function name = localTypeName(types, className)
name = types(strcmpi({types.class}, className)).name;
end

function text = localClassCounts(EEG)
% Number of components per most likely class, e.g. "脳 30・眼 4・...".
types = localComponentTypes();
classes = EEG.etc.ic_classification.ICLabel.classes;
[~, best] = max(EEG.etc.ic_classification.ICLabel.classifications, [], 2);
counts = accumarray(best(:), 1, [numel(classes) 1]);
parts = {};
for k = find(counts)'
    parts{end + 1} = sprintf('%s %d', localTypeName(types, classes{k}), counts(k)); %#ok<AGROW>
end
text = strjoin(parts, '・');
end

function startSec = localBlinkStart(EEG)
% Start the 20 s view so that the largest frontal deflection (a blink) is
% in its middle, under the red line.
fp1 = strcmpi({EEG.chanlocs.labels}, 'Fp1');
[~, peak] = max(abs(EEG.data(fp1, :)));
startSec = max(0, floor((peak - 1) / EEG.srate - 10));
end

function types = localComponentTypes()
% The 7 ICLabel classes with what to look for in the scalp map and in the
% time course / spectrum (after the ICLabel tutorial, Pion-Tonachini et al.
% 2019), in the order of the rows of the 成分の要因 panel.
types = struct( ...
    'class', {'Brain', 'Eye', 'Muscle', 'Heart', 'Line Noise', 'Channel Noise', 'Other'}, ...
    'name',  {'脳', '眼', '筋肉', '心臓', '電源ノイズ', '電極ノイズ', 'その他'}, ...
    'map',   {'なだらかな1つのまとまり', 'おでこ、または目の左右で正負が逆', ...
              '頭の端（こめかみ・耳）に集中', '頭全体に斜めの勾配', ...
              '形はさまざま', '1つの電極だけに集中', 'どれにも当てはまらない'}, ...
    'wave',  {'リズムがあり、10 Hz付近に山', 'ゆっくり大きな揺れ（まばたき）', ...
              'ギザギザ。20 Hz以上が強い', '約1秒ごとに鋭い波（心拍）', ...
              '60 Hzに鋭い山', '突然大きく跳ぶ', '特徴がはっきりしない'});
end

function localIclabelPanel(parent)
% What the ICLabel plugin is, what it uses and how far to trust it.
panel = uipanel(parent, 'Title', 'ICLabel：成分の要因を自動で判定するプラグイン', ...
    'FontWeight', 'bold');
uilabel(uigridlayout(panel, [1 1], 'Padding', [8 6 8 6]), 'WordWrap', 'on', ...
    'VerticalAlignment', 'top', 'FontSize', 11.5, 'Text', { ...
    ['・ICLabelは、EEGLABに追加して使うプログラム（プラグイン）です。ICAで分けた' ...
     '成分のそれぞれが、下の7種類のどれに由来するかを確率で答えます。'], ...
    ['・判定には、成分の「頭皮上の分布」「周波数の内訳」「波形の繰り返し方」を使います。' ...
     '約6,000件の脳波記録から集めた成分で学習したニューラルネットワークです' ...
     '（Pion-Tonachini ら, 2019）。'], ...
    ['・確率は推定です。最も高い確率が50%未満の成分は判定があいまいなので、' ...
     '研究では人が図と波形を見て確かめます。'], ...
    ['・「その他」は特徴がはっきりしない成分で、脳の信号が混ざっていることも多いため、' ...
     '既定では残します（「脳以外」を除くと、成分の半分以上が消えることもあります）。']});
end
