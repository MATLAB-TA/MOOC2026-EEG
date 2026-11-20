# 信号源推定（開発者向けのバックアップ）

受講生向けの演習から、信号源推定（旧ステップ5「信号源推定」）を外しました。このフォルダには、外す前のコードをそのまま残しています。受講生は使いません。

- 外す前のコミット：`09b334a`（`git show 09b334a:src/app/steps/step_source.m` などでも取り出せます）
- このフォルダは MATLAB のパスに入りません（`setup_eeglab` が加えるのは `src/` だけです）。同じ名前の関数が `src/` にもあるので、パスに加えないでください。

## 中身

フォルダの構成は、演習フォルダと同じです。

| ファイル | 内容 |
|---|---|
| `src/app/steps/step_source.m` | アプリの旧ステップ5のタブ（eLORETA で68領域の活動を求め、領域ごとの ERD を脳の図で見る） |
| `src/analysis/mooc_roi_activity.m` | 68領域の活動の計算（ROIconnect の `pop_roi_activity` と同じ計算） |
| `src/plot/mooc_plot_brain.m` | 脳を上から見た図 |
| `docs/images/app_source.gif` | README に載せていた、旧ステップ5の動画 |
| `develop_files/tests/test_source_estimation.m` | 信号源推定のテスト |
| それ以外の `.m`・`README_project.md` | 信号源推定を外す前の版（タブ・状態・書き出し・データ作成・setup・機械学習の選択肢「脳の68領域」など） |

`README_project.md` は、外す前の演習の `README.md` です。

## 機械学習用のデータ

リリース v1.0 の機械学習用のデータには、信号源推定の結果（`EEG.roi`・`EEG.dipfit`）が入っていました。`src/remove_source_from_dataset.m` は、それを除いて別のフォルダに保存し直します（脳波 `EEG.data` などは元のまま）。信号源推定を戻すときは、v1.0 のデータを使うか、外す前の `build_course_dataset.m` で作り直してください。

## 戻すとき

このフォルダのファイルを、同じ場所（演習フォルダからの相対パス）に上書きすると、外す前の状態に戻ります。外した後に `src/` を変更していれば、その変更は消えるので、差分を見てから戻してください。

```bash
git diff --no-index archive/source_estimation/src src
```

信号源推定には、EEGLAB のプラグイン FieldTrip-lite と ROIconnect が必要です（外す前の `setup.m` のセクション2がダウンロードします）。
