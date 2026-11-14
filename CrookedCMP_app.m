function CrookedCMP_app(startPool)
% =====================================================================
% CrookedCMP_app  二维弯线采集测线优化工具 (Windows 11 风格界面)
% ---------------------------------------------------------------------
%   界面: 标题栏(品牌 / 运行 / 导出) + 左侧卡片式参数 + 右侧下划线页签
%         + 底部状态栏(指示灯 / 提示 / 并行池 / 版本)
%   视觉: 底色 #F3F3F3 · 卡片 #FFFFFF · 描边 #E0E0E0 · accent #0067C0
%         正文 Microsoft YaHei UI 11pt · 标题 14pt 半粗
%   点号 = loadPoints 按 X 升序后的行号; 鼠标悬停显示点号/坐标
%   配对方式: 按最大偏移距(maxoffset/2反演, maxoffset正演) / 滚进滚出(noff/2,noff)
%   面元: 用户填全宽 binX/binY, 内部派生 半宽cxHalf/cyHalf 与 步长cint=binX
%   次数: polyR/polyC 为搜索范围[最小 最大], 每段各自自动选(残差下降<5%)
%   断点: 个数 nBreak(1~5), 位置自动(趋势剧变点), 数据源可选 炮点/CMP线
%   范围裁剪: 仅检波点, 按点号区间(排序后序号), 留空=全部
%   迭代流程: 设"迭代次数上限" → "迭代对比" → 选"最终迭代次数" → "应用" → "运行"
%   运行: 命令窗口执行  CrookedCMP_app   (CrookedCMP_app(false) 跳过并行池启动)
% =====================================================================
if nargin < 1 || isempty(startPool), startPool = true; end
clc; close all;

t = uiTheme();

% --- 并行池(启动失败则退化为串行) ---
poolNote = '并行 · 未启动';
if startPool
    try
        pool = gcp('nocreate');
        if isempty(pool), pool = parpool('local', 4); end
        poolNote = sprintf('并行 · %d 核', pool.NumWorkers);
    catch ME
        poolNote = '并行不可用 · 串行计算';
        warning('CrookedCMP_app:pool','并行池启动失败: %s', ME.message);
    end
end

handles = struct();
handles.t = t;
handles.raw = struct();
handles.lastRes = [];
handles.finalCalnum = 3;
handles.appliedCalnum = false;      % 是否已通过"应用"设定最终迭代次数
handles.appDir = fileparts(mfilename('fullpath'));
handles.pageIdx = 1;

%% ================= 窗口 =================
handles.fig = uifigure('Name','弯线测线优化设计  V3.5','Position',[30 25 1340 770],'Color',t.bg);
try
    handles.fig.Icon = fullfile(handles.appDir,'CrookedLineDesginV3_resources','icon_48.png');
catch
end

root = uigridlayout(handles.fig,[3 1]);
root.RowHeight = {62,'1x',31};
root.Padding = [0 0 0 0]; root.RowSpacing = 0; root.BackgroundColor = t.bg;

%% ================= 标题栏 =================
head = uigridlayout(root,[2 1]);
head.RowHeight = {61,1}; head.Padding = [0 0 0 0]; head.RowSpacing = 0;
head.BackgroundColor = t.card;

hbar = uigridlayout(head,[1 3]);
hbar.ColumnWidth = {'1x',106,96};
hbar.Padding = [18 7 14 7]; hbar.ColumnSpacing = 10; hbar.BackgroundColor = t.card;

% 品牌区: 面板 + 绝对定位(网格内自适应列宽时避免文本被裁)
brandP = uipanel(hbar,'BorderType','none','BackgroundColor',t.card);
try
    ic = uiimage(brandP,'ImageSource',fullfile(handles.appDir,'CrookedLine_icon.png'));
    ic.Position = [2 7 34 34];
catch
end
uilabel(brandP,'Text','弯线测线优化设计','FontName',t.fUI,'FontSize',14,'FontWeight','bold', ...
    'FontColor',t.text,'Position',[46 24 470 22],'VerticalAlignment','bottom');
uilabel(brandP,'Text','Crooked Line Design · V3.5 · 二维弯线采集测线优化', ...
    'FontName',t.fUI,'FontSize',9.5,'FontColor',t.textFaint, ...
    'Position',[46 3 470 18],'VerticalAlignment','top');

handles.runBtn = uibutton(hbar,'Text','▶  运行', ...
    'BackgroundColor',t.accent,'FontColor',[1 1 1],'FontName',t.fUI,'FontSize',12, ...
    'FontWeight','bold','Tooltip','按当前参数执行完整流程(反演→正演→拟合→迭代→加密→覆盖统计)', ...
    'ButtonPushedFcn',@(s,e)runCb(s));
handles.exportBtn = uibutton(hbar,'Text','导出结果', ...
    'BackgroundColor',t.btnSoft,'FontColor',t.text,'FontName',t.fUI,'FontSize',12, ...
    'Tooltip','将优化后的检波点 (点号, X, Y) 导出为 CSV', ...
    'ButtonPushedFcn',@(s,e)exportCb(s));
uipanel(head,'BackgroundColor',t.line,'BorderType','none');

%% ================= 主体 =================
body = uigridlayout(root,[1 2]);
body.ColumnWidth = {436,'1x'}; body.Padding = [12 8 12 8];
body.ColumnSpacing = 12; body.RowSpacing = 0; body.BackgroundColor = t.bg;

leftStack = uigridlayout(body,[3 1]);
leftStack.RowHeight = {220,'1x',196}; leftStack.Padding = [0 0 0 0];
leftStack.RowSpacing = 8; leftStack.BackgroundColor = t.bg;

% --- 卡片1: 输入数据与测线范围 ---
gD = addCard(leftStack, t, '输入数据与测线范围', 7, {24,24,24,5,24,24,28}, 3, {78,'1x',46});
uilabel(gD,'Text','检波点','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text);
handles.recvEdit = uieditfield(gD,'text','Value','Crookedline-Receivers.csv', ...
    'FontName',t.fUI,'FontSize',t.fsSmall,'Tooltip','检波点坐标文件(CSV/TXT)');
handles.recvBtn = uibutton(gD,'Text','…','FontName',t.fUI,'FontSize',t.fsSmall, ...
    'BackgroundColor',t.btnSoft,'FontColor',t.text,'Tooltip','浏览选择检波点文件', ...
    'ButtonPushedFcn',@(s,e)browseCb(s,'recv'));
uilabel(gD,'Text','炮点','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text);
handles.shotsEdit = uieditfield(gD,'text','Value','Crookedline-Shots.csv', ...
    'FontName',t.fUI,'FontSize',t.fsSmall,'Tooltip','炮点坐标文件(CSV/TXT)');
handles.shotsBtn = uibutton(gD,'Text','…','FontName',t.fUI,'FontSize',t.fsSmall, ...
    'BackgroundColor',t.btnSoft,'FontColor',t.text,'Tooltip','浏览选择炮点文件', ...
    'ButtonPushedFcn',@(s,e)browseCb(s,'shots'));
uilabel(gD,'Text','CMP线','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text);
handles.cmpEdit = uieditfield(gD,'text','Value','Crooked line23 CMP.txt', ...
    'FontName',t.fUI,'FontSize',t.fsSmall,'Tooltip','初始CMP线坐标文件(两列 X,Y)');
handles.cmpBtn = uibutton(gD,'Text','…','FontName',t.fUI,'FontSize',t.fsSmall, ...
    'BackgroundColor',t.btnSoft,'FontColor',t.text,'Tooltip','浏览选择CMP线文件', ...
    'ButtonPushedFcn',@(s,e)browseCb(s,'cmp'));
hSep = uipanel(gD,'BackgroundColor',t.lineSoft,'BorderType','none');
hSep.Layout.Row = 4; hSep.Layout.Column = [1 3];
uilabel(gD,'Text','点号范围','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','检波点点号 = 按 X 升序排序后的行号');
rgNo = uigridlayout(gD,[1 2]); rgNo.Layout.Row = 5; rgNo.Layout.Column = [2 3];
rgNo.ColumnWidth = {'1x','1x'}; rgNo.ColumnSpacing = 8; rgNo.Padding = [0 0 0 0];
rgNo.RowSpacing = 0; rgNo.BackgroundColor = t.card;
handles.rIdx1Edit = uieditfield(rgNo,'text','Value','','Placeholder','起 · 留空=全部', ...
    'FontName',t.fUI,'FontSize',t.fsSmall,'Tooltip','起始点号, 留空表示从首点开始');
handles.rIdx2Edit = uieditfield(rgNo,'text','Value','','Placeholder','止 · 留空=全部', ...
    'FontName',t.fUI,'FontSize',t.fsSmall,'Tooltip','结束点号, 留空表示到末点为止');
uilabel(gD,'Text','配对方式','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','按最大偏移距: 反演半径 maxoffset/2; 滚进滚出: 反演半径 noff/2 并截断有效段');
handles.pairDrop = uidropdown(gD,'Items',{'按最大偏移距','滚进滚出'},'Value','按最大偏移距', ...
    'FontName',t.fUI,'FontSize',t.fsSmall,'Tooltip','检波点反演与CMP正演的配对半径口径');
handles.pairDrop.Layout.Column = [2 3];
handles.loadBtn = uibutton(gD,'Text','加载并显示点位', ...
    'BackgroundColor',t.accentSoft,'FontColor',t.accent,'FontName',t.fUI,'FontSize',t.fsSmall, ...
    'FontWeight','bold','Tooltip','读取三个文件并绘点位, 可在「点位查看」页悬停看点号', ...
    'ButtonPushedFcn',@(s,e)loadShowCb(s));
handles.loadBtn.Layout.Row = 7; handles.loadBtn.Layout.Column = [1 3];

% --- 卡片2: 计算参数 ---
gP = addCard(leftStack, t, '计算参数', 5, repmat({'1x'},1,5), 4, {100,86,100,'1x'});
uilabel(gP,'Text','最大炮检距 m','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','近偏移距上限, 超过该值的道对在优化时剔除');
handles.noffEdit = uieditfield(gP,'numeric','Value',2000,'FontName',t.fUI, ...
    'FontSize',t.fsSmall,'HorizontalAlignment','left');
uilabel(gP,'Text','理论最大偏移距 m','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','设计最大炮检距, 按最大偏移距配对时用于正演');
handles.maxoffsetEdit = uieditfield(gP,'numeric','Value',4000,'FontName',t.fUI, ...
    'FontSize',t.fsSmall,'HorizontalAlignment','left');
uilabel(gP,'Text','面元X m','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','面元沿测线方向全宽, 同时作为面元步长');
handles.binXEdit = uieditfield(gP,'numeric','Value',12.5,'FontName',t.fUI, ...
    'FontSize',t.fsSmall,'HorizontalAlignment','left');
uilabel(gP,'Text','面元Y m','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','面元垂直测线方向全宽, 可填多个值(空格分隔)做对比');
handles.binYEdit = uieditfield(gP,'text','Value','300 600','FontName',t.fUI,'FontSize',t.fsSmall);
uilabel(gP,'Text','检波点距 m','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','最终检波线等间距加密步长');
handles.rintEdit = uieditfield(gP,'numeric','Value',25,'FontName',t.fUI, ...
    'FontSize',t.fsSmall,'HorizontalAlignment','left');
uilabel(gP,'Text','容差 窗口','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','断点细化容差(m) 与拟合窗口(点数), 空格分隔');
handles.errRangeEdit = uieditfield(gP,'text','Value','100 1500','FontName',t.fUI,'FontSize',t.fsSmall);
uilabel(gP,'Text','检波次数范围','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','检波线分段拟合次数搜索范围[最小 最大], 每段自动择优(残差下降<5%)');
handles.polyREdit = uieditfield(gP,'text','Value','2 6','FontName',t.fUI,'FontSize',t.fsSmall);
uilabel(gP,'Text','CMP次数范围','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','CMP线分段拟合次数搜索范围[最小 最大]');
handles.polyCEdit = uieditfield(gP,'text','Value','2 6','FontName',t.fUI,'FontSize',t.fsSmall);
uilabel(gP,'Text','断点个数 1~5','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','自动断点个数, 位置取测线趋势剧变处');
handles.nBreakEdit = uieditfield(gP,'numeric','Value',1,'FontName',t.fUI, ...
    'FontSize',t.fsSmall,'HorizontalAlignment','left');
uilabel(gP,'Text','断点数据源','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','用炮点线或CMP线判定断点位置');
handles.breakSrcDrop = uidropdown(gP,'Items',{'炮点','CMP线'},'Value','炮点', ...
    'FontName',t.fUI,'FontSize',t.fsSmall,'Tooltip','断点判定所用测线');

% --- 卡片3: 迭代与执行 ---
gI = addCard(leftStack, t, '迭代与执行', 6, {24,24,20,5,30,'1x'}, 4, {64,84,76,'1x'});
l1 = uilabel(gI,'Text','迭代上限','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','「迭代对比」扫描的迭代次数上限');
l1.Layout.Row = 1; l1.Layout.Column = 1;
handles.maxitEdit = uieditfield(gI,'numeric','Value',5,'FontName',t.fUI, ...
    'FontSize',t.fsSmall,'HorizontalAlignment','left','Tooltip','扫描 1..N 次迭代的偏差与覆盖');
handles.maxitEdit.Layout.Row = 1; handles.maxitEdit.Layout.Column = 2;
handles.scanBtn = uibutton(gI,'Text','迭代对比','FontName',t.fUI,'FontSize',t.fsSmall, ...
    'BackgroundColor',t.btnSoft,'FontColor',t.text,'Tooltip','逐个迭代次数跑完整链路并画收敛曲线', ...
    'ButtonPushedFcn',@(s,e)scanCb(s));
handles.scanBtn.Layout.Row = 1; handles.scanBtn.Layout.Column = 3;
l2 = uilabel(gI,'Text','最终次数','FontName',t.fUI,'FontSize',t.fsSmall,'FontColor',t.text, ...
    'Tooltip','本次「运行」实际采用的迭代次数');
l2.Layout.Row = 2; l2.Layout.Column = 1;
handles.itSelDrop = uidropdown(gI,'Items',{'1'},'Value','1','FontName',t.fUI, ...
    'FontSize',t.fsSmall,'Tooltip','迭代对比后在下拉中选择最终迭代次数');
handles.itSelDrop.Layout.Row = 2; handles.itSelDrop.Layout.Column = 2;
handles.applyItBtn = uibutton(gI,'Text','应用','FontName',t.fUI,'FontSize',t.fsSmall, ...
    'BackgroundColor',t.btnSoft,'FontColor',t.text,'Tooltip','确认所选迭代次数, 之后点右上角「运行」', ...
    'ButtonPushedFcn',@(s,e)applyItCb(s));
handles.applyItBtn.Layout.Row = 2; handles.applyItBtn.Layout.Column = 3;
hint = uilabel(gI,'Text','① 迭代对比  →  ② 应用  →  ③ 右上角「运行」', ...
    'FontName',t.fUI,'FontSize',10,'FontColor',t.textFaint,'VerticalAlignment','center');
hint.Layout.Row = 3; hint.Layout.Column = [1 4];
hSep2 = uipanel(gI,'BackgroundColor',t.lineSoft,'BorderType','none');
hSep2.Layout.Row = 4; hSep2.Layout.Column = [1 4];
handles.rangeLabel = uilabel(gI,'Text','检波范围 —     CMP范围 —     断点 —', ...
    'FontName',t.fUI,'FontSize',10,'FontColor',t.textDim,'WordWrap','on', ...
    'VerticalAlignment','top');
handles.rangeLabel.Layout.Row = 5; handles.rangeLabel.Layout.Column = [1 4];
handles.statLabel = uilabel(gI,'Text','覆盖次数统计将在运行后显示', ...
    'FontName',t.fUI,'FontSize',10,'FontColor',t.text,'WordWrap','on', ...
    'VerticalAlignment','top','Tooltip','新/老测线覆盖次数 mean · std · max');
handles.statLabel.Layout.Row = 6; handles.statLabel.Layout.Column = [1 4];

%% ================= 右侧: 下划线页签 + 内容卡片 =================
rightArea = uigridlayout(body,[2 1]);
rightArea.RowHeight = {34,'1x'}; rightArea.Padding = [0 0 0 0];
rightArea.RowSpacing = 0; rightArea.BackgroundColor = t.bg;

tabHost = uigridlayout(rightArea,[2 1]);
tabHost.RowHeight = {31,3}; tabHost.Padding = [0 0 0 0];
tabHost.RowSpacing = 0; tabHost.BackgroundColor = t.bg;

tabNames = {'点位查看','测线与点位','覆盖次数','统计与日志','迭代曲线','新老CMP偏差'};
tabTips  = {'加载后可悬停查看点号与坐标', '优化前后测线与CMP线对比', ...
            '各面元尺寸的新/老测线覆盖次数', '覆盖统计表与运行日志', ...
            '偏差与覆盖随迭代次数的收敛', '新CMP线相对初始CMP线的逐点偏差'};
tabW = repmat({'1x'},1,numel(tabNames));
tabRow = uigridlayout(tabHost,[1 6]);
tabRow.ColumnWidth = tabW; tabRow.RowHeight = {31};
tabRow.Padding = [0 0 0 0]; tabRow.ColumnSpacing = 2; tabRow.BackgroundColor = t.bg;
tabRow.Layout.Row = 1;
ulRow = uigridlayout(tabHost,[1 6]);
ulRow.ColumnWidth = tabW; ulRow.RowHeight = {3};
ulRow.Padding = [0 0 0 0]; ulRow.ColumnSpacing = 2; ulRow.BackgroundColor = t.bg;
ulRow.Layout.Row = 2;
handles.tabBtn = gobjects(1,numel(tabNames));
handles.tabUl  = gobjects(1,numel(tabNames));
for k = 1:numel(tabNames)
    handles.tabBtn(k) = uibutton(tabRow,'Text',tabNames{k},'FontName',t.fUI, ...
        'FontSize',t.fsSmall,'FontColor',t.textDim,'BackgroundColor',t.bg, ...
        'Tooltip',tabTips{k},'ButtonPushedFcn',@(s,e)tabCb(s,k));
    handles.tabUl(k) = uipanel(ulRow,'BackgroundColor',t.bg,'BorderType','none');
    handles.tabUl(k).Layout.Column = k;
    handles.tabUl(k).Layout.Row = 1;
end
cardHost = uipanel(rightArea,'BorderType','line','ForegroundColor',t.line,'BackgroundColor',t.card);
pHost = uigridlayout(cardHost,[1 1]);
pHost.Padding = [0 0 0 0]; pHost.RowSpacing = 0; pHost.BackgroundColor = t.card;

handles.pages = cell(1,6);
for k = 1:6
    pg = uigridlayout(pHost,[1 1]);
    pg.Padding = [14 12 14 14]; pg.RowSpacing = 0;
    pg.BackgroundColor = t.card;
    pg.Layout.Row = 1; pg.Layout.Column = 1;   % 6 页重叠在同一格, 靠 Visible 切换
    handles.pages{k} = pg;
end

% 页1 点位查看
p1 = handles.pages{1};
p1.RowHeight = {24,'1x'}; p1.RowSpacing = 6;
handles.titleRaw = uilabel(p1,'Text','点位查看 — 鼠标悬停显示 点号 / 坐标', ...
    'FontName',t.fUI,'FontSize',t.fsBody,'FontWeight','bold','FontColor',t.text);
handles.axRaw = uiaxes(p1); styleAx(handles.axRaw, t);

% 页2 测线与点位
p2 = handles.pages{2};
p2.RowHeight = {24,'1x'}; p2.RowSpacing = 6;
handles.titleLine = uilabel(p2,'Text','测线与点位', ...
    'FontName',t.fUI,'FontSize',t.fsBody,'FontWeight','bold','FontColor',t.text);
handles.axLine = uiaxes(p2); styleAx(handles.axLine, t);

% 页3 覆盖次数(动态生成)
handles.pageCover = handles.pages{3};
handles.pageCoverPlaceholder = uilabel(handles.pageCover, ...
    'Text','运行后在此显示各面元尺寸的新 / 老测线覆盖次数曲线', ...
    'FontName',t.fUI,'FontSize',t.fsBody,'FontColor',t.textFaint, ...
    'HorizontalAlignment','center','VerticalAlignment','center');
handles.tab2 = handles.pageCover;      % 兼容旧字段

% 页4 统计与日志
p4 = handles.pages{4};
p4.RowHeight = {16,'1x',16,168}; p4.RowSpacing = 6;
lbStat = uilabel(p4,'Text','覆盖统计','FontName',t.fUI,'FontSize',t.fsSmall,'FontWeight','bold', ...
    'FontColor',t.textDim);
lbStat.Layout.Row = 1; lbStat.Layout.Column = 1;
handles.statTable = uitable(p4,'FontName',t.fUI,'FontSize',t.fsSmall);
handles.statTable.RowName = 'numbered';
handles.statTable.ColumnName = {'面元尺寸','新测线 mean','std','max','老测线 mean','std','max'};
handles.statTable.ColumnWidth = {230,140,80,70,140,80,80};
try, handles.statTable.BackgroundColor = t.card; catch, end
handles.statTable.Layout.Row = 2; handles.statTable.Layout.Column = 1;
lbLog = uilabel(p4,'Text','运行日志','FontName',t.fUI,'FontSize',t.fsSmall,'FontWeight','bold', ...
    'FontColor',t.textDim);
lbLog.Layout.Row = 3; lbLog.Layout.Column = 1;
handles.logArea = uitextarea(p4,'Editable','off','FontName',t.fUI,'FontSize',10, ...
    'FontColor',t.text,'BackgroundColor',t.logBg, ...
    'Value',{'点「加载并显示点位」查看点位与点号; 再填点号范围 / 配对方式; 测试迭代次数; 最后点「运行」输出结果。', ...
    '本程序可互换检波点与炮点输入实现炮点优化(实际很少用)。'});
handles.logArea.Layout.Row = 4; handles.logArea.Layout.Column = 1;
handles.iterLogArea = handles.logArea;     % 兼容旧字段

% 页5 迭代曲线
p5 = handles.pages{5};
p5.RowHeight = {24,'1x'}; p5.ColumnWidth = {'1x','1x'};
p5.RowSpacing = 6; p5.ColumnSpacing = 26;
handles.titleDmax = uilabel(p5,'Text','正反演偏差随迭代次数收敛', ...
    'FontName',t.fUI,'FontSize',t.fsBody,'FontWeight','bold','FontColor',t.text);
handles.titleDmax.Layout.Row = 1; handles.titleDmax.Layout.Column = 1;
handles.titleFold = uilabel(p5,'Text','新测线覆盖随迭代次数', ...
    'FontName',t.fUI,'FontSize',t.fsBody,'FontWeight','bold','FontColor',t.text);
handles.titleFold.Layout.Row = 1; handles.titleFold.Layout.Column = 2;
handles.axDmax = uiaxes(p5); styleAx(handles.axDmax, t);
handles.axDmax.Layout.Row = 2; handles.axDmax.Layout.Column = 1;
handles.axFold = uiaxes(p5); styleAx(handles.axFold, t);
handles.axFold.Layout.Row = 2; handles.axFold.Layout.Column = 2;

% 页6 新老CMP偏差
p6 = handles.pages{6};
p6.RowHeight = {24,'1x'}; p6.RowSpacing = 6;
handles.titleDev = uilabel(p6,'Text','新老CMP线偏差  ( 虚线 = 断点 )', ...
    'FontName',t.fUI,'FontSize',t.fsBody,'FontWeight','bold','FontColor',t.text);
handles.axDev = uiaxes(p6); styleAx(handles.axDev, t);

%% ================= 状态栏 =================
sb = uigridlayout(root,[2 1]);
sb.RowHeight = {1,30}; sb.Padding = [0 0 0 0]; sb.RowSpacing = 0; sb.BackgroundColor = t.bg;
uipanel(sb,'BackgroundColor',t.line,'BorderType','none');
sbar = uigridlayout(sb,[1 5]);
sbar.ColumnWidth = {14,68,'1x',150,118}; sbar.RowHeight = {30};
sbar.Padding = [16 0 16 0]; sbar.ColumnSpacing = 8;
sbar.BackgroundColor = t.bg;
handles.stateDot = uilabel(sbar,'Text','●','FontName',t.fUI,'FontSize',11, ...
    'FontColor',t.textDim,'HorizontalAlignment','center','VerticalAlignment','center');
handles.stateLabel = uilabel(sbar,'Text','就绪','FontName',t.fUI,'FontSize',10, ...
    'FontColor',t.textDim,'HorizontalAlignment','left','VerticalAlignment','center');
handles.statusLabel = uilabel(sbar,'Text','等待加载数据','FontName',t.fUI,'FontSize',10, ...
    'FontColor',t.textDim,'HorizontalAlignment','left','VerticalAlignment','center');
handles.poolLabel = uilabel(sbar,'Text',poolNote,'FontName',t.fUI,'FontSize',10, ...
    'FontColor',t.textFaint,'HorizontalAlignment','right','VerticalAlignment','center');
rel = regexp(version,'\(R[0-9a-zA-Z]+\)','match','once');
if isempty(rel), rel = ''; end
uilabel(sbar,'Text',sprintf('V3.5   %s',rel),'FontName',t.fUI,'FontSize',10, ...
    'FontColor',t.textFaint,'HorizontalAlignment','right','VerticalAlignment','center');

setappdata(handles.fig,'h',handles);
showPage(handles, 1);
end

% =====================================================================
%                          视觉主题与控件工厂
% =====================================================================
function t = uiTheme()
t.bg         = [0.953 0.953 0.953];   % 窗口底色
t.card       = [1 1 1];               % 卡片
t.line       = [0.878 0.878 0.878];   % 卡片描边 / 分隔线
t.lineSoft   = [0.933 0.933 0.933];   % 卡片内细分隔线
t.logBg      = [0.976 0.976 0.976];   % 日志只读区
t.rowAlt     = [0.965 0.965 0.965];   % 表格斑马行
t.text       = [0.106 0.106 0.106];   % 主文字
t.textDim    = [0.380 0.380 0.380];   % 次级文字
t.textFaint  = [0.545 0.545 0.545];   % 弱提示
t.accent     = [0.000 0.404 0.753];   % accent #0067C0
t.accentSoft = [0.918 0.949 0.984];   % accent 淡底
t.btnSoft    = [0.961 0.961 0.961];   % 次级按钮底色
t.ok         = [0.063 0.486 0.063];   % 完成 #107C10
t.warn       = [0.769 0.169 0.110];   % 出错 #C42B1C
t.cRecv      = [0.376 0.427 0.494];   % 检波点 蓝灰
t.cShot      = [0.878 0.451 0.000];   % 炮点 橙
t.cCMP       = [0.102 0.549 0.353];   % 初始CMP 绿
t.cNew       = [0.000 0.404 0.753];   % 新CMP线 accent 蓝
t.cRline     = [0.470 0.243 0.659];   % 检波线 紫
t.cBreak     = [0.769 0.169 0.110];   % 断点 红
t.cOld       = [0.545 0.545 0.545];   % 老测线 灰
t.fUI    = 'Microsoft YaHei UI';
t.fsBody = 12; t.fsSmall = 11;
end

function g = addCard(parent, t, titleTxt, nRows, rowHeights, nCols, colWidths)
% addCard  白色卡片: 1px 描边 + 组标题 + 细分隔线, 返回内容网格
outer = uipanel(parent,'BorderType','line','ForegroundColor',t.line, ...
    'BackgroundColor',t.card,'FontName',t.fUI,'FontSize',t.fsSmall);
inner = uigridlayout(outer,[2 1]);
inner.RowHeight = {20,'1x'}; inner.Padding = [12 8 12 8];
inner.RowSpacing = 6; inner.BackgroundColor = t.card;
hdr = uigridlayout(inner,[2 1]);
hdr.RowHeight = {19,1}; hdr.Padding = [0 0 0 0]; hdr.RowSpacing = 0;
hdr.BackgroundColor = t.card;
uilabel(hdr,'Text',titleTxt,'FontName',t.fUI,'FontSize',t.fsSmall,'FontWeight','bold', ...
    'FontColor',t.textDim,'VerticalAlignment','center');
hln = uipanel(hdr,'BackgroundColor',t.lineSoft,'BorderType','none');
hln.Layout.Row = 2;
g = uigridlayout(inner,[nRows nCols]);
g.RowHeight = rowHeights; g.ColumnWidth = colWidths;
g.Padding = [0 0 0 0]; g.RowSpacing = 4; g.ColumnSpacing = 8;
g.BackgroundColor = t.card; g.Layout.Row = 2; g.Layout.Column = 1;
end

function styleAx(ax, t)
% styleAx  统一坐标区: 白底、浅灰网格、细刻度、无边框
ax.Color      = t.card;
ax.XColor     = t.textDim; ax.YColor = t.textDim;
ax.GridColor  = [0.72 0.72 0.72]; ax.GridAlpha = 0.28;
ax.FontName   = t.fUI; ax.FontSize = t.fsSmall;
ax.Box        = 'off';
ax.TickDir    = 'out';
ax.Layer      = 'bottom';
ax.XLabel.FontName = t.fUI; ax.XLabel.FontSize = t.fsSmall; ax.XLabel.Color = t.textDim;
ax.YLabel.FontName = t.fUI; ax.YLabel.FontSize = t.fsSmall; ax.YLabel.Color = t.textDim;
ax.Title.FontName = t.fUI; ax.Title.FontSize = t.fsBody; ax.Title.Color = t.text;
end

function lg = addLegend(ax, labels, t, loc)
if nargin < 4, loc = 'best'; end
try
    lg = legend(ax, labels, 'Location', loc);
    lg.Box = 'off'; lg.Color = 'none';
    lg.FontName = t.fUI; lg.FontSize = 10; lg.TextColor = t.textDim;
catch
    lg = [];
end
end

function showPage(h, k)
% showPage  切换页签: 高亮页签文字 + accent 下划线 + 显示对应页
for i = 1:numel(h.pages)
    h.pages{i}.Visible = 'off';
end
h.pages{k}.Visible = 'on';
for i = 1:numel(h.tabBtn)
    if i == k
        h.tabBtn(i).BackgroundColor = h.t.card;
        h.tabBtn(i).FontColor = h.t.accent;
        h.tabBtn(i).FontWeight = 'bold';
        h.tabUl(i).BackgroundColor = h.t.accent;
    else
        h.tabBtn(i).BackgroundColor = h.t.bg;
        h.tabBtn(i).FontColor = h.t.textDim;
        h.tabBtn(i).FontWeight = 'normal';
        h.tabUl(i).BackgroundColor = h.t.bg;
    end
end
h.pageIdx = k;
end

function writeLog(h, lines)
% writeLog  写运行日志, 并同步底部状态栏(取最后一行)
if ischar(lines) || isstring(lines), lines = cellstr(lines); end
lines = lines(:)';
if isempty(lines), return; end
h.logArea.Value = lines;
last = strtrim(regexprep(char(lines{end}), '\s+', ' '));
if numel(last) > 110, last = [last(1:108) '…']; end
if ~isempty(last), h.statusLabel.Text = last; end
end

function setState(h, kind, label)
switch lower(kind)
    case 'busy', c = h.t.accent;
    case 'ok',   c = h.t.ok;
    case 'err',  c = h.t.warn;
    otherwise,   c = h.t.textDim;
end
h.stateDot.FontColor = c;
h.stateLabel.FontColor = c;
if nargin >= 3 && ~isempty(label), h.stateLabel.Text = label; end
end

function h = uiBusy(h, on)
% uiBusy  计算期间锁定关键按钮, 避免重入
if on
    h.runBtn.Enable = 'off'; h.runBtn.Text = '运行中…';
    h.exportBtn.Enable = 'off'; h.scanBtn.Enable = 'off'; h.loadBtn.Enable = 'off';
else
    h.runBtn.Enable = 'on'; h.runBtn.Text = '▶  运行';
    h.exportBtn.Enable = 'on'; h.scanBtn.Enable = 'on'; h.loadBtn.Enable = 'on';
end
end

% =====================================================================
%                              回调
% =====================================================================
function tabCb(s, k)
h = getappdata(ancestor(s,'figure'),'h');
showPage(h, k);
setappdata(h.fig,'h',h);
end

function browseCb(s, field)
h = getappdata(ancestor(s,'figure'),'h');
[f,pth] = uigetfile({'*.csv;*.txt','数据文件 (*.csv,*.txt)';'*.*','所有文件'},'选择数据文件');
if isequal(f,0), return; end
switch field
    case 'recv',  h.recvEdit.Value  = fullfile(pth,f);
    case 'shots', h.shotsEdit.Value = fullfile(pth,f);
    case 'cmp',   h.cmpEdit.Value   = fullfile(pth,f);
end
writeLog(h, sprintf('已选择文件: %s', fullfile(pth,f)));
setappdata(h.fig,'h',h);
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
    pR = plot(ax, h.raw.R0(:,1),  h.raw.R0(:,2),  '.', 'Color',h.t.cRecv, 'MarkerSize',7);
    pS = plot(ax, h.raw.S(:,1),   h.raw.S(:,2),   '.', 'Color',h.t.cShot, 'MarkerSize',2.5);
    pC = plot(ax, h.raw.CMP0(:,1),h.raw.CMP0(:,2),'.', 'Color',h.t.cCMP,  'MarkerSize',5);
    hold(ax,'off');
    styleAx(ax, h.t);
    axis(ax,'equal'); grid(ax,'on');
    xlabel(ax,'X (m)'); ylabel(ax,'Y (m)');
    h.titleRaw.Text = '点位查看 — 鼠标悬停显示 点号 / 坐标';
    addLegend(ax, {'检波点','炮点','初始CMP'}, h.t);
    dc = datacursormode(h.fig);
    set(dc,'UpdateFcn',@(obj,evt) dcUpdate(obj,evt,h.raw));
    setappdata(h.fig,'pR',pR); setappdata(h.fig,'pS',pS); setappdata(h.fig,'pC',pC);
    writeLog(h, {sprintf('已加载: 检波点 %d 点, 炮点 %d 点, CMP %d 点', ...
        size(h.raw.R0,1), size(h.raw.S,1), size(h.raw.CMP0,1)), ...
        '在「点位查看」页悬停可看 点号/坐标, 再填检波点点号范围'});
    setState(h,'ok','已加载');
    showPage(h, 1);
catch ME
    writeLog(h, ['加载出错: ' ME.message]); setState(h,'err','出错'); beep;
end
setappdata(h.fig,'h',h);
end

function txt = dcUpdate(~,evt,raw)
pos = evt.Position; tgt = evt.Target;
tp = '点'; idx = NaN;
try
    fig = ancestor(tgt,'figure');
    if isequal(tgt,getappdata(fig,'pR'))
        tp = '检波点'; d = raw.R0;
    elseif isequal(tgt,getappdata(fig,'pS'))
        tp = '炮点'; d = raw.S;
    else
        tp = '初始CMP'; d = raw.CMP0;
    end
    if ~isempty(d)
        [~,idx] = min(hypot(d(:,1)-pos(1), d(:,2)-pos(2)));
    end
catch
end
if isnan(idx)
    txt = sprintf('%s  X=%.1f  Y=%.1f', tp, pos(1), pos(2));
else
    txt = sprintf('%s #%d   X=%.1f  Y=%.1f', tp, idx, pos(1), pos(2));
end
end

function runCb(s)
h = getappdata(ancestor(s,'figure'),'h');
h = uiBusy(h, true); setState(h,'busy','运行中');
h.statusLabel.Text = '正在计算: 反演 → 正演 → 拟合 → 迭代 → 加密 → 覆盖统计…';
setappdata(h.fig,'h',h); drawnow;
try
    p = readParams(h);
    if ~h.appliedCalnum
        writeLog(h, '未做迭代对比/应用, 按默认 3 次迭代运行; 建议先「迭代对比」再「应用」选定次数');
        drawnow;
    end
    files = getInputFiles(h);
    res = crooked_core(p, files);
    bl = res.p.breakList;
    blStr = strjoin(arrayfun(@(i)sprintf('(%.0f,%.0f)',bl(i,1),bl(i,2)), ...
        1:size(bl,1),'UniformOutput',false), ' ');
    h.rangeLabel.Text = sprintf('检波 %.0f ~ %.0f    CMP %.0f ~ %.0f\n断点 %s  [源: %s]', ...
        res.p.rstart(1),res.p.rend(1),res.p.cstart(1),res.p.cend(1), blStr, res.p.breakSrcUsed);
    stats = cell(numel(res.p.binY),1);
    for n = 1:numel(res.p.binY)
        stats{n} = sprintf('面元 %.1f×%.0fm  新 mean %.1f · std %.1f · max %d   老 mean %.1f · std %.1f · max %d', ...
            res.p.binX,res.p.binY(n),mean(res.foldn(:,n)),std(res.foldn(:,n)),max(res.foldn(:,n)), ...
            mean(res.foldo(:,n)),std(res.foldo(:,n)),max(res.foldo(:,n)));
    end
    h.statLabel.Text = strjoin(stats,newline);
    writeLog(h, res.iterLog);
    h.logArea.Value = [h.logArea.Value(:); ...
        {sprintf('断点个数 = %d, 坐标 = %s, 数据源 = %s', size(res.p.breakList,1), blStr, res.p.breakSrcUsed)}];
    h.lastRes = res;
    setappdata(h.fig,'h',h);
    plotLine(h,res); plotCoverage(h,res); fillTable(h,res); plotDev(h,res);
    setState(h,'ok','完成');
    showPage(h, 2);
catch ME
    fprintf(2,'[runCb] %s\n',ME.message);
    writeLog(h, ['运行出错: ' ME.message]); setState(h,'err','出错'); beep;
end
h = uiBusy(h, false);
setappdata(h.fig,'h',h);
end

function p = readParams(h)
p.noff = h.noffEdit.Value; p.maxoffset = h.maxoffsetEdit.Value;
p.binX = h.binXEdit.Value;
p.binY = str2num(h.binYEdit.Value); if isempty(p.binY), p.binY = [300 600]; end %#ok<ST2NM>
p.rint = h.rintEdit.Value;
p.pairMode = 'maxoffset';
if strcmp(h.pairDrop.Value,'滚进滚出'), p.pairMode = 'roll'; end
p.polyR = str2num(h.polyREdit.Value);
if isempty(p.polyR) || numel(p.polyR) ~= 2, p.polyR = [2 6]; end %#ok<ST2NM>
p.polyC = str2num(h.polyCEdit.Value);
if isempty(p.polyC) || numel(p.polyC) ~= 2, p.polyC = [2 6]; end %#ok<ST2NM>
p.nBreak = max(1, min(5, round(h.nBreakEdit.Value)));
p.breakSrc = 'shot';
if strcmp(h.breakSrcDrop.Value,'CMP线'), p.breakSrc = 'cmp'; end
er = str2num(h.errRangeEdit.Value); %#ok<ST2NM>
if numel(er) >= 2, p.error1 = er(1); p.range1 = er(2); else, p.error1 = 100; p.range1 = 1500; end
p.calnum = h.finalCalnum;
v1s = strtrim(h.rIdx1Edit.Value);
v2s = strtrim(h.rIdx2Edit.Value);
if isempty(v1s) && isempty(v2s)
    p.rIdx = [];
else
    v1 = str2double(v1s); v2 = str2double(v2s);
    if isnan(v1) || isnan(v2)
        error('检波点点号起/止需同时填写有效数字, 或同时留空');
    end
    p.rIdx = [round(v1), round(v2)];
end
end

function plotLine(h,res)
ax = h.axLine; cla(ax); hold(ax,'on');
plot(ax,res.R0(:,1),res.R0(:,2),'.','Color',[0.78 0.78 0.78],'MarkerSize',2);
plot(ax,res.S(:,1),res.S(:,2),'.','Color',[0.94 0.62 0.30],'MarkerSize',1.5);
plot(ax,res.CMP0(:,1),res.CMP0(:,2),'--','Color',h.t.cCMP,'LineWidth',1.1);
plot(ax,res.CMP(:,1),res.CMP(:,2),'-','Color',h.t.cNew,'LineWidth',2);
plot(ax,res.R1(:,1),res.R1(:,2),'-','Color',h.t.cRline,'LineWidth',1.3);
for k = 1:size(res.p.breakList,1)
    plot(ax,res.p.breakList(k,1),res.p.breakList(k,2),'x','Color',h.t.cBreak, ...
        'MarkerSize',11,'LineWidth',2);
end
hold(ax,'off');
xs = [res.R0(:,1);res.S(:,1);res.CMP0(:,1);res.CMP(:,1);res.R1(:,1)];
ys = [res.R0(:,2);res.S(:,2);res.CMP0(:,2);res.CMP(:,2);res.R1(:,2)];
xlim(ax,[min(xs)-1000 max(xs)+1000]); ylim(ax,[min(ys)-1000 max(ys)+1000]);
axis(ax,'equal');
styleAx(ax, h.t); grid(ax,'on');
xlabel(ax,'X (m)'); ylabel(ax,'Y (m)');
h.titleLine.Text = sprintf('测线与点位  ·  迭代 %d 次  ·  配对 %s  ·  断点源 %s', ...
    res.p.calnum, res.p.pairMode, res.p.breakSrcUsed);
addLegend(ax,{'检波点','炮点','初始CMP','新CMP线','检波线','断点'}, h.t);
end

function plotCoverage(h,res)
try, delete(h.pageCover.Children); catch, end
nc = numel(res.p.binY);
g2 = uigridlayout(h.pageCover,[2 nc]);
g2.RowHeight = {24,'1x'}; g2.ColumnWidth = repmat({'1x'},1,nc);
g2.Padding = [0 0 0 0]; g2.RowSpacing = 6; g2.ColumnSpacing = 26;
g2.BackgroundColor = h.t.card;
for n = 1:nc
    tl = uilabel(g2,'Text',sprintf('面元 %.1f × %.0f m',res.p.binX,res.p.binY(n)), ...
        'FontName',h.t.fUI,'FontSize',h.t.fsBody,'FontWeight','bold','FontColor',h.t.text);
    tl.Layout.Row = 1; tl.Layout.Column = n;
    ax = uiaxes(g2); ax.Layout.Row = 2; ax.Layout.Column = n;
    hold(ax,'on');
    plot(ax,res.foldn(:,n),'-','Color',h.t.cNew,'LineWidth',1.6);
    plot(ax,res.foldo(:,n),'.','Color',h.t.cOld,'MarkerSize',5);
    hold(ax,'off');
    styleAx(ax, h.t);
    grid(ax,'on'); axis(ax,'tight');
    xlabel(ax,'面元编号'); ylabel(ax,'覆盖次数');
    if n == 1, addLegend(ax,{'新测线','老测线'}, h.t); end
end
end

function fillTable(h,res)
nc = numel(res.p.binY);
data = cell(nc,7);
for n = 1:nc
    data(n,:) = {sprintf('%.1f × %.0f m',res.p.binX,res.p.binY(n)), ...
        sprintf('%.1f',mean(res.foldn(:,n))), sprintf('%.1f',std(res.foldn(:,n))), ...
        sprintf('%d',max(res.foldn(:,n))), ...
        sprintf('%.1f',mean(res.foldo(:,n))), sprintf('%.1f',std(res.foldo(:,n))), ...
        sprintf('%d',max(res.foldo(:,n)))};
end
h.statTable.Data = data;
try, removeStyle(h.statTable); catch, end
try
    idx = 1:2:nc;
    if ~isempty(idx)
        addStyle(h.statTable, uistyle('BackgroundColor',h.t.rowAlt), 'row', idx);
    end
catch
end
end

function plotDev(h,res)
ax = h.axDev; cla(ax); hold(ax,'on');
plot(ax, res.CMP(:,1), res.dCMP, '.', 'Color',h.t.cNew, 'MarkerSize',7);
yline(ax, 0, '--', 'Color',[0.55 0.55 0.55], 'LineWidth',1);
for k = 1:size(res.p.breakList,1)
    xline(ax, res.p.breakList(k,1), '--', 'Color',h.t.cBreak, 'LineWidth',1);
end
hold(ax,'off');
styleAx(ax, h.t); grid(ax,'on');
xlabel(ax,'X (m)'); ylabel(ax,'新CMP − 初始CMP (m)');
h.titleDev.Text = '新老CMP线偏差  ( 虚线 = 断点 )';
end

function files = getInputFiles(h)
appDir = fileparts(mfilename('fullpath'));
names = {h.recvEdit.Value, h.shotsEdit.Value, h.cmpEdit.Value};
for k = 1:3
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
h = uiBusy(h, true); h.scanBtn.Text = '对比中…'; setState(h,'busy','对比中');
setappdata(h.fig,'h',h); drawnow;
try
    maxit = round(h.maxitEdit.Value); if maxit < 1, maxit = 1; end
    files = getInputFiles(h);
    dmax = zeros(maxit,1); f150 = zeros(maxit,1); f300 = nan(maxit,1);
    for k = 1:maxit
        pk = readParams(h);
        pk.calnum = k;
        res = crooked_core(pk, files);
        n = numel(res.iterLog);
        tok = regexp(res.iterLog{n},'偏差([0-9.]+)m','tokens');
        if ~isempty(tok), dmax(k) = str2double(tok{1}{1}); end
        f150(k) = mean(res.foldn(:,1));
        if size(res.foldn,2) >= 2, f300(k) = mean(res.foldn(:,2)); end
        writeLog(h, sprintf('迭代对比  k = %d : 偏差 = %.1f m,  新测线 150m 覆盖 = %.1f', k, dmax(k), f150(k)));
        setappdata(h.fig,'h',h); drawnow;
    end
    h.itSelDrop.Items = arrayfun(@(x)num2str(x),1:maxit,'UniformOutput',false);
    plotIterCurve(h,dmax,f150,f300,maxit);
    showPage(h, 5);
    writeLog(h, '迭代对比完成: 在「最终次数」下拉中选迭代次数 → 「应用」→ 右上角「运行」');
    setState(h,'ok','对比完成');
catch ME
    fprintf(2,'[scanCb] id=%s msg=%s\n', ME.identifier, ME.message);
    for kk = 1:numel(ME.stack)
        fprintf(2,'   at %s (line %d)\n',ME.stack(kk).name,ME.stack(kk).line);
    end
    try, writeLog(h, sprintf('迭代对比出错: %s', ME.message)); catch, end
    setState(h,'err','出错'); beep;
end
h.scanBtn.Text = '迭代对比';
h = uiBusy(h, false);
setappdata(h.fig,'h',h);
end

function applyItCb(s)
h = getappdata(ancestor(s,'figure'),'h');
v = str2double(h.itSelDrop.Value);
if isnan(v), v = 3; end
h.finalCalnum = round(v);
h.appliedCalnum = true;
setappdata(h.fig,'h',h);
writeLog(h, sprintf('最终迭代次数已设为 %d, 请点右上角「运行」生成最终结果', h.finalCalnum));
setState(h,'ok',sprintf('已应用 %d 次', h.finalCalnum));
end

function exportCb(s)
h = getappdata(ancestor(s,'figure'),'h');
if ~isfield(h,'lastRes') || isempty(h.lastRes)
    writeLog(h, '请先点「运行」生成结果, 再导出最终检波点'); beep; return;
end
res = h.lastRes;
T = table((1:size(res.rfinal,1))', res.rfinal(:,1), res.rfinal(:,2), ...
    'VariableNames', {'PointNo','X','Y'});
[fn,pth] = uiputfile('Final_Receivers.csv','保存最终检波点(CSV)');
if isequal(fn,0), return; end
fpath = fullfile(pth,fn);
writetable(T, fpath);
writeLog(h, sprintf('已导出最终检波点 %d 点 (等间距 %.0f m): %s', ...
    size(res.rfinal,1), res.p.rint, fpath));
setState(h,'ok','已导出');
end

function plotIterCurve(h,dmax,f150,f300,maxit)
x = 1:maxit;
ax = h.axDmax; cla(ax);
plot(ax,x,dmax,'-o','Color',h.t.cNew,'LineWidth',1.6,'MarkerSize',6,'MarkerFaceColor',h.t.cNew);
styleAx(ax, h.t); grid(ax,'on');
if maxit >= 2, ax.XTick = 1:maxit; else, ax.XTick = 1; end
xlabel(ax,'迭代次数'); ylabel(ax,'新CMP线最大偏差 (m)');
h.titleDmax.Text = '正反演偏差随迭代次数收敛';

ax = h.axFold; cla(ax); hold(ax,'on');
plot(ax,x,f150,'-o','Color',h.t.cNew,'LineWidth',1.6,'MarkerSize',6,'MarkerFaceColor',h.t.cNew);
if ~all(isnan(f300))
    plot(ax,x,f300,'-s','Color',h.t.cShot,'LineWidth',1.6,'MarkerSize',6,'MarkerFaceColor',h.t.cShot);
    labels = {'150 m','300 m'};
else
    labels = {'150 m'};
end
hold(ax,'off');
styleAx(ax, h.t); grid(ax,'on');
if maxit >= 2, ax.XTick = 1:maxit; else, ax.XTick = 1; end
xlabel(ax,'迭代次数'); ylabel(ax,'新测线覆盖 mean');
addLegend(ax, labels, h.t);
h.titleFold.Text = '新测线覆盖随迭代次数';
end
