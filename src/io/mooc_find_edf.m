function edfFile = mooc_find_edf(subject, run)
%MOOC_FIND_EDF 参加者と記録の番号から、脳波のファイルの場所を返す
%
%   ファイルは setup.m で external/PhysioNet にダウンロードしたもの。
%   見つからないときは、setup.m を実行するよう知らせる。

arguments
    subject (1, 1) double {mustBeInteger, mustBeBetween(subject, 1, 109)}
    run (1, 1) double {mustBeInteger, mustBeBetween(run, 1, 14)}
end

paths = mooc_default_config().paths;
subjectId = sprintf('S%03d', subject);
fileName = sprintf('%sR%02d.edf', subjectId, run);

edfFile = fullfile(paths.rawDir, subjectId, fileName);
if isfile(edfFile) && isfile([edfFile '.event'])
    return;
end

error('mooc2026:RecordNotFound', ['%s が見つかりません。\n' ...
    'setup.m のセクション4（脳波データ）を実行してください。'], fileName);
end
