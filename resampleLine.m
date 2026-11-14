function [line, Angel] = resampleLine(fun, x0, y0, step, nmax, xEnd)
% resampleLine 等弧长步进加密 + 局部倾角
%   沿分段拟合线 fun 用 fsolve 求解等弧长(step)的下一加密点；
%   输出加密测线 line 及各点局部倾角 Angel(差分 atan2(dY,dX))，供覆盖旋转坐标。
%   输入: fun  - 分段拟合函数句柄 fun(x)
%         x0,y0- 起始点
%         step - 弧长步长(检波线 rint=25, CMP面元 cint=12.5)
%         nmax - 最大加密点数
%         xEnd - 测线终点 X（到达即止）
%   输出: line - n x2 等弧长加密测线 [X Y]
%         Angel- n x1 局部倾角
% 注: 显式收紧 fsolve 容差(原仅 Display off)；X~1e6 量级下默认容差偏松。
line = zeros(nmax, 2); line(1,:) = [x0, y0];
a = x0; b = y0; n = 1; done = false;
opts = optimoptions('fsolve', 'Display', 'off', ...
                    'TolFun', 1e-8, 'TolX', 1e-8, 'MaxIterations', 100);
for i = 2:nmax
    f = @(x) [(x(1)-a)^2 + (x(2)-b)^2 - step^2;  x(2) - fun(x(1))];
    [ans1, ~, ef] = fsolve(f, [a+step, fun(a+step)], opts);
    if ef <= 0 || ~isfinite(ans1(1)) || ans1(1) <= a   % 未收敛则回退到弧长近似
        ans1 = [a+step, fun(a+step)];
    end
    line(i,:) = ans1;
    a = ans1(1); b = ans1(2);
    if a >= xEnd, n = i; done = true; break; end
end
if ~done, n = nmax; end
line = line(1:n, :);
dX = diff(line(:,1)); dY = diff(line(:,2));
Angel = atan2(dY, dX); Angel = [Angel; Angel(end)];
end