function bar = mooc_ui_pipeline_bar(parent)
%MOOC_UI_PIPELINE_BAR タブの上の「解析中のデータ」の帯
%
%   どのステップまで処理したかを表示する。

stages = struct( ...
    'tab',   {2, 3, 4, 5, 6}, ...
    'name',  {'データ', 'ノイズ除去', 'ICA', '左右比較', '信号源'});

% A darker band with a line below, so the bar reads as separate from the
% tabs underneath.
band = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', [0.80 0.84 0.90]);
grid = uigridlayout(band, [1 2 * numel(stages)], 'Padding', [12 8 12 8], ...
    'ColumnSpacing', 6, 'BackgroundColor', band.BackgroundColor);
grid.ColumnWidth = [{110}, repmat({'1x', 22}, 1, numel(stages) - 1), {'1x'}];
uilabel(grid, 'Text', '解析中のデータ', 'FontWeight', 'bold', 'FontSize', 13);

boxes = gobjects(1, numel(stages));
names = gobjects(1, numel(stages));
details = gobjects(1, numel(stages));
for k = 1:numel(stages)
    boxes(k) = uipanel(grid, 'BorderType', 'line');
    inner = uigridlayout(boxes(k), [2 1], 'RowHeight', {18, '1x'}, ...
        'Padding', [8 2 8 2], 'RowSpacing', 0);
    names(k) = uilabel(inner, 'Text', stages(k).name, 'FontWeight', 'bold');
    details(k) = uilabel(inner, 'Text', '', 'FontSize', 11.5);
    if k < numel(stages)
        uilabel(grid, 'Text', '→', 'FontSize', 18, 'HorizontalAlignment', 'center', ...
            'FontColor', [0.25 0.3 0.4]);
    end
end

bar = struct('update', @update);

    function update(state, tabIndex)
        texts = localDetails(state);
        done = [state.isDone('raw'), state.isDone('filtered'), ...
            state.isDone('clean'), state.isDone('erd'), state.isDone('regionErd')];
        for k = 1:numel(stages)
            isCurrent = stages(k).tab == tabIndex;
            prefix = '';
            if isCurrent
                prefix = '▶ ';
            end
            if done(k)
                names(k).Text = sprintf('%s%s ✓', prefix, stages(k).name);
                color = [0.89 0.96 0.89];
            else
                names(k).Text = sprintf('%s%s', prefix, stages(k).name);
                color = [0.97 0.97 0.97];
            end
            if isCurrent
                color = [0.82 0.90 1.00];
            end
            details(k).Text = texts{k};
            set([boxes(k), boxes(k).Children], 'BackgroundColor', color);
        end
    end
end

function texts = localDetails(state)
% One short line per stage: what was done, or what is still missing.
texts = {'まだ選んでいません', 'まだ', 'まだ', 'まだ', 'まだ'};
if state.isDone('raw')
    taskName = extractBefore([state.condition().displayName '（'], '（');   % e.g. 運動イメージ
    texts{1} = sprintf('S%03d・%s（R%s）', state.subject, taskName, ...
        strjoin(compose('%02d', state.runs), '+R'));
end
if state.isDone('filtered')
    settings = state.filteredEEG.etc.mooc.filterSettings;
    parts = {};
    if settings.notch.enabled
        parts{end + 1} = sprintf('%d Hz除去', settings.notch.frequencyHz);
    end
    parts{end + 1} = sprintf('%g〜%g Hz', settings.bandpass.lowHz, settings.bandpass.highHz);
    if settings.reref.enabled
        parts{end + 1} = '平均参照';
    end
    texts{2} = strjoin(parts, '・');
end
if state.isDone('clean')
    texts{3} = sprintf('%d成分中 %d個を除去', numel(state.rejectMask), nnz(state.rejectMask));
elseif state.isDone('decomposition')
    texts{3} = '途中（成分に分解済み）';
end
if state.isDone('erd')
    texts{4} = sprintf('%d回を平均（%g〜%g Hz）', state.epochEEG.trials, state.erd.bandHz);
elseif state.isDone('epoch')
    texts{4} = sprintf('%d回を切り出し済み', state.epochEEG.trials);
end
if state.isDone('regionErd')
    texts{5} = sprintf('%d領域（%g〜%g Hz）', numel(state.regionErd.regionNames), state.regionErd.bandHz);
elseif state.isDone('source')
    texts{5} = sprintf('%d領域の活動を推定済み', state.sourceEEG.roi.nROI);
end
end
