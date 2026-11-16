# 脳波データの出典とライセンス

`physionet_eegmmidb_s001-s005.zip` と `external/mooc_dataset/` のデータは、次のデータセットを元にしています。

- Gerwin Schalk, *EEG Motor Movement/Imagery Dataset*, version 1.0.0, PhysioNet (2009)
- https://physionet.org/content/eegmmidb/1.0.0/
- DOI: https://doi.org/10.13026/C28G6P
- License: Open Data Commons Attribution License v1.0 (ODC-By-1.0)
- License text: https://opendatacommons.org/licenses/by/1-0/

`physionet_eegmmidb_s001-s005.zip` は、元データを変更せず、演習で使うS001〜S005の記録R03・R04・R07・R08・R11・R12と対応するイベントファイルだけを収録した部分集合です。このZIP内のデータもODC-By-1.0で提供します。

`external/mooc_dataset/` は、上記データをこの演習の処理手順で加工した派生データです。この派生データもODC-By-1.0で提供します。

使用時は、PhysioNetのデータセットページに示された次の文献も引用してください。

- Schalk, G., McFarland, D. J., Hinterberger, T., Birbaumer, N., & Wolpaw, J. R. (2004). BCI2000: A General-Purpose Brain-Computer Interface (BCI) System. *IEEE Transactions on Biomedical Engineering*, 51(6), 1034–1043.
- Goldberger, A. L., et al. (2000). PhysioBank, PhysioToolkit, and PhysioNet: Components of a new research resource for complex physiologic signals. *Circulation*, 101(23), e215–e220.
