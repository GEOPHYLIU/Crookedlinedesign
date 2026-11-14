%% =====================================================================
%  二维弯线采集测线优化 —— 模块化重构
%  依据论文《二维弯线采集中测线优化设计方案与实现》技术路线(图4):
%    数据准备 → 检波点反演 → CMP点正演 → 分段多项式拟合 → 迭代(3次)
%            → 等间距加密 → 不同面元有效覆盖次数分析
%  输入数据:
%    检波点  Crookedline-Receivers.csv
%    炮点    Crookedline-Shots.csv
%    初始CMP线 Crooked line23 CMP.txt
%  运行: 在 MATLAB 命令窗口执行  Crooked_CMP_pipeline
% =====================================================================
clear; clc; close all;
cd(fileparts(mfilename('fullpath')));
% 启动并行池(4核)
if isempty(gcp('nocreate'))
    parpool('local', 4);
end

%% 0. 设计参数
p.noff      = 2000;              % 近偏移距(m)，滚进滚出模式下反演/正演半径
p.maxoffset = 4000;              % 最大偏移距(m)，按最大偏移距配对时的半径
p.binX      = 12.5;              % 面元沿测线全宽(m) → 半宽6.25, 步长12.5
p.binY      = [300 600];         % 面元垂直测线全宽(m, 多值) → 半宽150/300
p.rint      = 25;                % 检波点等间距步长(也是拟合线采样步长)
p.polyR = [2 6];                 % 检波点拟合次数搜索范围(最小 最大), 实际次数自动选
p.polyC = [2 6];                 % CMP点拟合次数搜索范围
p.error1    = 100;               % 断点容差
p.range1    = 1500;              % 拟合窗口点数
p.calnum    = 3;                 % 迭代次数
p.nBreak    = 1;                 % 断点个数(1~5)
% --- 配对方式与检波点范围 ---
p.pairMode  = 'maxoffset';       % 'maxoffset'=按最大偏移距配对 | 'roll'=检波点滚进滚出
p.rIdx      = [];                % 检波点点号范围 [i1 i2](排序后序号), [] = 全部

%% 1. 数据准备
R0   = loadPoints('Crookedline-Receivers.csv'); % 检波点
S    = loadPoints('Crookedline-Shots.csv');      % 炮点
CMP0 = loadPoints('Crooked line23 CMP.txt');     % 初始CMP线
fprintf('数据: 检波点 %d, 炮点 %d, 初始CMP线 %d\n', ...
    size(R0,1), size(S,1), size(CMP0,1));

%% 1.1 检波点范围说明(实际裁剪在 crooked_core 内按 p.rIdx 执行)
if isempty(p.rIdx)
    fprintf('检波点范围: 全部 (%d 点)\n', size(R0,1));
else
    fprintf('检波点范围: 点号 %d ~ %d\n', p.rIdx(1), p.rIdx(2));
end

%% 2. 调用核心计算
res = crooked_core(p, struct('recv','Crookedline-Receivers.csv', ...
                             'shots','Crookedline-Shots.csv', ...
                             'cmp','Crooked line23 CMP.txt'));
p = res.p;

fprintf('有效检波范围 X %.0f~%.0f, CMP范围 X %.0f~%.0f\n', ...
    p.rstart(1), p.rend(1), p.cstart(1), p.cend(1));
fprintf('断点个数=%d:\n', size(p.breakList,1));
for k = 1:size(p.breakList,1)
    fprintf('  断点%d: X=%.0f Y=%.1f\n', k, p.breakList(k,1), p.breakList(k,2));
end
fprintf('配对方式: %s\n', p.pairMode);
for it = 1:numel(res.iterLog)
    fprintf('%s\n', res.iterLog{it});
end
fprintf('检波线加密 %d 点, CMP面元中心 %d 点\n', size(res.rfinal,1), size(res.cfinal,1));
fprintf('新测线CMP点 %d, 老测线(原始) CMP点 %d\n', size(res.ncmp,1), size(res.ncmp0,1));
for n = 1:numel(p.binY)
    fprintf('面元 %.1f x %.0fm: 新测线 mean=%.1f std=%.1f max=%d, 老测线 mean=%.1f std=%.1f max=%d\n', ...
        p.binX, p.binY(n), mean(res.foldn(:,n)), std(res.foldn(:,n)), max(res.foldn(:,n)), ...
        mean(res.foldo(:,n)), std(res.foldo(:,n)), max(res.foldo(:,n)));
end

%% 3. 迭代过程图(最终结果示意)
figure('Name','迭代过程','Color','w');
plot(res.CMP0(:,1), res.CMP0(:,2), '-', 'Color',[0.7 0.7 0.7]); hold on;
plot(res.R1(:,1), res.R1(:,2), '-b');
plot(res.CMP(:,1), res.CMP(:,2), '-r');
plot(res.S(:,1), res.S(:,2), '*', 'Color',[0.3 0.3 0.3], 'MarkerSize',1);
for k = 1:size(res.p.breakList,1)
    plot(res.p.breakList(k,1), res.p.breakList(k,2), 'x', 'Color',[0.8 0 0], ...
        'MarkerSize',12,'LineWidth',2);
end
hold off;
axis equal; xlabel('X'); ylabel('Y');
legend('初始CMP','检波线','CMP线','炮点','断点','Location','best');
title(sprintf('最终结果 (迭代%d次, 配对=%s, 断点%d个)', p.calnum, p.pairMode, size(p.breakList,1)));

%% 4. 覆盖次数对比图
figure('Name','覆盖次数对比','Color','w');
for n = 1:numel(p.binY)
    subplot(1, numel(p.binY), n);
    plot(res.foldn(:,n), '-r', 'LineWidth',1.5); hold on;
    plot(res.foldo(:,n), '.b', 'MarkerSize',6); hold off;
    xlabel('面元编号'); ylabel('覆盖次数');
    title(sprintf('面元 %.1f x %.0fm 有效覆盖对比', p.binX, p.binY(n)));
    legend('新测线','老测线','Location','best'); grid on; axis tight;
end

%% 5. CMP分布图
figure('Name','CMP分布','Color','w');
subplot(1,2,1);
plot(res.ncmp(:,1), res.ncmp(:,2), '.', 'Color',[0.6 0.6 0.6], 'MarkerSize',2); hold on;
plot(res.R1(:,1), res.R1(:,2), '-b', 'LineWidth',1.2);
plot(res.S(:,1), res.S(:,2), '-r', 'LineWidth',0.8); hold off;
axis equal; xlabel('X'); ylabel('Y');
title('近偏移距CMP分布'); legend('CMP点','检波线','炮线','Location','best');
subplot(1,2,2);
plot(res.cfinal(:,1), res.cfinal(:,2), '.k', 'MarkerSize',2); hold on;
plot(res.CMP0(:,1), res.CMP0(:,2), '--g', 'LineWidth',1.2);
plot(res.R1(:,1), res.R1(:,2), '-b', 'LineWidth',1.2); hold off;
axis equal; xlabel('X'); ylabel('Y');
title('优化CMP面元中心 vs 初始CMP线'); legend('面元中心','初始CMP','检波线','Location','best');

%% 6. 新老CMP偏差图
figure('Name','新老CMP偏差','Color','w');
plot(res.CMP(:,1), res.dCMP, '.', 'Color',[0.2 0.4 0.8]); hold on;
yline(0,'k--');
for k = 1:size(res.p.breakList,1)
    xline(res.p.breakList(k,1),'r--');
end
hold off; grid on; xlabel('X (m)'); ylabel('新CMP - 初始CMP (m)');
title('新老CMP线偏差 (红线=断点)');

%% 7. 保存结果
save('Crooked_CMP_results.mat', 'p', 'R0', 'S', 'CMP0', 'res');
fprintf('结果已保存至 Crooked_CMP_results.mat\n');

%% 8. 输出最终检波点(rfinal, 等弧长加密25m)为CSV
T = table((1:size(res.rfinal,1))', res.rfinal(:,1), res.rfinal(:,2), ...
    'VariableNames', {'PointNo','X','Y'});
writetable(T, 'Final_Receivers.csv');
fprintf('最终检波点已输出: Final_Receivers.csv (%d 点, 等弧长加密%.0fm)\n', ...
    size(res.rfinal,1), p.rint);