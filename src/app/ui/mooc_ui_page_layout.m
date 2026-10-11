function ui = mooc_ui_page_layout(tab, state, nav, description, options)
%MOOC_UI_PAGE_LAYOUT 各ステップの画面の共通の枠組み
%
%   左に説明・操作・処理の記録、右に図の場所を置く。最初に開いたときの
%   説明画面も作る。

arguments
    tab
    state
    nav struct
    description char
    options.ControlRows cell = {32}
    options.DescriptionHeight (1, 1) double = 150
    options.NextStep = []
    options.Guide = []
    options.HistoryGroup char = ''
end

% The page and the guide screen share one cell; the guide is created last
% so that it is drawn on top of the page.
stack = uigridlayout(tab, [1 1], 'Padding', [0 0 0 0]);
page = uigridlayout(stack, [1 2]);
page.Layout.Row = 1;
page.Layout.Column = 1;
page.ColumnWidth = {420, '1x'};
page.Padding = [14 12 14 12];
page.ColumnSpacing = 14;

% ---- Left column ---------------------------------------------------------
left = uigridlayout(page, [4 1]);
left.RowHeight = {options.DescriptionHeight, 'fit', '1x', 34};
left.Padding = [0 0 0 0];
left.RowSpacing = 10;

descriptionPanel = uipanel(left, 'Title', 'このステップでやること', 'FontWeight', 'bold');
descriptionGrid = uigridlayout(descriptionPanel, [2 1], 'RowHeight', {'1x', 0});
uilabel(descriptionGrid, 'Text', description, 'WordWrap', 'on', ...
    'VerticalAlignment', 'top', 'FontSize', 13);
guideButton = uibutton(descriptionGrid, 'Text', '説明をもう一度見る', 'Tag', 'option');

controlPanel = uipanel(left, 'Title', '操作', 'FontWeight', 'bold');
ui.controls = uigridlayout(controlPanel, [numel(options.ControlRows) 2]);
ui.controls.RowHeight = options.ControlRows;
ui.controls.ColumnWidth = {110, '1x'};
ui.controls.RowSpacing = 8;

logPanel = uipanel(left, 'Title', 'このデータに行った処理（裏側で行われていること）', ...
    'FontWeight', 'bold');
logGrid = uigridlayout(logPanel, [2 2], 'RowHeight', {'1x', 24}, ...
    'ColumnWidth', {'1x', 130}, 'Padding', [4 4 4 4], 'RowSpacing', 4);
logView = MoocProcessLog(logGrid, state.history, options.HistoryGroup);
logView.list.Layout.Column = [1 2];
uilabel(logGrid, 'Text', '「>>」の行をダブルクリック：使った関数のファイルを開く', ...
    'FontSize', 11, 'FontColor', [0.4 0.4 0.4]);
expandButton = uibutton(logGrid, 'Text', '右側に全体を表示', 'Tag', 'option');

ui.nextButton = uibutton(left, 'Text', '次のステップへ →', 'FontWeight', 'bold', 'Tag', 'stage:next', ...
    'Enable', 'off');
if isempty(options.NextStep)
    ui.nextButton.Visible = 'off';
else
    ui.nextButton.ButtonPushedFcn = @(~, ~) nav.goTo(options.NextStep);
end

% ---- Right column --------------------------------------------------------
% The plot area and the whole history share one cell; the history is
% created last so that it covers the plots while it is shown.
right = uigridlayout(page, [1 1], 'Padding', [0 0 0 0]);
ui.plotArea = uipanel(right, 'BorderType', 'none');
ui.plotArea.Layout.Row = 1;
ui.plotArea.Layout.Column = 1;
historyPanel = uipanel(right, 'Visible', 'off', 'FontWeight', 'bold', ...
    'Title', 'このデータに行った処理（すべてのステップ。「>>」の行をダブルクリックすると関数のファイルが開きます）');
historyPanel.Layout.Row = 1;
historyPanel.Layout.Column = 1;
fullView = MoocProcessLog(uigridlayout(historyPanel, [1 1]), state.history, '');
fullView.list.FontSize = 13;
expandButton.ButtonPushedFcn = @(~, ~) toggleHistory();

% ---- Guide screen --------------------------------------------------------
ui.guide = struct('show', @() [], 'hide', @() []);
if ~isempty(options.Guide)
    overlay = localGuideScreen(stack, options.Guide);
    descriptionGrid.RowHeight = {'1x', 28};
    guideButton.ButtonPushedFcn = @(~, ~) set(overlay.panel, 'Visible', 'on');
    overlay.startButton.ButtonPushedFcn = @(~, ~) set(overlay.panel, 'Visible', 'off');
    ui.guide = struct('show', @() set(overlay.panel, 'Visible', 'on'), ...
        'hide', @() set(overlay.panel, 'Visible', 'off'));
else
    guideButton.Visible = 'off';
end

    function toggleHistory()
        % Show the whole history in place of the plots, or the plots again.
        showHistory = ~historyPanel.Visible;
        historyPanel.Visible = showHistory;
        if showHistory
            expandButton.Text = 'グラフに戻る';
            state.history.redraw();
        else
            expandButton.Text = '右側に全体を表示';
        end
    end
end

function overlay = localGuideScreen(stack, guide)
% A centred card on a gray background, covering the whole page.
pictureHeight = 230 * ~isempty(guide.picture);
if isfield(guide, 'pictureHeight')
    pictureHeight = guide.pictureHeight;
end
cardWidth = 820;
if isfield(guide, 'width')
    cardWidth = guide.width;
end
textHeight = 27 * localWrappedLineCount(guide.lines, cardWidth - 60) + 10;
rowHeights = [40, pictureHeight, textHeight, 44];
cardHeight = sum(rowHeights) + 3 * 14 + 44;

panel = uipanel(stack, 'BorderType', 'none', 'BackgroundColor', [0.88 0.89 0.91]);
panel.Layout.Row = 1;
panel.Layout.Column = 1;
outer = uigridlayout(panel, [3 3], 'RowHeight', {'1x', cardHeight, '1x'}, ...
    'ColumnWidth', {'1x', cardWidth, '1x'}, 'BackgroundColor', panel.BackgroundColor);
card = uipanel(outer, 'BackgroundColor', 'white');
card.Layout.Row = 2;
card.Layout.Column = 2;
grid = uigridlayout(card, [4 1], 'RowHeight', num2cell(rowHeights), ...
    'Padding', [30 20 30 24], 'RowSpacing', 14, 'BackgroundColor', 'white');
uilabel(grid, 'Text', guide.title, 'FontSize', 22, 'FontWeight', 'bold');
pictureAxes = uiaxes(grid);
if isa(guide.picture, 'function_handle')
    guide.picture(pictureAxes);
elseif ~isempty(guide.picture)
    mooc_plot_step_comic(pictureAxes, guide.picture);
end
disableDefaultInteractivity(pictureAxes);
uilabel(grid, 'Text', guide.lines, 'WordWrap', 'on', 'FontSize', 15, ...
    'VerticalAlignment', 'top');
startButton = uibutton(grid, 'Text', 'はじめる', 'FontSize', 15, 'FontWeight', 'bold', ...
    'Tag', 'start');
overlay = struct('panel', panel, 'startButton', startButton);
end

function count = localWrappedLineCount(lines, textWidth)
% Number of screen lines the guide text takes when long lines wrap
% (15 pt font: about 15 px for a Japanese character, 8.5 px for others).
count = 0;
for k = 1:numel(lines)
    characters = char(lines{k});
    isWide = double(characters) > 255;
    lineWidth = 15 * nnz(isWide) + 8.5 * nnz(~isWide);
    count = count + max(1, ceil(lineWidth / textWidth));
end
end
