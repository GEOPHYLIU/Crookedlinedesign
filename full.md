文章编号 <sub>：</sub> 1001－1749（2023）05－0579－06

# 二维弯线采集中测线优化设计方案与实现

刘军胜（中石化 石油工程地球物理有限公司 北京 100000）

摘 要 <sub>：</sub> 区别于常规二维地震资料采集方法 弯线采集以自由曲线或折线的形式进行测线设计弯线采集在炮点和检波点选择方面更为灵活 能够有效解决大型障碍物 困难地形区域施工的问题 然而弯线的CMP点在平行和垂直测线方向都是离散的 特别是当目的层埋深较浅时 叠加剖面的真实性受到严重影响 降低CMP离散度和离散CMP点的处理是提升资料品质和可靠性的关键 因此 这里提出了在优选炮点的基础上 利用检波点反演 CMP点正演 CMP点 ＆ 检波点分段拟合 迭代优化等相结合的方式对 检波点和CMP面元进行优化的方案 并通过软件编程实现测线自动优化和分析最小化目的层CMP点的离散度 以保障资料品质

关键词 <sub>：</sub> 空间假频<sub>；</sub> CDMO<sub>；</sub> 检波点反演<sub>；</sub> CMP点正演<sub>；</sub> 多项式分段拟合

中图分类号 <sub>：</sub> P631．4

文献标志码 <sub>：</sub> A

DOI<sub>：</sub>10．3969／j．issn．1001－1749．2023．05．03

## 0 引言

在复杂地形区域二维地震资料采集中（如在山地 黄土塬 水网 城镇等区域） 为了克服各种障碍物的影响 炮检点变观设计 折线施工 非纵观测 弯线采集等方法得到广泛地应用<sup>［1－2］</sup> 相较于其他三种方法 弯线采集是最<sup>“</sup>友好<sup>”</sup>的施工方式 国内学者自上世纪70年代开始至今<sup>［3］</sup> 对弯线施工的采集方法 资料处理 解释方法做了大量地研究 陆上石油地震勘探资料采集技术规程中明确了二维地震采用折线或弯线施工时 测线拐角和边长应根据CMP离散度确定 一般测线转折方位角采用8<sup>°</sup>16<sup>°</sup>30<sup>°</sup>的递进方式 转折点为激发点或接收点 严重弯曲的地段应增加覆盖次数 页岩气调查地震资料采集与处理技术规程中指出弯线施工时 物理点的横向偏移距应小于第一菲尼尔带半径 杨庆道等<sup>［4］</sup>则对弯线地震勘探技术应用中采集和处理的问题进行了梳理和分析 提出<sup>“</sup>能直不弯 转折角能小不大 转折角太大时测线能交不连<sup>”</sup>的弯线设计原则 并提出以面元聚敛响应作为指标 对炮检路径进行优化 强正阳<sup>［5］</sup>总结了弯线设计应满足时间 空间 最大离散距等要求<sub>；</sub> 郭晓滨等<sup>［6］</sup>提出<sup>“</sup>三步法<sup>”</sup>静校正解决处理方面 的 问 题 国 外 学 者 Mladen R．Nedimovic等<sup>［7－8］</sup>提出了振幅叠加和Cross－di 叠加方法 解决弯线处理的问题 并提出了振幅叠加和CDMO校正量的计算公式

就弯线设计而言 常规做法是炮点和检波点沿着相同的路径布设 这样限制了 CMP点的优化在2017年某项目中 笔者根据甲方要求设计了炮检点沿不同路径的宽弯线（三线一炮）施工方案 炮点为沿着道路均匀布设的震源点 中心检波线则为炮点线的中位线 两侧检波线与中心检波线平行 该设计在有效解决了检波点施工问题的同时 也使CMP线得到了优化 取得了较好的效果 笔者将以检波点和炮点沿不同路径布设的思路 以某山地项目测线为例 利用 MladenR．Nedimovic等<sup>［7］</sup> 提出的CDMO（横向倾角时差校正）算式 针对主要目的层的有效CMP点进行反演 正演运算 找出检波线和CMP线的最优解 同时将通过分析不同面元尺寸下 目的层覆盖次数的变化来判断新测线 CMP的收敛特性

## 1 设计参数分析

## 1．1 研究区地震地质条件

在某山地二维测线的施工中 测线穿越大范围的无人区且地形切割剧烈 工区内的山体走向主要为南北向 绵延数为60km 东西向则约 $6 \ \mathrm { k m } \sim 7 $ km 研究测线属于南北向联络测线 测线位于山中腹地 长约18km 山中无任何道路 仅能依托山间南北向沟谷进行设备和人员运输 测线为位于某平缓背斜的一翼 沿测线方向地层平缓 且倾角近视为零 垂直测线方向存在较小倾角 约5<sup>°</sup>左右地层倾角 原设计和施工方案为利用沟谷等地形 在尽量降低转折角的基础上 根据<sup>“</sup>五避五就<sup>”</sup>的原则优选激发线 然后以激发线上对物理点进行适当调整 均匀布设检波点 现场叠加处理以后 浅层剖面资料显示相邻的数个CMP点波形与附近CMP波形一致性较差 有多相位 弱相位等问题（图1）

分析原因认为 由于地层存在一定的倾角且CMP点位置离散的问题 现场资料处理做了动校正以后 不能完全消除共中心点炮集或道集的时差如图2所示 CMP1 CMP2经过 NMO以后仍然存在时差<sub>，</sub>当 ${ t _ { 0 } } ^ { \prime } - t _ { 0 } > T / 4$ 时叠加会产生空间假频在这种情况下 多 CMP点叠加不但不能提升资料信噪比 反而会削弱信号 此时需要进行CDMO处理 计算离散CMP点的静校正量 消除空间假频的影响 针对该区单一样式的构造形态 CDMO校正量能够准确地计算 然而 随着构造条件的复杂化每个CMP点的静校正量的准确计算难度逐渐增大 笔者认为选择合理的弯线设计参数 从设计源头尽量减少空间假频的出现 同时辅以CDMO校正是解决问题的关键

## 1．2 关键设计参数的选取

假设传播介质为均匀介质 速度为V 针对平面反射界面 炮检点的双程旅行时 t 与共中心点CMP处的 $t _ { 0 }$ 之间的关系可以表示为式（1）

$$
t ^ {2} (x, y, h) = \left(t _ {0} (x) + p _ {y} y\right) ^ {2} + p ^ {2} h ^ {2}\tag{1}
$$

式中 $: x$ 为沿CMP线的偏移量 $\div y$ 为垂直CMP线方向的偏移量<sub>；</sub>h 为炮检距 $: \boldsymbol { \hat { p } } _ { : }$ 为垂直CMP线方向的慢度 $\phi _ { y } y$ 为垂直CMP线方向 $\arctan$ 生的时差 也就是CDMO量 $\boldsymbol { \phi }$ 为平行测线方向的慢度

![](images/416ed25edd770f153d5567217ddebcac12a51962303426c157d8255b156fa0bf.jpg)  
图1 测线浅层初叠剖面（部分）

Fi<sub>g</sub>．1 Linebrutestacksectionofshallowla<sub>y</sub>er（<sub>p</sub>artial）  
![](images/a7c4e9b9285cf1f3f98237361281b8e9f6ab9cc39633ec0a1d586116e8ca2cd5.jpg)  
图2 CMP点时差示意图  
Fi<sub>g</sub>．2 Timedifferencedia<sub>g</sub>ramofdifferentCMP

MladenR．Nedimovic<sup>［5］</sup>给出了详细的 $\phi _ { y }$ 和 $\boldsymbol { \phi }$ 的计算公式 并进行了简化 见式（2） 式（3）

$$
p _ {y} = \frac {- 2 \sin \theta_ {y} \cos \theta_ {x}}{V (1 - \sin^ {2} \theta_ {x} \sin^ {2} \theta_ {y}) ^ {1 / 2}}\tag{2}
$$

$$
p = \left[ \frac {1}{V ^ {2}} - \frac {\sin^ {2} \theta_ {x}}{V ^ {2}} \right] ^ {1 / 2} = \frac {\cos \theta_ {x}}{V}\tag{3}
$$

式中 θ 为平行CMP线方向的地层视倾角 $\theta _ { y }$ 为垂直CMP线方向的地层视倾角

常规动校正和倾角时差校正能够消除由炮检距$\arctan$ 生的影响 即 $\phi ^ { 2 } h ^ { 2 }$ 但无法消除 $\phi _ { y } y _ { \mathrm { ~ o ~ } } \mathrm { ~ y ~ }$ 是弯线设计的关键点 $\mid \phi _ { y } y \mid < T / 4$ 时能够避免空间假频的影响 而对应 $y$ 应满足如下要求

$$
y <   \frac {V * T (1 - \sin^ {2} \theta_ {x} \sin^ {2} \theta_ {y}) ^ {1 / 2}}{8 \sin \theta_ {y} \cos \theta_ {x}}\tag{4}
$$

为了有效消除空间假频影响 要求同一面元内的任意两个CMP点的离散距离均要小于 $y$ 即对于大小为 $d x \ast d y$ 的面元 $d x$ 为道距的1／2 而 $d y$ 应小于 <sub>y</sub> 利用研究测线的地层参数计算 $y$ 量 结果见表1

表1 研究测线的地层参数及 <sub>y</sub> 量  
Tab．1 La<sub>y</sub>er<sub>p</sub>arametersand<sub>y</sub>valueofanal<sub>y</sub>zedline

<table><tr><td>主要目的层</td><td>目的层埋深/m</td><td>平均速度/m·s-1</td><td>Max θx/°</td><td>Max θy/°</td><td>目的层主频/Hz</td><td>消除空间假频影响的 y/m</td></tr><tr><td>T1</td><td>600</td><td>2 800</td><td>0</td><td>5</td><td>25</td><td>160.4</td></tr><tr><td>T2</td><td>1 200</td><td>3 500</td><td>0</td><td>6</td><td>25</td><td>174.1</td></tr><tr><td>T3</td><td>2 000</td><td>3 800</td><td>0</td><td>6</td><td>24</td><td>189.0</td></tr></table>

![](images/765b7cdd7cb9e0f18eb095bd1025d2baf9b110d790bca8dee47d8cdc8d4a3f1f.jpg)  
(a)全偏移距CMP分布

![](images/4605e3d6a183c01c58131ad96eaa959f8f92d61b704fa36e3b9e3feb1892f1be.jpg)  
(b)近偏移距2000m分布

![](images/f2bc69efd4b9079dd49e3e7f37da1c1e47bee392b3906afc8857d8b59665566a.jpg)  
(c)中远偏移距2000m\~4.000m分布  
图3 不同偏移距CMP点分布图（局部）  
Fi<sub>g．</sub>3 CMPdistributionma<sub>p</sub>sofdifferentoffset（<sub>p</sub>artial）

1） 偏移距 项目设计的最大偏移距为4000m 而实际满足该测线主要目的层的最大偏移距达到2000m即可 偏移距在2000m～4000m之间炮检点产生的 CMP点可视为冗余 CMP点 图3为不同偏移距下 CMP点分布图 可以看出原设计测线存在大量的冗余点 在测线优化时应暂不考虑2000m～4000m范围内的冗余点 否则将会影响CMP拟合线的选择 最终影响整体测线优化效果

2）面元尺寸 针对不同目的层 选择合适的面元 剔除面元外CMP点 进而分析不同面元尺寸下的有效覆盖次数 可以作为测线优化程度的判定标准 在资料处理时 也可以根据面元尺寸进行不同偏移距和面元尺寸的分批叠加处理 若面元外的CMP点仍较多 则需考虑进行 CDMO校正 根据表1计算结果 150m 为保障研究测线目的层资料的最优离散距 本次分析则选择面元尺寸12．5m＊150m和12．5m＊300m进行对比<sub>，</sub>研究优化效果和改进方向

![](images/2ec42eafd30aaddd7c5a932fa73942326d9709d79de9cc7f7fdba1d46d172e04.jpg)  
图4 技术路线和流程  
Fi<sub>g</sub>．4 Technicalrouteandflowchart

## 2 测线优化流程及应用效果

在炮点线和检波点线一致的情况下 我们可以通过正演模拟分析 利用最小二乘法拟合出最优的CMP线 从而实现面元内 CMP点的最大程度收敛 而当炮点线和检波点线可以分离时 测线优化空间显著增加 对于固定的检波点或者炮点 选取初始CMP线 通过如图4所示的流程即可实现对应物理点和CMP线的优化 以研究测线为例分析部分关键流程和应用效果

## 2．1 数据准备

数据准备阶段主要需要输入物理点 初始CMP线 偏移距 面元尺寸 检波点范围 炮点范围 施工模式（滚进或滚出） 分段拟合方式和断点等参数研究测线的炮点是实际钻井点位 作为固定物理点初始CMP线为根据原始检波点由设计软件 OMNI3D弯线设计模块计算的 CMP线 项目施工模式为滚进滚出的模式 分段拟合方式和断点则是通过对初始CMP点进行回归和拟合分析得出的最优拟合方式 本测线为三次 四次多项式分两段分别拟合 <sub>。</sub>

## 2．2 迭代运算

数据准备完毕以后 利用程序将对物理点和CMP点进行不断的正演 反演迭代优化 随着拟合次数的增加 测线的拟合优度 回归平方和逐渐减小 断点处的CMP线分段拟合误差也逐渐减小（图5） 当拟合优度和回归平方和变化较小时 可认为拟合得到近视最优解 随着迭代的继续增加 反而会出现测线端点处拟合度降低的问题 （图6） 这种现象在非滚进滚出的情况下更为突出 经过不断测试分析 选择三次迭代进行正反演模拟运算

## 2．3 不同面元有效覆盖次数分析

利用程序计算不同面元位置和尺寸条件下 覆盖次数的变化情况 验证目的层覆盖次数的均匀性和有效覆盖次数的变化 图7为偏移距为2000m条件下的计算和对比结果 从图7可以看出 经过优化后的测线覆盖次数均匀性 150m 范围内离散度等 方 面 得 到 显 著 提 升 CMP151－650 段 和CMP1146－1350段效果最为明显 然而<sub>，</sub>CMP654－837和CMP932－1148段改善不明显 即使重新选择初始CMP线进行二次优化后仍然得到相似的结果 分析主要原因为该区域炮点成连续<sup>“</sup>S<sup>”</sup>型大范围偏移 CMP点难以有效收敛 （图8） CMP和检波点优化不能有效解决这一区域的问题 可通过加强CDMO攻关处理 调整炮点位置或者加密炮点等三种方式实现离散 CMP点的叠加<sub>，</sub> 提升目的层有效覆盖次数 进而保障资料品质

![](images/2f489f73a151f9ce7d2b2b8f188d766ddb0d9c127e5e6ac23e8bbdb9c36f9233.jpg)  
(a)一次迭代

![](images/4fac4d76d3d67c025c2a92b7774d62ffbcb067f50327c1ea193b54b76089b06b.jpg)  
(b)三次迭代  
(c) 五次迭代

![](images/a5d579ff8c5981f5ae6c1b4d73204192114899f79fa32053bf6258bf0f7d470b.jpg)  
(d)十次迭代  
图5 断点附近拟合结果对比

Fi<sub>g</sub>．5 Com<sub>p</sub>arisonoffittedresultsnearbreak<sub>p</sub>oint  
![](images/14ceadb678efd9dc1cbf5647dcb89b9047b3ae36ce216f41ba7063333f6e612d.jpg)

![](images/1cc59c41ad8e6ea5bb70fba7d6f69f37c14fe617d21f7a023c497f4621068cdd.jpg)  
(a)一次迭代

![](images/9c05c5a5788c130a4183dfa3c0484d5707fd3ea2c7aa2221c94f7ca8397816de.jpg)  
(b)三次迭代

![](images/abdf96ad75d4d9de3cbd775a26a642ead0a3c7915a7dbf85891ef10692c4b869.jpg)  
(c)五次迭代  
(d)十次迭代  
图6 端点附近拟合结果对比  
Fi<sub>g</sub>．6 Com<sub>p</sub>arisonoffittedresultsnearend<sub>p</sub>oint

## 3 结论

笔者提出了一种以提升CMP收敛度为目标的二维弯线采集测线优化设计方案 能够改善弯线采集资料品质 通过研究分析 认为弯线采集中应注意以下问题

![](images/47dc97d5e4f6297f25c1377313bc577e2c9daa1d01c860b64e167eb96b3afe04.jpg)  
图7 不同面元尺寸线测线优化前后有效覆盖次数对比（偏移距2000m）

Fi<sub>g</sub>．7 Effectivefoldscom<sub>p</sub>arisonbetweendifferentbinsizes beforeandafterlineo<sub>p</sub>timization  
![](images/6b1b4e2ccb6a4029c97f9385a0b72d72db53653e7681270bb6dcd269602a44ac.jpg)  
(a)全偏移距 CMP分布

![](images/f1d57aa118e02b82098d40e463b3de5c5b23c2b4657f0f6d8e788f4125567315.jpg)

![](images/d22236a3bcee110fe836db4061f8e17fbf89aca00b2317967ad1fdc240dbda1b.jpg)  
图8 CMP651－1145不同偏移距物理点和CMP点分布  
Fi<sub>g</sub>．8 Shots<sub>，</sub> receivers<sub>，</sub> CMPdistributioncom<sub>p</sub>arison ofdifferentoffsetofCMP651－1145

1）合理的测线设计是弯线二维施工的关键环节 设计中应针对测线的主要目的层参数进行设计论证分析 灵活优化物理点 在提升CMP点收敛度的基础上 提升目的层有效覆盖次数

2）弯线设计中应尽量避免连续的<sup>“</sup>S<sup>”</sup>型弯折大偏移量的<sup>“</sup>S<sup>”</sup>型弯折 一方面会造成浅层覆盖次数的缺少或严重降低 另一方面影响 CMP点收敛度 造成CDMO量的急剧增大 降低资料的可信度

3）检波点 炮点 CMP点之间的迭代正演 反演计算 辅以拟合分析能够实现测线的不断优化 而编程软件中的拟合回归分析 方程求根 循环计算等算法也促进了测线自动优化地实现

4）在复杂构造带或陡倾角地层区域应尽量避免弯线设计或仅采用小弯折施工 若采用弯线采集资料处理阶段需不断开展CDMO校正攻关 提升叠加资料的可靠性

## 参考文献 <sub>：</sub>

［1］ 杨双安 魏书宏．煤田弯线地震勘探技术及应用［J］．煤田地震与勘探 200230（4） 55－57YANGSA WEISH．Coalfieldcrookseismic<sub>p</sub>ros－<sub>p</sub>ectin<sub>g</sub>technolo<sub>gy</sub>anda<sub>pp</sub>lication［J］．CoalGeolo<sub>gy</sub><sup>＆</sup>Ex<sub>p</sub>loration<sub>，</sub>2002<sub>，</sub>30（4） <sub>：</sub>55<sup>－</sup>57．（InChinese）

［2］ 郭良红 田小平．黄土塬区煤田弯线地震勘探采集技术的应用［J］．中国煤田地质 200618（6） 43－45GUOLH<sub>，</sub> TIANXP．A<sub>pp</sub>licationofcoalfieldslalomseismic<sub>p</sub>ros<sub>p</sub>ectin<sub>g</sub>dataac<sub>q</sub>uisitiontechni<sub>q</sub>ueinloesstableland［J］．CoalGeolo<sub>gy</sub>ofChina 200618（6） <sub>：</sub>43<sup>－</sup>45．（InChinese）

［3］ 包吉山．弯曲测线多次覆盖［J］．石油物探 1977（04）16<sup>－</sup>28BAOJS Multi<sub>p</sub>lecovera<sub>g</sub>eofcrookedline［J］．Geo－<sub>p</sub>h<sub>y</sub>sicalPros<sub>p</sub>ectin<sub>g</sub>forPetroleum<sub>，</sub> 1977（04） <sub>：</sub>16－28．（InChinese）

［4］ 杨庆道 王伟锋 尹以东 等．弯线地震勘探技术应用中的若干问题［J］．石油地球物理勘探 <sub>，</sub>2011<sub>，</sub>46（3） <sub>：</sub>365<sup>－</sup>369YANGQD WANG WF YINYDetal．Someis－suesina<sub>pp</sub>licationsofseismiccrookedline［J］．OilGe－o<sub>p</sub>h<sub>y</sub>sicalPros<sub>p</sub>ectin<sub>g</sub> 2011 46（3） <sub>：</sub>364<sup>－</sup>369．（InChinese）

［5］ 强正阳 卢育霞 陈永明 等．浅层弯线地震勘探采集与处理技术［J］．地震工程学报 201335（1） <sub>：</sub>139－144QIANGZY LU Y X CHEN Y M etal<sub>．</sub>Shallow

seismic<sub>p</sub>ros<sub>p</sub>ectin<sub>g</sub> dataac<sub>q</sub>uisition and <sub>p</sub>rocessin<sub>g</sub>technolo<sub>gy</sub>ofcrooked－linemeasurement［J］．ChinaEarth<sub>q</sub>uakeEn<sub>g</sub>ineerin<sub>g</sub>Journal<sub>，</sub>2013<sub>，</sub>35（1） <sub>：</sub>139－144．（InChinese）

［6］ 郭晓滨 李刚 冯永强．<sup>“</sup>三步法<sup>”</sup>静校正在鄂北麻黄山地区地震资料采集处理中的应用［J］．海洋地质动态2006<sub>，</sub>22（4） <sub>：</sub>34<sup>－</sup>36GUOXB LIG FENGYQ．A<sub>pp</sub>licationof"three－<sub>stepmet</sub>h<sub>o</sub>d"<sub>stat</sub>i<sub>ccorrect</sub>i<sub>ontose</sub>i<sub>sm</sub>i<sub>c</sub>d<sub>ataprocess</sub>－in<sub>g</sub>inMahuan<sub>g</sub>shanofNorhternHubei<sub>p</sub>rovince［J］MarineGeolo<sub>gy</sub>Letters200622（4） 34<sup>－</sup>36．（InChi－nese）

［7］ MLADEN<sub>，</sub>R．NEDIMOVIC<sup>′</sup> <sub>，</sub>GORDONF．WestCrooked －line2Dseismicreflectionima<sub>g</sub>in<sub>g</sub>incr<sub>y</sub>stallineterrains<sub>：</sub> Part1data<sub>p</sub>rocessin<sub>g</sub>［J］．GEOPHYSICS200368（1） 274<sup>－</sup>285

［8］ BECKEL RUTH A JUHLIN C．Thecross－di<sub>p</sub> correctionasatooltoim<sub>p</sub>roveima<sub>g</sub>in<sub>g</sub>ofcrooked－ lineseismicdata acasestud<sub>y</sub>fromthe<sub>p</sub>ost－<sub>g</sub>lacia Burtr？skfault Sweden［J］．SolidEarthDiscussions 2018（10） 581<sup>－</sup>598 DOI10．5194／se<sup>－</sup>2018<sup>－</sup>120

# Lineoptimizationdesignschemeandimplementationincrooked<sup>－</sup>linesurvey

LIUJunshen<sub>g</sub>（Sino<sub>p</sub>ecGe<sub>p</sub>h<sub>y</sub>sicalCor<sub>p</sub>oration Beijin<sub>g</sub> China 100000 China）

Abstract Unlikeconventional2Dseismicdataacquisition thecrooked<sup>－</sup>linesurveydesignsthelineasafreecurveor brakeline．Thecrooked－linesurve<sub>y</sub>ismoreflexibleinchoosin<sub>g</sub>shotandreceiver<sub>p</sub>ointsandcaneffectivel<sub>y</sub>solvetheo<sub>p</sub>eration difficultiesofenormousobstaclesandcom<sub>p</sub>lexterrainareas．However theCMP<sub>p</sub>ointsofthecurvedlinearediscreteinboth the<sub>p</sub>arallelandverticaldirections es<sub>p</sub>eciall<sub>y</sub>whenthetar<sub>g</sub>etla<sub>y</sub>erisshallow theauthenticit<sub>y</sub>ofthestacksectionisseriousl<sub>y</sub> affected．Theke toimrovin data ualit andreliabilitisreducin CMPdisersionanddiscreteCMP oints<sup>＇</sup>data rocessin Inthis aer anotimizin schemewasraised．Basedonthe referredshot ointsdesin thereceiver ointsandCMPbin couldbeotimizedthrouhreceivesinversion CMP ointforwardin PolnomialPiecewisefit andIteration．Theautomatic o<sub>p</sub>timizationandanal<sub>y</sub>sisofthesurve<sub>y</sub>linewasrealizedthrou<sub>g</sub>hsoftware<sub>p</sub>ro<sub>g</sub>rammin<sub>g</sub>．The<sub>p</sub>ro<sub>g</sub>ramshel<sub>p</sub>edminimizethetar－ <sub>g</sub>etla<sub>y</sub>er<sup>＇</sup>sdis<sub>p</sub>ersionandensurethedata<sub>q</sub>ualit<sub>y</sub>

Ke<sub>y</sub>words<sub>：</sub> s<sub>p</sub>atialaliasin<sub>g；</sub> CDMOcorrection<sub>；</sub> receiversinversion<sub>；</sub> CMPforwardin<sub>g； p</sub>ol<sub>y</sub>nomial<sub>p</sub>iecewisefit