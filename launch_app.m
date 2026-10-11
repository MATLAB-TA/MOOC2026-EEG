function app = launch_app()
%LAUNCH_APP 脳波解析演習のアプリを起動する
%
%   演習フォルダを「現在のフォルダー」にして、このファイルを実行する。

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'src'));
setup_eeglab();
app = mooc_app();
if nargout == 0
    clear app
end
end
