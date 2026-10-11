function erd = mooc_compute_erd(EEG, labels, bandHz, baselineSec, cfg)
%MOOC_COMPUTE_ERD 合図の後に、脳波の強さがどう変わるかを計算する
%
%   左拳・右拳ごと、電極（または脳の領域）ごとに、EEGLAB の pop_newtimef で
%   選んだ周波数の強さを時間ごとに求め、合図の前（休憩中）と比べて何%
%   増えたか・減ったかにする。マイナスは弱くなった（ERD）ことを表す。
%
%     erd = mooc_compute_erd(EEG, labels, bandHz, baselineSec, cfg)
%       EEG：切り出した脳波、labels：試行ごとの合図、bandHz：周波数の範囲、
%       baselineSec：基準にする時間（例：[-1 0]）
%       erd.percent（電極 × 時間 × 合図）が変化の割合、erd.times が時刻（秒）

labels = categorical(labels(:));
classes = categories(labels);
windowLength = round(cfg.erd.windowSec * EEG.srate);
for classIndex = 1:numel(classes)
    members = find(labels == classes{classIndex});
    classEEG = pop_select(EEG, 'trial', members);
    for channel = 1:EEG.nbchan
        % ersp: power change in dB from the baseline (frequencies x times);
        % powbase: the baseline power of each frequency (not in dB).
        [ersp, ~, powbase, times, ~] = pop_newtimef(classEEG, 1, channel, ...
            [EEG.xmin EEG.xmax] * 1000, 0, 'freqs', bandHz, 'winsize', windowLength, ...
            'timesout', cfg.erd.timePoints, 'baseline', baselineSec * 1000, ...
            'plotersp', 'off', 'plotitc', 'off', 'verbose', 'off');
        if classIndex == 1 && channel == 1
            power = zeros(EEG.nbchan, numel(times), numel(classes));
            trialCounts = zeros(1, numel(classes));
        end
        power(channel, :, classIndex) = mean(powbase(:) .* 10 .^ (ersp / 10), 1);
    end
    trialCounts(classIndex) = numel(members);
end

times = times / 1000;
baseline = mean(power(:, times >= baselineSec(1) & times <= baselineSec(2), :), 2);
percent = (power - baseline) ./ baseline * 100;

erd = struct('times', times, 'classes', {classes'}, 'percent', percent, ...
    'power', power, 'trialCount', trialCounts, 'bandHz', bandHz, ...
    'baselineSec', baselineSec);
end
