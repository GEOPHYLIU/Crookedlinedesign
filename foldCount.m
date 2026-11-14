function fold = foldCount(binLine, Angel, cmpPts, cxHalf, cyHalf)
% foldCount 面元有效覆盖次数统计（论文: 不同面元尺寸有效覆盖次数分析）
%   将CMP点旋转到面元局部坐标系(u,v)，落入半宽cxHalf x cyHalf(n)即计入。
%   优化: 外包矩形粗筛 + parfor并行(按面元)。
%   输入: binLine - nBx2 面元中心线; Angel - nBx1 面元局部倾角
%         cmpPts  - mCx2 CMP点; cxHalf - 沿测线半宽; cyHalf - 垂直半宽(可多值)
%   输出: fold    - nB x numel(cyHalf) 覆盖次数
nB = size(binLine,1); ncy = numel(cyHalf);
fold = zeros(nB, ncy);
if isempty(cmpPts), return; end
Rmax = hypot(cxHalf, max(cyHalf)) + 1e-6;   % 外包矩形半径(对角线, 含余量)
parfor i = 1:nB
    dx = cmpPts(:,1) - binLine(i,1);
    dy = cmpPts(:,2) - binLine(i,2);
    m = abs(dx) <= Rmax & abs(dy) <= Rmax;
    if ~any(m), continue; end
    ddx = dx(m); ddy = dy(m);
    dist = hypot(ddx, ddy);
    ang = atan2(ddy, ddx) - Angel(i);
    u = abs(dist .* cos(ang));
    v = abs(dist .* sin(ang));
    for n = 1:ncy
        fold(i,n) = sum((u <= cxHalf) & (v <= cyHalf(n)));
    end
end
end