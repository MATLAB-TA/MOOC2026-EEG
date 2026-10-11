function names = mooc_ui_step_names(step)
%MOOC_UI_STEP_NAMES ステップ0〜6の名前（タブに出すもの）

names = {'はじめに', 'データを理解', 'ノイズを除去', '独立成分分析（ICA）', ...
    '左右の拳で脳の変化を比較', '信号源推定', 'データを書き出す'};
if nargin == 1
    names = sprintf('%d. %s', step, names{step + 1});
end
end
