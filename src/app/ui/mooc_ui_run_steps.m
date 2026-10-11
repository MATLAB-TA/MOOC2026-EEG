function ok = mooc_ui_run_steps(state, group, steps, component)
%MOOC_UI_RUN_STEPS 処理の工程を順に実行し、「このデータに行った処理」に記録する
%
%   実行中は進み具合の画面を出す。途中でエラーが出たら、そこで止めて知らせる。
%     ok = mooc_ui_run_steps(state, 見出し, steps, 画面の部品)

fig = ancestor(component, 'figure');
state.invalidateFrom(steps(1).stage);
history = state.history;
indices = zeros(1, numel(steps));
for k = 1:numel(steps)
    indices(k) = history.add(steps(k).stage, group, steps(k).label, steps(k).fn, steps(k).code);
end

fig.Pointer = 'watch';
restorePointer = onCleanup(@() set(fig, 'Pointer', 'arrow'));
progress = uiprogressdlg(fig, 'Title', ['処理中：' group], 'Indeterminate', 'on');
closeProgress = onCleanup(@() delete(progress));
ok = true;
for k = 1:numel(steps)
    progress.Message = {sprintf('（%d／%d）%s', k, numel(steps), steps(k).label), '', ...
        '詳しい進み具合は、MATLABのコマンドウィンドウに表示されます。'};
    history.update(indices(k), 'run', '処理中...');
    fprintf('\n=== %s（%d／%d）%s ===\n', group, k, numel(steps), steps(k).label);
    fprintf('    >> %s\n', steps(k).code{:});
    timer = tic;
    try
        detail = steps(k).run();
    catch exception
        history.update(indices(k), 'fail', exception.message);
        delete(progress);
        uialert(fig, exception.message, 'エラー');
        fprintf(2, '%s\n', getReport(exception, 'extended', 'hyperlinks', 'off'));
        ok = false;
        return;
    end
    result = sprintf('%s（%.1f秒）', detail, toc(timer));
    history.update(indices(k), 'done', result);
    fprintf('    → %s\n', result);
end
end
