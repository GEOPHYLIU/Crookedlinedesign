function R = invertReceivers(CMP, S, dmax)
% invertReceivers 检波点反演（论文步骤：由CMP线反演检波点）
%   对每个炮点 S(i)，找CMP线上距其不超过 dmax 的点，R = 2*CMP - S。
%   优化: X粗筛 + cell收集 + parfor并行(按炮点)。
%   输入: CMP - nCx2 初始CMP线; S - nSx2 炮点; dmax - 反演半径
%   输出: R   - nRx2 反演检波点(按X升序)
nS = size(S,1);
parts = cell(nS,1);
d2 = dmax^2;
xmin = min(CMP(:,1)); xmax = max(CMP(:,1));
parfor i = 1:nS
    sx = S(i,1);
    lo = max(xmin, sx - dmax);
    hi = min(xmax, sx + dmax);
    if lo > hi, continue; end
    cand = find(CMP(:,1) >= lo & CMP(:,1) <= hi);
    if isempty(cand), continue; end
    dx = CMP(cand,1) - sx;
    dy = CMP(cand,2) - S(i,2);
    m = (dx.^2 + dy.^2) <= d2;
    if any(m)
        cc = cand(m);
        parts{i} = [2*CMP(cc,1)-sx, 2*CMP(cc,2)-S(i,2)];
    end
end
parts = parts(~cellfun(@isempty, parts));
if isempty(parts)
    R = zeros(0,2);
else
    R = sortrows(vertcat(parts{:}), 1);
end
end