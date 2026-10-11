function grid = mooc_plot_ic_grid(ax, EEG, onClick)
%MOOC_PLOT_IC_GRID ICA の全部の成分の頭皮上の分布を、並べて描く
%
%   成分の図をクリックすると、その番号を知らせる。

componentCount = size(EEG.icawinv, 2);
chanlocs = EEG.chanlocs(EEG.icachansind);
columnCount = ceil(sqrt(componentCount * 1.6));
rowCount = ceil(componentCount / columnCount);
cellWidth = 1.32;
cellHeight = 1.52;
unknownColor = [0.72 0.72 0.72];

cla(ax, 'reset');
hold(ax, 'on');
colormap(ax, mooc_style('colormap'));
clim(ax, [-1 1]);
centers = zeros(componentCount, 2);
images = gobjects(1, componentCount);
frames = gobjects(1, componentCount);
labels = gobjects(1, componentCount);
crosses = gobjects(1, componentCount);
for component = 1:componentCount
    column = mod(component - 1, columnCount);
    row = floor((component - 1) / columnCount);
    center = [column * cellWidth, -row * cellHeight];
    centers(component, :) = center;

    % EEGLAB's topoplot interpolates the map (without drawing it).
    weights = EEG.icawinv(:, component);
    [topo, gridX, gridY] = mooc_topoplot(ax, weights / max(abs(weights)), chanlocs, ...
        'GridOnly', true, 'GridScale', 41);
    images(component) = image(ax, center(1) + gridX(1, [1 end]) * 0.9, ...
        center(2) + gridY([1 end], 1) * 0.9, topo, ...
        'AlphaData', ~isnan(topo), 'CDataMapping', 'scaled');
    localDrawHead(ax, center, 0.9);
    frames(component) = rectangle(ax, ...
        'Position', [center(1) - 0.6, center(2) - 0.62, 1.2, 1.38], ...
        'EdgeColor', unknownColor, 'LineWidth', 2.5);
    labels(component) = text(ax, center(1), center(2) + 0.66, ...
        sprintf('%d', component), 'HorizontalAlignment', 'center', ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', unknownColor * 0.8);
    crosses(component) = plot(ax, center(1) + [-0.5 0.5 NaN -0.5 0.5], ...
        center(2) + [-0.5 0.5 NaN 0.5 -0.5], 'k-', 'LineWidth', 2, ...
        'Visible', 'off', 'HitTest', 'off');

    callback = @(~, ~) onClick(component);
    set([images(component), frames(component), labels(component)], ...
        'ButtonDownFcn', callback);
end

% The selection outline is drawn last so that no other cell covers it.
selection = rectangle(ax, 'Position', [0 0 1 1], 'EdgeColor', 'k', ...
    'LineWidth', 1.8, 'LineStyle', '--', 'Visible', 'off', 'HitTest', 'off');

% Legend of the frame colors.
legendClasses = {'Brain', 'Eye', 'Muscle', 'Heart', 'Line Noise', 'Channel Noise', 'Other'};
legendNames = {'脳', '眼', '筋肉', '心臓', '電源ノイズ', '電極ノイズ', 'その他'};
legendStep = (columnCount * cellWidth) / (numel(legendClasses) + 2.5);
legendTexts = gobjects(1, numel(legendClasses) + 1);
for index = 1:numel(legendClasses)
    [~, color] = mooc_style('icClass', legendClasses{index});
    legendTexts(index) = text(ax, -0.6 + (index - 1) * legendStep, 1.1, ...
        ['■ ' legendNames{index}], 'Color', color, 'FontSize', 9, 'FontWeight', 'bold');
end
legendTexts(end) = text(ax, (columnCount - 1) * cellWidth + 0.66, 1.1, '× = 除去する', ...
    'HorizontalAlignment', 'right', 'FontSize', 9);
set(legendTexts, 'Visible', 'off');     % shown once the types are known
hold(ax, 'off');

axis(ax, 'equal');
axis(ax, 'off');
xlim(ax, [-0.72, (columnCount - 1) * cellWidth + 0.72]);
ylim(ax, [-(rowCount - 1) * cellHeight - 0.72, 1.25]);

grid = struct('setCell', @setCell, 'setRejected', @setRejected, ...
    'setSelected', @setSelected, 'componentAt', @componentAt, ...
    'showLegend', @(show) set(legendTexts, 'Visible', show), ...
    'componentCount', componentCount);

    function setCell(component, labelText, color)
        frames(component).EdgeColor = color;
        labels(component).String = labelText;
        labels(component).Color = color * 0.85;
    end

    function setRejected(rejectMask)
        rejectMask(end + 1:componentCount) = false;
        for k = 1:componentCount
            crosses(k).Visible = rejectMask(k);
            alpha = ~isnan(images(k).CData);
            images(k).AlphaData = alpha * (1 - 0.65 * rejectMask(k));
        end
    end

    function component = componentAt(point)
        inside = abs(centers(:, 1) - point(1)) <= cellWidth / 2 & ...
            abs(centers(:, 2) - point(2)) <= cellHeight / 2;
        component = find(inside, 1);
    end

    function setSelected(component)
        if isempty(component)
            selection.Visible = 'off';
            return;
        end
        center = centers(component, :);
        selection.Position = [center(1) - 0.65, center(2) - 0.67, 1.3, 1.48];
        selection.Visible = 'on';
    end
end

function localDrawHead(ax, center, scale)
% Head outline (radius 0.5 * SCALE) with nose and ears, nose up.
color = [0.3 0.3 0.3];
r = 0.5 * scale;
angle = linspace(0, 2 * pi, 100);
earAngle = linspace(-pi / 2, pi / 2, 20);
plot(ax, center(1) + r * cos(angle), center(2) + r * sin(angle), ...
    'Color', color, 'LineWidth', 1.2, 'HitTest', 'off');
plot(ax, center(1) + r * [-0.18 0 0.18], center(2) + r * [0.98 1.15 0.98], ...
    'Color', color, 'LineWidth', 1.2, 'HitTest', 'off');
for side = [-1 1]
    plot(ax, center(1) + side * (r + 0.04 * scale * cos(earAngle)), ...
        center(2) + 0.12 * scale * sin(earAngle), 'Color', color, 'LineWidth', 1.2, ...
        'HitTest', 'off');
end
end
