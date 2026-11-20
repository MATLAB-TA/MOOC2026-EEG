classdef MoocAppState < handle
    %MOOCAPPSTATE 解析中のデータと、各段階の結果をまとめて持つ
    %
    %   どの段階をやり直すと、どの結果が消えるかも、ここで決めている。

    properties (Constant)
        Stages = {'raw', 'filtered', 'decomposition', 'iclabel', ...
            'selection', 'clean', 'epoch', 'erd', 'source', 'regionErd'}
    end

    properties
        cfg                     % settings from mooc_default_config
        history                 % MoocHistory of the stages done so far
        subject = []            % participant number
        conditionIndex = 1      % index into cfg.data.conditions
        runs = []               % runs that were joined

        rawEEG = []             % raw
        filteredEEG = []        % filtered
        icaDecomposedEEG = []   % decomposition (filtered data + ICA weights)
        icaEEG = []             % iclabel (decomposition + class probabilities)
        rejectMask = []         % selection: true = component removed
        cleanEEG = []           % clean
        epochEEG = []           % epoch
        trialLabels = categorical.empty     % epoch: left_fist / right_fist of each epoch
        erd = []                % erd
        sourceEEG = []          % source: the epochs with EEG.dipfit (head model)
                                %   and EEG.roi (68 region signals)
        regionErd = []          % regionErd

        introDone = false       % step 0: environment checked
        exportFile = ''         % step 6: file the processed data was saved to
    end

    methods
        function obj = MoocAppState(cfg)
            if nargin < 1
                cfg = mooc_default_config();
            end
            obj.cfg = cfg;
            obj.history = MoocHistory(obj.Stages);
        end

        function condition = condition(obj)
            condition = obj.cfg.data.conditions(obj.conditionIndex);
        end

        function invalidateFrom(obj, stage)
            % Clear STAGE and every later stage, and their history entries.
            first = find(strcmp(obj.Stages, stage), 1);
            if isempty(first)
                error('mooc2026:UnknownStage', 'Unknown stage: %s', stage);
            end
            obj.exportFile = '';      % the saved data no longer matches
            for name = obj.Stages(first:end)
                switch name{1}
                    case 'raw'
                        obj.rawEEG = [];
                    case 'filtered'
                        obj.filteredEEG = [];
                    case 'decomposition'
                        obj.icaDecomposedEEG = [];
                    case 'iclabel'
                        obj.icaEEG = [];
                    case 'selection'
                        obj.rejectMask = [];
                    case 'clean'
                        obj.cleanEEG = [];
                    case 'epoch'
                        obj.epochEEG = [];
                        obj.trialLabels = categorical.empty;
                    case 'erd'
                        obj.erd = [];
                    case 'source'
                        obj.sourceEEG = [];
                    case 'regionErd'
                        obj.regionErd = [];
                end
            end
            obj.history.removeFrom(stage);
        end

        function done = isDone(obj, stage)
            % True when STAGE has a result.
            switch stage
                case 'raw',           done = ~isempty(obj.rawEEG);
                case 'filtered',      done = ~isempty(obj.filteredEEG);
                case 'decomposition', done = ~isempty(obj.icaDecomposedEEG);
                case 'iclabel',       done = ~isempty(obj.icaEEG);
                case 'selection',     done = ~isempty(obj.rejectMask);
                case 'clean',         done = ~isempty(obj.cleanEEG);
                case 'epoch',         done = ~isempty(obj.epochEEG);
                case 'erd',           done = ~isempty(obj.erd);
                case 'source',        done = ~isempty(obj.sourceEEG);
                case 'regionErd',     done = ~isempty(obj.regionErd);
            end
        end

        function done = completedSteps(obj)
            % One flag per tab (steps 0-6).
            done = [obj.introDone, obj.isDone('raw'), obj.isDone('filtered'), ...
                obj.isDone('clean'), obj.isDone('erd'), obj.isDone('regionErd'), ...
                ~isempty(obj.exportFile)];
        end

        function EEG = latestContinuous(obj)
            % The most processed continuous data available (for step 4).
            if ~isempty(obj.cleanEEG)
                EEG = obj.cleanEEG;
            elseif ~isempty(obj.filteredEEG)
                EEG = obj.filteredEEG;
            else
                EEG = obj.rawEEG;
            end
        end
    end
end
