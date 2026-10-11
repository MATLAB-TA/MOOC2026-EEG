function api = step_export(tab, state, nav)
%STEP_EXPORT ステップ6「データを書き出す」の画面
%
%   処理したデータを EEGLAB のデータセット（.set）として保存し、中身を表示する。

cfg = state.cfg;

% ---- Layout --------------------------------------------------------------
ui = mooc_ui_page_layout(tab, state, nav, ...
    ['・ここまで処理したデータを、EEGLAB のデータセット（.set）として保存する' newline ...
     '・保存したデータは、機械学習で使える'], ...
    'ControlRows', {34, 'fit', 34}, 'DescriptionHeight', 110, ...
    'HistoryGroup', '');      % '' = every step in full: the whole history is saved

exportButton = uibutton(ui.controls, 'Text', '保存先を選んで書き出す', 'FontWeight', 'bold', ...
    'Tag', 'stage:export', ...
    'ButtonPushedFcn', @(~, ~) exportData());
exportButton.Layout.Column = [1 2];
savedLabel = uilabel(ui.controls, 'Text', 'まだ書き出していません', 'WordWrap', 'on', ...
    'FontColor', [0.4 0.4 0.4]);
savedLabel.Layout.Column = [1 2];
closeButton = uibutton(ui.controls, 'Text', 'このアプリを閉じる', 'Tag', 'option', ...
    'ButtonPushedFcn', @(~, ~) close(ancestor(tab, 'figure')));
closeButton.Layout.Column = [1 2];

plotGrid = uigridlayout(ui.plotArea, [3 1], 'RowHeight', {250, '1x', 110}, 'RowSpacing', 14);
filesPanel = uipanel(plotGrid, 'Title', ...
    'ファイルの中身（EEG = pop_loadset(''ファイル名.set''); で読み込むと、EEG の中にこれらが入っています）', ...
    'FontWeight', 'bold');
contents = {
    'EEG.data', '電極 × 時間 × 試行', '脳波（µV）。1試行分は「行 = 電極、列 = 時間」の表'
    'EEG.roi.source_roi_data', '領域 × 時間 × 試行', '（ステップ5を行った場合）脳の68領域の活動'
    'EEG.etc.mooc.labels', '試行 × 1', '試行ごとの合図：left_fist（左拳）／ right_fist（右拳）。EEG.etc.mooc.runs に記録の番号'
    'EEG.times', '1 × 時間', '合図からの時間（ミリ秒）。0 = 合図'
    'EEG.srate', '1 × 1', '1秒あたりのサンプル数'
    'EEG.chanlocs', '1 × 電極', '電極の名前（labels）と位置'
    'EEG.roi.atlas.Scouts', '1 × 領域', '領域の名前（Label）'
    'EEG.etc.mooc.info', '表', 'データの作り方（参加者・フィルタ・除去した成分など）'
    'EEG.history', '文字', 'このデータに行った処理のコード'};
contentsTable = uitable(uigridlayout(filesPanel, [1 1]), 'RowName', {}, ...
    'ColumnName', {'中身', '大きさ', '内容'}, 'ColumnWidth', {190, 130, 'auto'}, 'Data', contents);
previewPanel = uipanel(plotGrid, 'Title', 'EEG.data の1試行目（書き出した後に表示）', ...
    'FontWeight', 'bold');
previewTable = uitable(uigridlayout(previewPanel, [1 1]), 'RowName', {});
nextPanel = uipanel(plotGrid, 'Title', 'この後（機械学習）', 'FontWeight', 'bold');
uilabel(uigridlayout(nextPanel, [1 1]), 'WordWrap', 'on', 'VerticalAlignment', 'top', ...
    'FontSize', 13, 'Text', { ...
    '・機械学習では、この処理を参加者全員に行い、同じ形式で保存したデータ（external/mooc_dataset。setup.m のセクション5でダウンロード）を使う', ...
    '・自分で書き出したデータを使うこともできる'});

api = struct('refresh', @refresh, 'setNextEnabled', @(flag) [], ...
    'exportData', @exportData);
refresh();

% ---- Callbacks -----------------------------------------------------------
    function file = exportData(parent)
        % Asks for a folder (PARENT, given by tests, skips the dialog) and
        % saves a file into it, e.g. S001_imagery.set. Returns the file
        % written ('' when nothing was saved).
        file = '';
        fig = ancestor(tab, 'figure');
        if ~state.isDone('clean')
            uialert(fig, '先に「3. 独立成分分析（ICA）」の④まで進めてください。', '確認');
            return;
        end
        if nargin == 0
            if ~isfolder(cfg.paths.outputDir)
                mkdir(cfg.paths.outputDir);
            end
            parent = uigetdir(cfg.paths.outputDir, '書き出す場所を選ぶ');
            figure(fig);                 % the dialog may leave the app behind
            if isequal(parent, 0)
                return;                  % cancelled
            end
        end
        problem = localFolderProblem(parent, cfg.paths);
        if ~isempty(problem)
            uialert(fig, problem, '別の場所を選んでください');
            return;
        end
        file = fullfile(parent, sprintf('S%03d_%s.set', state.subject, state.condition().name));
        fig.Pointer = 'watch';
        restorePointer = onCleanup(@() set(fig, 'Pointer', 'arrow'));
        progress = uiprogressdlg(fig, 'Title', '処理中：データを書き出す', 'Indeterminate', 'on', ...
            'Message', {'合図ごとに切り出して、ファイルに保存しています', '', ...
            '詳しい進み具合は、MATLABのコマンドウィンドウに表示されます。'});
        closeProgress = onCleanup(@() delete(progress));
        if state.isDone('source')
            % The epochs of steps 4-5, with the brain-region signals (EEG.roi).
            epochEEG = state.sourceEEG;
        else
            epochEEG = pop_epoch(state.cleanEEG, {'T1', 'T2'}, cfg.epoch.windowSec, 'epochinfo', 'yes');
        end
        fprintf('\n=== データを書き出す：%s ===\n', file);
        mooc_save_epochs(epochEEG, file, localAbout(state), localScript(state.history.entries));
        fprintf('    → %d試行分を保存しました\n', epochEEG.trials);
        state.exportFile = file;
        showPreview(file);
        refresh();
        nav.update();
    end

% ---- Drawing ---------------------------------------------------------------
    function refresh()
        exportButton.Enable = state.isDone('clean');
        if isempty(state.exportFile)
            savedLabel.Text = 'まだ書き出していません';
        else
            savedLabel.Text = {'保存した場所：', state.exportFile};
        end
    end

    function showPreview(file)
        % Read the saved file back: the actual sizes, and the first trial.
        saved = pop_loadset(file);
        sizes = {size(saved.data), [], size(saved.etc.mooc.labels), size(saved.times), [1 1], ...
            size(saved.chanlocs), [], size(saved.etc.mooc.info), size(saved.history)};
        if isfield(saved, 'roi') && isfield(saved.roi, 'source_roi_data')
            sizes{2} = size(saved.roi.source_roi_data);
            sizes{7} = size(saved.roi.atlas.Scouts);
        end
        for k = 1:numel(sizes)
            if isempty(sizes{k})
                contentsTable.Data{k, 2} = '（なし）';
            else
                contentsTable.Data{k, 2} = char(strjoin(string(sizes{k}), ' × '));
            end
        end
        firstTrial = saved.data(:, :, 1);                  % electrodes x samples
        previewTable.Data = firstTrial;
        previewTable.RowName = {saved.chanlocs.labels};
        previewTable.ColumnName = compose('%.3f 秒', saved.times / 1000);
        previewPanel.Title = sprintf('EEG.data(:, :, 1) の中身：1試行目（%d電極 × %d点。1点 = 1/%g 秒）', ...
            size(firstTrial, 1), size(firstTrial, 2), saved.srate);
    end

end

% ---- Local functions -----------------------------------------------------
function problem = localFolderProblem(folder, paths)
% Why FOLDER must not be used ('' = it can be used). Writing into MATLAB's
% own folders, into this exercise's program folders or into a folder on
% the MATLAB path could break the app, so these are refused. In the exercise folder only
% outputs/ may be used.
folder = char(folder);
isInside = @(root) startsWith([folder filesep], [char(root) filesep], 'IgnoreCase', ispc);
if isInside(matlabroot)
    problem = 'MATLAB本体のフォルダには保存できません。';
elseif isInside(paths.projectRoot) && ~isInside(paths.outputDir)
    problem = sprintf(['演習のプログラムやデータが入ったフォルダには保存できません。' ...
        '演習フォルダの中では outputs フォルダを選んでください：\n%s'], paths.outputDir);
elseif any(strcmpi(strsplit(path, pathsep), folder))
    problem = 'MATLABのパスに含まれるフォルダには保存できません。';
else
    problem = '';
end
end

function about = localAbout(state)
% The facts for the table "how the data was made" (MOOC_SAVE_EPOCHS).
settings = state.filteredEEG.etc.mooc.filterSettings;
notchHz = [];
if settings.notch.enabled
    notchHz = settings.notch.frequencyHz;
end
about = struct('subject', state.subject, 'task', state.condition().displayName, ...
    'notchHz', notchHz, 'bandHz', [settings.bandpass.lowHz settings.bandpass.highHz], ...
    'removed', find(state.rejectMask), 'madeBy', '脳波解析演習アプリ（ステップ1〜6）');
end

function lines = localScript(entries)
% The code of every stage in the history, as one MATLAB script.
lines = {'% このデータに行った処理（脳波解析演習アプリが書き出したもの）'};
groups = unique({entries.group}, 'stable');
for g = 1:numel(groups)
    lines{end + 1} = ''; %#ok<AGROW>
    lines{end + 1} = sprintf('%%%% %s', groups{g}); %#ok<AGROW>
    for entry = entries(strcmp({entries.group}, groups{g}))
        lines{end + 1} = ['% ' entry.label]; %#ok<AGROW>
        lines = [lines, entry.code]; %#ok<AGROW>
    end
end
end
