# MOOC2026 脳波解析演習（EEGLAB + MATLAB）

中高生〜大学生向けに、脳波解析の流れ（データ取得 → フィルタ → ICA → エポック化 → 信号源推定 → 機械学習）をGUI操作で体験する教材です。難しい処理は `src/` の関数にまとめ、受講生はGUIからそれらを呼び出します。

- データ：PhysioNet [EEG Motor Movement/Imagery Dataset v1.0.0](https://physionet.org/content/eegmmidb/1.0.0/)（64ch・160 Hz・109名）
- 本編の課題：**左右の拳の運動イメージ**（R04/R08/R12）。比較用に**実動作**（R03/R07/R11）
- 実行環境：MATLAB Online で完結（デスクトップ版も可）

## 演習の構成

| 層 | データ | 内容 |
|---|---|---|
| A. 体験パート | 1名分（その場でPhysioNetから取得） | 前処理と可視化をGUIで1ステップずつ操作 |
| B. 機械学習パート | 多人数分（TAが事前計算して配布） | Deep Learning Toolboxで左右を分類し、条件を変えて比較 |

## 実装状況

| 段階 | 内容 | 状態 |
|---|---|---|
| 1 | 基盤関数（取得・前処理・CAR・ICA・エポック・ERD・特徴量） | ✅ |
| 2 | 配布データの一括作成ツール | ✅（アプリの書き出しと同じ EEGLAB のデータセット（.set）。全員分の作成とリリースへの添付は未実施） |
| 3 | GUI：体験パート（タブ0〜4） | ✅（標準のUI部品のみで構成） |
| 4 | 機械学習（別のアプリ。書き出したデータ・配布データを使用） | 未着手 |
| 5 | MATLAB Onlineでの通し確認と配布方法 | 未着手 |
| 6 | 信号源推定（GUIのステップ5） | ✅（標準の頭のモデル＋eLORETA、68領域） |

## ディレクトリ構成

```text
MOOC2026eeglab/
├── setup.m                  # ★最初に1回：必要なプログラムと脳波データをダウンロード（Live Script）
├── launch_app.m             # ★GUIを起動
├── src/                     # GUIなどから呼ばれる関数（受講生は直接使わない）
│   ├── mooc_default_config.m   # すべての既定値とフォルダの場所
│   ├── setup_eeglab.m       # パス設定とEEGLAB起動（最初に呼ぶ）
│   ├── build_course_dataset.m  # 機械学習用のデータ（external/mooc_dataset）の一括作成（TA用）
│   ├── io/                  # データの読込・書き出し（合図の読み込み、pop_saveset）
│   ├── analysis/            # ERD（pop_newtimef）と、脳の領域ごとの活動（pop_roi_activity と同じ計算）
│   ├── plot/                # 描画
│   └── app/                 # GUI（下の「GUIのコードの読み方」を参照）
├── outputs/                 # 受講生の書き出し先（演習フォルダ内で選べるのはここだけ）
├── external/                # 外部から取得したもの（setup.m がダウンロード。GitHubでは空）
│   ├── eeglab/              # EEGLAB（plugins/ に firfilt・ICLabel・dipfit・FieldTrip-lite・ROIconnect）
│   ├── BioSig/
│   ├── PhysioNet/S###/      # PhysioNetのEDFファイル（生データ。setup.m で指定した参加者だけ）
│   └── mooc_dataset/<課題>/S###_<課題>.set   # 機械学習用のデータ（105人分。この演習のGitHubリリースから）
└── develop/                 # 開発用（配布物には含めない）
    ├── tests/               # 自動テスト
    ├── screenshots/         # テストが保存する画面の画像
    ├── make_ml_illustrations.m  # machine_learning.m の説明のイラストを作り、埋め込む（TA用）
    ├── ml_illustrations/    # そのイラスト（PNG）
    └── legacy/              # 以前の試作と、整理で外した関数・スクリプト
```

## 準備（setup.m）

`setup.m` は、セクションごとに説明を読みながら実行する Live Script です（MATLAB R2025a 以降の、テキスト形式の Live Script）。上から順に「セクションを実行」を押すと、次のものを演習フォルダの中にダウンロードします。演習フォルダの外は変更しません。

| セクション | 取得するもの | 取得先 | 大きさ | 置き場所 |
|---|---|---|---|---|
| 1 | EEGLAB 2026.0.0 | GitHub（sccn/eeglab のタグ） | 約30 MB | `external/eeglab` |
| 2 | EEGLAB のプラグイン：firfilt 2.8・ICLabel 1.7・dipfit 5.6・FieldTrip-lite（250523）・ROIconnect 1.1 | EEGLABのプラグイン配布サイト | 約160 MB | `external/eeglab/plugins/<名前と版>`（例：`dipfit5.6`。版の番号を付けると、EEGLAB が「新しい版があります」と表示しない） |
| 3 | BioSig 3.8.5（MATLAB の組み込み関数と同じ名前のファイルを含むため plugins の外に置き、使う部分だけパスに加える） | EEGLABのプラグイン配布サイト | 約5 MB | `external/BioSig` |
| 4 | 脳波データ：`subjects` で指定した参加者（既定は S001〜S005）× 左右の拳の記録6回（R03・R04・R07・R08・R11・R12） | PhysioNet | 1人 約15 MB | `external/PhysioNet/S###/` |
| 5 | 機械学習用のデータ：105人 × 2課題（アプリの書き出しと同じ形式の .set） | この演習の GitHub リリース | 約3 GB | `external/mooc_dataset/<課題>/` |
| 6 | 確認 | — | — | — |

- 同じセクションを2回実行しても壊れません（済んでいるものは飛ばし、途中で止まったものはやり直します。脳波データは続きから取得します）。
- ダウンロードを行うのは `setup.m` だけです。アプリと `src/` の関数はインターネットに接続しません。ただし EEGLAB は起動時にプラグインの新しい版があるかを確認します（EEGLAB の標準の動作）。
- 外部から取得したもの（プログラム・生データ・機械学習用のデータ）はすべて `external/` に置きます。GitHub では `external/` を空の状態で公開します（`.gitignore`）。
- アプリで解析するのは1人ずつなので、生データは必要な参加者だけをダウンロードします。アプリの参加者の選択肢には、ダウンロード済みの参加者だけが出ます。
- 機械学習用のデータは全員分の作成に時間がかかるため、TAが事前に `src/build_course_dataset.m` で作成し、GitHub のリリースに zip で添付します（リポジトリには入れません。Git の履歴が大きくなるのを避けるため）。
- バージョンは固定しています。上の版で動作を確認済みです（MATLAB R2026b）。

## 使い方

```matlab
setup                                    % 最初に1回（Live Scriptとして開き、セクションごとに実行するのがおすすめ）
launch_app                               % GUIを起動
```

関数を直接使う場合は、先に `addpath src; setup_eeglab` でパスを設定します。

### GUIの構成

| タブ | 内容 | ファイル |
|---|---|---|
| 0. はじめに | データの内容（仕様・電極配置・参加者の画面）、6ステップの流れ（絵付き）、環境の確認（MATLAB・Signal Processing Toolbox・EEGLAB・BioSig・ICLabel・ROIconnect） | `src/app/steps/step_intro.m` |
| 1. データを理解 | ① 記録を選ぶ：左右の拳の記録6回分の一覧から、つなげる記録をチェックして読込、つなげた結果の時間軸表示（チェックを変えるたびに更新。保存済みの記録は合図の位置まで表示）。② 脳波を見る：波形と電極配置、実験の再生 | `src/app/steps/step_data.m` |
| 2. ノイズを除去 | ノッチ・バンドパス・間引き・CAR（間引きとCARは初期状態でオフ）。PSDと波形の前後比較（電極の位置図つき）、60 Hzノイズの減少量 | `src/app/steps/step_filter.m` |
| 3. 独立成分分析（ICA） | ①〜④の段階ボタン（セーブポイントつき。ICAは毎回計算し、計算済み結果の読み込みは使わない）。説明画面にステップ全体の図（混ざった波形 → ICA → ICLabel → 組み立て直し）。①の後に成分一覧（クリックで波形・周波数）、②の後に7種類の要因（図に重ねると該当する要因が色付き、クリックした成分の確率を円グラフで表示）、③で×印（手動で変更可）、除去前後の比較 | `src/app/steps/step_ica.m` |
| 4. 左右の拳で脳の変化を比較 | ① エポックに分ける（左拳・右拳の合図ごとに切り出し、C3などの波形を表示）。② 周波数帯（δ・θ・α/μ・β・γ のプリセット、または Hz を自分で入力）のパワーのC3/C4での時間変化と頭皮マップ。マップは合図の前後を実時間で再生（既定1/4倍速）し、参加者の画面も同じ時刻に合わせて表示（`mooc_ui_erd_view`） | `src/app/steps/step_erd.m` |
| 5. 信号源推定 | ステップ4のエポックから、標準の頭のモデル（Colin27）とeLORETAで脳の約5000点の活動を推定し、68領域（Desikan-Killiany）にまとめる。左拳・右拳の領域ごとのERDを脳の図（上から見た図）で表示し、左右の運動野・感覚野の時間変化を比較。画面の構成と再生はステップ4と同じ（`mooc_ui_erd_view`） | `src/app/steps/step_source.m` |
| 6. データを書き出す | 処理済みデータを EEGLAB のデータセット（.set）として `pop_saveset` で保存（保存先はダイアログで選択し、その中に `S###_<課題>.set`）。`EEG.data`（電極 × 時間 × 試行）・`EEG.roi.source_roi_data`（ステップ5を行った場合）・`EEG.etc.mooc.labels`（試行ごとの合図）・`EEG.history`（処理のコード）など。保存後に `pop_loadset` で読み直し、中身の大きさと1試行目を表で表示。演習のプログラムのフォルダ・MATLABのパス上のフォルダは選べない | `src/app/steps/step_export.m` |

ウィンドウの最上部には、どのタブでも「解析中のデータ」の帯（`src/app/ui/mooc_ui_pipeline_bar.m`）が表示されます。

- 内容：データ → ノイズ除去 → ICA → 左右比較 の各段階を、済／未と主な設定つきで示します。
- 役割：すべてのタブが、ステップ1で選んだ同じデータを順に処理していることを示します。

どのタブも同じ画面構成です（`src/app/ui/mooc_ui_page_layout.m`）。

- 左側：「このステップでやること」（説明画面を開き直すボタンつき）「操作」「このデータに行った処理」「次のステップへ」
- 右側：グラフ（数値はグラフ上に直接書き込む）
- 説明画面：タブを初めて開いたときに、このステップで行うことを絵と箇条書きで重ねて表示します。
- 進捗ダイアログ：処理の実行中は、実行中の工程名と「詳しい進み具合はコマンドウィンドウに表示される」旨を表示します（`mooc_ui_run_steps`）。

ボタンは役割ごとに色分けします（`src/app/ui/mooc_ui_style_buttons.m`。ボタンの `Tag` で役割を指定）。

| 色 | 役割 |
|---|---|
| 青（白い文字） | 次に押すボタン（そのタブでまだ済んでいない最初の段階。全部済んだら「次のステップへ」） |
| 薄い緑 | 済んだ段階のボタン（押せばやり直せる） |
| 薄い青 | まだ済んでいないが押せる段階のボタン |
| 白 | ワークフローと関係のない補助のボタン（「説明をもう一度見る」など） |
| 灰色 | 前の段階が済んでいないため押せないボタン |

#### 処理の履歴とセーブポイント

データに行った処理は、1本の履歴（`MoocHistory`）として全タブで共有され、処理が増えるたびに積み上がります。

- 各工程の下に、その工程で実行したコマンド（`>> EEG = pop_eegfiltnew(...)`）を表示します。
- 開いているタブのステップは工程の詳細まで、ほかのステップは1行の要約で表示します。「右側に全体を表示」で、グラフの場所に全ステップを表示します。
- 行をクリックすると、その工程で使った関数のファイル（例：`pop_eegfiltnew.m`）をMATLABのエディタで開きます。
- 書き出しのときに、全工程のコードを1本のスクリプト（`processing_script.m`）として保存します。

各段階の結果はセーブポイントとして `MoocAppState` に保存されます。

| 段階 | 内容 |
|---|---|
| raw | 読込・結合 |
| filtered | フィルタ |
| decomposition | ICA①（ICA。成分の数は pop_runica がデータの次元に合わせて決める） |
| iclabel | ICA②（ICLabel） |
| selection | ICA③（除去する成分） |
| clean | ICA④（組み立て直し） |
| epoch | エポック |
| erd | ERD |
| source | 信号源推定（頭のモデル・eLORETA・68領域の活動） |
| regionErd | 領域ごとのERD |

ある段階をやり直すと、その段階より後ろの結果と履歴だけが消えます。例えばICAの「④ 除去する成分」を変えても、①〜③（数分かかるICAを含む）はやり直しません。

#### GUIのコードの読み方

```text
src/app/
├── mooc_app.m            # ウィンドウとタブを作り、各ステップを組み立てる（入口）
├── MoocAppState.m        # 解析中のデータと、各段階の結果（セーブポイント）
├── MoocHistory.m         # このデータに行った処理の履歴（全タブで共有）
├── steps/                # 1タブ = 1ファイル
│   └── step_*.m          # 「Layout → Callbacks → Drawing → Local functions」の順に記述
└── ui/                   # 全タブ共通の部品
    ├── mooc_ui_page_layout.m   # タブの画面構成と説明画面
    ├── mooc_ui_pipeline_bar.m  # 「解析中のデータ」の帯
    ├── mooc_ui_step_names.m    # タブ名と履歴の見出し（ここを変えると全体に反映）
    ├── MoocProcessLog.m        # 履歴の表示（工程とコマンド。クリックで関数を開く）
    ├── mooc_ui_run_steps.m     # 工程を順に実行し、履歴に追加する
    ├── mooc_ui_step.m          # 工程1つ分の定義（段階・説明・関数名・処理・コード）
    ├── mooc_ui_cue_display.m   # 参加者が見ていた画面
    ├── mooc_ui_wave_player.m   # 波形と実験の再生（ステップ1〜3）
    ├── mooc_ui_erd_view.m      # 強さの変化のグラフと分布の図の再生（ステップ4・5）
    ├── mooc_ui_band_picker.m   # 周波数帯を選ぶ欄
    ├── mooc_ui_style_buttons.m # ボタンの役割ごとの色
    └── mooc_ui_placeholder.m   # 「〜を押すと表示されます」の表示
```

ステップのファイルでは、ボタンを押したときの処理を `mooc_ui_step` の配列として書いています。1工程ごとに「どの段階か」「何をするか（日本語）」「使う関数」「実際の処理」「対応するコード」が並ぶので、上から読めば処理の流れが分かります。解析は EEGLAB の pop_ 関数と、`src/io`・`src/analysis` の関数で行い、GUIのファイルはそれらを呼び出して結果を表示するだけです。

### 1名分の前処理（関数を直接使う例）

アプリの「このデータに行った処理」と、書き出した `processing_script.m` に、同じ処理のコードが並びます。主な部分は次のとおりです（EEGLABの関数を直接使います）。

```matlab
cfg = mooc_default_config();
EEG = mooc_import_run(1, 4, cfg);                              % S001R04（運動イメージ）
EEG = pop_chanedit(EEG, 'lookup', cfg.paths.channelLocationFile);
EEG = pop_eegfiltnew(EEG, 59, 61, [], 1);                      % 60 Hzの電源ノイズ
EEG = pop_eegfiltnew(EEG, 0.5, 45);                            % 0.5〜45 Hzを残す
EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, 'rndreset', 'off');
EEG = pop_iclabel(EEG, 'default');
[~, best] = max(EEG.etc.ic_classification.ICLabel.classifications, [], 2);
EEG = pop_subcomp(EEG, find(~ismember(best, [1 7])), 0);       % 脳・その他以外を除く
EEG = pop_epoch(EEG, {'T1', 'T2'}, cfg.epoch.windowSec, 'epochinfo', 'yes');   % -1〜4 s
isLeft = ~isnan(eeg_getepochevent(EEG, 'type', 'T1', 'timewin', [0 0]));         % 合図の時刻に T1 = 左拳
labels = categorical(isLeft(:), [true false], {'left_fist', 'right_fist'});
erd = mooc_compute_erd(EEG, labels, [8 13], cfg.epoch.baselineSec, cfg);         % μ波のERD（pop_newtimef）
```

### 配布データの作成（TA）

```matlab
addpath src
build_course_dataset            % 除外者以外の全員（105名）
build_course_dataset(1:10)      % 指定した被験者
```

アプリのステップ1〜6と同じ処理を全員に行い（pop_ 関数が返すコマンドを `eeg_hist` で `EEG.history` に積むので、処理のコードはアプリの書き出しと同じ形になる）、アプリの書き出しと同じ関数（`mooc_save_epochs`、中身は `pop_saveset`）で `external/mooc_dataset/<課題>/S###_<課題>.set` に保存します。脳波データは全員分が必要です（`setup.m` のセクション4で `subjects = 1:109;`）。ICAの結果（`external/mooc_dataset/ica/`）は作り直すときに再利用します。リリース用の zip の作り方は `build_course_dataset.m` の先頭の説明にあります。1名あたり約3分（Apple Silicon）です。Parallel Computing Toolbox は使わないので、急ぐときは MATLAB を複数起動し、被験者を分けて実行します（2026年10月の全員分は4つに分けて実行）。1名につきICAを1回（運動イメージと実動作の6ランをまとめて）計算するので、両課題は同じ成分除去で比較できます。書き出し済みの被験者は飛ばすため、途中で止めても再実行すれば続きから処理します。

出力は1名・1課題あたり約14 MB（電極 64 と 領域 68 × 640点 × 45試行、single）、全員分で約3 GB です。信号源推定のリードフィールド（約8 MB）は保存しません。

### 機械学習用のデータ（`external/mooc_dataset`）の中身

`imagery/S###_imagery.set`（運動イメージ）と `movement/S###_movement.set`（実動作）が105人分あります。アプリの書き出しと同じ形式の EEGLAB のデータセットで、`EEG = pop_loadset('S001_imagery.set');` で読み込みます。

| 中身 | 大きさ | 内容 |
|---|---|---|
| `EEG.data` | 電極 × 時間 × 試行 | 脳波（µV）。64 電極 × 640 点（−1〜4 秒）× 45 試行 |
| `EEG.roi.source_roi_data` | 領域 × 時間 × 試行 | 信号源推定で求めた、脳の68領域の活動。ROIconnect の `pop_roi_activity`（nPCA 1）と同じく、各領域の第1主成分を長さ1にそろえたもの（符号と、領域どうしの大きさの比には意味がない） |
| `EEG.roi.atlas.Scouts` | 1 × 領域 | 領域の名前（`Label`、例：`precentral L`） |
| `EEG.etc.mooc.labels` / `EEG.etc.mooc.runs` | 試行 × 1 | 試行ごとの合図（`"left_fist"` 左拳／`"right_fist"` 右拳）と記録の番号 |
| `EEG.times` / `EEG.srate` | — | 合図からの時間（ミリ秒）／1秒あたりのサンプル数（128） |
| `EEG.chanlocs` | 1 × 電極 | 電極の名前と位置 |
| `EEG.etc.mooc.info` | 表 | データの作り方（参加者・フィルタ・除去した成分など） |
| `EEG.history` | 文字 | このデータに行った処理のコード |

アプリとの違いは、ICA を運動イメージと実動作の6回分の記録をまとめて1回だけ計算している点だけです。

## 既定の解析設定（`src/mooc_default_config.m`）

| 項目 | 既定値 | 理由 |
|---|---|---|
| ノッチ | **60 Hz** | 米国で記録されたデータのため（PSDで60 Hzにピークを確認） |
| バンドパス | 0.5〜45 Hz | 運動に関係するμ波（8〜13 Hz）とβ波（13〜30 Hz）を含む範囲を残す（上限は60 Hzの電源ノイズから離す） |
| リサンプリング | 128 Hz | 160 Hzからダウンサンプリング |
| 再参照 | 共通平均参照（CAR） | ランクが1下がるため、ICAはPCAで次元を自動調整 |
| ICの選択 | `brain_other` | ICLabelの最大クラスがBrainかOtherの成分を残す（Live Script教材と同じ） |
| エポック | −1〜4 s | −1〜0 sは休息（ERDのベースライン）、0〜4 sは課題（機械学習に使用） |
| 除外被験者 | S088, S092, S100, S104 | サンプリング周波数・試行タイミングがほかと異なる |

ICの選択方針は `brain_only`（P(Brain)が閾値以上だけを残す）と `artifact_threshold`（いずれかのノイズクラスが閾値以上なら除去）にも切り替えられます。

## 主な関数

| 関数 | 役割 |
|---|---|
| `mooc_find_edf` | EDFファイルの場所を探す（`external/PhysioNet`） |
| `mooc_import_run` | 1ランの読込（`pop_biosig`）と、合図（T0/T1/T2）の意味付け |
| `mooc_read_wfdb_events` | 合図の時刻を `.edf.event` から読む（BioSigでEDFから読むと1点ずれ、最初の合図が欠けるため） |
| `mooc_cue_events` | 合図（休憩・左拳・右拳）の時刻と長さの一覧（再生と、合図の図に使う） |
| `mooc_compute_erd` | 帯域パワーの時間変化（ERD）。左右・電極（または領域）ごとに `pop_newtimef` を行い、休憩中に比べた変化（%）にする |
| `mooc_roi_activity` | 68領域の活動。ROIconnect の `pop_roi_activity`（eLORETA・nPCA 1）と同じ計算を、メモリを節約するため領域ごとに行う（結果は一致することをテストで確認。`pop_roi_activity` は全点の周波数も計算するため、このデータで約8 GB を使い、MATLAB Online で保証される 4 GB を超える） |
| `mooc_save_epochs` | 書き出し（`pop_saveset`。処理のコードを `EEG.history`、試行の表と作り方を `EEG.etc.mooc` に入れる。機械学習用のデータも同じ形式。演習フォルダの場所は "." に置き換え、個人のフォルダ名が残らないようにする） |
| `mooc_topoplot` | EEGLABの `topoplot` をアプリの中に描く |
| `mooc_style` | 名前と色の決まり（合図・ICLabelの7種類・周波数帯の呼び名・青〜白〜赤の色）。すべての図で同じ色を使うために1か所にまとめている |

解析は EEGLAB とプラグインの関数をそのまま使っています：フィルタ・間引き・再参照（`pop_eegfiltnew`・`pop_resample`・`pop_reref`）、ICA（`pop_runica`・`pop_iclabel`・`pop_icflag`・`pop_subcomp`）、切り出し（`pop_epoch`・`pop_select`）、時間周波数解析（`pop_newtimef`）、信号源推定の頭のモデル（`pop_dipfit_settings`・`pop_leadfield`）。

## テスト

```matlab
run("develop/tests/test_analysis_functions.m")   % ERD（合成データ）
run("develop/tests/test_source_estimation.m")   % 信号源推定（既知の位置に置いた信号源が正しい領域で見つかるか）
run("develop/tests/test_app_workflow.m")         % GUIを全タブ自動操作し、各タブの画像を develop/screenshots/ に保存
```

## 配布データの再現（オプション課題）

配布データは `src/build_course_dataset.m` だけで作られています。受講生も同じ手順で作り直せます。

```matlab
addpath src
build_course_dataset(1)        % まず1名分（約3分）
build_course_dataset(1:10)     % 10名分（約30分）
```

- 必要なもの：MATLAB と Signal Processing Toolbox、`setup.m` のセクション1〜4（脳波データは全員分）
- Windows・macOS・Linux・MATLAB Onlineのいずれでも同じコードで動きます。OSに依存する処理はありません。
- ICAは乱数の状態を固定しているため、同じ環境で作り直せば同じ結果になります。ただし、OSやCPUが違うと数値計算ライブラリの丸め誤差の違いで、成分の順番や符号がわずかに変わることがあります。除去される成分の種類や機械学習の精度は、ほぼ同じになります。

## 環境についての注意

- ICLabel は `pop_iclabel` をそのまま使います。高速化のための MEX（コンパイル済みプログラム）は Windows・Linux（MATLAB Online）・Intel Mac 用が同梱されています。Apple Silicon Mac では、最初に MEX のコンパイルを試みて「MEX-file compilation failed」と表示したあと、MATLAB 版の計算に切り替わります（結果は同じ。1名あたり約45秒）。
- 開発・動作確認は MATLAB R2026b（Signal Processing Toolbox・Deep Learning Toolbox あり）で行っています。Signal Processing Toolbox の使用は許可済みです。
- **Signal Processing Toolbox が必要です。** 周波数ごとの強さは `pwelch`、ERDの時間変化は `stft` で計算しています（自作の計算を減らすため）。間引き（`pop_resample`）も、その `resample` を使います。

## 参考資料・ライセンス

- [EEGLAB](https://eeglab.org/) / [ICLabel](https://github.com/sccn/ICLabel) / [BioSig](https://biosig.sourceforge.net/) / [ROIconnect](https://github.com/sccn/roiconnect)（eLORETA `mkfilt_eloreta_v2` と領域の主成分 `roi_getact`） / [FieldTrip](https://www.fieldtriptoolbox.org/)（`pop_leadfield` が使う）
- eLORETA: Pascual-Marqui, R. D. (2007). Discrete, 3D distributed, linear imaging methods of electric neuronal activity. arXiv:0710.3341
- [PhysioNet EEGMMIDB v1.0.0](https://physionet.org/content/eegmmidb/1.0.0/)（DOI: [10.13026/C28G6P](https://doi.org/10.13026/C28G6P)）

データセット・EEGLAB・各プラグインの利用時は、それぞれのライセンスと引用要件に従ってください。
