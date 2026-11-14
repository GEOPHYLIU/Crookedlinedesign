function P = loadPoints(fname)
% loadPoints 读取测线坐标数据文件(检波点/炮点/CMP线), 返回 [X Y] 升序
%   支持两类格式:
%   (1) 带表头的表格(csv/txt), 表头含 X、Y 列名 → 按列名定位坐标列
%       如 Crookedline-Receivers.csv / Crookedline-Shots.csv (6列: Lin,Stn,Pnt,X,Y,Elev)
%   (2) 无表头的数值文件 → 智能取列: 第1列为常数(线号)取第3、4列; 否则取前2列
%       如 Crooked line23 CMP.txt (2列 X,Y)
try
    opts = detectImportOptions(fname);
    opts.VariableNamingRule = 'preserve';   % 保留含空格表头原名, 避免警告
    vn = string(opts.VariableNames);
catch
    opts = []; vn = [];
end
if ~isempty(opts) && any(strcmpi(vn,'X')) && any(strcmpi(vn,'Y'))
    T = readtable(fname, opts);
    P = double([T.X T.Y]);
else
    M = readmatrix(fname);
    if isempty(M)
        error('无法读取数据文件: %s', fname);
    end
    if size(M, 2) >= 4 && range(M(:,1)) < 1e-6
        P = M(:, [3 4]);        % 第1列为线号(常数)，坐标在第3、4列
    elseif size(M, 2) >= 2
        P = M(:, [1 2]);        % 前两列为 X、Y
    else
        error('数据文件列数不足(需>=2列): %s', fname);
    end
end
P = double(P);
P = sortrows(P, 1);
end
