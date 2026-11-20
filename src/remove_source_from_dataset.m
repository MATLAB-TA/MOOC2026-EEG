function remove_source_from_dataset(inputDir, outputDir)
%REMOVE_SOURCE_FROM_DATASET 機械学習用のデータから、信号源推定の結果を除く
%
%   リリース v1.0 の機械学習用のデータ（build_course_dataset で作ったもの）には、
%   信号源推定の結果が入っています。演習から信号源推定を外したので、それを除いて
%   別のフォルダに保存し直します。脳波（EEG.data）などは、元のファイルのままです。
%   信号源推定のコードは archive/source_estimation にあります。
%
%   使い方（演習フォルダを「現在のフォルダー」にして実行）：
%     addpath src
%     remove_source_from_dataset(元のフォルダ, 保存するフォルダ)
%       元のフォルダ：imagery と movement のフォルダが入ったところ（例：external/mooc_dataset）
%
%   除くもの：
%     EEG.roi                    脳の68領域の活動
%     EEG.dipfit                 頭のモデルの設定（[] にする。EEGLAB の空のデータと同じ）
%     EEG.etc.mooc.info の行      「信号源推定」
%     EEG.history の行            pop_dipfit_settings・pop_leadfield・mooc_roi_activity
%   EEG.history の最後に、このプログラムで除いたことを1行書き足します。
%
%   保存し直したあと、もう一度 pop_loadset で読み込み、除いたもの以外が元の
%   ファイルと同じかを確かめます。違えばエラーで止まります。

inputDir = char(inputDir);
outputDir = char(outputDir);
if strcmp(localFullPath(inputDir), localFullPath(outputDir))
    error('元のフォルダと同じ場所には保存しません：%s', outputDir);
end
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'src'));
setup_eeglab();

removedCode = ["pop_dipfit_settings", "pop_leadfield", "mooc_roi_activity"];
note = '% 信号源推定の結果（EEG.roi・EEG.dipfit）は、src/remove_source_from_dataset.m で除いた';

for condition = {'imagery', 'movement'}
    condition = condition{1}; %#ok<FXSET>   % char: pop_loadset does not take strings
    files = dir(fullfile(inputDir, condition, '*.set'));
    if isempty(files)
        error('ファイルがありません：%s', fullfile(inputDir, condition));
    end
    targetDir = fullfile(outputDir, condition);
    if ~isfolder(targetDir)
        mkdir(targetDir);
    end
    for k = 1:numel(files)
        source = fullfile(files(k).folder, files(k).name);
        target = fullfile(targetDir, files(k).name);
        if isfile(target)
            error('上書きしません。消してから実行してください：%s', target);
        end

        % .set（savemode onefile）は、EEG の各欄が1つずつ変数として入った MAT ファイル。
        % pop_loadset を通さずに読み書きすると、ほかの欄はそのまま残る。
        saved = load(source, '-mat');
        if ~isfield(saved, 'roi')
            error('信号源推定の結果が入っていません：%s', source);
        end
        saved = rmfield(saved, 'roi');
        saved.dipfit = [];
        info = saved.etc.mooc.info;
        saved.etc.mooc.info = info(~strcmp(info.item, '信号源推定'), :);
        lines = string(splitlines(saved.history));
        lines = lines(~contains(lines, removedCode));
        saved.history = char(strjoin([lines; note], newline));
        save(target, '-struct', 'saved', '-v7.3');

        localCheck(source, target, removedCode);
        fprintf('%s：%.1f MB → %.1f MB\n', files(k).name, files(k).bytes / 1e6, ...
            dir(target).bytes / 1e6);
    end
end
fprintf('完了：%s\n', outputDir);
end

function localCheck(source, target, removedCode)
% Load both with pop_loadset (as machine_learning.m does) and compare.
[~, before] = evalc('pop_loadset(source)');
[~, after] = evalc('pop_loadset(target)');
% eeg_checkset adds an empty EEG.roi when loading (as for the app's export).
assert((~isfield(after, 'roi') || isempty(after.roi)) && isempty(after.dipfit), ...
    'まだ残っています：%s', target);
assert(~contains(after.history, removedCode), '処理のコードが残っています：%s', target);
assert(isequal(after.etc.mooc.info, ...
    before.etc.mooc.info(~strcmp(before.etc.mooc.info.item, '信号源推定'), :)), ...
    '作り方の表が違います：%s', target);
before = rmfield(before, {'roi', 'dipfit', 'history', 'filepath'});
after = rmfield(after, intersect({'roi', 'dipfit', 'history', 'filepath'}, fieldnames(after)));
before.etc.mooc = rmfield(before.etc.mooc, 'info');
after.etc.mooc = rmfield(after.etc.mooc, 'info');
assert(isequaln(before, after), '除いたもの以外が変わっています：%s', target);
end

function folder = localFullPath(folder)
if isfolder(folder)
    folder = char(java.io.File(folder).getCanonicalPath());
end
end
