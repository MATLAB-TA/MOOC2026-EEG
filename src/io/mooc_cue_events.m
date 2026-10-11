function events = mooc_cue_events(EEG)
%MOOC_CUE_EVENTS 記録の中の合図（休憩・左拳・右拳）の時刻と長さの一覧を作る

events = struct('onset', {}, 'duration', {}, 'label', {});
if isempty(EEG.event) || ~isfield(EEG.event, 'eegmmidb_label')
    return;
end
labeled = EEG.event(~cellfun(@isempty, {EEG.event.eegmmidb_label}));
events = struct( ...
    'onset', num2cell((double([labeled.latency]) - 1) / EEG.srate), ...
    'duration', num2cell(double([labeled.duration]) / EEG.srate), ...
    'label', {labeled.eegmmidb_label});
end
