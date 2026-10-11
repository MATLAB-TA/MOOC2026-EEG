function varargout = mooc_style(kind, name)
%MOOC_STYLE アプリ全体で使う、名前と色の決まり
%
%   同じものをどの図でも同じ色で表すために、1か所にまとめている。
%     [名前, 色] = mooc_style('label', 'left_fist')   合図の日本語名と色
%     [名前, 色] = mooc_style('icClass', 'Brain')     ICLabel の成分の種類の日本語名と色
%     bands = mooc_style('bands')                     脳波の周波数の呼び名（δ〜γ）
%     map = mooc_style('colormap')                    青（マイナス）〜白〜赤（プラス）の色

switch kind
    case 'label'
        [varargout{1}, varargout{2}] = localLabel(name);
    case 'icClass'
        [varargout{1}, varargout{2}] = localIcClass(name);
    case 'bands'
        varargout{1} = localBands();
    case 'colormap'
        varargout{1} = localColormap();
end
end

function [displayText, color] = localLabel(label)
% Japanese name and color of an event label.
switch string(label)
    case "rest"
        displayText = "休息";
        color = [0.6 0.6 0.6];
    case "left_fist"
        displayText = "左拳";
        color = [0.00 0.45 0.74];
    case "right_fist"
        displayText = "右拳";
        color = [0.85 0.33 0.10];
    case "both_fists"
        displayText = "両拳";
        color = [0.47 0.67 0.19];
    case "both_feet"
        displayText = "両足";
        color = [0.49 0.18 0.56];
    otherwise
        displayText = string(label);
        color = [0.3 0.3 0.3];
end
end

function [displayName, color] = localIcClass(className)
% Short Japanese name and frame color of an ICLabel class
% (電源 = power-line noise, 電極 = channel noise: bad electrode contact).
switch lower(string(className))
    case "brain"
        displayName = "脳";
        color = [0.20 0.63 0.17];
    case "muscle"
        displayName = "筋肉";
        color = [0.89 0.10 0.11];
    case "eye"
        displayName = "眼";
        color = [0.12 0.47 0.71];
    case "heart"
        displayName = "心臓";
        color = [0.91 0.41 0.67];
    case "line noise"
        displayName = "電源";
        color = [0.99 0.70 0.00];
    case "channel noise"
        displayName = "電極";
        color = [0.55 0.34 0.16];
    otherwise
        displayName = "その他";
        color = [0.55 0.55 0.55];
end
end

function bands = localBands()
% The classic EEG frequency bands: symbol (in the spectrum plot), name,
% rangeHz, color of the band's area and a short description.
bands = struct( ...
    'symbol', {'δ', 'θ', 'α/μ', 'β', 'γ'}, ...
    'name', {'δ（デルタ）波', 'θ（シータ）波', 'α（アルファ）波／μ（ミュー）波', ...
        'β（ベータ）波', 'γ（ガンマ）波'}, ...
    'rangeHz', {[0.5 4], [4 8], [8 13], [13 30], [30 80]}, ...
    'color', {[0.55 0.55 0.85], [0.45 0.75 0.85], [0.40 0.80 0.45], ...
        [0.95 0.75 0.30], [0.90 0.50 0.50]}, ...
    'description', { ...
        {'深く眠っているときに強い、ゆっくりした波'}, ...
        {'うとうとしたときや、記憶にかかわる波'}, ...
        {'α：目を閉じて落ち着くと、頭の後ろで強くなる', ...
         'μ：体を動かす場所（頭のてっぺん付近）の波。動かしたり想像したりすると弱くなる'}, ...
        {'考えごとや体の動きにかかわる。μ波と同じように、動かすと弱くなる'}, ...
        {'細かい情報処理にかかわる。筋肉のノイズも混ざりやすい'}});
end

function map = localColormap()
% Blue-white-red, for signed values (blue = decrease, red = increase).
anchors = [0.13 0.40 0.67; 0.57 0.77 0.87; 0.97 0.97 0.97; ...
    0.96 0.65 0.51; 0.70 0.09 0.17];
positions = linspace(0, 1, size(anchors, 1));
map = interp1(positions, anchors, linspace(0, 1, 256));
end
