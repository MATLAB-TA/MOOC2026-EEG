function cue = mooc_ui_cue_display(parent, titleText, mainFontSize)
%MOOC_UI_CUE_DISPLAY 実験の参加者が見ていた画面をまねて表示する枠
%
%     cue = mooc_ui_cue_display(parent, 見出し, 文字の大きさ)
%       cue.show('left_fist', 秒) のように、合図とその時刻を表示する

if nargin < 2 || isempty(titleText)
    titleText = '参加者が見ていた画面（イメージ）';
end
if nargin < 3
    mainFontSize = 40;
end
panel = uipanel(parent, 'Title', titleText, ...
    'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', [0.2 0.2 0.2]);
grid = uigridlayout(panel, [3 1], 'RowHeight', {'1x', 20, 16}, 'RowSpacing', 2, ...
    'BackgroundColor', [0.2 0.2 0.2]);
mainLabel = uilabel(grid, 'Text', '', 'FontSize', mainFontSize, 'FontWeight', 'bold', ...
    'FontColor', 'white', 'HorizontalAlignment', 'center');
subLabel = uilabel(grid, 'Text', '', 'FontSize', 14, 'FontColor', 'white', ...
    'HorizontalAlignment', 'center');
timeLabel = uilabel(grid, 'Text', '', 'FontSize', 11, ...
    'FontColor', [0.85 0.85 0.85], 'HorizontalAlignment', 'center');

cue = struct('panel', panel, 'show', @show);
show('', NaN);

    function show(label, timeSec)
        switch label
            case 'rest'
                texts = {'＋', '休憩'};
                color = [0.25 0.25 0.25];
            case 'left_fist'
                texts = {'← 左', '左の拳'};
                color = [0.16 0.36 0.58];
            case 'right_fist'
                texts = {'右 →', '右の拳'};
                color = [0.62 0.28 0.18];
            otherwise
                texts = {'', label};
                color = [0.25 0.25 0.25];
        end
        mainLabel.Text = texts{1};
        subLabel.Text = texts{2};
        if isnan(timeSec)
            timeLabel.Text = '';
        else
            timeLabel.Text = sprintf('記録開始から %d分%02d秒', ...
                floor(timeSec / 60), floor(mod(timeSec, 60)));
        end
        set([panel grid], 'BackgroundColor', color);
        panel.ForegroundColor = 'white';
    end
end
