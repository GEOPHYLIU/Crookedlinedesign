function CrookedCMP_app
% CrookedCMP_app  二维弯线采集测线优化工具(完整交互界面)
%   App: 加载显示(可悬停看点号) + 参数面板 + 运行 + 图(测线/覆盖) + 覆盖统计表
%   点号 = loadPoints 按 X 升序后的行号; 鼠标悬停显示点号/坐标
%   配对方式: 按最大偏移距(maxoffset/2反演, maxoffset正演) / 滚进滚出(noff/2,noff)
%   面元: 用户填全宽 binX/binY, 内部派生 半宽cxHalf/cyHalf 与 步长cint=binX
%   次数: polyR/polyC 为搜索范围[最小 最大], 每段各自自动选(残差下降<5%)
%   断点: 个数 nBreak(1~5), 位置自动(趋势剧变点), 数据源可选 炮点/CMP线
%   范围裁剪: 仅检波点, 按点号区间(排序后序号), 留空=全部
%   迭代流程: 设"迭代次数上限" → "迭代对比" → 选"最终迭代次数" → "应用" → "运行"
%   运行: 命令窗口执行  CrookedCMP_app
% =====================================================================
clc; close all;
% 启动并行池(4核)
if isempty(gcp('nocreate'))
    parpool('local', 4);
end
FS = 10;
handles = struct();
handles.raw = struct();
handles.lastRes = [];
handles.finalCalnum = 3;
handles.appliedCalnum = false;   % 是否已通过"应用"设定最终迭代次数
handles.fig = uifigure('Name','Crooked Line Design V3.5','Position',[60 40 1280 800]);
root = uigridlayout(handles.fig,[1 2]);
root.ColumnWidth = {400,'1x'}; root.RowHeight = {'1x'}; root.Padding = [5 5 5 5];

%% ---- 左: 数据与参数面板 ----
handles.leftP = uipanel(root,'Title','数据与参数'); handles.leftP.Layout.Row=1; handles.leftP.Layout.Column=1;
gL = uigridlayout(handles.leftP,[4 1]);
gL.RowHeight = {100,100,295,'1x'};
gL.Padding = [3 3 3 3];

% --- 数据文件 ---
dataP = uipanel(gL,'Title','输入数据文件'); dataP.Layout.Row=1;
gD = uigridlayout(dataP,[3 3]);
gD.ColumnWidth={'1x','2x',52};
gD.RowHeight={18,18,18};
gD.Padding=[2 2 2 2];
uilabel(gD,'Text','检波点','FontSize',FS);
handles.recvEdit = uieditfield(gD,'text','Value','Crookedline-Receivers.csv','FontSize',FS);
handles.recvBtn = uibutton(gD,'Text','浏览','FontSize',FS,'ButtonPushedFcn',@(s,e)browseCb(s,'recv'));
uilabel(gD,'Text','炮点','FontSize',FS);
handles.shotsEdit= uieditfield(gD,'text','Value','Crookedline-Shots.csv','FontSize',FS);
handles.shotsBtn= uibutton(gD,'Text','浏览','FontSize',FS,'ButtonPushedFcn',@(s,e)browseCb(s,'shots'));
uilabel(gD,'Text','CMP线','FontSize',FS);
handles.cmpEdit  = uieditfield(gD,'text','Value','Crooked line23 CMP.txt','FontSize',FS);
handles.cmpBtn = uibutton(gD,'Text','浏览','FontSize',FS,'ButtonPushedFcn',@(s,e)browseCb(s,'cmp'));

% --- 范围与配对 ---
rngP = uipanel(gL,'Title','范围与配对'); rngP.Layout.Row=2;
gR = uigridlayout(rngP,[3 3]);
gR.ColumnWidth={'0.9x','1.1x','1.1x'};
gR.RowHeight={18,18,18};
gR.Padding=[2 2 2 2];
uilabel(gR,'Text','点号起','FontSize',FS);
handles.rIdx1Edit = uieditfield(gR,'text','Value','','FontSize',FS);
uilabel(gR,'Text','留空=全部','FontSize',FS);
uilabel(gR,'Text','点号止','FontSize',FS);
handles.rIdx2Edit = uieditfield(gR,'text','Value','','FontSize',FS);
handles.loadBtn = uibutton(gR,'Text','加载并显示','FontSize',FS,'ButtonPushedFcn',@(s,e)loadShowCb(s));
uilabel(gR,'Text','配对方式','FontSize',FS);
handles.pairDrop = uidropdown(gR,'Items',{'按最大偏移距','滚进滚出'},'Value','按最大偏移距','FontSize',FS);
uilabel(gR,'Text','','FontSize',FS);

% --- 计算参数 ---
parP = uipanel(gL,'Title','计算参数'); parP.Layout.Row=3;
gP = uigridlayout(parP,[10 2]); gP.ColumnWidth={'1x','2x'};
gP.RowHeight=repmat({18},1,10); gP.Padding=[2 2 2 2];
uilabel(gP,'Text','最大炮检距设定 (m)','FontSize',FS);      handles.noffEdit = uieditfield(gP,'numeric','Value',2000,'FontSize',FS);
uilabel(gP,'Text','理论最大炮检距 (m)','FontSize',FS);     handles.maxoffsetEdit = uieditfield(gP,'numeric','Value',4000,'FontSize',FS);
uilabel(gP,'Text','面元X (m)','FontSize',FS);             handles.binXEdit = uieditfield(gP,'numeric','Value',12.5,'FontSize',FS);
uilabel(gP,'Text','面元Y (m,空格分隔)','FontSize',FS);     handles.binYEdit = uieditfield(gP,'text','Value','300 600','FontSize',FS);
uilabel(gP,'Text','检波点距 (m)','FontSize',FS);           handles.rintEdit = uieditfield(gP,'numeric','Value',25,'FontSize',FS);
uilabel(gP,'Text','检波次数范围 (最小 最大)','FontSize',FS); handles.polyREdit = uieditfield(gP,'text','Value','2 6','FontSize',FS);
uilabel(gP,'Text','CMP次数范围 (最小 最大)','FontSize',FS);  handles.polyCEdit = uieditfield(gP,'text','Value','2 6','FontSize',FS);
uilabel(gP,'Text','断点个数 (1~5)','FontSize',FS);          handles.nBreakEdit = uieditfield(gP,'numeric','Value',1,'FontSize',FS);
uilabel(gP,'Text','断点数据源','FontSize',FS);              handles.breakSrcDrop = uidropdown(gP,'Items',{'炮点','CMP线'},'Value','炮点','FontSize',FS);
uilabel(gP,'Text','容差 窗口','FontSize',FS);              handles.errRangeEdit = uieditfield(gP,'text','Value','100 1500','FontSize',FS);

% --- 数据驱动结果 / 迭代对比 / 运行 / 导出 / 日志 ---
ctrlP = uipanel(gL,'Title','数据驱动结果'); ctrlP.Layout.Row=4;
gC = uigridlayout(ctrlP,[8 1]);
gC.RowHeight={16,36,25,25,5,25,25,'1x'};
gC.RowSpacing=2; gC.ColumnSpacing=2; gC.Padding=[2 2 2 2];
handles.rangeLabel = uilabel(gC,'Text','检波范围: -   CMP范围: -  断点: -','FontSize',FS);
handles.statLabel  = uilabel(gC,'Text','','FontSize',FS,'VerticalAlignment','top');
gIt = uigridlayout(gC,[1 3]); gIt.ColumnWidth={'1x',64,72}; gIt.RowHeight={22}; gIt.RowSpacing=0; gIt.ColumnSpacing=2; gIt.Padding=[0 0 0 0];
uilabel(gIt,'Text','迭代次数上限','FontSize',FS); handles.maxitEdit=uieditfield(gIt,'numeric','Value',5,'FontSize',FS);
handles.scanBtn=uibutton(gIt,'Text','迭代对比','FontSize',FS,'ButtonPushedFcn',@(s,e)scanCb(s));
gSel = uigridlayout(gC,[1 3]); gSel.ColumnWidth={'1x',64,72}; gSel.RowHeight={22}; gSel.RowSpacing=0; gSel.ColumnSpacing=2; gSel.Padding=[0 0 0 0];
uilabel(gSel,'Text','最终迭代次数','FontSize',FS); handles.itSelDrop=uidropdown(gSel,'Items',{'1'},'Value','1','FontSize',FS);
handles.applyItBtn=uibutton(gSel,'Text','应用','FontSize',FS,'ButtonPushedFcn',@(s,e)applyItCb(s));
gItRun = uigridlayout(gC,[1 3]); gItRun.ColumnWidth={'1x',64,72}; gItRun.RowHeight={22}; gItRun.RowSpacing=0; gItRun.ColumnSpacing=2; gItRun.Padding=[0 0 0 0];
uilabel(gItRun,'Text','','FontSize',FS);
uilabel(gItRun,'Text','','FontSize',FS); uilabel(gItRun,'Text','','FontSize',FS);
handles.runBtn = uibutton(gC,'Text','运行','FontWeight','bold','FontSize',FS,'ButtonPushedFcn',@(s,e)runCb(s));
handles.exportBtn = uibutton(gC,'Text','导出检波点（优化后）','FontSize',FS,'ButtonPushedFcn',@(s,e)exportCb(s));
handles.logArea = uitextarea(gC,'Editable','off','FontSize',FS, ...
    'Value',{'本程序可互换检波点炮点输入实现炮点优化（实际很少用）；点击"加载并显示"查看点位与点号, 再填范围/配对方式, 测试迭代次数，最后"运行，输出"'});

%% ---- 右: 图与结果 ----
handles.tabs = uitabgroup(root); handles.tabs.Layout.Row=1; handles.tabs.Layout.Column=2;
handles.tab0 = uitab(handles.tabs,'Title','点位查看(可悬停看号)');
g0 = uigridlayout(handles.tab0,[1 1]); g0.Padding=[4 4 4 4];
handles.axRaw = uiaxes(g0); handles.axRaw.FontSize=FS;
handles.tab1 = uitab(handles.tabs,'Title','测线与点位');
g1 = uigridlayout(handles.tab1,[1 1]); g1.Padding=[4 4 4 4];
handles.axLine = uiaxes(g1); handles.axLine.FontSize=FS;
handles.tab2 = uitab(handles.tabs,'Title','覆盖次数对比');
handles.tab3 = uitab(handles.tabs,'Title','覆盖统计与日志');
g3 = uigridlayout(handles.tab3,[2 1]); g3.RowHeight={'1x',120}; g3.Padding=[4 4 4 4];
handles.statTable = uitable(g3,'FontSize',FS);
g3b = uigridlayout(g3,[1 1]); g3b.Padding=[0 0 0 0];
handles.iterLogArea = uitextarea(g3b,'Editable','off','FontSize',FS);
handles.tab4 = uitab(handles.tabs,'Title','迭代曲线');
g4 = uigridlayout(handles.tab4,[1 2]); g4.Padding=[4 4 4 4];
handles.axDmax = uiaxes(g4); handles.axDmax.FontSize=FS;
handles.axFold = uiaxes(g4); handles.axFold.FontSize=FS;
handles.tab5 = uitab(handles.tabs,'Title','新老CMP偏差');
g5 = uigridlayout(handles.tab5,[1 1]); g5.Padding=[4 4 4 4];
handles.axDev = uiaxes(g5); handles.axDev.FontSize=FS;

setappdata(handles.fig,'h',handles);
end

% =====================================================================
function browseCb(s, field)
h = getappdata(ancestor(s,'figure'),'h');
[f,pth] = uigetfile({'*.csv;*.txt','数据文件 (*.csv,*.txt)';'*.*','所有文件'},'选择数据文件');
if isequal(f,0), return; end
switch field
    case 'recv',  h.recvEdit.Value = fullfile(pth,f);
    case 'shots', h.shotsEdit.Value = fullfile(pth,f);
    case 'cmp',   h.cmpEdit.Value   = fullfile(pth,f);
end
end

function loadShowCb(s)
h = getappdata(ancestor(s,'figure'),'h');
try
    files = getInputFiles(h);
    h.raw.R0   = loadPoints(files.recv);
    h.raw.S    = loadPoints(files.shots);
    h.raw.CMP0 = loadPoints(files.cmp);
    setappdata(h.fig,'h',h);
    ax = h.axRaw; cla(ax); hold(ax,'on');
    pR = plot(ax, h.raw.R0(:,1), h.raw.R0(:,2), '.', 'Color',[0.3 0.3 0.8], 'MarkerSize',8);
    pS = plot(ax, h.raw.S(:,1),  h.raw.S(:,2),  '.', 'Color',[0.9 0.5 0.1], 'MarkerSize',3);
    pC = plot(ax, h.raw.CMP0(:,1), h.raw.CMP0(:,2), '.', 'Color',[0 0.6 0.3], 'MarkerSize',6);
    hold(ax,'off');
    axis(ax,'equal'); grid(ax,'on'); xlabel(ax,'X (m)'); ylabel(ax,'Y (m)');
    title(ax,'点位查看: 鼠标悬停显示 点号/坐标 (检波点=排序后行号)');
    legend(ax,{'检波点','炮点','初始CMP'},'Location','best');
    dc = datacursormode(h.fig);
    set(dc,'UpdateFcn',@(obj,evt) dcUpdate(obj,evt,h.raw));
    setappdata(h.fig,'pR',pR); setappdata(h.fig,'pS',pS); setappdata(h.fig,'pC',pC);
    h.logArea.Value = {sprintf('已加载: 检波点%d, 炮点%d, CMP%d', ...
        size(h.raw.R0,1), size(h.raw.S,1), size(h.raw.CMP0,1)), ...
        '在"点位查看"页签鼠标悬停可看 点号/坐标, 再填检波点点号范围'};
catch ME
    h.logArea.Value = {['加载出错: ' ME.message]}; beep;
end
end

function txt = dcUpdate(~,evt,raw)
pos = evt.Position; tgt = evt.Target;
tp = '点'; idx = NaN;
try
    fig = ancestor(tgt,'figure');
    if isequal(tgt,getappdata(fig,'pR'))
        tp='检波点'; d=raw.R0;
    elseif isequal(tgt,getappdata(fig,'pS'))
        tp='炮点'; d=raw.S;
    else
        tp='初始CMP'; d=raw.CMP0;
    end
    if ~isempty(d)
        [~,idx] = min(hypot(d(:,1)-pos(1), d(:,2)-pos(2)));
    end
catch
end
if isnan(idx)
    txt = sprintf('%s  X=%.1f Y=%.1f', tp, pos(1), pos(2));
else
    txt = sprintf('%s #%d  X=%.1f Y=%.1f', tp, idx, pos(1), pos(2));
end
end

function runCb(s)
h = getappdata(ancestor(s,'figure'),'h');
h.runBtn.Enable='off'; h.runBtn.Text='运行中...'; drawnow;
try
    p = readParams(h);
    if ~h.appliedCalnum
        h.logArea.Value = {'未做迭代对比/应用时按默认3次运行; 建议先"迭代对比"再"应用"选定次数'}; drawnow;
    end
    files = getInputFiles(h);
    res = crooked_core(p, files);
    bl = res.p.breakList;
    blStr = strjoin(arrayfun(@(i)sprintf('(%.0f,%.0f)',bl(i,1),bl(i,2)), ...
        1:size(bl,1),'UniformOutput',false), ' ');
    h.rangeLabel.Text = sprintf('检波 %.0f~%.0f | CMP %.0f~%.0f | 断点 %s [源:%s]', ...
        res.p.rstart(1),res.p.rend(1),res.p.cstart(1),res.p.cend(1), blStr, res.p.breakSrcUsed);
    stats = cell(numel(res.p.binY),1);
    for n=1:numel(res.p.binY)
        stats{n} = sprintf('面元 %.1f x %.0fm  新测线 mean=%.1f std=%.1f max=%d | 老测线 mean=%.1f std=%.1f max=%d', ...
            res.p.binX,res.p.binY(n),mean(res.foldn(:,n)),std(res.foldn(:,n)),max(res.foldn(:,n)), ...
            mean(res.foldo(:,n)),std(res.foldo(:,n)),max(res.foldo(:,n)));
    end
    h.statLabel.Text = strjoin(stats,newline);
    h.logArea.Value  = res.iterLog;
    h.logArea.Value = [h.logArea.Value(:); ...
        {sprintf('断点个数=%d, 坐标=%s, 数据源=%s', size(res.p.breakList,1), blStr, res.p.breakSrcUsed)}];
    h.iterLogArea.Value = [res.iterLog(:); stats];
    h.lastRes = res;
    setappdata(h.fig,'h',h);
    plotLine(h,res); plotCoverage(h,res); fillTable(h,res); plotDev(h,res);
catch ME
    fprintf(2,'[runCb] %s\n',ME.message);
    h.logArea.Value = {['运行出错: ' ME.message]}; beep;
end
h.runBtn.Text='运行'; h.runBtn.Enable='on';
end

function p = readParams(h)
p.noff=h.noffEdit.Value; p.maxoffset=h.maxoffsetEdit.Value;
p.binX=h.binXEdit.Value;
p.binY=str2num(h.binYEdit.Value); if isempty(p.binY), p.binY=[300 600]; end %#ok<ST2NM>
p.rint=h.rintEdit.Value;
p.pairMode = 'maxoffset';
if strcmp(h.pairDrop.Value,'滚进滚出'), p.pairMode='roll'; end
p.polyR=str2num(h.polyREdit.Value); if isempty(p.polyR)||numel(p.polyR)~=2, p.polyR=[2 6]; end %#ok<ST2NM>
p.polyC=str2num(h.polyCEdit.Value); if isempty(p.polyC)||numel(p.polyC)~=2, p.polyC=[2 6]; end %#ok<ST2NM>
p.nBreak = max(1, min(5, round(h.nBreakEdit.Value)));
p.breakSrc = 'shot';
if strcmp(h.breakSrcDrop.Value,'CMP线'), p.breakSrc='cmp'; end
er=str2num(h.errRangeEdit.Value); if numel(er)>=2, p.error1=er(1); p.range1=er(2); else, p.error1=100; p.range1=1500; end %#ok<ST2NM>
p.calnum = h.finalCalnum;
v1s = strtrim(h.rIdx1Edit.Value);
v2s = strtrim(h.rIdx2Edit.Value);
if isempty(v1s) && isempty(v2s)
    p.rIdx = [];
else
    v1 = str2double(v1s); v2 = str2double(v2s);
    if isnan(v1) || isnan(v2)
        error('检波点点号起/止需同时填写有效数字，或同时留空');
    end
    p.rIdx = [round(v1), round(v2)];
end
end

function plotLine(h,res)
ax=h.axLine; cla(ax); hold(ax,'on');
plot(ax,res.R0(:,1),res.R0(:,2),'.','Color',[0.65 0.65 0.65],'MarkerSize',2);
plot(ax,res.S(:,1),res.S(:,2),'.','Color',[0.9 0.5 0.1],'MarkerSize',1);
plot(ax,res.CMP0(:,1),res.CMP0(:,2),'--','Color',[0 0.6 0.3],'LineWidth',1.2);
plot(ax,res.CMP(:,1),res.CMP(:,2),'-r','LineWidth',1.6);
plot(ax,res.R1(:,1),res.R1(:,2),'-b','LineWidth',1.2);
for k = 1:size(res.p.breakList,1)
    plot(ax,res.p.breakList(k,1),res.p.breakList(k,2),'x','Color',[0.8 0 0], ...
        'MarkerSize',12,'LineWidth',2);
end
hold(ax,'off');
xs=[res.R0(:,1);res.S(:,1);res.CMP0(:,1);res.CMP(:,1);res.R1(:,1)];
ys=[res.R0(:,2);res.S(:,2);res.CMP0(:,2);res.CMP(:,2);res.R1(:,2)];
xlim(ax,[min(xs)-1000 max(xs)+1000]); ylim(ax,[min(ys)-1000 max(ys)+1000]); axis(ax,'equal');
ax.XLabel.String='X (m)'; ax.YLabel.String='Y (m)';
legend(ax,{'检波点','炮点','初始CMP','新CMP线','检波线','断点'},'Location','best');
title(ax,sprintf('测线与点位 (迭代%d次, 配对=%s, 断点源=%s)',res.p.calnum,res.p.pairMode,res.p.breakSrcUsed));
end

function plotCoverage(h,res)
delete(h.tab2.Children);
nc=numel(res.p.binY);
g2 = uigridlayout(h.tab2,[1 nc]);
for n=1:nc
    ax=uiaxes(g2); hold(ax,'on');
    plot(ax,res.foldn(:,n),'-r','LineWidth',1.5);
    plot(ax,res.foldo(:,n),'.b','MarkerSize',6);
    hold(ax,'off');
    xlabel(ax,'面元编号'); ylabel(ax,'覆盖次数');
    title(ax,sprintf('面元 %.1f x %.0fm',res.p.binX,res.p.binY(n)));
    if n==1, legend(ax,{'新测线','老测线'},'Location','best'); end
    grid(ax,'on'); axis(ax,'tight');
end
end

function fillTable(h,res)
nc=numel(res.p.binY);
data=cell(nc,7);
for n=1:nc
    data(n,:)={sprintf('%.1f x %.0f m',res.p.binX,res.p.binY(n)), ...
        sprintf('%.1f',mean(res.foldn(:,n))),sprintf('%.1f',std(res.foldn(:,n))),sprintf('%d',max(res.foldn(:,n))), ...
        sprintf('%.1f',mean(res.foldo(:,n))),sprintf('%.1f',std(res.foldo(:,n))),sprintf('%d',max(res.foldo(:,n)))};
end
h.statTable.Data=data;
h.statTable.ColumnName={'面元尺寸','新测线mean','std','max','老测线mean','std','max'};
h.statTable.ColumnWidth={110,90,60,50,90,60,50};
end

function plotDev(h,res)
ax=h.axDev; cla(ax);
plot(ax, res.CMP(:,1), res.dCMP, '.', 'Color',[0.2 0.4 0.8]); hold(ax,'on');
yline(ax, 0, 'k--');
for k = 1:size(res.p.breakList,1)
    xline(ax, res.p.breakList(k,1), 'r--', 'LineWidth',1);
end
hold(ax,'off'); grid(ax,'on');
xlabel(ax,'X (m)'); ylabel(ax,'新CMP - 初始CMP (m)');
title(ax,'新老CMP线偏差 (红线=断点)');
end

function files = getInputFiles(h)
appDir = fileparts(mfilename('fullpath'));
names = {h.recvEdit.Value, h.shotsEdit.Value, h.cmpEdit.Value};
for k=1:3
    nm = strtrim(names{k});
    if isempty(nm), error('请填写第%d个输入文件路径', k); end
    if ~exist(nm,'file') && ~isempty(appDir)
        ap = fullfile(appDir, nm);
        if exist(ap,'file'), nm = ap; end
    end
    if ~exist(nm,'file'), error('找不到输入文件: %s', nm); end
    names{k} = nm;
end
files = struct('recv',names{1},'shots',names{2},'cmp',names{3});
end

function scanCb(s)
h = getappdata(ancestor(s,'figure'),'h');
h.scanBtn.Enable='off'; h.scanBtn.Text='对比中...'; drawnow;
try
    maxit = round(h.maxitEdit.Value); if maxit<1, maxit=1; end
    files = getInputFiles(h);
    dmax = zeros(maxit,1); f150 = zeros(maxit,1); f300 = nan(maxit,1);
    for k=1:maxit
        pk = readParams(h);
        pk.calnum = k;
        res = crooked_core(pk, files);
        n = numel(res.iterLog);
        tok = regexp(res.iterLog{n},'偏差([0-9.]+)m','tokens');
        if ~isempty(tok), dmax(k)=str2double(tok{1}{1}); end
        f150(k) = mean(res.foldn(:,1));
        if size(res.foldn,2)>=2, f300(k)=mean(res.foldn(:,2)); end
        h.logArea.Value = {sprintf('迭代对比 k=%d: 偏差=%.1fm, 新测线150m覆盖=%.1f',k,dmax(k),f150(k))};
        drawnow;
    end
    h.itSelDrop.Items = arrayfun(@(x)num2str(x),1:maxit,'UniformOutput',false);
    plotIterCurve(h,dmax,f150,f300,maxit);
    h.logArea.Value = [h.logArea.Value(:); {'迭代对比完成, 请选择最终迭代次数并"应用", 再"运行"'}];
catch ME
    fprintf(2,'[scanCb] id=%s msg=%s\n', ME.identifier, ME.message);
    for kk=1:numel(ME.stack)
        fprintf(2,'   at %s (line %d)\n',ME.stack(kk).name,ME.stack(kk).line);
    end
    try
        h.logArea.Value = {sprintf('迭代对比 k=%d 出错: %s', k, ME.message)}; catch, end
    beep;
end
h.scanBtn.Text='迭代对比'; h.scanBtn.Enable='on';
end


function applyItCb(s)
h = getappdata(ancestor(s,'figure'),'h');
v = str2double(h.itSelDrop.Value);
if isnan(v), v = 3; end
h.finalCalnum = round(v);
h.appliedCalnum = true;          % 标记已应用(无论选的次数是多少)
setappdata(h.fig,'h',h);
h.logArea.Value = {sprintf('最终迭代次数已设为 %d, 请点"运行"生成最终结果', h.finalCalnum)};
end

function exportCb(s)
h = getappdata(ancestor(s,'figure'),'h');
if ~isfield(h,'lastRes') || isempty(h.lastRes)
    h.logArea.Value = {'请先点"运行"生成结果, 再导出最终检波点'}; beep; return;
end
res = h.lastRes;
T = table((1:size(res.rfinal,1))', res.rfinal(:,1), res.rfinal(:,2), ...
    'VariableNames', {'PointNo','X','Y'});
[fn,pth] = uiputfile('Final_Receivers.csv','保存最终检波点(CSV)');
if isequal(fn,0), return; end
fpath = fullfile(pth,fn);
writetable(T, fpath);
h.logArea.Value = {sprintf('已导出最终检波点 %d 点(等弧长%.0fm): %s', ...
    size(res.rfinal,1), res.p.rint, fpath)};
end

function plotIterCurve(h,dmax,f150,f300,maxit)
x = 1:maxit;
cla(h.axDmax); plot(h.axDmax,x,dmax,'-o','LineWidth',1.5);
xlabel(h.axDmax,'迭代次数'); ylabel(h.axDmax,'新CMP线最大偏差 (m)'); grid(h.axDmax,'on');
title(h.axDmax,'正反演偏差随迭代次数收敛');
cla(h.axFold); plot(h.axFold,x,f150,'-o','LineWidth',1.5); hold(h.axFold,'on');
if ~all(isnan(f300)), plot(h.axFold,x,f300,'-s','LineWidth',1.5); end
hold(h.axFold,'off');
xlabel(h.axFold,'迭代次数'); ylabel(h.axFold,'新测线覆盖 mean'); grid(h.axFold,'on');
legend(h.axFold,{'150m','300m'},'Location','best');
title(h.axFold,'新测线覆盖随迭代次数');
end