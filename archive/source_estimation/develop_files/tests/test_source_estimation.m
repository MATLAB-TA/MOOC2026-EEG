%TEST_SOURCE_ESTIMATION Check that the source estimation finds a known source.
%
%   The head model of step 5 is prepared on 64 electrodes with standard
%   positions (pop_dipfit_settings, pop_leadfield). A 10 Hz rhythm is placed
%   at one point of the right precentral gyrus and projected to the
%   electrodes with that leadfield (plus a little noise). Then:
%     1. ROIconnect's pop_roi_activity must find most power in that region
%        (EEG.roi.source_roi_power: the mean power of each region's points)
%     2. mooc_roi_activity, which does pop_roi_activity's calculation region
%        by region to save memory, must give the same region signals
%     3. the band power of the region signals (mooc_compute_erd, i.e.
%        pop_newtimef, as in step 5) is computed for all 68 regions
%   pop_roi_activity's region signals (nPCA 1) are the first principal
%   component of each region scaled to unit length, so their power cannot be
%   compared between regions; that is why check 1 uses source_roi_power.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % develop/<folder>/ -> project
addpath(fullfile(projectRoot, 'src'));
setup_eeglab();
cfg = mooc_default_config();

% Epochs of 64 electrodes with standard positions (the data comes below).
names = {'Fc5', 'Fc3', 'Fc1', 'Fcz', 'Fc2', 'Fc4', 'Fc6', 'C5', 'C3', 'C1', 'Cz', ...
    'C2', 'C4', 'C6', 'Cp5', 'Cp3', 'Cp1', 'Cpz', 'Cp2', 'Cp4', 'Cp6', 'Fp1', 'Fpz', ...
    'Fp2', 'Af7', 'Af3', 'Afz', 'Af4', 'Af8', 'F7', 'F5', 'F3', 'F1', 'Fz', 'F2', 'F4', ...
    'F6', 'F8', 'Ft7', 'Ft8', 'T7', 'T8', 'T9', 'T10', 'Tp7', 'Tp8', 'P7', 'P5', 'P3', ...
    'P1', 'Pz', 'P2', 'P4', 'P6', 'P8', 'Po7', 'Po3', 'Poz', 'Po4', 'Po8', 'O1', 'Oz', ...
    'O2', 'Iz'};
srate = 128;
times = -1:1 / srate:(4 - 1 / srate);
trialCount = 10;
EEG = eeg_emptyset();
EEG.nbchan = 64;
EEG.pnts = numel(times);
EEG.trials = trialCount;
EEG.srate = srate;
EEG.xmin = times(1);
EEG.xmax = times(end);
EEG.data = zeros(64, numel(times), trialCount, 'single');
EEG.chanlocs = struct('labels', names);
EEG = pop_chanedit(EEG, 'lookup', cfg.paths.channelLocationFile);

% Head model, as in step 5.
source = cfg.source;
EEG = pop_dipfit_settings(EEG, 'hdmfile', source.hdmFile, 'coordformat', 'MNI', ...
    'mrifile', source.mriFile, 'chanfile', cfg.paths.channelLocationFile, ...
    'coord_transform', source.coordTransform, 'chansel', 1:64);
EEG = pop_leadfield(EEG, 'sourcemodel', source.sourceModelFile, ...
    'sourcemodel2mni', source.sourceModel2mni, 'downsample', 1);

% One source in the right precentral gyrus, pointing in its strongest direction.
atlas = load(source.sourceModelFile, 'atlas');
target = find(strcmp(atlas.atlas.label, 'precentral R'));
points = find(atlas.atlas.colorTable == target);
point = points(round(end / 2));
gain = EEG.dipfit.sourcemodel.leadfield{point};          % 64 x 3
[~, ~, directions] = svd(gain, 'econ');
scalpPattern = gain * directions(:, 1);

rng(3);
for trial = 1:trialCount
    rhythm = sin(2 * pi * 10 * times + 2 * pi * rand);
    scalp = scalpPattern * rhythm;
    EEG.data(:, :, trial) = scalp + 0.02 * std(scalp(:)) * randn(size(scalp));
end
EEG.data = EEG.data - mean(EEG.data, 1);      % average reference, as in the app
EEG = eeg_checkset(EEG);

% 1. pop_roi_activity finds the region (the data is small enough here)
withRoi = pop_roi_activity(EEG, 'leadfield', EEG.dipfit.sourcemodel, 'model', 'eLoreta', ...
    'modelparams', {source.eloretaRegularization}, 'atlas', 'Desikan-Kilianny', 'nPCA', 1, ...
    'resample', EEG.srate);
regionNames = {withRoi.roi.atlas.Scouts.Label};
[~, strongest] = max(sum(withRoi.roi.source_roi_power, 1));
assert(strongest == target, 'pop_roi_activity: strongest region is %s, expected precentral R.', ...
    regionNames{strongest});

% 2. mooc_roi_activity gives the same region signals (the sign is arbitrary)
EEG = mooc_roi_activity(EEG, source.eloretaRegularization);
assert(isequal({EEG.roi.atlas.Scouts.Label}, regionNames));
expected = double(withRoi.roi.source_roi_data);
actual = double(EEG.roi.source_roi_data);
for region = 1:numel(regionNames)
    a = reshape(expected(region, :, :), [], 1);
    b = reshape(actual(region, :, :), [], 1);
    difference = min(norm(a - b), norm(a + b)) / norm(a);
    assert(difference < 1e-4, 'Region %s differs from pop_roi_activity by %.1e.', ...
        regionNames{region}, difference);
end

% 3. Band power of the region signals (pop_newtimef), as in step 5
regionEEG = EEG;
regionEEG.data = actual;
regionEEG.nbchan = numel(regionNames);
regionEEG.chanlocs = struct('labels', regionNames);
regionEEG.dipfit = [];
regionEEG.roi = [];
labels = repmat(categorical("left_fist"), trialCount, 1);
erd = mooc_compute_erd(regionEEG, labels, [8 13], [-1 0], cfg);
assert(size(erd.percent, 1) == 68 && all(isfinite(erd.percent(:))));

fprintf('Source estimation test passed.\n');
