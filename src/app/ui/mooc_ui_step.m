function step = mooc_ui_step(stage, label, fn, run, code)
%MOOC_UI_STEP 処理の1工程（「このデータに行った処理」の1行）を作る
%
%     step = mooc_ui_step(段階, 説明, 関数名, 処理, コード)
%       段階：どの結果を作るか（やり直すと、それより後の結果も消える）
%       関数名：行をダブルクリックしたときに開く関数
%       処理：実行する関数（結果を1行の文字で返す）、コード：同じ処理の命令
%     step = mooc_ui_step(段階, 関数名, コード)
%       アプリでは何もしない「EEGLAB で同じ種類の図を見るなら」の行

if nargin == 3
    code = fn;
    fn = label;
    label = 'EEGLAB で同じ種類の図を見るなら（コマンドウィンドウで実行）';
    run = @() 'アプリでは実行しません（コマンドウィンドウに貼り付けると図が出ます）';
end
step = struct('stage', stage, 'label', label, 'fn', fn, 'run', run, ...
    'code', {cellstr(code)});
end
