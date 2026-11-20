function EEG = mooc_save_epochs(EEG, file, about, scriptLines)
%MOOC_SAVE_EPOCHS 処理した脳波を、EEGLAB のデータセット（.set）として保存する
%
%   アプリの書き出しと build_course_dataset の両方で使うので、どちらで
%   作ったファイルも同じ形になる。読み込むときは pop_loadset を使う。
%     EEG = mooc_save_epochs(EEG, ファイル名, about, コード)
%       about：作り方の表に書く内容（参加者・課題・フィルタ・除いた成分など）
%       コード：EEG.history に入れる処理のコード（省略すると今の EEG.history のまま）
%   EEG.etc.mooc に試行ごとの合図（labels）・記録の番号（runs）・作り方の表
%   （info）を入れる。頭のモデルの計算結果（約8 MB）は保存しない。演習
%   フォルダの場所は "." に置き換え、自分のフォルダ名がファイルに残らないようにする。

[folder, name] = fileparts(file);
EEG.setname = name;
if nargin > 3 && ~isempty(scriptLines)
    EEG.history = strjoin(cellstr(scriptLines), newline);
end

% The cue of every epoch: a T1 at time 0 means left fist.
isLeft = ~isnan(eeg_getepochevent(EEG, 'type', 'T1', 'timewin', [0 0]));
labels = ["right_fist"; "left_fist"];
EEG.etc.mooc.labels = labels(isLeft(:) + 1);            % trials x 1
runs = eeg_getepochevent(EEG, 'type', {'T1', 'T2'}, 'timewin', [0 0], 'fieldname', 'eegmmidb_run');
EEG.etc.mooc.runs = runs(:);
EEG.etc.mooc.info = localInfoTable(EEG, about);

if isfield(EEG, 'dipfit') && isfield(EEG.dipfit, 'sourcemodel') && ...
        isfield(EEG.dipfit.sourcemodel, 'leadfield')
    EEG.dipfit.sourcemodel = rmfield(EEG.dipfit.sourcemodel, 'leadfield');
end
EEG = localRelativePaths(EEG, mooc_default_config().paths.projectRoot);
if ~isfolder(folder)
    mkdir(folder);
end
EEG = pop_saveset(EEG, 'filename', [name '.set'], 'filepath', folder, 'savemode', 'onefile');
% pop_saveset also writes the folder it saved to (EEG.filepath) into the
% file; pop_loadset replaces it with the folder it loads from, so it is
% emptied here.
filepath = ''; %#ok<NASGU>
save(file, 'filepath', '-append');
end

function info = localInfoTable(EEG, about)
% How the data was made, one row per item.
notch = 'なし';
if ~isempty(about.notchHz)
    notch = sprintf('%g Hz', about.notchHz);
end
reference = '記録時のまま';
if strcmp(EEG.ref, 'average')
    reference = '全電極の平均（平均参照）';
end
source = 'なし';
if isfield(EEG, 'roi') && isfield(EEG.roi, 'source_roi_data')
    source = 'EEGLAB 標準の頭と eLORETA で、脳の68領域（Desikan-Killiany）の活動を推定';
end
items = {
    '参加者', sprintf('S%03d', about.subject)
    '課題', about.task
    '記録', strjoin(compose('R%02d', unique(EEG.etc.mooc.runs)'), '、')
    '電源ノイズの除去', notch
    '残した周波数', sprintf('%g〜%g Hz', about.bandHz)
    '1秒あたりのサンプル数', sprintf('%g', EEG.srate)
    '基準', reference
    'ICAで除いた成分', sprintf('%d個（%s）', numel(about.removed), num2str(about.removed(:)'))
    '信号源推定', source
    '作ったもの', about.madeBy
    '作った日時', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'))};
info = cell2table(items, 'VariableNames', {'item', 'value'});
end

function value = localRelativePaths(value, root)
% The exercise folder's path in every text of VALUE (a struct, cell array
% or text), replaced by "." (the exercise folder as the current folder).
if ischar(value) && size(value, 1) > 1
    value = char(strrep(cellstr(value), root, '.'));    % several lines of text
elseif ischar(value) || isstring(value)
    value = strrep(value, root, '.');
elseif iscell(value)
    for k = 1:numel(value)
        value{k} = localRelativePaths(value{k}, root);
    end
elseif isstruct(value)
    for name = fieldnames(value)'
        for k = 1:numel(value)
            value(k).(name{1}) = localRelativePaths(value(k).(name{1}), root);
        end
    end
end
end
