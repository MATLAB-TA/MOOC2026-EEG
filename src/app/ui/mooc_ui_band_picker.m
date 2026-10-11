function picker = mooc_ui_band_picker(controls, cfg, onChange)
%MOOC_UI_BAND_PICKER 周波数帯を選ぶ欄
%
%   μ波などの選択肢と、Hz の範囲の入力欄を並べる。
%     picker = mooc_ui_band_picker(controls, cfg, onChange)
%       picker.band() で、選んでいる周波数帯（名前と範囲）を返す

presets = cfg.bands;
uilabel(controls, 'Text', '周波数帯');
presetDropDown = uidropdown(controls, 'Items', [{presets.displayName}, {'自分で設定'}], ...
    'ItemsData', 1:numel(presets) + 1, 'Value', 1, ...     % last item = custom
    'ValueChangedFcn', @(~, ~) presetChosen());
uilabel(controls, 'Text', '範囲');
rangeGrid = uigridlayout(controls, [1 4], 'ColumnWidth', {'1x', 20, '1x', 24}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 4);
lowField = uieditfield(rangeGrid, 'numeric', 'Value', presets(1).rangeHz(1), ...
    'Limits', [0.5 60], 'ValueChangedFcn', @(~, ~) rangeTyped());
uilabel(rangeGrid, 'Text', '〜', 'HorizontalAlignment', 'center');
highField = uieditfield(rangeGrid, 'numeric', 'Value', presets(1).rangeHz(2), ...
    'Limits', [0.5 60], 'ValueChangedFcn', @(~, ~) rangeTyped());
uilabel(rangeGrid, 'Text', 'Hz');

picker = struct('band', @currentBand);

    function presetChosen()
        if presetDropDown.Value <= numel(presets)
            lowField.Value = presets(presetDropDown.Value).rangeHz(1);
            highField.Value = presets(presetDropDown.Value).rangeHz(2);
        end
        onChange();
    end

    function rangeTyped()
        if highField.Value <= lowField.Value
            uialert(ancestor(controls, 'figure'), '上限は下限より大きくしてください。', '周波数帯');
            return;
        end
        presetDropDown.Value = numel(presets) + 1;
        onChange();
    end

    function band = currentBand()
        rangeHz = [lowField.Value highField.Value];
        if presetDropDown.Value <= numel(presets)
            displayName = presets(presetDropDown.Value).displayName;
        else
            displayName = sprintf('%g〜%g Hz', rangeHz);
        end
        band = struct('displayName', displayName, 'rangeHz', rangeHz);
    end
end
