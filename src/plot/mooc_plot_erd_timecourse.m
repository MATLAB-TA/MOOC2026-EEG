function mooc_plot_erd_timecourse(ax, erd, channelLabels, channel, taskSec)
%MOOC_PLOT_ERD_TIMECOURSE 1か所の強さの変化を、左拳と右拳で重ねて描く
%
%     mooc_plot_erd_timecourse(ax, erd, 行の名前, 描く場所の名前, 課題の時間)

row = find(strcmpi(channelLabels, channel), 1);
if isempty(row)
    error('mooc2026:ChannelNotFound', 'チャンネル %s が見つかりません。', channel);
end

values = squeeze(erd.percent(row, :, :));
limit = max(30, ceil(max(abs(values(:))) / 10) * 10);
baselineSec = erd.baselineSec;

cla(ax, 'reset');
hold(ax, 'on');
% Periods: rest before the cue (the 0 % reference) and the task period.
patch(ax, baselineSec([1 2 2 1]), [-limit -limit limit limit], [0.85 0.92 0.85], ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
patch(ax, taskSec([1 2 2 1]), [-limit -limit limit limit], [0.93 0.93 0.93], ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
text(ax, mean(baselineSec), limit * 0.92, {'休憩中', '（基準 = 0%）'}, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 9, ...
    'Color', [0.2 0.45 0.2]);
text(ax, mean(taskSec), limit * 0.92, '拳を動かす（想像する）', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 9, ...
    'Color', [0.35 0.35 0.35]);
yline(ax, 0, '-', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
xline(ax, 0, '--', '合図', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off', ...
    'LabelVerticalAlignment', 'bottom');

for classIndex = 1:numel(erd.classes)
    [name, color] = mooc_style('label', erd.classes{classIndex});
    plot(ax, erd.times, values(:, classIndex), 'Color', color, 'LineWidth', 2, ...
        'DisplayName', sprintf('%s（%d回の平均）', name, erd.trialCount(classIndex)));
end
hold(ax, 'off');

xlim(ax, erd.times([1 end]));
ylim(ax, [-limit limit]);
xlabel(ax, '合図からの時間 (秒)');
ylabel(ax, {'休憩中と比べた変化 (%)', '↓ 弱くなった　　強くなった ↑'});
title(ax, sprintf('%s（%.0f–%.0f Hz）', channelLabels{row}, erd.bandHz), ...
    'FontWeight', 'normal');
legend(ax, 'Location', 'southwest');
grid(ax, 'on');
box(ax, 'on');
end
