function mooc_plot_psd_comparison(ax, spectra, options)
%MOOC_PLOT_PSD_COMPARISON 処理の前と後の、周波数ごとの強さを重ねて描く
%
%   フィルタで残す範囲の矢印、脳波の周波数の呼び名（δ〜γ）の色の帯、
%   電源ノイズの位置の矢印を付けられる。

arguments
    ax
    spectra struct
    options.MaxFrequencyHz (1, 1) double {mustBePositive} = 80
    options.Names cell = {'処理前', '処理後'}
    options.PassBand double = []
    options.BandZones (1, 1) logical = false
    options.MarkHz double = []
    options.MarkLabel = ''
end

beforeFreq = spectra.beforeHz(:);
afterFreq = spectra.afterHz(:);
beforePsd = spectra.before(:);
afterPsd = spectra.after(:);

cla(ax, 'reset');
hold(ax, 'on');
allValues = [beforePsd(:); afterPsd(:)];
yLimits = [min(allValues) - 3, max(allValues) + 3];
if ~isempty(options.PassBand)
    yLimits(2) = yLimits(2) + 0.15 * diff(yLimits);     % room for the arrow
end
if ~isempty(options.MarkHz)
    [~, nearest] = min(abs(beforeFreq - options.MarkHz));
    markPeak = beforePsd(nearest);
    yLimits(2) = max(yLimits(2), markPeak + 20);
end
if options.BandZones
    localDrawBandZones(ax, yLimits);
end
plot(ax, beforeFreq, beforePsd, 'Color', [0.6 0.6 0.6], 'LineWidth', 1.6, ...
    'DisplayName', options.Names{1});
plot(ax, afterFreq, afterPsd, 'Color', [0 0.45 0.74], 'LineWidth', 1.6, ...
    'DisplayName', options.Names{2});
if ~isempty(options.MarkHz)
    % The arrow points at the peak; the label ends at the arrow so that it
    % stays inside the plot even when the peak is near the right edge.
    markColor = [0.85 0.33 0.10];
    text(ax, options.MarkHz, markPeak + 1, '↓', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'Color', markColor, 'FontWeight', 'bold', 'FontSize', 13);
    text(ax, options.MarkHz + 1, markPeak + 6, cellstr(options.MarkLabel), ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
        'Color', markColor, 'FontWeight', 'bold', 'FontSize', 11);
end
if ~isempty(options.PassBand)
    localDrawPassBand(ax, options.PassBand, yLimits);
end
hold(ax, 'off');

xlim(ax, [0, min(options.MaxFrequencyHz, max(beforeFreq(end), afterFreq(end)))]);
ylim(ax, yLimits);
xlabel(ax, '周波数 (Hz) ＝ 1秒間に何回ゆれるか');
ylabel(ax, 'パワー (dB)');
title(ax, '周波数ごとの強さ（全チャンネル平均）', 'FontWeight', 'normal');
legend(ax, 'Location', 'best');
grid(ax, 'on');
box(ax, 'on');

end

function localDrawBandZones(ax, yLimits)
% Classic EEG frequency bands, labeled along the top of the plot, with
% the frequency of each border along the bottom.
bands = mooc_style('bands');
for band = bands
    range = band.rangeHz;
    patch(ax, range([1 2 2 1]), yLimits([1 1 2 2]), band.color, ...
        'FaceAlpha', 0.10, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    text(ax, mean(range), yLimits(2), band.symbol, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold', ...
        'Color', band.color * 0.7, 'HitTest', 'off');
end
for border = [4 8 13 30]
    plot(ax, [border border], yLimits, ':', 'Color', [0.5 0.5 0.5], ...
        'HandleVisibility', 'off', 'HitTest', 'off');
    text(ax, border, yLimits(1), sprintf(' %d Hz', border), 'Rotation', 90, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
        'FontSize', 9, 'Color', [0.35 0.35 0.35], 'HitTest', 'off');
end
end

function localDrawPassBand(ax, range, yLimits)
% A red double arrow over the frequencies the band-pass filter keeps.
red = [0.85 0.1 0.1];
y = yLimits(2) - 0.13 * diff(yLimits);
plot(ax, range, [y y], '-', 'Color', red, 'LineWidth', 2, 'HandleVisibility', 'off');
plot(ax, range(1), y, '<', 'Color', red, 'MarkerFaceColor', red, 'MarkerSize', 7, ...
    'HandleVisibility', 'off');
plot(ax, range(2), y, '>', 'Color', red, 'MarkerFaceColor', red, 'MarkerSize', 7, ...
    'HandleVisibility', 'off');
text(ax, mean(range), y, sprintf('フィルタで残す範囲（%g〜%g Hz）', range), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', red, ...
    'FontWeight', 'bold', 'FontSize', 11, 'HitTest', 'off');
end
