function R = rollCut(R, xlo, xhi)
% rollCut 滚进滚出切割（论文施工模式）
%   只保留 X 坐标在 [xlo, xhi] 范围内的检波点。
%   输入: R   - nRx2 检波点; xlo,xhi - 检波点范围(东西向)起止 X
%   输出: R   - 保留后的检波点
m = R(:,1) >= xlo & R(:,1) <= xhi;
R = R(m, :);
end
