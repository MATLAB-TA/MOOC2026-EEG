function outputFile = package_course_raw_data(outputFile)
%PACKAGE_COURSE_RAW_DATA GitHub Release用の演習用脳波ZIPを作る
%
%   external/PhysioNet にあるS001〜S005のうち、演習で使う6記録だけを
%   physionet_eegmmidb_s001-s005.zip にまとめる。ZIPには出典・ライセンス表示も
%   PhysioNet/NOTICE.md として含める。

projectRoot = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1
    outputFile = fullfile(projectRoot, 'physionet_eegmmidb_s001-s005.zip');
end
if isfile(outputFile)
    error('上書きしません。既存のファイルを移動してから再実行してください：%s', outputFile);
end

subjects = 1:5;
runs = [3 4 7 8 11 12];
rawDir = fullfile(projectRoot, 'external', 'PhysioNet');
noticeFile = fullfile(projectRoot, 'DATA_LICENSE.md');
stagingDir = tempname;
stagingRawDir = fullfile(stagingDir, 'PhysioNet');
mkdir(stagingRawDir);
cleanup = onCleanup(@() removeFolder(stagingDir));

for subject = subjects
    subjectId = sprintf('S%03d', subject);
    targetSubjectDir = fullfile(stagingRawDir, subjectId);
    mkdir(targetSubjectDir);
    for run = runs
        recordName = sprintf('%sR%02d.edf', subjectId, run);
        copyRequired(fullfile(rawDir, subjectId, recordName), targetSubjectDir);
        copyRequired(fullfile(rawDir, subjectId, [recordName '.event']), targetSubjectDir);
    end
end
copyRequired(noticeFile, fullfile(stagingRawDir, 'NOTICE.md'));

zip(outputFile, 'PhysioNet', stagingDir);
fprintf('作成しました：%s\n', outputFile);
end

function copyRequired(source, destination)
if ~isfile(source)
    error('必要なファイルがありません：%s', source);
end
copyfile(source, destination);
end

function removeFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end
