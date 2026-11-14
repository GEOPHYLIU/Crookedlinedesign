function ncmp = forwardCMP(R, S, noff)
% forwardCMP CMP 点正演（论文步骤：由检波点+炮点正演CMP点）
%   对每个炮点 S(i)，找检波点 R 距其不超过 noff 的点，CMP = (R + S)/2。
%   优化: X粗筛 + cell收集 + parfor并行(按炮点)。
%   输入: R - nRx2 检波点; S - nSx2 炮点; noff - 近偏移距
%   输出: ncmp - nCx2 近偏移距CMP点(按X升序)
nS = size(S,1);
parts = cell(nS,1);
d2 = noff^2;
xmin = min(R(:,1)); xmax = max(R(:,1));
parfor i = 1:nS
    sx = S(i,1);
    lo = max(xmin, sx - noff);
    hi = min(xmax, sx + noff);
    if lo > hi, continue; end
    cand = find(R(:,1) >= lo & R(:,1) <= hi);
    if isempty(cand), continue; end
    dx = R(cand,1) - sx;
    dy = R(cand,2) - S(i,2);
    m = (dx.^2 + dy.^2) <= d2;
    if any(m)
        cc = cand(m);
        parts{i} = [R(cc,1)/2 + sx/2, R(cc,2)/2 + S(i,2)/2];
    end
end
parts = parts(~cellfun(@isempty, parts));
if isempty(parts)
    ncmp = zeros(0,2);
else
    ncmp = sortrows(vertcat(parts{:}), 1);
end
end