classdef MoocHistory < handle
    %MOOCHISTORY 「このデータに行った処理」の記録
    %
    %   どのタブでも同じ記録を表示する。

    properties (SetAccess = private)
        entries = struct('stage', {}, 'group', {}, 'label', {}, 'fn', {}, ...
            'status', {}, 'detail', {}, 'code', {})
        stageOrder          % stage names in processing order
    end

    properties (Access = private)
        views = {}
    end

    methods
        function obj = MoocHistory(stageOrder)
            obj.stageOrder = stageOrder;
        end

        function attach(obj, view)
            obj.views{end + 1} = view;
            view.render(obj.entries);
        end

        function removeFrom(obj, stage)
            % Drop the entries of STAGE and of every later stage.
            first = find(strcmp(obj.stageOrder, stage), 1);
            stageIndex = cellfun(@(name) find(strcmp(obj.stageOrder, name), 1), ...
                {obj.entries.stage});
            obj.entries = obj.entries(stageIndex < first);
            obj.redraw();
        end

        function index = add(obj, stage, group, label, fn, code)
            % Append a stage that is about to run; returns its index.
            obj.entries(end + 1) = struct('stage', stage, 'group', group, ...
                'label', label, 'fn', fn, 'status', 'todo', 'detail', '', ...
                'code', {cellstr(code)});
            index = numel(obj.entries);
            obj.redraw();
        end

        function update(obj, index, status, detail)
            % STATUS is 'run', 'done' or 'fail'.
            obj.entries(index).status = status;
            obj.entries(index).detail = detail;
            obj.redraw();
        end

        function appendNote(obj, stage, note)
            % Add NOTE to the result of the last entry of STAGE, e.g. when a
            % student changes a decision by hand after the stage ran.
            index = find(strcmp({obj.entries.stage}, stage), 1, 'last');
            if ~isempty(index) && ~contains(obj.entries(index).detail, note)
                obj.entries(index).detail = [obj.entries(index).detail ' ' note];
                obj.redraw();
            end
        end

        function redraw(obj)
            % Redraw every view. Also called when a tab is opened: a text
            % area that was updated while its tab was hidden can stay blank.
            % Views whose window was closed are dropped.
            obj.views = obj.views(cellfun(@(view) isvalid(view.list), obj.views));
            for k = 1:numel(obj.views)
                obj.views{k}.render(obj.entries);
            end
            drawnow limitrate;
        end
    end
end
