function mooc_plot_run_timeline(ax, runs, runSeconds, cueEvents, titleText)
%MOOC_PLOT_RUN_TIMELINE つなげた記録と合図の位置を、1本の時間軸に並べて描く

starts = [0, cumsum(runSeconds(1:end - 1))] / 60;      % minutes
widths = runSeconds / 60;
colors = [0.86 0.90 0.96; 0.93 0.93 0.93];

cla(ax, 'reset');
hold(ax, 'on');
for k = 1:numel(runs)
    rectangle(ax, 'Position', [starts(k), 0, widths(k), 1], ...
        'FaceColor', colors(mod(k - 1, 2) + 1, :), 'EdgeColor', [0.4 0.4 0.4]);
    text(ax, starts(k) + widths(k) / 2, 1.25, sprintf('R%02d（%.1f分）', runs(k), widths(k)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end

counts = struct('left_fist', 0, 'right_fist', 0);
for event = cueEvents
    if ~isfield(counts, event.label)
        continue;
    end
    counts.(event.label) = counts.(event.label) + 1;
    [~, color] = mooc_style('label', event.label);
    plot(ax, event.onset / 60 * [1 1], [0.15 0.85], 'Color', color, 'LineWidth', 1.5);
end
hold(ax, 'off');

xlim(ax, [0, sum(widths)]);
ylim(ax, [-0.1 1.6]);
ax.YTick = [];
xlabel(ax, '時間（分）');
if nargin < 5
    titleText = sprintf(['つなげた記録：合計 %.1f分、合図 %d回' ...
        '（青：左拳 %d回、橙：右拳 %d回）'], sum(widths), ...
        counts.left_fist + counts.right_fist, counts.left_fist, counts.right_fist);
end
title(ax, titleText, 'FontWeight', 'normal');
box(ax, 'on');
disableDefaultInteractivity(ax);
end
