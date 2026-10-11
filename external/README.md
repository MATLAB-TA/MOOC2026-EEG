# external

外部から取得したものが入るフォルダです。

- プログラム：EEGLAB（`eeglab`。プラグインの firfilt・ICLabel・dipfit・FieldTrip-lite・ROIconnect は `eeglab/plugins` の中）・BioSig（`BioSig`）
- 脳波の生データ：PhysioNet「EEG Motor Movement/Imagery Dataset」（`PhysioNet`）
- 機械学習用のデータ：生データにアプリと同じ処理を行った EEGLAB のデータセット（`mooc_dataset`。この演習の GitHub リリースから）

GitHub では空の状態で公開しています。演習フォルダの `setup.m` を上から順に実行すると、ここにダウンロードされます。
