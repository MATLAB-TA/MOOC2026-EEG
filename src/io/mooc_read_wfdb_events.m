function events = mooc_read_wfdb_events(eventFile, sampleRate)
%MOOC_READ_WFDB_EVENTS 合図の時刻のファイル（.edf.event）を読む
%
%   BioSig で EDF ファイルから合図を読むと、時刻が1点ずれ、最初の合図が
%   欠けるので、こちらを使う。

eventFile = char(string(eventFile));
if ~isfile(eventFile)
    error('mooc2026:EventFileNotFound', ...
        'イベントファイルが見つかりません: %s', eventFile);
end

fileId = fopen(eventFile, 'rb');
if fileId < 0
    error('mooc2026:EventFileOpenFailed', ...
        'イベントファイルを開けません: %s', eventFile);
end
cleanup = onCleanup(@() fclose(fileId));
bytes = fread(fileId, Inf, '*uint8');

events = struct('type', {}, 'latency', {}, 'duration', {});
byteIndex = 1;
sampleIndex = 0;
pendingSample = NaN;

while byteIndex + 1 <= numel(bytes)
    word = double(bytes(byteIndex)) + 256 * double(bytes(byteIndex + 1));
    byteIndex = byteIndex + 2;
    if word == 0
        break;
    end

    annotationType = floor(word / 1024);
    value = mod(word, 1024);

    switch annotationType
        case 59  % SKIP: signed 32-bit time displacement follows.
            if byteIndex + 3 > numel(bytes)
                error('mooc2026:InvalidEventFile', ...
                    'WFDB SKIPレコードが途中で終了しています: %s', eventFile);
            end
            displacement = double(bytes(byteIndex)) + ...
                256 * double(bytes(byteIndex + 1)) + ...
                65536 * double(bytes(byteIndex + 2)) + ...
                16777216 * double(bytes(byteIndex + 3));
            if displacement >= 2^31
                displacement = displacement - 2^32;
            end
            sampleIndex = sampleIndex + displacement;
            byteIndex = byteIndex + 4;
        case {60, 61, 62}  % NUM, SUB and CHN modify annotation metadata.
            continue;
        case 63  % AUX: text attached to the preceding annotation.
            textLength = value;
            if byteIndex + textLength - 1 > numel(bytes)
                error('mooc2026:InvalidEventFile', ...
                    'WFDB AUXレコードが途中で終了しています: %s', eventFile);
            end
            textBytes = bytes(byteIndex:(byteIndex + textLength - 1));
            auxiliaryText = char(textBytes(:).');
            byteIndex = byteIndex + textLength + mod(textLength, 2);

            tokens = regexp(auxiliaryText, ...
                '^(T[012])\s+duration:\s*([0-9.]+)$', 'tokens', 'once');
            if ~isempty(tokens) && ~isnan(pendingSample)
                eventIndex = numel(events) + 1;
                events(eventIndex).type = tokens{1};
                events(eventIndex).latency = pendingSample + 1;
                events(eventIndex).duration = ...
                    str2double(tokens{2}) * sampleRate;
            end
        otherwise
            sampleIndex = sampleIndex + value;
            pendingSample = sampleIndex;
    end
end
end
