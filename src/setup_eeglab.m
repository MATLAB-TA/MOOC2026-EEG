function env = setup_eeglab()
%SETUP_EEGLAB 演習のプログラムと EEGLAB を使えるようにする
%
%   src フォルダと EEGLAB を MATLAB のパスに加え、EEGLAB を画面なしで起動する。
%   アプリや build_course_dataset が最初に呼ぶ。

sourceDir = fileparts(mfilename('fullpath'));
addpath(genpath(sourceDir));
paths = mooc_default_config().paths;

if ~isfile(fullfile(paths.eeglabRoot, 'eeglab.m'))
    error('mooc2026:EEGLABNotFound', ...
        ['EEGLABが見つかりません: %s\n' ...
         '演習フォルダの setup.m を上から順に実行してください。'], paths.eeglabRoot);
end

if ~isfolder(paths.outputDir)
    mkdir(paths.outputDir);
end

% EEGLAB is started when this exercise's EEGLAB and its plugins are not
% all on the path yet. Checking pop_runica alone is not enough: the path may
% hold another EEGLAB, or folders of an earlier start (e.g. a saved path),
% without the plugins.
if ~localIsReady(paths.eeglabRoot)
    addpath(paths.eeglabRoot);
    [~, ~, ~, ~] = eeglab('nogui');
end
if ~localIsReady(paths.eeglabRoot)
    error('mooc2026:EEGLABNotReady', ...
        ['EEGLAB のプラグイン（firfilt・ICLabel・dipfit）が使えません。\n' ...
         'setup.m のセクション2を実行してから、MATLAB を再起動してください。\n' ...
         '（使われている EEGLAB：%s）'], which('eeglab'));
end

% Without its window ('nogui'), EEGLAB does not run the plugins' setup
% functions. ROIconnect adds its libraries (e.g. the eLORETA code) there,
% so its setup is run here; the part that builds its menu needs EEGLAB's
% window and is skipped.
if ~isempty(which('eegplugin_roiconnect')) && isempty(which('mkfilt_eloreta_v2'))
    try
        eegplugin_roiconnect([], {}, {});
    catch
        % the menu part: no EEGLAB window
    end
end

% Adding all of BioSig with genpath shadows MATLAB built-ins. Only the EDF
% reader and the resampling helper it calls are needed.
if isfolder(paths.biosigRoot)
    biosigFileAccess = fullfile(paths.biosigRoot, 'biosig', 't200_FileAccess');
    biosigPreprocessing = fullfile(paths.biosigRoot, 'biosig', ...
        't250_ArtifactPreProcessingQualityControl');
    if ~isfolder(biosigFileAccess) || ...
            ~isfile(fullfile(biosigPreprocessing, 'rs.m'))
        error('mooc2026:InvalidBiosigLayout', ...
            'BioSigの構成が想定と異なります: %s', paths.biosigRoot);
    end
    addpath(biosigFileAccess, biosigPreprocessing);
end

env = paths;
env.eeglabVersion = eeg_getversion();
env.matlabVersion = version();
env.hasDeepLearningToolbox = ~isempty(ver('nnet'));
end

function ready = localIsReady(eeglabRoot)
% This exercise's EEGLAB is the one used, with the plugins of steps 2-5.
ready = startsWith(which('eeglab'), eeglabRoot) && ...
    startsWith(which('pop_runica'), eeglabRoot) && ...
    ~isempty(which('pop_eegfiltnew')) && ~isempty(which('pop_iclabel')) && ...
    ~isempty(which('pop_dipfit_settings')) && ~isempty(which('pop_leadfield'));
end
