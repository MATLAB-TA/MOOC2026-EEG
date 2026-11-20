function EEG = mooc_roi_activity(EEG, regularization)
%MOOC_ROI_ACTIVITY 電極の脳波から、脳の68の領域それぞれの活動を求める
%
%   pop_leadfield で頭のモデルを計算したあとのデータに使う。ROIconnect の
%   pop_roi_activity と同じ計算（eLORETA で脳の約5000点の活動を求め、領域
%   ごとに1つの波形にまとめる）を、領域ごとに順番に行う。pop_roi_activity は
%   脳の全点の周波数も一度に計算するので、このデータでは約8 GB のメモリを使う。
%
%     EEG = mooc_roi_activity(EEG, regularization)
%       結果は EEG.roi.source_roi_data（領域 × 時間 × 試行）に入る

leadfield = EEG.dipfit.sourcemodel;
pointCount = numel(leadfield.leadfield);
channelCount = EEG.nbchan;
gain = permute(reshape([leadfield.leadfield{:}], [channelCount 3 pointCount]), [1 3 2]);

% 1. Average reference (as roi_activity)
reference = eye(channelCount) - ones(channelCount) ./ channelCount;
data = reference * EEG.data(:, :);                         % channels x (samples, trials)
gain = reshape(reference * gain(:, :), channelCount, pointCount, 3);

% 2. eLORETA filter: channels x points x 3 directions
filter = mkfilt_eloreta_v2(gain, regularization);

% 3. One signal per region
sourceModel = load(leadfield.file, 'atlas');
regionCount = numel(sourceModel.atlas.label);
regionData = zeros(EEG.pnts * EEG.trials, regionCount);
scouts = struct('Label', sourceModel.atlas.label(:)', 'Vertices', []);
for region = 1:regionCount
    points = find(sourceModel.atlas.colorTable == region);
    scouts(region).Vertices = points;
    pointActivity = reshape(data' * reshape(filter(:, points, :), channelCount, []), ...
        EEG.pnts * EEG.trials, numel(points), 3);
    regionData(:, region) = roi_getact(pointActivity, 1:numel(points), 1);
end

EEG.roi.source_roi_data = single(permute(reshape(regionData, EEG.pnts, EEG.trials, []), [3 1 2]));
EEG.roi.atlas = struct('Name', 'Desikan-Kilianny', 'Scouts', scouts);
EEG.roi.nROI = regionCount;
EEG.roi.nPCA = 1;
EEG.roi.srate = EEG.srate;
EEG.roi.pnts = EEG.pnts;
EEG.roi.parameters = {'model', 'eLoreta', 'modelparams', {regularization}, ...
    'atlas', 'Desikan-Kilianny', 'nPCA', 1};
end
