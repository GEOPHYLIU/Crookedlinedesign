function brkList = findBreak(P, polydeg, nBreak, opts)
% findBreak 自动确定测线趋势剧变点(多断点): 局部方向角变化最大的若干位置
%   输入: P       - nPx2 点(按X升序, 如炮点线或CMP线)
%         polydeg - 1x2 [左 右] 多项式次数(用于两侧最少点数约束)
%         nBreak  - 断点个数(1~3)
%         opts    - 可选: error1(细化容差m), range1(窗口点数), thr(角变化阈值), minGap(断点最小间距m)
%   输出: brkList - nBreak x 2 断点坐标(按X升序)
if nargin < 3 || isempty(nBreak), nBreak = 1; end
if nargin < 4, opts = struct(); end
if ~isfield(opts,'error1'), opts.error1 = 100; end
if ~isfield(opts,'range1'), opts.range1 = 1500; end
if ~isfield(opts,'thr'),    opts.thr = 0.15; end
if ~isfield(opts,'minGap'), opts.minGap = 1500; end

x = P(:,1); y = P(:,2); n = numel(x);
minSide = max(polydeg) + 5;
if n < (nBreak+1)*minSide, error('点数不足以找 %d 个断点', nBreak); end

% 局部方向角 + 平滑
dth = atan2(diff(y), diff(x));
w = max(3, min(11, round(opts.range1/100)));
dthS = movmean(dth, w);

% 前后窗口角差
k = max(10, min( round(opts.range1/10), floor(n/4) ));
dAng = zeros(n-1,1);
for i = (k+1):(n-1-k)
    dAng(i) = abs( mean(dthS(i+1:i+k)) - mean(dthS(i-k:i-1)) );
end

% 排除两端
valid = false(n-1,1);
valid(minSide : n-1-minSide) = true;
dAng(~valid) = 0;

% 按角变化降序，逐个选取并满足最小间距
[~, ord] = sort(dAng, 'descend');
sel = [];
for j = 1:numel(ord)
    idx = ord(j);
    if dAng(idx) < opts.thr && ~isempty(sel), break; end
    if isempty(sel) || all(abs(x(idx) - x(sel)) >= opts.minGap)
        sel(end+1) = idx; %#ok<AGROW>
        if numel(sel) >= nBreak, break; end
    end
end
if numel(sel) < nBreak
    warning('仅找到 %d 个断点(需 %d), 取等分补足', numel(sel), nBreak);
    cand = round(linspace(minSide, n-1-minSide, nBreak+2)); cand = cand(2:end-1);
    for c = cand
        if numel(sel) >= nBreak, break; end
        if isempty(sel) || all(abs(x(c) - x(sel)) >= opts.minGap)
            sel(end+1) = c; %#ok<AGROW>
        end
    end
end
sel = sort(sel(1:min(nBreak,numel(sel))));

% ±error1 细化
for j = 1:numel(sel)
    x0 = x(sel(j));
    inWin = abs(x - x0) <= opts.error1;
    if any(inWin)
        cand = find(inWin);
        [~, jj] = max(dAng(min(cand,n-1)));
        sel(j) = cand(min(jj, numel(cand)));
    end
end
sel = unique(min(max(sel,1), n));

% 强制夹到合法范围(两端留 minGap, 断点间 >= minGap)
xlo = x(1) + opts.minGap;
xhi = x(end) - opts.minGap;
xsel = x(sel);
xsel = min(max(xsel, xlo), xhi);
if numel(xsel) >= 2 && any(diff(xsel) < opts.minGap)
    xsel = linspace(xlo, xhi, nBreak+2); xsel = xsel(2:end-1);
end
brkList = [xsel(:), interp1(x, y, xsel(:))];
end