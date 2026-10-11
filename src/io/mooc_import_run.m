function EEG = mooc_import_run(subject, run, cfg)
%MOOC_IMPORT_RUN 脳波の記録を1つ読み込み、合図の意味を付ける
%
%   pop_biosig で読み込み、合図（T0・T1・T2）に「休憩」「左拳」などの意味を
%   付ける。電極の名前の後ろの「.」も取り除く（例：Fc5. → Fc5）。
%     EEG = mooc_import_run(参加者の番号, 記録の番号, cfg)

edfFile = mooc_find_edf(subject, run);
EEG = pop_biosig(edfFile, 'importevent', 'off', 'importannot', 'off');
if EEG.nbchan ~= cfg.data.expectedChannels
    error('mooc2026:UnexpectedChannelCount', '%d電極のはずが、%d電極でした：%s', ...
        cfg.data.expectedChannels, EEG.nbchan, edfFile);
end
[~, EEG.setname] = fileparts(edfFile);

EEG.event = mooc_read_wfdb_events([edfFile '.event'], EEG.srate);
EEG.urevent = [];
info = cfg.data.runInfo(run);
labels = struct('T0', 'rest', 'T1', info.t1, 'T2', info.t2);
for k = 1:numel(EEG.event)
    EEG.event(k).eegmmidb_label = labels.(EEG.event(k).type);
    EEG.event(k).eegmmidb_subject = subject;
    EEG.event(k).eegmmidb_run = run;
end
EEG = eeg_checkset(EEG, 'eventconsistency');

for k = 1:EEG.nbchan
    EEG.chanlocs(k).labels = regexprep(strtrim(EEG.chanlocs(k).labels), '\.+$', '');
end
end
