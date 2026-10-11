function mooc_plot_ica_concept(ax)
%MOOC_PLOT_ICA_CONCEPT ICA のステップ全体を1枚で説明する図（説明画面で使う）

cla(ax, 'reset');
hold(ax, 'on');
t = linspace(0, 1, 200);
dark = [0.30 0.30 0.30];
gray = [0.55 0.55 0.55];

% name, color, waveform, kept after cleaning
[~, brainColor] = mooc_style('icClass', 'Brain');
[~, eyeColor] = mooc_style('icClass', 'Eye');
[~, muscleColor] = mooc_style('icClass', 'Muscle');
sources = {
    '脳のリズム', brainColor,  0.15 * sin(2 * pi * 10 * t),              true
    'まばたき',   eyeColor,    0.32 * exp(-((t - 0.5) / 0.05) .^ 2),     false
    '筋肉',       muscleColor, 0.12 * localNoise(numel(t)),               false
    };
sourceY = [3 2 1];
electrodeNames = {'Fp1', 'C3', 'C4', 'O1'};
electrodeY = [3.3 2.4 1.6 0.7];
mixing = [0.4 1.0 0.3; 0.8 0.3 0.5; 0.8 0.2 0.6; 0.7 0.1 0.4];
waveWidth = 0.85;

% 1. Sources, and every source reaching every electrode.
for k = 1:3
    plot(ax, 0.1 + waveWidth * t, sourceY(k) + sources{k, 3}, 'Color', sources{k, 2}, 'LineWidth', 1.4);
    text(ax, 0.55, sourceY(k) - 0.32, sources{k, 1}, 'HorizontalAlignment', 'center');
    for e = 1:4
        plot(ax, [1.0 1.95], [sourceY(k) electrodeY(e)], ':', 'Color', sources{k, 2});
    end
end

% 2. Electrode waveforms: the data we have.
rectangle(ax, 'Position', [1.82 0.25 1.28 3.45], 'Curvature', 0.05, ...
    'EdgeColor', [0.16 0.40 0.70], 'LineWidth', 2, 'LineStyle', '--');
localElectrodes(ax, 2.0, electrodeY, electrodeNames, mixing * vertcat(sources{:, 3}), t, dark);

% 3. ① ICA -> components of unknown origin (in no particular order).
localTool(ax, 3.3, {'① ICA', 'ほどく'});
componentOrder = [2 3 1];
for k = 1:3
    source = componentOrder(k);
    plot(ax, 4.45 + waveWidth * t, sourceY(k) + sources{source, 3}, 'Color', gray, 'LineWidth', 1.4);
    text(ax, 4.87, sourceY(k) - 0.32, sprintf('成分%d：？', k), 'HorizontalAlignment', 'center');
end

% 4. ② ICLabel -> origin of each component; ③ noise crossed out.
localTool(ax, 5.45, {'② ICLabel', '③ 選ぶ'});
for k = 1:3
    source = componentOrder(k);
    y = sourceY(k);
    plot(ax, 6.6 + waveWidth * t, y + sources{source, 3}, 'Color', sources{source, 2}, 'LineWidth', 1.4);
    if sources{source, 4}
        verdict = '残す';
    else
        verdict = '除く';
        plot(ax, [6.65 7.4 NaN 6.65 7.4], [y - 0.25 y + 0.25 NaN y + 0.25 y - 0.25], ...
            'k-', 'LineWidth', 2);
    end
    text(ax, 7.02, y - 0.42, sprintf('成分%d：%s → %s', k, sources{source, 1}, verdict), ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', sources{source, 2} * 0.8);
end

% 5. ④ Rebuild -> electrode waveforms with the brain rhythm only.
localTool(ax, 7.6, {'④ 組み立て', '直す'});
kept = [sources{:, 4}];
cleanMixing = mixing .* kept;
localElectrodes(ax, 8.75, electrodeY, electrodeNames, cleanMixing * vertcat(sources{:, 3}), t, dark);

headers = {
    0.55, {'信号のもと', '（頭の中）'}
    2.46, {'電極の波形', '＝ 手元のデータ'}
    4.87, {'成分', '（何の信号かは不明）'}
    7.02, {'成分の要因', '（ノイズを除く）'}
    9.21, {'ノイズを除いた', '電極の波形'}};
for k = 1:size(headers, 1)
    text(ax, headers{k, 1}, 4.05, headers{k, 2}, 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold');
end
hold(ax, 'off');
axis(ax, 'off');
xlim(ax, [0 9.8]);
ylim(ax, [0.2 4.35]);
end

function localElectrodes(ax, x, electrodeY, names, signals, t, color)
% Electrode circles with the waveform each one records.
for e = 1:numel(names)
    plot(ax, x, electrodeY(e), 'o', 'MarkerSize', 14, 'MarkerFaceColor', [0.95 0.95 0.95], ...
        'MarkerEdgeColor', color);
    text(ax, x, electrodeY(e), names{e}, 'HorizontalAlignment', 'center', 'FontSize', 8);
    plot(ax, x + 0.18 + 0.85 * t, electrodeY(e) + signals(e, :), 'Color', color);
end
end

function localTool(ax, x, label)
% A processing box with arrows on both sides, centered vertically.
localArrow(ax, x - 0.12 + [0 0.12], [2 2]);
rectangle(ax, 'Position', [x + 0.02, 1.55, 0.86, 0.9], 'Curvature', 0.2, ...
    'FaceColor', [0.93 0.93 0.93], 'EdgeColor', [0.3 0.3 0.3]);
text(ax, x + 0.45, 2.0, label, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
localArrow(ax, x + 0.9 + [0 0.12], [2 2]);
end

function values = localNoise(count)
% Fixed pseudo-random "muscle" signal so the figure is the same every time.
stream = RandStream('mt19937ar', 'Seed', 3);
values = randn(stream, 1, count);
end

function localArrow(ax, x, y)
quiver(ax, x(1), y(1), diff(x), diff(y), 0, 'Color', [0.3 0.3 0.3], ...
    'LineWidth', 1.5, 'MaxHeadSize', 2);
end
