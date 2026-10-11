function build_course_dataset(subjects)
%BUILD_COURSE_DATASET 全員分の脳波データを、アプリと同じ処理で作る
%
%   アプリでは1人分のデータを1ステップずつ処理し、最後の「書き出し」で
%   EEGLAB のデータセット（例：S001_imagery.set）に保存しました。このプログラムは、
%   それと同じ処理を参加者全員（105人）に行い、アプリの書き出しと同じ形式で
%   保存します。できたデータは GitHub のリリースで配布し、受講生は setup.m の
%   セクション5でダウンロードします。
%
%   使い方（演習フォルダを「現在のフォルダー」にして実行）：
%     addpath src
%     build_course_dataset           % 全員（1人あたり約3分。全員で約5時間）
%     build_course_dataset(1:3)      % S001〜S003 だけ
%
%   作るもの：
%     external/mooc_dataset/imagery/S001_imagery.set       運動イメージ（R04・R08・R12）
%     external/mooc_dataset/movement/S001_movement.set     実動作（R03・R07・R11）
%       └ 中身はアプリの「書き出し」と同じ（EEG.data、EEG.roi.source_roi_data、
%         EEG.etc.mooc.labels など）。pop_loadset で読み込む
%     external/mooc_dataset/ica/S001_ica.mat   ICAの結果（作り直すときに再利用）
%     external/mooc_dataset/build_log.csv      参加者ごとの結果と、かかった時間
%
%   脳波データ（external/PhysioNet）は全員分が必要です。setup.m のセクション4で
%   subjects = 1:109; にしてダウンロードしておきます。
%
%   書き出しが済んでいる参加者は飛ばします。途中で止めても、もう一度
%   実行すれば続きから処理します。作り直すときは、その参加者のファイルを
%   消してから実行してください（ica フォルダに ICA の結果があれば再利用）。
%
%   配布するとき：課題ごとに zip にまとめ、GitHub のリリースに添付します
%   （setup.m のセクション5がダウンロードするファイル名です）。ica と
%   build_log.csv は配布しません。
%     folder = fullfile('external', 'mooc_dataset');
%     zip('mooc_dataset_imagery.zip', 'imagery', folder)
%     zip('mooc_dataset_movement.zip', 'movement', folder)
%
%   アプリとの違い：ICAは、運動イメージと実動作の6回分の記録をまとめて
%   1回だけ計算します。そのため、2つの課題では同じ成分が除かれ、
%   機械学習の結果を同じ条件で比べられます。

% ---- 準備 --------------------------------------------------------------
projectRoot = fileparts(fileparts(mfilename('fullpath')));   % src フォルダの1つ上
addpath(fullfile(projectRoot, 'src'));
setup_eeglab();
cfg = mooc_default_config();     % フィルタなどの設定（アプリの既定値と同じ）

if nargin < 1
    subjects = setdiff(1:109, cfg.data.excludedSubjects);   % 105人
end

makeFolder(cfg.paths.icaDir);
logFile = fullfile(cfg.paths.datasetDir, 'build_log.csv');

% ---- 1人ずつ処理する ------------------------------------------------------
for subject = subjects
    subjectId = sprintf('S%03d', subject);
    startTime = tic;
    try
        result = processSubject(subject, cfg);
    catch problem
        result = "エラー：" + problem.message;
    end
    seconds = toc(startTime);
    fprintf('%s：%s（%.0f 秒）\n', subjectId, result, seconds);
    writeLog(logFile, subjectId, result, seconds);
end
end

% =========================================================================
function result = processSubject(subject, cfg)
% 1人分の処理。アプリのステップ1〜6と同じ順番です。

subjectId = sprintf('S%03d', subject);
conditions = cfg.data.conditions;            % imagery（運動イメージ）と movement（実動作）

% 保存するファイル（例：external/mooc_dataset/imagery/S001_imagery.set）
files = cell(1, numel(conditions));
for index = 1:numel(conditions)
    name = conditions(index).name;
    files{index} = fullfile(cfg.paths.datasetDir, name, sprintf('%s_%s.set', subjectId, name));
end

% 書き出しが済んでいれば飛ばす
if all(cellfun(@isfile, files))
    result = "済み";
    return;
end

% ---- ステップ1：読み込み（6回分の記録をつなげる） ----------------------------
% EEGLAB の pop_ 関数は、実行した命令を最後の出力（com）として返す。それを
% eeg_hist で EEG.history に書き足していくと、行った処理のコードが残る。
runs = sort([conditions.runs]);              % [3 4 7 8 11 12]
EEG = mooc_import_run(subject, runs(1), cfg);
EEG.history = sprintf('%% %s の処理（src/build_course_dataset.m）\ncfg = mooc_default_config();', subjectId);
EEG = eeg_hist(EEG, sprintf('EEG = mooc_import_run(%d, %d, cfg);   %% pop_biosig で読み込む', subject, runs(1)));
for run = runs(2:end)
    EEG = pop_mergeset(EEG, mooc_import_run(subject, run, cfg), 0);
    EEG = eeg_hist(EEG, sprintf('EEG = pop_mergeset(EEG, mooc_import_run(%d, %d, cfg), 0);', subject, run));
end
[EEG, ~, ~, com] = pop_chanedit(EEG, 'lookup', cfg.paths.channelLocationFile);   % 電極の位置
EEG = eeg_hist(EEG, com);

% ---- ステップ2：フィルタ ------------------------------------------------------
notchHz = cfg.notch.frequencyHz;             % 60 Hz（電源ノイズ）
[EEG, com] = pop_eegfiltnew(EEG, notchHz - cfg.notch.halfWidthHz, notchHz + cfg.notch.halfWidthHz, [], 1);
EEG = eeg_hist(EEG, com);
[EEG, com] = pop_eegfiltnew(EEG, cfg.bandpass.lowHz, cfg.bandpass.highHz);   % 0.5〜45 Hz を残す
EEG = eeg_hist(EEG, com);
[EEG, com] = pop_resample(EEG, cfg.resample.targetHz);                        % 128 Hz に間引く
EEG = eeg_hist(EEG, com);
[EEG, com] = pop_reref(EEG, []);                                              % 平均参照
EEG = eeg_hist(EEG, com);

% ---- ステップ3：ICA（脳以外の成分を除く） ---------------------------------------
icaFile = fullfile(cfg.paths.icaDir, [subjectId '_ica.mat']);
if isfile(icaFile)
    EEG = loadIca(EEG, icaFile);             % 前に計算した結果を使う
    EEG = eeg_hist(EEG, ['% ICA と ICLabel は、前に計算した結果を使った（' icaFile '）']);
else
    [EEG, com] = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, ...
        'rndreset', 'off', 'interrupt', 'off');                  % 乱数を固定
    EEG = eeg_hist(EEG, com);
    [EEG, com] = pop_iclabel(EEG, cfg.ica.iclabelVersion);        % 成分の種類を判定
    EEG = eeg_hist(EEG, com);
    saveIca(EEG, icaFile);
end
% 最も確率の高い種類が「脳」でも「その他」でもない成分を除く（アプリの既定と同じ）
[~, best] = max(EEG.etc.ic_classification.ICLabel.classifications, [], 2);
removed = find(~ismember(best, [1 7]))';     % 1 = 脳、7 = その他
[EEG, com] = pop_subcomp(EEG, removed, 0);
EEG = eeg_hist(EEG, com);

% ---- ステップ5の準備：標準の頭のモデル（電極の位置は全部の課題で同じなので1回だけ） ------
source = cfg.source;
[EEG, com] = pop_dipfit_settings(EEG, 'hdmfile', source.hdmFile, 'coordformat', 'MNI', ...
    'mrifile', source.mriFile, 'chanfile', cfg.paths.channelLocationFile, ...
    'coord_transform', source.coordTransform, 'chansel', 1:EEG.nbchan);
EEG = eeg_hist(EEG, com);
[EEG, com] = pop_leadfield(EEG, 'sourcemodel', source.sourceModelFile, ...
    'sourcemodel2mni', source.sourceModel2mni, 'downsample', 1);
EEG = eeg_hist(EEG, com);

% ---- ステップ4〜6：課題ごとに切り出し、信号源推定をして、書き出す ------------------
for index = 1:numel(conditions)
    condition = conditions(index);

    % ステップ4：合図（左の拳・右の拳）を基準に −1〜4 秒を切り出し、
    % この課題の記録（例：R04・R08・R12）の試行だけを残す
    [epochEEG, ~, com] = pop_epoch(EEG, {'T1', 'T2'}, cfg.epoch.windowSec, 'epochinfo', 'yes');
    epochEEG = eeg_hist(epochEEG, com);
    [epochEEG, ~, com] = pop_selectevent(epochEEG, 'eegmmidb_run', condition.runs, ...
        'deleteevents', 'off', 'deleteepochs', 'on');
    epochEEG = eeg_hist(epochEEG, com);

    % ステップ5：信号源推定（eLORETA で、68領域の活動にする。EEG.roi に入る）
    epochEEG = mooc_roi_activity(epochEEG, source.eloretaRegularization);
    epochEEG = eeg_hist(epochEEG, sprintf(['EEG = mooc_roi_activity(EEG, %g);   ' ...
        '%% pop_roi_activity（eLoreta・nPCA 1）と同じ計算を、領域ごとに行う'], source.eloretaRegularization));

    % ステップ6：アプリの「書き出し」と同じ関数で、EEGLAB のデータセットとして保存する
    about = struct('subject', subject, 'task', condition.displayName, ...
        'notchHz', notchHz, 'bandHz', [cfg.bandpass.lowHz cfg.bandpass.highHz], ...
        'removed', removed, 'madeBy', 'src/build_course_dataset.m（運動イメージと実動作の6回分をまとめてICA）');
    mooc_save_epochs(epochEEG, files{index}, about);
end
result = "完了";
end

% =========================================================================
function saveIca(EEG, icaFile)
% ICAの結果（分け方）と、ICLabel の判定を保存する。
icaResult = struct( ...
    'icaweights', EEG.icaweights, ...
    'icasphere', EEG.icasphere, ...
    'icachansind', EEG.icachansind, ...
    'channelLabels', {{EEG.chanlocs.labels}}, ...
    'classes', {EEG.etc.ic_classification.ICLabel.classes}, ...
    'classifications', EEG.etc.ic_classification.ICLabel.classifications);
save(icaFile, 'icaResult', '-v7');
end

function EEG = loadIca(EEG, icaFile)
% 保存したICAの結果を、EEG に戻す。
loaded = load(icaFile, 'icaResult');
icaResult = loaded.icaResult;
if ~isequal(lower({EEG.chanlocs.labels}), lower(icaResult.channelLabels))
    error('保存したICAと電極の構成が一致しません：%s', icaFile);
end
EEG.icaweights = icaResult.icaweights;
EEG.icasphere = icaResult.icasphere;
EEG.icachansind = icaResult.icachansind;
EEG.icawinv = pinv(EEG.icaweights * EEG.icasphere);
EEG.icaact = [];
EEG.etc.ic_classification.ICLabel.classes = icaResult.classes;
EEG.etc.ic_classification.ICLabel.classifications = icaResult.classifications;
EEG = eeg_checkset(EEG);
end

function writeLog(logFile, subjectId, result, seconds)
% build_log.csv に1行書き足す（なければ見出しの行から作る）。
isNew = ~isfile(logFile);
fid = fopen(logFile, 'a', 'n', 'UTF-8');
if isNew
    fprintf(fid, 'participant,result,seconds,finished\n');
end
fprintf(fid, '%s,%s,%.0f,%s\n', subjectId, strrep(result, ',', ' '), seconds, ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fclose(fid);
end

function makeFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end
