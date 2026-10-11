classdef MoocProcessLog < handle
    %MOOCPROCESSLOG 「このデータに行った処理」の欄
    %
    %   「>>」の行をダブルクリックすると、使った関数のファイルが開く。

    properties (SetAccess = private)
        list           % uilistbox, one item per line
        currentGroup   % heading of this tab's step, e.g. '2. ノイズを除去' ('' = full view)
        functionNames  % function opened by each line ('' = none)
    end

    methods
        function obj = MoocProcessLog(parent, history, currentGroup)
            obj.currentGroup = currentGroup;
            obj.list = uilistbox(parent, 'Items', {}, 'FontSize', 12, ...
                'Multiselect', 'on', 'DoubleClickedFcn', @(~, ~) obj.openClicked());
            history.attach(obj);
        end

        function render(obj, entries)
            if isempty(entries)
                obj.show({'まだ処理はありません。', ...
                    'データに行った処理が、ここに順番に積み上がっていきます。'}, {'', ''});
                return;
            end
            marks = struct('todo', '□', 'run', '▶', 'done', '✔', 'fail', '✖');
            lines = {};
            functions = {};
            groups = unique({entries.group}, 'stable');
            for g = 1:numel(groups)
                members = entries(strcmp({entries.group}, groups{g}));
                isOtherStep = ~isempty(obj.currentGroup) && ~strcmp(groups{g}, obj.currentGroup);
                if isOtherStep
                    lines{end + 1} = sprintf('【%s】 %s', groups{g}, ...
                        localSummary({members.status})); %#ok<AGROW>
                    functions{end + 1} = ''; %#ok<AGROW>
                    continue;
                end
                lines{end + 1} = sprintf('【%s】', groups{g}); %#ok<AGROW>
                functions{end + 1} = ''; %#ok<AGROW>
                for entry = members
                    heading = sprintf('%s %s', marks.(entry.status), entry.label);
                    if ~isempty(entry.detail)
                        heading = [heading '　→ ' entry.detail]; %#ok<AGROW>
                    end
                    [codeLines, isCommand] = localCodeLines(entry.code);
                    lineFunctions = repmat({''}, 1, numel(codeLines));
                    lineFunctions(isCommand) = {entry.fn};
                    lines = [lines, {heading}, codeLines]; %#ok<AGROW>
                    functions = [functions, {''}, lineFunctions]; %#ok<AGROW>
                end
            end
            obj.show(lines, functions);
        end
    end

    methods (Access = private)
        function show(obj, lines, functions)
            obj.functionNames = functions;
            obj.list.Items = lines;
            obj.list.ItemsData = 1:numel(lines);
            obj.list.Value = [];
        end

        function openClicked(obj)
            % Open the function file of the double-clicked line in the Editor.
            line = obj.list.Value;     % the double click selects the line
            obj.list.Value = [];
            if isempty(line)
                return;
            end
            name = obj.functionNames{line(1)};
            if isempty(name) || ~endsWith(which(name), '.m')
                return;
            end
            edit(which(name));
        end
    end
end

function [lines, isCommand] = localCodeLines(code)
% "    >> EEG = ..." for commands; comment lines are kept as they are.
lines = cell(1, numel(code));
isCommand = false(1, numel(code));
for k = 1:numel(code)
    if startsWith(strtrim(code{k}), '%')
        lines{k} = ['        ' code{k}];
    else
        lines{k} = ['    >> ' code{k}];
        isCommand(k) = true;
    end
end
end

function text = localSummary(statuses)
% e.g. "✔ 済（5工程）" for a step whose stages are all done.
if any(strcmp(statuses, 'fail'))
    text = '✖ エラーあり';
elseif any(strcmp(statuses, 'run')) || any(strcmp(statuses, 'todo'))
    text = '▶ 実行中';
else
    text = sprintf('✔ 済（%d工程）', numel(statuses));
end
end
