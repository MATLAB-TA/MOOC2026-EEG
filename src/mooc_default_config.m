function cfg = mooc_default_config()
%MOOC_DEFAULT_CONFIG 解析の既定の設定と、フォルダの場所
%
%   フィルタの範囲、切り出す時間などをここで決めている。設定を変える
%   ときは、このファイルを変えると、アプリ全体に反映される。

cfg = struct();
cfg.paths = localPaths();

% ---- Dataset (PhysioNet EEG Motor Movement/Imagery Dataset) -------------
cfg.data.expectedChannels = 64;
% Recordings that differ in sampling rate or trial timing from the rest.
cfg.data.excludedSubjects = [88 92 100 104];
% Left/right fist runs (T1 = left fist, T2 = right fist).
cfg.data.conditions = struct( ...
    'name', {'imagery', 'movement'}, ...
    'displayName', {'運動イメージ（左右の拳）', '実動作（左右の拳）'}, ...
    'runs', {[4 8 12], [3 7 11]});
% The 14 recordings of every participant: the task, and what the cues T1
% and T2 mean (T0 is always rest; '' = no cue).
tasks = {'左右の拳の実動作', '左右の拳の運動イメージ', '両拳・両足の実動作', '両拳・両足の運動イメージ'};
t1 = {'left_fist', 'left_fist', 'both_fists', 'both_fists'};
t2 = {'right_fist', 'right_fist', 'both_feet', 'both_feet'};
cycle = mod((3:14) - 3, 4) + 1;          % runs 3-14 repeat the 4 tasks
cfg.data.runInfo = struct( ...
    'task', [{'安静（開眼）', '安静（閉眼）'}, tasks(cycle)], ...
    't1', [{'', ''}, t1(cycle)], ...
    't2', [{'', ''}, t2(cycle)]);

% ---- Filters --------------------------------------------------------------
% EEGMMIDB was recorded in the USA, so the power-line noise is at 60 Hz.
cfg.notch.enabled = true;
cfg.notch.frequencyHz = 60;
cfg.notch.halfWidthHz = 1;

% Keep delta to low gamma, including mu (8-13 Hz) and beta (13-30 Hz),
% which carry the motor signal; 45 Hz stays clear of the 60 Hz line noise.
cfg.bandpass.enabled = true;
cfg.bandpass.lowHz = 0.5;
cfg.bandpass.highHz = 45;

cfg.resample.enabled = true;
cfg.resample.targetHz = 128;

% ---- Re-reference ---------------------------------------------------------
cfg.reref.enabled = true;   % common average reference (CAR)

% ---- ICA / ICLabel --------------------------------------------------------
cfg.ica.enabled = true;
cfg.ica.extended = true;
cfg.ica.iclabelVersion = 'default';
% runica shuffles the data randomly and, despite its help text, reseeds from
% the clock by default. true = fixed random state, so reruns are repeatable.
cfg.ica.fixedRandomState = true;
% 'brain_other'       : keep ICs whose most likely class is Brain or Other
% 'not_brain'         : keep ICs whose most likely class is Brain
% 'brain_only'        : keep ICs with P(Brain) >= threshold
% 'artifact_threshold': remove ICs with P(any artifact class) >= threshold
cfg.ica.selectionPolicy = 'brain_other';
cfg.ica.threshold = 0.70;

% ---- Epochs ---------------------------------------------------------------
% Cue onset (T1/T2) is 0 s. The second before it is rest and serves as the
% baseline for ERD plots; machine learning uses the 0-4 s task period.
cfg.epoch.windowSec = [-1 4];
cfg.epoch.baselineSec = [-1 0];
cfg.epoch.taskSec = [0 4];

% ---- Time-frequency analysis (ERD, pop_newtimef) -------------------------
% FFT of 0.5 s Hann windows (cycles 0), at this many time points over the
% epoch: fine enough for a smooth replay of the scalp maps.
cfg.erd.windowSec = 0.5;
cfg.erd.timePoints = 200;

% ---- Signal source estimation (step 5) ------------------------------------
% EEGLAB's standard head (dipfit's boundary element model in MNI space) and
% the cortex of the Colin27 head with the 68 regions of the Desikan-Killiany
% atlas, as in ROIconnect's examples. The electrode positions come from
% dipfit's standard_1005.elc, rotated by EEGLAB on lookup: coordTransform
% turns them back. eLORETA regularization 0.05 (ROIconnect's default).
cfg.source.hdmFile = fullfile(cfg.paths.dipfitRoot, 'standard_BEM', 'standard_vol.mat');
cfg.source.mriFile = fullfile(cfg.paths.dipfitRoot, 'standard_BEM', 'standard_mri.mat');
cfg.source.coordTransform = [0 0 0 0 0 -1.5708 1 1 1];
cfg.source.sourceModelFile = fullfile(cfg.paths.eeglabRoot, 'functions', 'supportfiles', ...
    'head_modelColin27_5003_Standard-10-5-Cap339.mat');
cfg.source.sourceModel2mni = [0 -26.6046230000 -46 0.1234625600 0 -1.5707963000 1000 1000 1000];
cfg.source.eloretaRegularization = 0.05;

% ---- Frequency bands ------------------------------------------------------
% Presets of the band pickers (steps 4 and 5); any range can also be typed.
% Motor imagery mainly changes mu and beta; gamma stops at 45 Hz because of
% the band-pass filter.
cfg.bands = struct( ...
    'displayName', {'μ波 (8–13 Hz)', 'β波 (13–30 Hz)', 'δ波 (0.5–4 Hz)', 'θ波 (4–8 Hz)', ...
        'γ波 (30–45 Hz)'}, ...
    'rangeHz', {[8 13], [13 30], [0.5 4], [4 8], [30 45]});

% ---- Plots ----------------------------------------------------------------
cfg.plot.maxSeconds = 120;
cfg.plot.maxFrequencyHz = 80;
cfg.plot.visible = 'on';
end

function paths = localPaths()
% The project folders, resolved from this file's location (src/).
% external/ holds everything downloaded by setup.m: the programs, the EEG
% recordings (external/PhysioNet) and the course dataset for machine
% learning (external/mooc_dataset, from this project's GitHub release,
% made by build_course_dataset).
projectRoot = fileparts(fileparts(mfilename('fullpath')));

paths = struct();
paths.projectRoot = projectRoot;
paths.eeglabRoot = fullfile(projectRoot, 'external', 'eeglab');
paths.dipfitRoot = fullfile(paths.eeglabRoot, 'plugins', 'dipfit5.6');
% Standard 10-5 electrode positions (looked up by electrode name).
paths.channelLocationFile = fullfile(paths.dipfitRoot, 'standard_BEM', 'elec', 'standard_1005.elc');
paths.biosigRoot = fullfile(projectRoot, 'external', 'BioSig');
paths.rawDir = fullfile(projectRoot, 'external', 'PhysioNet');
paths.datasetDir = fullfile(projectRoot, 'external', 'mooc_dataset');   % <condition>/S###_<condition>.set
paths.icaDir = fullfile(paths.datasetDir, 'ica');                 % kept for rebuilding, not released
paths.outputDir = fullfile(projectRoot, 'outputs');
end
