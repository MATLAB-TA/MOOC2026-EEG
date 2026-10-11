function mooc_plot_signals(ax, EEG, channels, startSec, durationSec, options)
%MOOC_PLOT_SIGNALS 選んだ電極の波形を上下に並べ、合図の区間に色を付けて描く
%
%   処理の前と後の2つのデータを重ねて描くこともできる。

arguments
    ax
    EEG struct
    channels cell
    startSec (1, 1) double
    durationSec (1, 1) double {mustBePositive}
    options.Compare = []
    options.Names cell = {'処理前', '処理後'}
    options.Spacing = []
    options.ShowEvents (1, 1) logical = true
    options.View = []
end

labels = {EEG.chanlocs.labels};
[found, rows] = ismember(lower(channels), lower(labels));
rows = rows(found);
channels = labels(rows);
if isempty(rows)
    error('mooc2026:NoChannels', '表示するチャンネルが見つかりません。');
end

totalSec = EEG.pnts / EEG.srate;
startSec = max(0, min(startSec, totalSec - durationSec));
columns = max(1, floor(startSec * EEG.srate) + 1): ...
    min(EEG.pnts, floor((startSec + durationSec) * EEG.srate));
time = (columns - 1) / EEG.srate;
data = double(EEG.data(rows, columns));
data = data - mean(data, 2);

spacing = options.Spacing;
if isempty(spacing)
    spacing = max(10, 6 * median(std(data, 0, 2)));
end
offsets = (numel(rows):-1:1)' * spacing;

cla(ax, 'reset');
hold(ax, 'on');
yLimits = [0, (numel(rows) + 1) * spacing];
if options.ShowEvents
    localDrawEvents(ax, EEG, startSec, startSec + durationSec, yLimits);
end

hasCompare = ~isempty(options.Compare);
firstColor = [0.2 0.2 0.2];
if hasCompare
    firstColor = [0.65 0.65 0.65];
end
traceLines = plot(ax, time, data + offsets, 'Color', firstColor, 'LineWidth', 0.8);
legendHandles = traceLines(1);

if hasCompare
    other = options.Compare;
    otherRows = cellfun(@(c) find(strcmpi({other.chanlocs.labels}, c), 1), channels);
    otherColumns = max(1, floor(startSec * other.srate) + 1): ...
        min(other.pnts, floor((startSec + durationSec) * other.srate));
    otherTime = (otherColumns - 1) / other.srate;
    otherData = double(other.data(otherRows, otherColumns));
    otherData = otherData - mean(otherData, 2);
    otherLines = plot(ax, otherTime, otherData + offsets, ...
        'Color', [0 0.45 0.74], 'LineWidth', 0.9);
    legendHandles(2) = otherLines(1);
    legend(ax, legendHandles, options.Names, 'Location', 'northoutside', ...
        'Orientation', 'horizontal', 'Box', 'off');
end
hold(ax, 'off');

set(ax, 'YTick', flipud(offsets), 'YTickLabel', flip(channels));
ylim(ax, yLimits);
if isempty(options.View)
    options.View = [startSec, startSec + durationSec];
end
xlim(ax, options.View);
xlabel(ax, '時間 (秒)');
box(ax, 'on');
title(ax, sprintf('縦の目盛り1つ = %.0f µV', spacing), 'FontWeight', 'normal', ...
    'FontSize', 10);
end

function localDrawEvents(ax, EEG, fromSec, toSec, yLimits)
if isempty(EEG.event) || ~isfield(EEG.event, 'eegmmidb_label')
    return;
end
for event = EEG.event(:)'
    if isempty(event.eegmmidb_label)
        continue;
    end
    onset = (double(event.latency) - 1) / EEG.srate;
    duration = 4;
    if isfield(event, 'duration') && ~isempty(event.duration) && event.duration > 0
        duration = double(event.duration) / EEG.srate;
    end
    if onset + duration < fromSec || onset > toSec
        continue;
    end
    [name, color] = mooc_style('label', event.eegmmidb_label);
    patch(ax, onset + [0 duration duration 0], yLimits([1 1 2 2]), color, ...
        'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HitTest', 'off');
    if onset >= fromSec
        text(ax, onset + 0.05, yLimits(2), name, 'VerticalAlignment', 'top', ...
            'Color', color * 0.8, 'FontWeight', 'bold', 'FontSize', 10, ...
            'HitTest', 'off');
    end
end
end
