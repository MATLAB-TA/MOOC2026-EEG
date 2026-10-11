function [grid, gridX, gridY] = mooc_topoplot(ax, values, chanlocs, options)
%MOOC_TOPOPLOT 頭皮上の分布の図を、アプリの中に描く
%
%   EEGLAB の topoplot で描いた図を、アプリの図の場所に写す。値を省くと、
%   電極の位置だけを描く。
%     mooc_topoplot(ax, 電極ごとの値, 電極の位置, 'Highlight', 目立たせる電極)

arguments
    ax
    values
    chanlocs struct
    options.Highlight cell = {}
    options.ColorLimits = []
    options.ColorbarLabel char = ''
    options.ShowSides (1, 1) logical = false
    options.ShowNames (1, 1) logical = true
    options.GridOnly (1, 1) logical = false
    options.GridScale (1, 1) double = 67
end

previousFigure = get(groot, 'CurrentFigure');
scratch = figure('Visible', 'off');          % becomes the current figure
cleanup = onCleanup(@() localClose(scratch, previousFigure));
scratchAxes = axes(scratch);

if options.GridOnly
    % One map per column of VALUES (stacked along the third dimension).
    for column = size(values, 2):-1:1
        [~, map, ~, gridX, gridY] = topoplot(values(:, column), chanlocs, 'noplot', 'on', ...
            'gridscale', options.GridScale, 'headrad', 'rim');
        grid(:, :, column) = map;
    end
    return;
end

marked = find(ismember(lower({chanlocs.labels}), lower(options.Highlight)));
markerStyle = {marked, 'o', [0.85 0.33 0.10], 7, 1};
if isempty(values)
    electrodeStyle = 'on';
    if options.ShowNames
        electrodeStyle = 'labelpoint';
    end
    topoplot([], chanlocs, 'style', 'blank', 'electrodes', electrodeStyle, ...
        'efontsize', 7, 'headrad', 'rim');
    localCopy(scratchAxes, ax);
    % topoplot's own marking in this style only marks a few electrodes, so
    % the marks are drawn here, on the electrode dots topoplot drew (one dot
    % per electrode, in the order of CHANLOCS).
    dots = findobj(ax, 'Type', 'line', 'Marker', '.');
    dots = dots(arrayfun(@(dot) numel(dot.XData) == numel(chanlocs), dots));
    if ~isempty(marked) && ~isempty(dots)
        hold(ax, 'on');
        plot(ax, dots(1).XData(marked), dots(1).YData(marked), 'o', 'MarkerSize', 6, ...
            'Color', [0.85 0.1 0.1], 'MarkerFaceColor', [0.85 0.1 0.1], 'HitTest', 'off');
        hold(ax, 'off');
    end
else
    limits = options.ColorLimits;
    if isempty(limits)
        limits = [-1 1] * max(abs(values));
    end
    topoplot(values, chanlocs, 'maplimits', limits, 'electrodes', 'on', 'headrad', 'rim', ...
        'gridscale', options.GridScale, 'numcontour', 0, 'emarker2', markerStyle, ...
        'colormap', mooc_style('colormap'));
    localCopy(scratchAxes, ax);
    colormap(ax, mooc_style('colormap'));
    clim(ax, limits);
    if ~isempty(options.ColorbarLabel)
        bar = colorbar(ax);
        bar.Label.String = options.ColorbarLabel;
    end
end
if options.ShowSides
    text(ax, -0.62, 0, '左', 'HorizontalAlignment', 'right', 'FontSize', 11);
    text(ax, 0.62, 0, '右', 'HorizontalAlignment', 'left', 'FontSize', 11);
    text(ax, 0, 0.6, '鼻（前）', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', 9);
end
disableDefaultInteractivity(ax);
end

function localCopy(source, target)
% The drawn objects and the visible area, without titles and labels
% (topoplot adds "64 of 64 electrode locations shown" in its blank style).
cla(target, 'reset');
copyobj(source.Children, target);
for note = findall(target, 'Type', 'text')'
    if any(contains(string(note.String), 'electrode'))
        delete(note);
    end
end
axis(target, 'equal', 'off');
xlim(target, source.XLim);
ylim(target, source.YLim);
end

function localClose(scratch, previousFigure)
delete(scratch);
if ~isempty(previousFigure) && isvalid(previousFigure)
    set(groot, 'CurrentFigure', previousFigure);
end
end
