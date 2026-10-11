function mooc_ui_style_buttons(fig, state)
%MOOC_UI_STYLE_BUTTONS ボタンに、役割に合わせた色を付ける
%
%   次に押すボタン、済んだ段階のボタン、補助のボタンを色で分ける。

styles = struct( ...
    'next',     struct('back', [0.16 0.44 0.82], 'font', [1 1 1]), ...
    'done',     struct('back', [0.87 0.95 0.87], 'font', [0.10 0.30 0.10]), ...
    'waiting',  struct('back', [0.85 0.91 0.99], 'font', [0 0 0]), ...
    'optional', struct('back', [1 1 1],          'font', [0.15 0.15 0.15]), ...
    'disabled', struct('back', [0.96 0.96 0.96], 'font', [0 0 0]));
order = [{'intro'}, state.Stages, {'export'}];

buttons = findall(fig, 'Type', 'uibutton')';
roles = repmat({'optional'}, 1, numel(buttons));
rank = inf(1, numel(buttons));        % position in ORDER of a stage not done yet
for k = 1:numel(buttons)
    tag = buttons(k).Tag;
    if ~buttons(k).Enable
        roles{k} = 'disabled';
    elseif strcmp(tag, 'start')
        roles{k} = 'next';
    elseif strcmp(tag, 'stage:next')
        roles{k} = 'waiting';
    elseif startsWith(tag, 'stage:')
        stage = extractAfter(tag, 'stage:');
        if localIsDone(state, stage)
            roles{k} = 'done';
        else
            roles{k} = 'waiting';
            rank(k) = find(strcmp(order, stage), 1);
        end
    end
end

% In each tab, the earliest stage not done yet is the one to press next;
% when there is none, it is "次のステップへ" (if it can be pressed).
tabs = arrayfun(@(button) ancestor(button, 'uitab'), buttons, 'UniformOutput', false);
handled = false(1, numel(buttons));
for k = 1:numel(buttons)
    if handled(k)
        continue;
    end
    inTab = cellfun(@(other) isequal(other, tabs{k}), tabs);
    handled = handled | inTab;
    candidates = rank;
    candidates(~inTab) = inf;
    [best, index] = min(candidates);
    if isinf(best)
        index = find(inTab & strcmp({buttons.Tag}, 'stage:next') & ...
            strcmp(roles, 'waiting'), 1);
    end
    if ~isempty(index)
        roles{index} = 'next';
    end
end

for k = 1:numel(buttons)
    style = styles.(roles{k});
    buttons(k).BackgroundColor = style.back;
    buttons(k).FontColor = style.font;
end
end

function done = localIsDone(state, stage)
switch stage
    case 'intro'
        done = state.introDone;
    case 'export'
        done = ~isempty(state.exportFile);
    otherwise
        done = state.isDone(stage);
end
end
