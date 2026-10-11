function mooc_ui_placeholder(ax, message)
%MOOC_UI_PLACEHOLDER 図の場所を空にして、灰色の案内の文字を出す

cla(ax, 'reset');
text(ax, 0.5, 0.5, message, 'HorizontalAlignment', 'center', ...
    'FontSize', 13, 'Color', [0.5 0.5 0.5]);
axis(ax, 'off');
end
