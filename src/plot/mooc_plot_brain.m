function mooc_plot_brain(ax, model, regionValues, limit, options)
%MOOC_PLOT_BRAIN 脳を上から見た図を描き、領域ごとに値で色を付ける
%
%     mooc_plot_brain(ax, 脳の表面, 領域ごとの値, 色の幅, 'Highlight', 枠で囲む領域)

arguments
    ax
    model struct
    regionValues (:, 1) double
    limit (1, 1) double {mustBePositive}
    options.Highlight cell = {}
    options.ColorbarLabel char = ''
end

% Top view: right ear to the right, nose up.
points = [-model.vertices(:, 2), model.vertices(:, 1), model.vertices(:, 3)] * 1000;   % mm

cla(ax, 'reset');
hold(ax, 'on');
pointValues = zeros(numel(model.region), 1);      % points in no region: 0 (white)
inSomeRegion = model.region > 0;
pointValues(inSomeRegion) = regionValues(model.region(inSomeRegion));
patch(ax, 'Faces', model.faces, 'Vertices', points, ...
    'FaceVertexCData', pointValues, 'FaceColor', 'interp', ...
    'EdgeColor', 'none');
for name = options.Highlight
    % Outline: the edges used by only one triangle of the region.
    inRegion = model.region == find(strcmp(model.regionNames, name{1}), 1);
    regionFaces = model.faces(all(inRegion(model.faces), 2), :);
    edges = sort([regionFaces(:, [1 2]); regionFaces(:, [2 3]); regionFaces(:, [3 1])], 2);
    [uniqueEdges, ~, index] = unique(edges, 'rows');
    outline = uniqueEdges(accumarray(index, 1) == 1, :);
    x = [points(outline(:, 1), 1), points(outline(:, 2), 1), nan(size(outline, 1), 1)]';
    y = [points(outline(:, 1), 2), points(outline(:, 2), 2), nan(size(outline, 1), 1)]';
    plot3(ax, x(:), y(:), 200 * ones(numel(x), 1), '-', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.2);
end
hold(ax, 'off');

colormap(ax, mooc_style('colormap'));
clim(ax, [-limit limit]);
bar = colorbar(ax);
bar.Label.String = options.ColorbarLabel;
view(ax, 0, 90);
axis(ax, 'equal', 'off');
extent = [min(points(:, 1:2)); max(points(:, 1:2))];
text(ax, extent(1, 1) - 5, mean(extent(:, 2)), 100, '左', 'HorizontalAlignment', 'right');
text(ax, extent(2, 1) + 5, mean(extent(:, 2)), 100, '右', 'HorizontalAlignment', 'left');
text(ax, mean(extent(:, 1)), extent(2, 2) + 5, 100, '鼻（前）', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
disableDefaultInteractivity(ax);
end
