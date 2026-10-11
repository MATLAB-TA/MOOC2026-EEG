function mooc_plot_ic_detail(activityAxes, spectrumAxes, activity, srate, component, typeName, color)
%MOOC_PLOT_IC_DETAIL ICA の1つの成分の、時間変化と周波数の内訳を描く

windowSec = 10;

% Show the window with the largest deflection so blinks are easy to find.
windowLength = min(numel(activity), round(windowSec * srate));
[~, peak] = max(abs(activity));
first = max(1, min(numel(activity) - windowLength + 1, peak - round(windowLength / 2)));
columns = first:first + windowLength - 1;
time = (columns - 1) / srate;

% Spectrum: Welch's method, 2-second Hann windows, half overlapping.
window = 2 * srate;
[power, frequencies] = pwelch(double(activity(:)), hann(window), window / 2, window, srate);
psdDb = 10 * log10(power);

activityLine = localLine(activityAxes, '時間 (秒)', '強さ', 0.9, false);
activityLine.XData = time;
activityLine.YData = activity(columns);
activityLine.Color = color;
xlim(activityAxes, time([1 end]));
heading = sprintf('成分 %d の時間変化', component);
if ~isempty(typeName)
    heading = sprintf('成分 %d（%s）の時間変化', component, typeName);
end
title(activityAxes, heading, 'FontWeight', 'normal');

spectrumLine = localLine(spectrumAxes, '周波数 (Hz)', 'パワー (dB)', 1.4, true);
spectrumLine.XData = frequencies;
spectrumLine.YData = psdDb;
spectrumLine.Color = color;
xlim(spectrumAxes, [1, min(45, srate / 2)]);
title(spectrumAxes, '周波数の内訳', 'FontWeight', 'normal');
end

function line = localLine(ax, xText, yText, width, isSpectrum)
% The axes' data line, created (with labels) the first time.
line = ax.UserData;
if isempty(line) || ~isgraphics(line)
    cla(ax, 'reset');
    line = plot(ax, NaN, NaN, 'LineWidth', width);
    xlabel(ax, xText);
    ylabel(ax, yText);
    box(ax, 'on');
    if isSpectrum
        xline(ax, 10, ':', '10 Hz', 'Color', [0.4 0.4 0.4]);
        grid(ax, 'on');
    end
    ax.UserData = line;
end
end
