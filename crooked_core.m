function res = crooked_core(p, files)
% crooked_core  弯线测线优化核心计算(供 App/脚本复用)
%   输入: p     - 参数(noff/maxoffset/binX/binY/rint/polyR/polyC/
%                 error1/range1/calnum/pairMode/rIdx/nBreak)
%         files - struct: recv/shots/cmp
%   输出: res   - 结果结构(含 breakList, degInfo, segRMSE, 新老CMP偏差等)
%   派生: cxHalf=binX/2, cyHalf=binY/2, cint=binX
%         多项式次数: polyR/polyC 为搜索范围, 每段各自自动选
%   流程: 读数据 → 裁剪 → 多断点 → 迭代 → 加密 → 覆盖统计
% =====================================================================
res = [];
R0   = loadPoints(files.recv);
S    = loadPoints(files.shots);
CMP0 = loadPoints(files.cmp);

%% 派生面元参数
p.cxHalf = p.binX/2;
p.cyHalf = p.binY(:)'/2;
p.cint   = p.binX;
if ~isfield(p,'nBreak') || isempty(p.nBreak), p.nBreak = 1; end

%% 1.0 检波点裁剪
if isfield(p,'rIdx') && ~isempty(p.rIdx)
    i1 = max(1, round(p.rIdx(1)));
    i2 = min(size(R0,1), round(p.rIdx(2)));
    if i2 <= i1, error('检波点点号范围非法: [%d, %d]', i1, i2); end
    R0 = R0(i1:i2, :);
end

%% 1.1 范围
p.rstart = R0(1,:);   p.rend = R0(end,:);
p.srange = [S(1,:); S(end,:)];
p.cstart = CMP0(1,:); p.cend = CMP0(end,:);

%% 1.2 断点 = 趋势剧变点(数据源可选: 炮点 shot / CMP线 cmp)
if ~isfield(p,'breakSrc') || isempty(p.breakSrc), p.breakSrc = 'shot'; end
selC = CMP0(:,1)>=p.cstart(1) & CMP0(:,1)<=p.cend(1);   % 无条件先算, 供后续fun0使用
optsB = struct('error1',p.error1, 'range1',p.range1, 'thr',0.15);
if strcmpi(p.breakSrc,'shot')
    selS = S(:,1)>=p.cstart(1) & S(:,1)<=p.cend(1);
    if nnz(selS) < 2*max(p.polyC)+10
        warning('炮点有效段过少(%d), 回退用CMP0找断点', nnz(selS));
        p.breakList = findBreak(CMP0(selC,:), p.polyC, p.nBreak, optsB);
        p.breakSrcUsed = 'cmp(回退)';
    else
        p.breakList = findBreak(S(selS,:), p.polyC, p.nBreak, optsB);
        p.breakSrcUsed = 'shot';
    end
else
    p.breakList = findBreak(CMP0(selC,:), p.polyC, p.nBreak, optsB);
    p.breakSrcUsed = 'cmp';
end
%% 配对方式半径
switch lower(p.pairMode)
    case 'maxoffset'
        rInv = p.maxoffset/2;  rFwd = p.maxoffset;  doRoll = false;
    case 'roll'
        rInv = p.noff/2;       rFwd = p.noff;       doRoll = true;
    otherwise
        error('未知配对方式: %s', p.pairMode);
end

%% 采样点数
nR1  = max(2, ceil((p.rend(1)-p.rstart(1))/p.rint) + 1);
nCMP = max(2, ceil((p.cend(1)-p.cstart(1))/p.cint) + 1);

%% 2. 迭代
iterLog = cell(0);
segRMSE = cell(0);
CMP = CMP0;
degR = []; degC = [];
for it = 1:p.calnum
    if it == 1, src='初始CMP线'; else, src='上轮拟合新CMP线'; end
    R = invertReceivers(CMP, S, rInv);
    if doRoll, R = rollCut(R, p.rstart(1), p.rend(1)); end
    [R1, funR, degR] = piecewiseFit(R, p.breakList, p.polyR, p.range1, p.error1, ...
                               nR1, p.rstart(1), p.rend(1));
    ncmp = forwardCMP(R1, S, rFwd);
    [CMP_new, funC, degC] = piecewiseFit(ncmp, p.breakList, p.polyC, p.range1, p.error1, ...
                                   nCMP, p.cstart(1), p.cend(1));
    yold = interp1(CMP(:,1), CMP(:,2), CMP_new(:,1), 'linear', NaN);
    dmax = max(abs(CMP_new(:,2) - yold), [], 'omitnan');
    if ~isfinite(dmax), dmax = 0; end
    % 每段RMSE(检波线、CMP线)
    rmseR = segRMSEof(R, funR, p.breakList);
    rmseC = segRMSEof(ncmp, funC, p.breakList);
    segRMSE{end+1} = struct('it',it, 'rmseR',rmseR, 'rmseC',rmseC); %#ok<AGROW>
    iterLog{end+1} = sprintf(['迭代%d [%s]: 反演检波点%d, 检波线次数[%s] RMSE[%s], ' ...
        '正演CMP%d, CMP次数[%s] RMSE[%s], 新CMP与反演用线最大偏差%.1fm'], ...
        it, src, size(R,1), num2str(degR(:)'), num2str(rmseR,'%.1f '), ...
        size(ncmp,1), num2str(degC(:)'), num2str(rmseC,'%.1f '), dmax);
    CMP = CMP_new;
end

%% 3. 加密
[rfinal, ~]    = resampleLine(funR, p.rstart(1), funR(p.rstart(1)), p.rint, 5000, p.rend(1));
[cfinal, Angel]= resampleLine(funC, p.cstart(1), funC(p.cstart(1)), p.cint, 10000, p.cend(1));

%% 4. 覆盖统计
ncmp0 = forwardCMP(R0, S, rFwd);
ncmp0 = rollCut(ncmp0, p.cstart(1), p.cend(1));
if isempty(ncmp) || isempty(ncmp0) || isempty(cfinal)
    error('CMP点或面元中心为空: ncmp=%d, ncmp0=%d, cfinal=%d', ...
        size(ncmp,1), size(ncmp0,1), size(cfinal,1));
end
xlo = max(min(ncmp(:,1)), min(ncmp0(:,1)));
xhi = min(max(ncmp(:,1)), max(ncmp0(:,1)));
if xhi <= xlo
    error('新老CMP点X范围无交集: xlo=%.1f xhi=%.1f', xlo, xhi);
end
keep = cfinal(:,1) >= xlo & cfinal(:,1) <= xhi;
if ~any(keep)
    error('cfinal 与 CMP 点范围无交集: xlo=%.0f xhi=%.0f', xlo, xhi);
end
cfinal2 = cfinal(keep,:); Angel2 = Angel(keep);
foldn = foldCount(cfinal2, Angel2, ncmp, p.cxHalf, p.cyHalf);

[~, fun0, deg0] = piecewiseFit(CMP0(selC,:), p.breakList, p.polyC, p.range1, p.error1, ...
                         2000, p.cstart(1), p.cend(1));
Xg = min(cfinal2(:,1), p.cend(1)); Xg = Xg(:);
if isempty(Xg), error('面元中心有效范围为空'); end
y0 = fun0(Xg); y0 = y0(:);
if numel(y0) ~= numel(Xg)
    if isscalar(y0), y0 = repmat(y0, size(Xg)); else, y0 = reshape(y0, size(Xg)); end
end
CF0 = [Xg, y0];
dCF = diff(CF0); Angel0 = atan2(dCF(:,2), dCF(:,1)); Angel0 = [Angel0; Angel0(end)];
foldo = foldCount(CF0, Angel0, ncmp0, p.cxHalf, p.cyHalf);

%% 新老CMP偏差(逐点)
y0atCMP = fun0(CMP(:,1));
dCMP = CMP(:,2) - y0atCMP;

%% 5. 结果
res = struct('p',p, 'R0',R0, 'S',S, 'CMP0',CMP0, 'R1',R1, 'funR',funR, ...
             'CMP',CMP, 'funC',funC, 'rfinal',rfinal, 'cfinal',cfinal, ...
             'Angel',Angel, 'ncmp',ncmp, 'ncmp0',ncmp0, ...
             'foldn',foldn, 'foldo',foldo, 'CF0',CF0, 'Angel0',Angel0, ...
             'breakList',p.breakList, 'degInfo',struct('R',degR,'C',degC,'CMP0',deg0), ...
             'segRMSE',{segRMSE}, 'dCMP',dCMP, 'iterLog',{iterLog});
end

% =====================================================================
function rmse = segRMSEof(pts, fun, breakList)
% 按断点切段算每段RMSE
xB = sort(breakList(:,1)); nB = numel(xB);
edges = [-inf; xB(:); inf];
rmse = zeros(nB+1,1);
for k = 1:nB+1
    m = pts(:,1) > edges(k) & pts(:,1) <= edges(k+1);
    if any(m)
        r = pts(m,2) - fun(pts(m,1));
        rmse(k) = sqrt(mean(r.^2));
    else
        rmse(k) = NaN;
    end
end
end