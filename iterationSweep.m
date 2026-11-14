function iterationSweep()
% iterationSweep 正反演迭代次数敏感性对比（确定最优迭代次数后开展下一步）
%
% ===================== DEPRECATED (已弃用) =====================
% 本函数为早期命令行工具，使用旧输入 Crooked line23 RP.txt / SP.txt
% (与当前 CSV 数据不一致)。其功能已由 CrookedCMP_app 的"迭代对比"按钮
% 完全取代(扫描 1..上限 跑完整 crooked_core 链路，画偏差/覆盖迭代曲线)。
% 保留本文件仅作备查，不再维护；如需独立使用请先更新输入路径与数据格式。
% ================================================================
%
%   单次运行跑满 maxCal 次迭代，记录"若在第 calnum 次停止"时的：
%     ① 本轮拟合新CMP线与反演用线最大偏差 dmax（收敛判据）
%     ② 正演CMP点数、③ 新/老测线在 12.5x150、12.5x300 面元下的覆盖 mean/max
%   输出对比表 → 据"偏差趋于稳定、覆盖不再显著提升"选定具体迭代次数。
base = fileparts(mfilename('fullpath')); cd(base);
R0 = loadPoints('Crooked line23 RP.txt');
S  = loadPoints('Crooked line23 SP.txt');
CMP0 = loadPoints('Crooked line23 CMP.txt');
% --- 论文参数 ---
p.noff=2000; p.cx=12.5; p.cy=[150 300]; p.rn0=800; p.rint=25; p.cint=12.5;
p.rstart=[2516867 667525]; p.rend=[2533570 661779];
p.cstart=[2516826 667685]; p.cend=[2533548 661727];
p.runonoff=1; p.break1=[2521740 667280]; p.error1=100; p.range1=1500;
p.polyR=[3 4]; p.polyC=[3 4];
maxCal = 5;                        % 扫描的最大迭代次数(可调)
CMP = CMP0; prevCMP = CMP0;
fprintf('迭代 | 偏差dmax(m) | 正演CMP | 12.5x150 新/老mean | 12.5x300 新/老mean\n');
for it = 1:maxCal
    R = invertReceivers(CMP, S, p.noff/2);
    if p.runonoff==1, R = rollCut(R, p.rstart(1), p.rend(1)); end
    [R1, funR] = piecewiseFit(R, p.break1, p.polyR, p.range1, p.error1, ...
                              p.rn0, p.rstart(1), p.rend(1));
    ncmp = forwardCMP(R1, S, p.noff);
    [CMP, funC] = piecewiseFit(ncmp, p.break1, p.polyC, p.range1, p.error1, ...
                               p.rn0*2, p.cstart(1), p.cend(1));
    % ① 本轮新CMP线与上一轮反演用线最大偏差(收敛判据)
    yold = interp1(prevCMP(:,1), prevCMP(:,2), CMP(:,1), 'linear', NaN);
    dmax = max(abs(CMP(:,2) - yold), [], 'omitnan'); if ~isfinite(dmax), dmax = 0; end
    % ② 加密+覆盖
    [cfinal, Angel] = resampleLine(funC, p.cstart(1), funC(p.cstart(1)), p.cint, 10000, p.cend(1));
    foldn = foldCount(cfinal, Angel, ncmp, p.cx, p.cy);          % 新测线
    dx0 = diff(CMP0(:,1)); dy0 = diff(CMP0(:,2));
    Angel0 = atan2(dy0, dx0); Angel0 = [Angel0; Angel0(end)];
    foldo = foldCount(CMP0, Angel0, ncmp, p.cx, p.cy);           % 老测线
    fprintf('%d    | %.1f        | %d  | %.1f / %.1f        | %.1f / %.1f\n', ...
        it, dmax, size(ncmp,1), mean(foldn(:,1)), mean(foldo(:,1)), ...
        mean(foldn(:,2)), mean(foldo(:,2)));
    prevCMP = CMP;
end
fprintf('\n说明: 偏差dmax随迭代减小并趋于稳定、覆盖均值不再显著提升时即为可用迭代次数。\n');
fprintf('主脚本 Crooked_CMP_pipeline.m 中参数 p.calnum(当前=3) 即此迭代次数, 按上表确定后修改即可。\n');
end