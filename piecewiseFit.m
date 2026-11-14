function [line, fun, degInfo] = piecewiseFit(pts, breakList, degRange, range1, error1, nOut, xStart, xEnd)
% piecewiseFit 多断点分段多项式拟合(重叠窗口 + 自动次数 + 鲁棒 + 链式C0)
%   1) 断点列表 breakList (nB x 2), 将数据切成 nB+1 段
%   2) bp: 每个断点取"最近点索引"(不依赖error1附近有点, 多断点稳定)
%   3) range1: 相邻段在断点附近重叠 range1 点
%   4) 次数: 每段自动选(范围 degRange=[min max], 残差相对下降<5%)
%   5) 鲁棒: fit+Bisquare; 无工具箱回退 polyfit
%   6) 链式C0: 从段2起逐段与上一段在断点处对齐(只平移当前段), 异常偏差跳过
%   输入: pts - nPx2; breakList - nBx2; degRange - [degMin degMax];
%         range1 - 重叠点数; error1 - 保留参数(不再用于bp定位); nOut - 采样点数; xStart,xEnd
%   输出: line - nOutx2; fun - 分段函数句柄; degInfo - 每段次数
nP = size(pts,1);
if nargin < 3 || isempty(degRange), degRange = [2 6]; end
if nargin < 4, range1 = 1500; end
if nargin < 5, error1 = 100; end

if isempty(breakList)
    breakList = zeros(0,2);
end
nB = size(breakList,1);
xB = sort(breakList(:,1));   % 断点X(升序)

% --- 1) bp: 每个断点取最近点索引(多断点稳定) ---
bp = zeros(nB,1);
for k = 1:nB
    [~, bp(k)] = min(abs(pts(:,1) - xB(k)));
end
bp = min(max(bp, 1), nP);

% --- 2) 段窗口: 段0 [1,bp1+range1]; 段k [bp(k-1)-range1, bp(k)+range1]; 段nB [bp(nB)-range1,nP] ---
segStart = zeros(nB+1,1); segEnd = zeros(nB+1,1);
segStart(1) = 1;              segEnd(1) = min(nP, bp(1)+range1);
for k = 2:nB
    segStart(k) = max(1, bp(k-1)-range1);
    segEnd(k)   = min(nP, bp(k)+range1);
end
segStart(nB+1) = max(1, bp(nB)-range1);
segEnd(nB+1)   = nP;

% --- 2b) 段最小点数保护 ---
minPts = degRange(1)+2;
for k = 1:nB+1
    if segEnd(k) < segStart(k), segEnd(k) = segStart(k); end
    if segEnd(k)-segStart(k)+1 < minPts
        need = minPts - (segEnd(k)-segStart(k)+1);
        segStart(k) = max(1, segStart(k)-ceil(need/2));
        segEnd(k)   = min(nP, segEnd(k)+ceil(need/2));
    end
end

% --- 3) 每段自动次数 + 鲁棒拟合 ---
degArr = zeros(nB+1,1);
funSeg = cell(nB+1,1);
for k = 1:nB+1
    i1 = segStart(k); i2 = segEnd(k);
    xk = pts(i1:i2,1); yk = pts(i1:i2,2);
    dk = autoDeg(xk, yk, degRange, 0.05);
    [fk, ok] = robustFit(xk, yk, dk);
    if ~ok, fk = @(x) zeros(size(x)); end
    degArr(k) = dk; funSeg{k} = fk;
end

% --- 4) 链式C0对齐(段k与段k-1在 xB(k) 处对齐, 只平移段k; 异常偏差跳过) ---
shift = zeros(nB+1,1);
for k = 2:nB+1
    xb = xB(k-1);
    vPrev = funSeg{k-1}(xb) + shift(k-1);
    vCur  = funSeg{k}(xb);
    sh = vPrev - vCur;
    if abs(sh) > 1e4
        warning('段%d在断点%.0f处对齐偏差%.0f m, 跳过该段对齐', k, xb, sh);
        sh = 0;
    end
    shift(k) = sh;
end

% --- 5) 分段函数句柄(按断点X切换) ---
fun = @(xv) evalFun(funSeg, shift, xB, xv);
Xo = linspace(xStart, xEnd, nOut);
line = [Xo(:), fun(Xo(:))];
degInfo = degArr;
end

% =====================================================================
function v = evalFun(funSeg, shift, xB, xv)
% 按断点切换段: xv<=xB(1)->段1; xB(k-1)<xv<=xB(k)->段k; xv>xB(end)->段nB+1
nB = numel(xB);
v = zeros(size(xv));
for i = 1:numel(xv)
    x = xv(i);
    if nB == 0
        k = 1;
    elseif x <= xB(1)
        k = 1;
    elseif x > xB(end)
        k = nB + 1;
    else
        k = find(x <= xB, 1, 'first');
    end
    v(i) = funSeg{k}(x) + shift(k);
end
end

% =====================================================================
function deg = autoDeg(x, y, degRange, relTol)
% 按残差相对下降选次数: 从degMin升到degMax, 首次相对下降<relTol 即停
degMin = degRange(1); degMax = degRange(2);
degMax = min(degMax, numel(x)-1);
if degMax < degMin, deg = max(1, min(degMin, numel(x)-1)); return; end
mu = mean(x); sd = std(x); if sd==0, sd=1; end
xs = (x - mu) / sd;
rmse = zeros(degMax-degMin+1,1);
for d = degMin:degMax
    c = polyfit(xs, y, d);
    yf = polyval(c, xs);
    rmse(d-degMin+1) = sqrt(mean((y-yf).^2));
end
deg = degMax;
for i = 2:numel(rmse)
    if rmse(i-1) > 0 && (rmse(i-1)-rmse(i))/rmse(i-1) < relTol
        deg = degMin + i - 2; break;
    end
end
end

% =====================================================================
function [f, ok] = robustFit(x, y, deg)
% 鲁棒拟合: fit+Normalize+Bisquare; 失败回退中心化 polyfit
ok = false;
if numel(x) < deg+1, return; end
try
    ft = fittype(sprintf('poly%d', deg));
    opts = fitoptions('Method','LinearLeastSquares', ...
                      'Normalize','on', 'Robust','Bisquare');
    fr = fit(x(:), y(:), ft, opts);
    f = @(xv) fr(xv);
    ok = true;
    return;
catch
end
mu = mean(x); sd = std(x); if sd==0, sd=1; end
xs = (x - mu) / sd;
c = polyfit(xs, y, deg);
f = @(xv) polyval(c, (xv - mu) / sd);
ok = true;
end