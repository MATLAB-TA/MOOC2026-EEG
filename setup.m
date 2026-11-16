%[text] # 演習の準備（最初に1回だけ）
%[text] このスクリプトは、演習に必要な**プログラム**と**脳波データ**をインターネットからダウンロードして、この演習フォルダの中に置きます。
%[text] - ダウンロードしたものは、すべて `external` フォルダに置きます。
%[text] - 演習フォルダの外は変更しません。
%[text] - ダウンロードの大きさ：プログラム 約200 MB、アプリ用の脳波データ 約41 MB、機械学習用のデータ 約3 GB \
%[text] ## 実行のしかた
%[text] このスクリプトは、ダウンロードするものごとにセクションで区切っています。各セクションにある「**このセクションを実行**」ボタンを、**上から順に1つずつ**押してください。
%[text] ```
%[text] == セクションとは？ ==
%[text] 横線で区切られている分割単位です。この区切りごとにコードを実行することができます。
%[text] ```
%[text] 途中でエラーが出たり止まったりした場合は、同じセクションの「このセクションを実行」ボタンをもう一度押してください。
%[text] 済んでいるものは飛ばし、残りだけを行います。
%%
%[text] ## 0. 演習フォルダの確認
%[text] MATLAB の画面左側にある「**現在のフォルダー**」が、このファイル（`setup.m`）が入っているフォルダになっているかを確かめます。
%[text] 違うフォルダになっているとエラーが表示されます。そのときは、「現在のフォルダー」でこの演習フォルダを開いてから、もう一度実行してください。
  %[control:button:30b3]{"position":[1,2]}

% 「現在のフォルダー」の場所を取り出す（pwd は「今いるフォルダ」を表す命令）
projectRoot = pwd;

% 演習フォルダには launch_app.m というファイルがあるはずなので、それで確かめる
checkFile = fullfile(projectRoot, 'launch_app.m');   % fullfile は、フォルダ名とファイル名をつないで場所を作る命令
if ~isfile(checkFile)
    error('このファイル（setup.m）があるフォルダを「現在のフォルダー」にしてから実行してください。');
end

% ダウンロードしたものを置くフォルダ（external）と、その中の
% 脳波データ（external/PhysioNet）・機械学習用のデータ（external/mooc_dataset）の場所
externalDir = fullfile(projectRoot, 'external');
rawDataDir  = fullfile(externalDir, 'PhysioNet');
datasetDir  = fullfile(externalDir, 'mooc_dataset');

fprintf('演習フォルダ：%s\n', projectRoot);
%%
%[text] ## 1. EEGLAB（脳波解析のツール）をダウンロードする
%[text] EEGLAB は、米国カリフォルニア大学サンディエゴ校の研究所（SCCN）が無料で公開している、脳波解析のためのツールです。
%[text] - 紹介ページ：[https://eeglab.org](https://eeglab.org)
%[text] - **ダウンロード元：**[https://github.com/sccn/eeglab/archive/refs/tags/2026.0.0.zip](https://github.com/sccn/eeglab/archive/refs/tags/2026.0.0.zip)（版 2026.0.0、約30 MB）
%[text] - 置き場所：`external/eeglab` \
%[text] 上のリンクから zip ファイルをダウンロードし、展開して置きます。
%[text] ```
%[text] == zipファイルとは？ ==
%[text] 複数のファイルを1つにまとめて圧縮したものです。プログラムやデータを配布するときによく使われる形式です。
%[text] ```
  %[control:button:81b7]{"position":[1,2]}

eeglabUrl = 'https://github.com/sccn/eeglab/archive/refs/tags/2026.0.0.zip';
eeglabFolderInZip = 'eeglab-2026.0.0';               % zip の中に入っているフォルダの名前
eeglabDir = fullfile(externalDir, 'eeglab');         % 置き場所
eeglabCheckFile = 'eeglab.m';                        % このファイルがあれば「済み」とみなす

downloadAndUnzip(eeglabUrl, eeglabFolderInZip, eeglabDir, eeglabCheckFile);
%%
%[text] ## 2. EEGLAB の追加機能（プラグイン）をダウンロードする
%[text] EEGLAB の本体には入っていない、次の5つの追加機能を、EEGLAB のプラグイン配布サイト（[https://sccn.ucsd.edu/eeglab/plugins](https://sccn.ucsd.edu/eeglab/plugins)）からダウンロードします。EEGLAB の `plugins` フォルダに置くと、EEGLAB の起動時に自動で読み込まれます。
%[text] - <u>**firfilt 2.8**</u>
%[text]     - 使用用途　　　：データのフィルタリング（ステップ2）
%[text]     - サイズ　　　　：約50 KB
%[text]     - ダウンロード元：[https://sccn.ucsd.edu/eeglab/plugins/firfilt2.8.zip](https://sccn.ucsd.edu/eeglab/plugins/firfilt2.8.zip)
%[text]     - 置き場所　　　：`external/eeglab/plugins/firfilt2.8`
%[text] - <u>**ICLabel 1.7**</u>
%[text]     - 使用用途　　　：成分の要因の判定（ステップ3）
%[text]     - サイズ　　　　：約40 MB
%[text]     - ダウンロード元：[https://sccn.ucsd.edu/eeglab/plugins/ICLabel1.7.zip](https://sccn.ucsd.edu/eeglab/plugins/ICLabel1.7.zip)
%[text]     - 置き場所　　　：`external/eeglab/plugins/ICLabel1.7`
%[text] - <u>**dipfit 5.6**</u>
%[text]     - 使用用途　　　：電極の標準の位置と、標準の頭のモデル（ステップ1・5）
%[text]     - サイズ　　　　：約25 MB
%[text]     - ダウンロード元：[https://sccn.ucsd.edu/eeglab/plugins/dipfit5.6.zip](https://sccn.ucsd.edu/eeglab/plugins/dipfit5.6.zip)
%[text]     - 置き場所　　　：`external/eeglab/plugins/dipfit5.6`
%[text] - <u>**FieldTrip-lite**</u>
%[text]     - 使用用途　　　：頭のモデルから、脳の各点の活動が電極にどう届くかを計算する（ステップ5。dipfit が使う）
%[text]     - サイズ　　　　：約85 MB
%[text]     - ダウンロード元：[https://sccn.ucsd.edu/eeglab/plugins/fieldtrip-lite-20250523.zip](https://sccn.ucsd.edu/eeglab/plugins/fieldtrip-lite-20250523.zip)
%[text]     - 置き場所　　　：`external/eeglab/plugins/Fieldtrip-lite250523`
%[text] - <u>**ROIconnect 1.1**</u>
%[text]     - 使用用途　　　：信号源推定で、脳の領域ごとの活動を求める（ステップ5）
%[text]     - サイズ　　　　：約9 MB
%[text]     - ダウンロード元：[https://sccn.ucsd.edu/eeglab/plugins/roiconnect1.1.zip](https://sccn.ucsd.edu/eeglab/plugins/roiconnect1.1.zip)
%[text]     - 置き場所　　　：`external/eeglab/plugins/roiconnect1.1` \
%[text] FieldTrip-lite は大きいので、少し時間がかかります。
  %[control:button:2ed9]{"position":[1,2]}

pluginsDir = fullfile(externalDir, 'eeglab', 'plugins');

% firfilt（フィルタ）
firfiltUrl  = 'https://sccn.ucsd.edu/eeglab/plugins/firfilt2.8.zip';
firfiltPath = fullfile(pluginsDir, 'firfilt2.8');
downloadAndUnzip(firfiltUrl, 'firfilt', firfiltPath, 'pop_eegfiltnew.m');

% ICLabel（成分の要因の判定）
iclabelUrl  = 'https://sccn.ucsd.edu/eeglab/plugins/ICLabel1.7.zip';
iclabelPath = fullfile(pluginsDir, 'ICLabel1.7');
downloadAndUnzip(iclabelUrl, 'ICLabel', iclabelPath, 'pop_iclabel.m');

% dipfit（電極の標準の位置・標準の頭のモデル）
dipfitUrl  = 'https://sccn.ucsd.edu/eeglab/plugins/dipfit5.6.zip';
dipfitPath = fullfile(pluginsDir, 'dipfit5.6');
downloadAndUnzip(dipfitUrl, 'dipfit', dipfitPath, 'pop_dipfit_settings.m');

% FieldTrip-lite（頭のモデルの計算）
fieldtripUrl  = 'https://sccn.ucsd.edu/eeglab/plugins/fieldtrip-lite-20250523.zip';
fieldtripPath = fullfile(pluginsDir, 'Fieldtrip-lite250523');
downloadAndUnzip(fieldtripUrl, 'fieldtrip-20250523', fieldtripPath, 'ft_prepare_leadfield.m');

% ROIconnect（脳の領域ごとの活動）
roiconnectUrl  = 'https://sccn.ucsd.edu/eeglab/plugins/roiconnect1.1.zip';
roiconnectPath = fullfile(pluginsDir, 'roiconnect1.1');
downloadAndUnzip(roiconnectUrl, 'roiCONNECT', roiconnectPath, 'pop_roi_activity.m');
%%
%[text] ## 3. BioSig をダウンロードする
%[text] 脳波のファイル（EDF形式）を読み込むためのプログラムです。EEGLAB のプラグイン配布サイトからダウンロードします。
%[text] BioSig には MATLAB の組み込みの関数と同じ名前のファイルが含まれているので、`plugins` フォルダには置かず、演習で使う部分だけを読み込みます。
%[text] - <u>**BioSig 3.8.5**</u>
%[text]     - 使用用途　　　：脳波のファイル（EDF形式）の読み込み（ステップ1）
%[text]     - サイズ　　　　：約5 MB
%[text]     - ダウンロード元：[https://sccn.ucsd.edu/eeglab/plugins/Biosig3.8.5.zip](https://sccn.ucsd.edu/eeglab/plugins/Biosig3.8.5.zip)
%[text]     - 置き場所　　　：`external/BioSig` \
  %[control:button:86e7]{"position":[1,2]}

biosigUrl       = 'https://sccn.ucsd.edu/eeglab/plugins/Biosig3.8.5.zip';
biosigCheckFile = fullfile('biosig', 't200_FileAccess', 'sopen.m');
biosigPath      = fullfile(externalDir, 'BioSig');
downloadAndUnzip(biosigUrl, 'Biosig3.8.5', biosigPath, biosigCheckFile);
%%
%[text] ## 4. 脳波データをダウンロードする
%[text] PhysioNet で公開されている「EEG Motor Movement/Imagery Dataset」（体を動かしたり、動かすところを想像したりしているときの脳波の記録）を使います。
%[text] - 紹介ページ　　：[https://physionet.org/content/eegmmidb/1.0.0/](https://physionet.org/content/eegmmidb/1.0.0/)
%[text] - ライセンス　　：[Open Data Commons Attribution License v1.0](https://physionet.org/content/eegmmidb/view-license/1.0.0/)（再配布可。出典とライセンスは `DATA_LICENSE.md` に記載）
%[text] - 置き場所　　　：`external/PhysioNet/S001/` など \
%[text] **最初に使う5人分（S001〜S005）**
%[text] - この演習の GitHub Release にまとめた1つのZIP（約41 MB）から取得します。元のPhysioNetデータを変更せず、演習で使う記録だけを収録しています。
%[text] - PhysioNetへファイルごとに何度も接続しないため、短時間で準備できます。すでにあるファイルは上書きしません。 \
%[text] **ほかの参加者も試す場合（任意）**
%[text] - コードの `additionalSubjects` に番号を追加すると、その人だけをPhysioNetから取得します（例：`additionalSubjects = [10 20];`）。
%[text] - S001〜S109から選べます。ただし、記録のしかたがほかと違うS088・S089・S092・S100・S104は使いません（指定しても飛ばします）。
%[text] - 記録　：参加者ごとに14回分の記録が公開されています。この演習では、次の6回分だけを使います。
%[text]     - R03・R07・R11：左右の拳を実際に動かした記録
%[text]     - R04・R08・R12：左右の拳を動かすところを想像した記録
%[text] - 1回の記録につき、ファイルが2つあります。たとえば `S001R03.edf`（脳波そのもの）と `S001R03.edf.event`（「右」「左」などの合図が出た時刻）です。 \
%[text] 1人分は 約15 MB です。追加取得では、1人分が終わるたびに「S010：完了」のように表示されます。
%[text] 途中で止めても、もう一度「このセクションを実行」ボタンを押せば、続きからダウンロードします。
  %[control:button:3256]{"position":[1,2]}

% 記録の番号
runs = [3 4 7 8 11 12];

% S001〜S005は、この演習のGitHub ReleaseにまとめたZIPから取得する
releaseUrl = 'https://github.com/MATLAB-TA/MOOC2026-EEG/releases/download/v1.0';
courseDataUrl = [releaseUrl '/physionet_eegmmidb_s001-s005.zip'];
bundledSubjects = 1:5;
expectedFiles = rawRecordFiles(bundledSubjects, runs);
downloadAndMergeZip(courseDataUrl, 'PhysioNet', rawDataDir, expectedFiles);

% ほかの参加者も試したいときだけ番号を追加する（例：[10 20]）。空なら何もしない
additionalSubjects = [];
if any(additionalSubjects < 1 | additionalSubjects > 109 | fix(additionalSubjects) ~= additionalSubjects)
    error('additionalSubjectsには1〜109の整数を指定してください。');
end

% 追加分のダウンロード元。この後ろに「/S010/S010R03.edf」のようにつなげる
physionetUrl = 'https://physionet.org/files/eegmmidb/1.0.0';
excludedSubjects = [88 89 92 100 104];
if isempty(additionalSubjects)
    subjects = zeros(1, 0);   % forループが一度も実行されない、列数0の配列
else
    subjects = setdiff(additionalSubjects, [bundledSubjects excludedSubjects]);
end

% 追加する参加者ごとにくり返す
for subject = subjects
    % 参加者の名前を作る（例：1 → 'S001'。%03d は「3けたの数字、足りない分は0で埋める」という意味）
    subjectId = sprintf('S%03d', subject);
    subjectDir = fullfile(rawDataDir, subjectId);    % 例：external/PhysioNet/S001

    % 記録ごとにくり返す
    for run = runs
        % 記録の名前を作る（例：'S001R03'。%02d は「2けたの数字」という意味）
        recordName = sprintf('%sR%02d', subjectId, run);

        % 脳波そのもののファイル（例：S001R03.edf）
        eegFileName = [recordName '.edf'];
        eegUrl = [physionetUrl '/' subjectId '/' eegFileName];
        downloadFile(eegUrl, fullfile(subjectDir, eegFileName));

        % 合図の時刻のファイル（例：S001R03.edf.event）
        eventFileName = [recordName '.edf.event'];
        eventUrl = [physionetUrl '/' subjectId '/' eventFileName];
        downloadFile(eventUrl, fullfile(subjectDir, eventFileName));
    end

    fprintf('%s：完了\n', subjectId);
end
%%
%[text] ## 5. 機械学習用のデータをダウンロードする
%[text] 機械学習のパートでは、たくさんの人のデータが必要です。そこで、アプリと同じ処理（ステップ1〜6）を参加者104人全員に行ったデータを、あらかじめ用意しました。
%[text] アプリの「書き出し」で保存したファイル（例：`S001_imagery.set`）と同じ形式の EEGLAB のデータセットが、1人・1課題ごとに1つずつ入っています。`EEG = pop_loadset('S001_imagery.set');` のようにして読み込みます。
%[text] - 作ったところ：この演習の GitHub のページ（MATLAB-TA/MOOC2026-EEG）のリリース v1.0
%[text] - **ダウンロード元：**[https://github.com/MATLAB-TA/MOOC2026-EEG/releases/tag/v1.0](https://github.com/MATLAB-TA/MOOC2026-EEG/releases/tag/v1.0)
%[text] - 置き場所　　　：`external/mooc_dataset` \
%[text] **ダウンロードするもの**
%[text] - <u>**運動イメージ**</u>（左右の拳を動かすところを想像した記録 R04・R08・R12）
%[text]     - ファイル　　　：`mooc_dataset_imagery.zip`（約1.5 GB）
%[text]     - 置き場所　　　：`external/mooc_dataset/imagery`
%[text] - <u>**実動作**</u>（左右の拳を実際に動かした記録 R03・R07・R11）
%[text]     - ファイル　　　：`mooc_dataset_movement.zip`（約1.5 GB）
%[text]     - 置き場所　　　：`external/mooc_dataset/movement` \
%[text] 大きいので、時間がかかります。
  %[control:button:5d71]{"position":[1,2]}

% ダウンロード元の場所（この後ろにファイル名をつなげる）
releaseUrl = 'https://github.com/MATLAB-TA/MOOC2026-EEG/releases/download/v1.0';

% 運動イメージ（最後の参加者のファイル S109_imagery.set があれば「済み」とみなす）
imageryUrl = [releaseUrl '/mooc_dataset_imagery.zip'];
downloadAndUnzip(imageryUrl, 'imagery', fullfile(datasetDir, 'imagery'), 'S109_imagery.set');

% 実動作
movementUrl = [releaseUrl '/mooc_dataset_movement.zip'];
downloadAndUnzip(movementUrl, 'movement', fullfile(datasetDir, 'movement'), 'S109_movement.set');
%%
%[text] ## 6. 確認
%[text] すべてそろったかを確かめます。最後に「**準備ができました**」と表示されたら、準備は終わりです。
%[text] そのあと、コマンド ウィンドウに `launch_app` と入力して Enter キーを押すと、演習のアプリが起動します。
  %[control:button:3ea0]{"position":[1,2]}

% 演習用の関数が入っている src フォルダを、MATLAB が見つけられるようにする
srcDir = fullfile(projectRoot, 'src');
addpath(srcDir);

% EEGLAB を起動して、ダウンロードしたものが使えるかを確かめる
env = setup_eeglab();

% ダウンロードした脳波データの人数を数える（フォルダ S001 などの数）
subjectFolders = dir(fullfile(rawDataDir, 'S*'));
subjectCount = numel(subjectFolders);

% 機械学習用のデータのファイルの数を数える（104人分ずつ あるはず）
imageryCount   = numel(dir(fullfile(datasetDir, 'imagery', '*.set')));
movementCount = numel(dir(fullfile(datasetDir, 'movement', '*.set')));

fprintf('EEGLAB の版：%s\n', env.eeglabVersion);
fprintf('脳波データ：%d 人分\n', subjectCount);
fprintf('機械学習用のデータ：運動イメージ %d 人分、実動作 %d 人分\n', imageryCount, movementCount);
fprintf('準備ができました。launch_app を実行してください。\n');
%[text] 
%[text] 〜ここまでできれば、環境設定は終わりです〜
%%
%[text] ## （参考）このスクリプトで使っている関数
%[text] ダウンロードは、次の2つの関数で行っています。読まなくても演習は進められます。
%[text] - `downloadAndUnzip`：zip ファイルをダウンロードして、展開（解凍）して置く
%[text] - `downloadFile`：ファイルを1つダウンロードして置く \
%[text] どちらも、すでに済んでいれば何もしません。そのため、同じセクションを何回実行しても大丈夫です。
function downloadAndUnzip(url, folderInZip, destination, checkFile)
% url         ：zip ファイルのダウンロード元
% folderInZip ：zip の中に入っているフォルダの名前
% destination ：置き場所
% checkFile   ：置き場所の中にこのファイルがあれば「済み」とみなす

% すでに済んでいれば、何もしないで終わる
if isfile(fullfile(destination, checkFile))
    fprintf('済み：%s\n', destination);
    return;
end

% 置き場所が中途半端に残っていたら（前回途中で止まったとき）、いったん消してやり直す
if isfolder(destination)
    rmdir(destination, 's');
end

% 作業用のフォルダを作る（最後に消す）
workDir = [destination '_download'];
if isfolder(workDir)
    rmdir(workDir, 's');
end
mkdir(workDir);

% zip ファイルをダウンロードする（websave は、インターネット上のファイルを保存する命令）
fprintf('ダウンロード中：%s\n', url);
zipFile = websave(fullfile(workDir, 'download.zip'), url);

% zip ファイルを展開する
unzip(zipFile, workDir);

% 展開してできたフォルダを、置き場所へ移す
movefile(fullfile(workDir, folderInZip), destination);

% 作業用のフォルダを消す
rmdir(workDir, 's');
fprintf('完了：%s\n', destination);
end
%[text] 
function downloadFile(url, target)
% url    ：ファイルのダウンロード元
% target ：保存する場所（ファイル名まで）

% すでにあれば、何もしないで終わる
if isfile(target)
    return;
end

% 保存先のフォルダがなければ作る
targetDir = fileparts(target);    % fileparts で、ファイルの場所からフォルダの部分を取り出す
if ~isfolder(targetDir)
    mkdir(targetDir);
end

% いったん「.part」を付けた名前で保存し、最後まで保存できたら正しい名前に変える
% （途中で止まったファイルを、済んだものと取り違えないため）
partialFile = [target '.part'];
websave(partialFile, url);
movefile(partialFile, target);
end

function files = rawRecordFiles(subjects, runs)
% 参加者と記録の番号から、ZIPに入っているはずの相対パスを作る。
files = strings(0, 1);
for subject = subjects
    subjectId = sprintf('S%03d', subject);
    for run = runs
        recordName = sprintf('%sR%02d.edf', subjectId, run);
        files(end + 1) = fullfile(subjectId, recordName); %#ok<AGROW>
        files(end + 1) = fullfile(subjectId, [recordName '.event']); %#ok<AGROW>
    end
end
end

function downloadAndMergeZip(url, folderInZip, destination, expectedFiles)
% ZIPを展開して、まだないファイルだけをdestinationへコピーする。
% 既存の参加者データは削除・上書きしない。
if all(arrayfun(@(file) isfile(fullfile(destination, file)), expectedFiles))
    fprintf('済み：%s（S001〜S005）\n', destination);
    return;
end

workDir = [destination '_download'];
if isfolder(workDir)
    rmdir(workDir, 's');
end
mkdir(workDir);
cleanup = onCleanup(@() removeFolder(workDir));

fprintf('ダウンロード中：%s\n', url);
zipFile = websave(fullfile(workDir, 'download.zip'), url);
unzip(zipFile, workDir);
source = fullfile(workDir, folderInZip);
if ~isfolder(source)
    error('ZIPの中に %s フォルダがありません：%s', folderInZip, url);
end

entries = dir(fullfile(source, '**', '*'));
entries = entries(~[entries.isdir]);
for k = 1:numel(entries)
    sourceFile = fullfile(entries(k).folder, entries(k).name);
    relativePath = erase(sourceFile, [source filesep]);
    targetFile = fullfile(destination, relativePath);
    targetDir = fileparts(targetFile);
    if ~isfolder(targetDir)
        mkdir(targetDir);
    end
    if ~isfile(targetFile)
        copyfile(sourceFile, targetFile);
    end
end

missing = expectedFiles(~arrayfun(@(file) isfile(fullfile(destination, file)), expectedFiles));
if ~isempty(missing)
    error('ZIPに必要な脳波データがありません：%s', strjoin(missing, ', '));
end
fprintf('完了：%s（S001〜S005）\n', destination);
end

function removeFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[control:button:30b3]
%   data: {"label":"このセクションを実行","run":"Section"}
%---
%[control:button:81b7]
%   data: {"label":"このセクションを実行","run":"Section"}
%---
%[control:button:2ed9]
%   data: {"label":"このセクションを実行","run":"Section"}
%---
%[control:button:86e7]
%   data: {"label":"このセクションを実行","run":"Section"}
%---
%[control:button:3256]
%   data: {"label":"このセクションを実行","run":"Section"}
%---
%[control:button:5d71]
%   data: {"label":"このセクションを実行","run":"Section"}
%---
%[control:button:3ea0]
%   data: {"label":"このセクションを実行","run":"Section"}
%---
