function mooc_plot_step_comic(ax, step)
%MOOC_PLOT_STEP_COMIC 各ステップを表す小さな絵（はじめにタブと説明画面で使う）

cla(ax, 'reset');
hold(ax, 'on');
t = linspace(0, 1, 300);
dark = [0.25 0.25 0.25];
blue = [0.16 0.40 0.70];

switch step
    case 1
        localHead(ax, [2.4 3], 1.7, dark);
        angles = linspace(0, 2 * pi, 13);
        for radius = [0.6 1.2]
            plot(ax, 2.4 + radius * cos(angles), 3 + radius * sin(angles), 'o', ...
                'MarkerSize', 5, 'MarkerFaceColor', [0.85 0.4 0.2], 'MarkerEdgeColor', 'none');
        end
        for k = 1:3
            y = 1.6 + k * 0.9;
            plot(ax, 5 + 4.5 * t, y + 0.25 * sin(2 * pi * (6 + k) * t) .* (0.6 + 0.4 * abs(sin(2 * pi * (k + 1) * t))), ...
                'Color', dark);
        end
        localArrow(ax, [4.3 4.9], [3 3]);

    case 2
        noisy = 0.35 * sin(2 * pi * 4 * t) + 0.25 * sin(2 * pi * 45 * t) + 0.3 * t;
        plot(ax, 0.5 + 9 * t, 4.8 + noisy, 'Color', [0.55 0.55 0.55]);
        patch(ax, [2.5 7.5 6 4], [3.6 3.6 2.6 2.6], [0.9 0.9 0.9], 'EdgeColor', dark);
        text(ax, 5, 3.1, 'フィルタ', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
        plot(ax, 0.5 + 9 * t, 1.3 + 0.35 * sin(2 * pi * 4 * t), 'Color', blue, 'LineWidth', 1.5);
        localArrow(ax, [5 5], [4.3 3.7]);
        localArrow(ax, [5 5], [2.5 1.9]);

    case 3
        brain = 0.3 * sin(2 * pi * 8 * t);
        blink = 0.6 * exp(-((t - 0.5) / 0.06) .^ 2);
        muscle = 0.18 * sin(2 * pi * 70 * t) .* sin(2 * pi * 3 * t);
        plot(ax, 0.3 + 3 * t, 3 + brain + blink + muscle, 'Color', [0.45 0.45 0.45]);
        rectangle(ax, 'Position', [3.8 2.4 1.4 1.2], 'Curvature', 0.2, ...
            'FaceColor', [0.92 0.92 0.92], 'EdgeColor', dark);
        text(ax, 4.5, 3, 'ICA', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
        localArrow(ax, [3.35 3.75], [3 3]);
        sources = {brain, [0.20 0.55 0.25], '脳', false; blink, blue, '眼', true; ...
            muscle, [0.75 0.25 0.20], '筋肉', true};
        for k = 1:3
            y = 5 - 1.7 * (k - 1);
            localArrow(ax, [5.3 5.9], [3 y]);
            plot(ax, 6.1 + 3 * t, y + sources{k, 1}, 'Color', sources{k, 2}, 'LineWidth', 1.3);
            text(ax, 9.3, y + 0.55, sources{k, 3}, 'FontSize', 10, 'HorizontalAlignment', 'right');
            if sources{k, 4}
                plot(ax, [6.3 8.9], y + [-0.5 0.5], 'Color', [0.8 0 0], 'LineWidth', 2);
                plot(ax, [6.3 8.9], y + [0.5 -0.5], 'Color', [0.8 0 0], 'LineWidth', 2);
            end
        end

    case 4
        [gridX, gridY] = meshgrid(linspace(-1, 1, 120));
        spot = -exp(-((gridX - 0.45) .^ 2 + (gridY - 0.05) .^ 2) / 0.06);
        spot(hypot(gridX, gridY) > 1) = NaN;
        imagesc(ax, 5 + [-1.9 1.9], 3 + [-1.9 1.9], spot, 'AlphaData', ~isnan(spot));
        colormap(ax, mooc_style('colormap'));
        clim(ax, [-1 1]);
        localHead(ax, [5 3], 1.9, dark);
        text(ax, 2.6, 3, '左', 'HorizontalAlignment', 'right', 'FontSize', 11);
        text(ax, 7.4, 3, '右', 'HorizontalAlignment', 'left', 'FontSize', 11);
        text(ax, 5, 0.5, '左拳のとき、右側が青く（弱く）なる', ...
            'HorizontalAlignment', 'center', 'FontSize', 10);

    case 5
        localHead(ax, [1.8 3], 1.4, dark);
        angles = linspace(0, 2 * pi, 11);
        plot(ax, 1.8 + 0.9 * cos(angles), 3 + 0.9 * sin(angles), 'o', 'MarkerSize', 4, ...
            'MarkerFaceColor', [0.85 0.4 0.2], 'MarkerEdgeColor', 'none');
        localArrow(ax, [3.5 4.6], [3 3]);
        text(ax, 4.05, 3.7, 'eLORETA', 'HorizontalAlignment', 'center', 'FontSize', 8);
        % The brain from above: two hemispheres, the right motor area weakened.
        angles = linspace(-pi / 2, pi / 2, 60);
        for side = [-1 1]
            patch(ax, 7.1 + side * (0.08 + 1.3 * cos(angles)), 3 + 1.7 * sin(angles), ...
                [0.96 0.92 0.90], 'EdgeColor', dark);
        end
        [gridX, gridY] = meshgrid(linspace(-1, 1, 80));
        spot = exp(-((gridX) .^ 2 + (gridY) .^ 2) / 0.15);
        spot(spot < 0.15) = NaN;
        imagesc(ax, 7.85 + [-0.5 0.5], 3.2 + [-0.5 0.5], -spot, 'AlphaData', ~isnan(spot));
        colormap(ax, mooc_style('colormap'));
        clim(ax, [-1 1]);
        text(ax, 7.1, 0.6, '脳の中の場所を推定', 'HorizontalAlignment', 'center', 'FontSize', 10);

    case 6
        for k = 1:3
            y = 1.9 + k * 0.7;
            plot(ax, 0.3 + 2.8 * t, y + 0.2 * sin(2 * pi * (8 + k) * t), 'Color', dark);
        end
        localArrow(ax, [3.3 3.9], [3 3]);
        patch(ax, [4.2 5.4 5.8 5.8 4.2], [4.2 4.2 3.8 1.8 1.8], [0.95 0.95 0.95], ...
            'EdgeColor', dark);
        text(ax, 5, 3, '.mat', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 12);
        localArrow(ax, [6.1 6.7], [3 3]);
        text(ax, 8.3, 3, '機械学習', 'HorizontalAlignment', 'center', ...
            'FontSize', 11, 'FontWeight', 'bold', 'Color', blue);
end

hold(ax, 'off');
axis(ax, 'off');
xlim(ax, [0 10]);
ylim(ax, [0 6]);
ax.DataAspectRatio = [1 1 1];   % keep circles round
disableDefaultInteractivity(ax);
end

function localHead(ax, center, radius, color)
% Head outline seen from above, nose up.
angle = linspace(0, 2 * pi, 100);
plot(ax, center(1) + radius * cos(angle), center(2) + radius * sin(angle), ...
    'Color', color, 'LineWidth', 1.5);
plot(ax, center(1) + radius * [-0.15 0 0.15], center(2) + radius * [0.98 1.15 0.98], ...
    'Color', color, 'LineWidth', 1.5);
end

function localArrow(ax, x, y)
quiver(ax, x(1), y(1), diff(x), diff(y), 0, 'Color', [0.3 0.3 0.3], ...
    'LineWidth', 1.3, 'MaxHeadSize', 0.8);
end
