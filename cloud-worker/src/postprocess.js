// Post-processing for private Vent / Feral drafts (mode "vent" only).
//
// Never applied to the roommate transcript — the app's EchoesParser reads its
// `[ROLE/IDX] …` lines, and their tags and the bridge word ("Sharp"/"Savage")
// are Latin runs by design — nor to the numbered sendable roast variants.
//
// Two kinds of fix, both measured on production output (2026-10-22 audit,
// 34 calls on the shipped prompt):
//   - cosmetic, applied in place: markdown emphasis / headings (literal
//     asterisks in 3 of 6 en replies) and the prompt's example words printed
//     after the draft (ja: "（うるせえ、ふざけんな、ありえねえ）").
//   - defects that need a new draft: English words inside zh/ja replies
//     ("fucking陳志明", "entitlement", "餡餅 stuffing": 3 of 14 zh-Hant),
//     Simplified characters inside zh-Hant replies (鸽/礼/妈/烦: 5 of 14),
//     a word stuck on repeat (「根本是根本根本根本」, gate run 2026-10-22), and
//     the person's name from the user's situation (zh only, below).
//     index.js asks the same model once more and keeps whichever draft has
//     fewer names, then fewer defects.
//   - names: the prompt says never to repeat a name, yet with the name in the
//     situation (「慣老闆陳志明…」「同事王强把…」) the primary model wrote it in 5
//     of 8 Chinese drafts and the fallback model in 4 of 4, nearly always as
//     the opening direct address 「陳志明你…」 / 「王强，你…」, and once in
//     English as "Fuck you, Kevin." (gate 2026-10-22). The draft may end up on
//     a share image. A name used as a form of address — opening the draft, or
//     closing an English sentence — is removed in place (stripNameAddress);
//     anywhere else it counts as a defect for the retry.
// Nothing else rewrites the text.

import { isTraditionalChinese } from "./locale.js";
import { VOICES } from "./vent_prompt.js";

/// Characters that only exist in Simplified Chinese, in the BMP CJK block.
/// Generated from OpenCC 1.1's STCharacters.txt: every single-character key
/// whose Traditional candidates do NOT include the character itself, minus
/// every key of TSCharacters.txt (characters that are themselves
/// Traditional), minus every character on either side of OpenCC's TW/HK
/// variant tables (温, 床, 峰… are standard Taiwan or Hong Kong forms), minus
/// 着 and the other one-to-many forms Taiwan text uses. Checked against the
/// app's zh-Hant Localizable.strings (3,939 Han characters): 0 hits. Against
/// the 14 zh-Hant audit replies: exactly the 5 bleeds a human found.
const SIMPLIFIED_ONLY = new Set([
  "与专业丛东丝丢两严丧个临为丽举义乌乐乔习乡书买乱争亏亚产亩亲亵亸亿仅从仑仓仪们众优会伛伞伟传伡伣伤伥伦伧伪伫体佥侠侣侥侦侧侨侩侪侬侭俣俦俨俩俪俫俭债倾偬偻偾偿傤傥傧储傩儿兖兰关兴兹养兽冁内冈册写军农冯",
  "冲决况冻净凄凉减凑凛凤凫凭凯击凿刍刘则刚创删别刬刭刹刽刾刿剀剂剐剑剥剧劝办务劢动励劲劳势勋勚匀匦匮区医华协单卖卢卤卫却卺厅历厉压厌厍厐厕厢厣厦厨厩厮县参叆叇双发变叙叠号叹叽吓吕吗吨听启吴呐呒呓呕呖呗员",
  "呙呛呜咏咙咛咝咤响哑哒哓哔哕哗哙哜哝哟唛唝唠唡唢唤啧啬啭啮啯啰啴啸喷喽喾嗫嗳嘘嘤嘱噜嚣团园围囵国图圆圣圹场坏块坚坛坜坝坞坟坠垄垅垆垒垦垩垫垭垯垱垲垴埘埙埚堑堕塆墙壮声壳壶壸处备复够头夹夺奁奂奋奖奥妆妇",
  "妈妩妪妫姗姹娄娅娆娇娈娱娲娴婳婴婵婶媭嫒嫔嫱嬷孙学孪宁宝实宠审宪宫宽宾寝对寻导寿将尔尘尝尧尴尽层屃屉届属屡屦屿岁岂岖岗岘岚岛岭岽岿峃峄峡峣峤峥峦崂崃崄崭嵘嵚嵝巅巩巯币帅师帏帐帜带帧帮帱帻帼幂并庄庆庐庑",
  "库应庙庞废庼廪开异弃弑张弥弪弯弹强归当录彟彦彨彻径徕忆忏忧忾怀态怂怃怄怅怆怜总怼怿恋恒恳恶恸恹恺恻恼恽悫悬悭悮悯惊惧惨惩惫惬惭惮惯愤愦慑慭懑懒懔戆戋戏戗战戬戯扑执扩扪扫扬扰抚抛抟抠抡抢护报担拟拢拣拥拦",
  "拧拨择挚挛挜挝挞挟挠挡挢挣挤挥挦捞损捡换捣掳掴掷掸掺掼揽揿搀搁搂搄搅携摄摅摆摇摈摊撄撑撵撷撸撺擜擞攒敌敛敩数斋斓斩断无旧时旷旸昙昵昼昽显晋晒晓晔晕晖暂暅暧术机杀杂权条来杨杩构枞枢枣枥枧枨枪枫枭柠柽栀栅",
  "标栈栉栊栋栌栎栏树栖样栾桠桡桢档桤桥桦桧桨桩桪梦梼梾梿检棂椁椝椟椠椢椤椫椭椮楼榄榇榈榉榝槚槛槟槠横樯樱橥橱橹橼檩欢欤欧歼殁殇残殒殓殚殡殴毁毂毕毙毡毵毶氇气氢氩汇汉汤汹沄沟没沣沤沥沦沧沨沩沪泞泪泶泷泸泺",
  "泻泼泽泾洁洒洼浃浅浆浇浈浉浊测浍济浏浐浑浒浓浔浕涛涝涞涟涠涡涢涣涤润涧涨涩渊渌渍渎渐渑渔渖渗湾湿溁溃溅溆溇滗滚滞滟滠满滢滤滥滦滨滩滪潆潇潋潍潜潴澛澜濑濒灏灭灯灵灾灿炀炉炖炜炝点炼炽烁烂烃烛烟烦烧烨烩烫",
  "烬热焕焖焘爱爷牍牦牵牺犊状犷犸犹狈狝狞独狭狮狯狰狱狲猃猎猕猡猪猫猬献獭玑玙玚玛玮环现玱玺珐珑珰珲琎琏琐琼瑶瑷瑸璎瓒瓮瓯电画畅畴疖疗疟疠疡疬疭疮疯疱疴痈痉痒痖痨痪痫瘅瘆瘗瘘瘪瘫瘾瘿癞癣癫皑皱皲盏盐监盖盗",
  "盘眍眦眬睁睐睑瞆瞒瞩矫矶矾矿砀码砖砗砚砜砺砻砾础硁硕硖硗硙硚硵硷碍碛碜碱礼祃祎祢祯祷祸禀禄禅离秃秆积称秽秾稆稣稳穑穞穷窃窍窎窑窜窝窥窦窭竖竞笃笋笔笕笺笼笾筚筛筜筝筹筼签筿简箓箦箧箨箩箪箫篑篓篮篯篱簖籁",
  "籴类籼粜粝粤粪粮糁糇糍紧絷縆纟纠纡红纣纤纥约级纨纩纪纫纬纭纮纯纰纱纲纳纴纵纶纷纸纹纺纻纼纽纾线绀绁绂练组绅细织终绉绊绋绌绍绎经绐绑绒结绔绕绖绗绘给绚绛络绝绞统绠绡绢绣绤绥绦继绨绩绪绫绬续绮绯绰绱绲绳维",
  "绵绶绷绸绹绺绻综绽绾绿缀缁缂缃缄缅缆缇缈缉缊缋缌缍缎缏缐缑缒缓缔缕编缗缘缙缚缛缜缝缞缟缠缡缢缣缤缥缦缧缨缩缪缫缬缭缮缯缰缱缲缳缴缵罂网罗罚罢罴羁羟羡翘翙翚耢耧耸耻聂聋职聍联聩聪肃肠肤肮肴肾肿胀胁胆胧胨",
  "胪胫胶脉脍脏脐脑脓脔脚脶脸腘腭腻腼腾膑臜舆舣舰舱舻艰艳艺节芈芗芜芦苁苇苈苋苌苍苎苏茎茏茑茔茕茧荆荙荚荛荜荝荞荟荠荡荣荤荥荦荧荨荩荪荫荬荭荮药莅莱莲莳莴莶获莸莹莺莼萚萝萤营萦萧萨蒇蒉蒋蒌蒏蓝蓟蓠蓣蓥蓦蔂",
  "蔷蔹蔺蔼蕰蕲蕴薮藓蘖虏虑虚虬虮虱虽虾虿蚀蚁蚂蚃蚕蚬蛊蛎蛏蛮蛰蛱蛲蛳蛴蜗蝇蝈蝉蝼蝾螀螨蟏衅衔补衬衮袄袅袆袜袭袯装裆裈裢裣裤裥褛褴襕见观觃规觅视觇览觉觊觋觌觍觎觏觐觑觞触觯訚詟誉誊讠计订讣认讥讦讧讨让讪讫",
  "讬训议讯记讱讲讳讴讵讶讷许讹论讻讼讽设访诀证诂诃评诅识诇诈诉诊诋诌词诎诏诐译诒诓诔试诖诗诘诙诚诛诜话诞诟诠诡询诣诤该详诧诨诩诪诫诬语诮误诰诱诲诳说诵诶请诸诹诺读诼诽课诿谀谁谂调谄谅谆谇谈谉谊谋谌谍谎谏",
  "谐谑谒谓谔谕谖谗谘谙谚谛谜谝谞谟谠谡谢谣谤谥谦谧谨谩谪谫谬谭谮谯谰谱谲谳谴谵谶豮贝贞负贠贡财责贤败账货质贩贪贫贬购贮贯贰贱贲贳贴贵贶贷贸费贺贻贼贽贾贿赀赁赂赃资赅赆赇赈赉赊赋赌赍赎赏赐赑赒赓赔赕赖赗赘",
  "赙赚赛赜赝赞赟赠赡赢赣赪赵赶趋趱趸跃跄跞践跶跷跸跹跻踌踪踬踯蹑蹒蹰蹿躏躜躯车轧轨轩轪轫转轭轮软轰轱轲轳轴轵轶轷轸轹轺轻轼载轾轿辀辁辂较辄辅辆辇辈辉辊辋辌辍辎辏辐辑辒输辔辕辖辗辘辙辚辞辩辫边辽达迁过迈运",
  "还这进远违连迟迩迳迹选逊递逦逻遗遥邓邝邬邮邹邺邻郏郐郑郓郦郧郸酂酝酦酱酽酾酿释鉴銮錾钅钆钇针钉钊钋钌钍钎钏钐钑钒钓钔钕钖钗钘钙钚钛钜钝钞钟钠钡钢钣钤钥钦钧钨钩钪钫钬钭钮钯钰钱钲钳钴钵钶钷钸钹钺钻钼钽钾",
  "钿铀铁铂铃铄铅铆铇铈铉铊铋铌铍铎铏铐铑铒铓铔铕铖铗铘铙铚铛铜铝铞铟铠铡铢铣铤铥铦铧铨铩铪铫铬铭铮铯铰铱铲铳铴铵银铷铸铹铺铻铼铽链铿销锁锂锃锄锅锆锇锈锉锊锋锌锍锎锏锐锑锒锓锔锕锖锗锘错锚锛锜锝锞锟锠锡锢",
  "锣锤锥锦锧锨锩锪锫锬锭键锯锰锱锲锳锴锵锶锷锸锹锺锻锼锽锾锿镀镁镂镃镄镅镆镇镈镉镊镋镌镍镎镏镐镑镒镓镔镕镖镗镘镙镚镛镜镝镞镟镠镡镢镣镤镥镦镧镨镩镪镫镬镭镮镯镰镱镲镳镴镵镶长门闩闪闫闬闭问闯闰闱闲闳间闵闶",
  "闷闸闹闺闻闼闽闾闿阀阁阂阃阄阅阆阇阈阉阊阋阌阍阎阏阐阑阒阓阔阕阖阗阘阙阚阛队阳阴阵阶际陆陇陈陉陕陦陧陨险随隐隶隽难雇雏雠雳雾霁霉霡霭靓靔静靥鞑鞒鞯鞲韦韧韨韩韪韫韬韵页顶顷顸项顺须顼顽顾顿颀颁颂颃预颅领",
  "颇颈颉颊颋颌颍颎颏颐频颒颓颔颕颖颗题颙颚颛颜额颞颟颠颡颢颣颤颥颦颧风飏飐飑飒飓飔飕飖飗飘飙飚飞飨餍饣饤饥饦饧饨饩饪饫饬饭饮饯饰饱饲饳饴饵饶饷饸饹饺饻饼饽饾饿馀馁馂馃馄馅馆馇馈馉馊馋馌馍馎馏馐馑馒馓馔馕",
  "马驭驮驯驰驱驲驳驴驵驶驷驸驹驺驻驼驽驾驿骀骁骂骃骄骅骆骇骈骉骊骋验骍骎骏骐骑骒骓骔骕骖骗骘骙骚骛骜骝骞骟骠骡骢骣骤骥骦骧髅髋髌鬓鬶魇魉鱼鱽鱾鱿鲀鲁鲂鲃鲄鲅鲆鲇鲈鲉鲊鲋鲌鲍鲎鲏鲐鲑鲒鲓鲔鲕鲖鲗鲘鲙鲚鲛鲜",
  "鲝鲞鲟鲠鲡鲢鲣鲤鲥鲦鲧鲨鲩鲪鲫鲬鲭鲮鲯鲰鲱鲲鲳鲴鲵鲶鲷鲸鲹鲺鲻鲼鲽鲾鲿鳀鳁鳂鳃鳄鳅鳆鳇鳈鳉鳊鳋鳌鳍鳎鳏鳐鳑鳒鳓鳔鳕鳖鳗鳘鳙鳚鳛鳜鳝鳞鳟鳠鳡鳢鳣鳤鸟鸠鸡鸢鸣鸤鸥鸦鸧鸨鸩鸪鸫鸬鸭鸮鸯鸰鸱鸲鸳鸴鸵鸶鸷鸸鸹鸺",
  "鸻鸼鸽鸾鸿鹀鹁鹂鹃鹄鹅鹆鹇鹈鹉鹊鹋鹌鹍鹎鹏鹐鹑鹒鹓鹔鹕鹖鹗鹘鹙鹚鹛鹜鹝鹞鹟鹠鹡鹢鹣鹤鹥鹦鹧鹨鹩鹪鹫鹬鹭鹮鹯鹰鹱鹲鹳鹴鹾麦麸麹麺黄黉黡黩黪黾鼋鼌鼍鼹齐齑齿龀龁龂龃龄龅龆龇龈龉龊龋龌龙龚龛龟鿎鿏鿒鿔"
].join(""));

/// Latin words that are normal inside Chinese or Japanese text: app and
/// service names, office shorthand, and the few English loanwords Taiwan
/// speech uses as-is. Words the user typed in their own situation are allowed
/// too (see strayLatin), so "tag", "LINE群組" or a product name they used
/// never trigger a retry.
const LATIN_OK = new Set([
  "app", "apps", "line", "ppt", "kpi", "ktv", "ceo", "cfo", "npc", "mrt", "ptt",
  "sns", "vip", "diy", "pdf", "dcard", "iphone", "ipad", "android", "google",
  "gmail", "email", "mail", "youtube", "youtuber", "netflix", "threads",
  "instagram", "facebook", "discord", "slack", "teams", "excel", "word", "zoom",
  "uber", "ubereats", "foodpanda", "switch", "steam", "wifi", "tiktok", "case",
  "deadline", "call", "tag", "high", "low",
  // Internet shorthand and the code-switching Taiwan chat uses as-is (review
  // 2026-10-22: these cost an unneeded retry). Japanese laughter (www…) is
  // matched separately in strayLatin.
  "lol", "lmao", "omg", "omfg", "wtf", "orz", "btw", "okay", "sorry", "care", "chill"
]);

/// Remove markdown the app would show literally: headings, bold / italic /
/// strikethrough pairs, inline code, list and quote markers at line start,
/// and the two-space hard line break. A marker glued to a Latin letter or
/// digit is left alone, so censoring ("f*ck", "sh*t") and snake_case survive;
/// CJK text has no spaces, so a CJK neighbour does not block the match.
export function stripMarkdown(text) {
  if (!text) return "";
  let t = String(text);
  t = t.replace(/^[ \t]{0,3}#{1,6}[ \t]+/gm, "");
  t = t.replace(/^[ \t]*>[ \t]?/gm, "");
  t = t.replace(/^[ \t]*[-*•][ \t]+/gm, "");
  t = t.replace(/`([^`\n]+)`/g, "$1");
  const pairs = [
    /(^|[^A-Za-z0-9*])(\*{1,3})(?=[^\s*])([^*\n]*?[^\s*])\2(?![A-Za-z0-9*])/gm,
    /(^|[^A-Za-z0-9_])(_{1,2})(?=[^\s_])([^_\n]*?[^\s_])\2(?![A-Za-z0-9_])/gm,
    /(^|[^~])(~~)(?=[^\s~])([^~\n]*?[^\s~])\2(?!~)/gm
  ];
  for (let pass = 0; pass < 3; pass++) {
    const before = t;
    for (const re of pairs) t = t.replace(re, "$1$3");
    if (t === before) break;
  }
  // Orphan runs of 2+ asterisks (an unclosed **bold) go too — except
  // self-censoring: a run glued to Latin letters on both sides ("f**k",
  // "a**hole", "f***ing") or closing a one- or two-letter fragment ("sh**",
  // "my a**"). Stripping those turned them into "fk" / "sh" / "ahole".
  t = t.replace(/\*{2,}/g, (run, at, s) => {
    const before = s.slice(0, at);
    const glued = /[A-Za-z0-9]$/.test(before);
    if (glued && /^[A-Za-z0-9]/.test(s.slice(at + run.length))) return run;
    if (glued && /(?:^|[^A-Za-z0-9])[A-Za-z]{1,2}$/.test(before)) return run;
    return "";
  });
  t = t.replace(/[ \t]+\n/g, "\n");
  return t;
}

/// Example words a vent prompt has carried: every current per-script list
/// (src/vent_prompt.js VOICES) plus the lists the pre-v1.7-cleanup prompt
/// sent, which is what the measured dump printed. A trailing bracketed list is
/// only removed when it is made of these words.
const OLD_PROMPT_WORDS = [
  "うるせえ", "マジで", "ふざけんな", "いい加減にしろ", "ありえねえ", "クソ", "クソが", "ふざけるな", "ばかやろう",
  "他媽的", "老子", "特麼", "服了", "裝什麼裝", "煩死了", "傻逼", "操", "幹", "滾", "神經病",
  "他妈的", "特么", "装什么装", "烦死了", "卧槽", "神经病", "尼玛", "屁话", "你妈", "操你妈"
];
const EXAMPLE_WORDS = [...new Set([
  ...OLD_PROMPT_WORDS,
  ...Object.values(VOICES).flatMap((v) => Object.values(v.vocab || {}))
    .flatMap((list) => String(list).split(/[、,，]\s*/))
].map((w) => w.trim()).filter((w) => w && !/[A-Za-z]/.test(w)))];

/// Drop a trailing bracketed group of two or more short, comma-separated
/// CJK items when at least half of them are the prompt's example words — the
/// word list printed after the draft. A single aside such as "(笑)", a genuine
/// aside such as "（煩、累）", a bracketed sentence, or anything with Latin
/// letters (an English aside like "(seriously, wtf)") is kept.
export function stripWordListTail(text) {
  const t = String(text || "");
  const m = t.match(/\s*[（(]([^()（）\n]{1,60})[)）]\s*$/);
  if (!m) return t;
  const items = m[1].split(/[、,，/／;；]/).map((s) => s.trim()).filter(Boolean);
  const listy = items.length >= 2 &&
    items.every((s) => s.length <= 10 && !/[。！？.!?A-Za-z\s]/.test(s));
  if (!listy) return t;
  const fromPrompt = items.filter((s) => EXAMPLE_WORDS.some((w) => s.includes(w))).length;
  return fromPrompt * 2 >= items.length ? t.slice(0, m.index).trimEnd() : t;
}

/// The cosmetic cleanup, never returning less than it was given: if stripping
/// would leave nothing, the original (trimmed) text stands.
export function cleanVentText(text) {
  const original = String(text || "").trim();
  const cleaned = stripWordListTail(stripMarkdown(original)).trim();
  return cleaned || original;
}

/// Runs of 3+ Latin letters in a zh / ja draft that are neither on the
/// allow-list, nor words the user typed, nor Japanese laughter (www…). Other
/// languages are never checked.
export function strayLatin(text, locale, situation = "") {
  const code = String(locale || "").toLowerCase();
  if (!code.startsWith("zh") && !code.startsWith("ja")) return [];
  const own = new Set((String(situation || "").match(/[A-Za-z]{3,}/g) || []).map((w) => w.toLowerCase()));
  return (String(text || "").match(/[A-Za-z]{3,}/g) || [])
    .filter((w) => !LATIN_OK.has(w.toLowerCase()) && !own.has(w.toLowerCase()) && !/^w+$/i.test(w));
}

/// Simplified-only characters in a Traditional Chinese draft ([] for every
/// other locale).
export function simplifiedChars(text, locale) {
  if (!isTraditionalChinese(locale)) return [];
  return [...String(text || "")].filter((c) => SIMPLIFIED_ONLY.has(c));
}

/// A unit of 2–4 Han / kana characters said three or more times in a row
/// (「根本根本根本」) in a zh / ja draft: the model stuck on repeat. Laughter,
/// interjections and one character over and over (哈哈哈哈哈哈, ねえねえねえ,
/// 滾滾滾滾滾滾) are not counted; a word said twice (「很長很長」) never is.
/// Returns the repeated units.
const REPEAT = /([\u3040-\u30ff\u3400-\u9fff]{2,4})\1{2,}/gu;
const INTERJECTION = /^[哈呵嘻嘿啊喔哦欸吼齁啦嗚嗯呀耶あぁいぃうぅえぇおぉねよなわっーアイウエオ]+$/u;
export function repeatedUnits(text, locale) {
  const code = String(locale || "").toLowerCase();
  if (!code.startsWith("zh") && !code.startsWith("ja")) return [];
  return [...String(text || "").matchAll(REPEAT)].map((m) => m[1])
    .filter((u) => new Set(u).size > 1 && !INTERJECTION.test(u));
}

// Common single-character surnames (Taiwan and mainland lists, both scripts).
const SURNAMES = new Set([..."陳陈林黃黄張张李王吳吴劉刘蔡楊杨許许鄭郑謝谢郭洪曾邱廖賴赖周徐蘇苏葉叶莊庄呂吕江何蕭萧羅罗高潘簡简朱鍾钟彭游詹胡施沈余趙赵盧卢梁顏颜柯孫孙魏翁戴范宋方鄧邓杜傅侯曹薛丁卓阮馬马董唐藍蓝蔣蒋石古紀纪姚連连馮冯歐欧程湯汤田康姜白汪鄒邹尤巫黎涂龔龚嚴严韓韩袁金童陸陆夏柳邵錢钱伍倪溫温譚谭熊任秦顧顾毛章史萬万俞雷崔尹孔辛賀贺龍龙段郝邢孟喬乔賈贾鄔邬焦付覃"]);
// What typically follows a name used as the subject or object in a vent:
// 「陳志明又在…」「王强把…」. Generic followers (是 / 的 / 在 / 都 / punctuation)
// are left out on purpose: with them 「紀念日，」「高鐵的…」 would look like
// names.
const NAME_FOLLOWERS = new Set([..."又把說说講讲跟竟居每還还就也被給给叫問问突老總总再已"]);
// What comes right before a name: the end of a role word (老闆 / 同事 / 主管 /
// 室友 / 學長 …), a preposition, or the start of a sentence. Without this,
// 「在周会上说」「让我周末把」 read as names.
const NAME_PRECEDERS = new Set([..."闆板事管司長长友姊姐哥弟妹爸媽妈公婆舅叔姨嫂師师生學学員员東东客任跟和被對对給给叫找問问幫帮"]);
const NOT_NAMES = new Set(["周末", "週末", "周一", "周二", "周三", "周四", "周五", "周六", "周日", "周會", "周会", "周年", "方案", "方法", "高鐵", "高铁", "馬上", "马上", "萬一", "万一", "任何", "何必", "連續", "连续", "金額", "金额"]);
const HAN = /[\u3400-\u9fff]/;

/// Names of people in a situation. Chinese: a common surname plus one or two
/// more Han characters, right after a role word, a preposition or the start of
/// a sentence, and followed by one of NAME_FOLLOWERS (「慣老闆陳志明又…」
/// 「同事王强把…」). English: a capitalised word right after a role word ("my
/// manager Kevin", "my roommate Jess"; the role word in lower case, as in a
/// sentence, so a title like "Roommate Group" is not read as one), so places
/// and products ("in Vegas", "on Slack") never count. Deliberately narrow — a miss only means the name
/// is left to the prompt, as before, while a false hit would make a retry
/// prefer a draft without an ordinary word. Japanese and Korean return [].
const EN_ROLE_NAME = /\b(?:manager|boss|supervisor|co-?worker|colleague|room-?mate|flatmate|housemate|landlord|landlady|neighbou?r|friend|bestie|boyfriend|girlfriend|husband|wife|partner|ex|sister|brother|cousin|mom|mum|mother|dad|father|aunt|uncle|teacher|professor|coach|classmate|teammate|client|customer|son|daughter|in-law)\s+([A-Z][a-z]{2,})\b/g;
const EN_NOT_NAMES = new Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
  "January", "February", "March", "April", "June", "July", "August", "September", "October", "November", "December"]);
export function situationNames(situation, locale) {
  const code = String(locale || "").toLowerCase();
  const s = String(situation || "");
  if (code.startsWith("zh")) return chineseNames(s);
  if (code.startsWith("ja") || code.startsWith("ko")) return [];
  return [...new Set([...s.matchAll(EN_ROLE_NAME)].map((m) => m[1])
    .filter((n) => /^[A-Z]/.test(n) && !EN_NOT_NAMES.has(n) && !LATIN_OK.has(n.toLowerCase())))];
}

function chineseNames(s) {
  const found = new Set();
  for (let i = 0; i < s.length; i++) {
    if (!SURNAMES.has(s[i])) continue;
    const prev = i > 0 ? s[i - 1] : "";
    if (prev && HAN.test(prev) && !NAME_PRECEDERS.has(prev)) continue;
    for (const len of [3, 2]) {
      const name = s.slice(i, i + len);
      const next = s[i + len];
      if (name.length === len && [...name].every((c) => HAN.test(c)) && next && NAME_FOLLOWERS.has(next) &&
          !NOT_NAMES.has(name.slice(0, 2))) {
        found.add(name);
        break;
      }
    }
  }
  return [...found];
}

// Titles that follow a surname when a person is named by role: 陳主管,
// 王經理, 林老師, 張總, 李姐 (both scripts; the two-character titles first,
// then the one-character ones, so 「陳總監」 is found as 陳總).
const TITLES = ["主管", "經理", "经理", "老闆", "老板", "老師", "老师", "先生", "小姐", "太太", "主任",
  "組長", "组长", "課長", "课长", "科長", "科长", "處長", "处长", "部長", "部长", "店長", "店长",
  "副理", "協理", "协理", "襄理", "特助", "秘書", "秘书", "教授", "醫師", "医师", "醫生", "医生",
  "律師", "律师", "同學", "同学", "學長", "学长", "學姊", "學姐", "学姐", "學弟", "学弟", "學妹", "学妹",
  "阿姨", "師傅", "师傅", "董", "總", "总", "哥", "姐", "姊"];
// Common words that END in a surname character, so the character is not a
// surname there: 「對方主管」 is not 方主管, 「每周主管會議」 is not 周主管.
const SURNAME_IN_WORD = new Set(["對方", "对方", "雙方", "双方", "甲方", "乙方", "官方", "地方", "一方", "各方", "警方", "校方",
  "每周", "上周", "下周", "本周", "這周", "这周", "一周", "两周", "兩周", "提高", "最高", "很高", "太高",
  "責任", "责任", "主任", "信任", "擔任", "担任", "現金", "现金", "資金", "资金", "獎金", "奖金", "租金",
  "明白", "告白", "坦白", "空白", "工程", "課程", "课程", "過程", "过程", "流程", "行程", "歷史", "历史",
  "文章", "健康", "行李", "森林", "手段", "其余", "支付", "預付", "预付", "應付", "应付",
  "任何", "如何", "為何", "为何", "奈何", "幾何", "几何", "有錢", "有钱", "金錢", "金钱", "千萬", "千万"]);
// 總 / 总 starts ordinary words too: 總共, 總算, 總之, 總是.
const NOT_AFTER_ZONG = new Set([..."共算之是"]);

/// Surname + title forms of the people a Chinese situation names, as they
/// appear in `text`: for 「慣老闆陳志明…」 a draft's 「陳主管」 or 「陳先生」.
/// Only surnames taken from a name detected in THIS situation count, so an
/// unrelated 「王經理」 never does. Deliberately narrow, like situationNames.
///
/// Used only for drafts written in a Pro style's voice (index.js passes
/// `{ titles: true }` to echoedNames / stripNameAddress / draftDefects): a
/// polite or formal voice is what reached for 「陳主管欸」 (style gate
/// 2026-10-22). Unstyled Vent / Feral drafts keep exactly HEAD 4ed652f's name
/// handling (full names only) until the owner decides otherwise.
export function surnameTitles(text, locale, situation = "") {
  const code = String(locale || "").toLowerCase();
  if (!code.startsWith("zh")) return [];
  const t = String(text || "");
  const surnames = new Set(situationNames(situation, locale).map((n) => n[0]));
  const found = new Set();
  for (const surname of surnames) {
    for (let i = t.indexOf(surname); i !== -1; i = t.indexOf(surname, i + 1)) {
      if (i > 0 && SURNAME_IN_WORD.has(t[i - 1] + surname)) continue;
      const title = TITLES.find((x) => t.startsWith(x, i + 1));
      if (!title) continue;
      if ((title === "總" || title === "总") && NOT_AFTER_ZONG.has(t[i + 2] || "")) continue;
      found.add(surname + title);
    }
  }
  return [...found];
}

/// The situation's names that a draft repeats (English: as a whole word),
/// and, with `titles` (styled drafts only), a detected Chinese name's surname
/// followed by a title.
export function echoedNames(text, locale, situation = "", { titles = false } = {}) {
  const t = String(text || "");
  const full = situationNames(situation, locale)
    .filter((n) => (/^[A-Za-z]/.test(n) ? new RegExp(`\\b${n}\\b`).test(t) : t.includes(n)));
  return titles ? [...new Set([...full, ...surnameTitles(t, locale, situation)])] : full;
}

/// Remove a name from the situation where the draft uses it to address that
/// person: opening the draft (「陳志明你又…」 → 「你又…」, 「王强，你…」 → 「你…」,
/// 「陳主管，你…」 → 「你…」 with `titles`, "Kevin, you…" → "You…") or, in
/// English, closing a sentence ("Fuck you, Kevin." → "Fuck you."). In those
/// positions the name is a vocative, so dropping it keeps the sentence whole;
/// anywhere else the text is left alone (and the quality retry sees the name).
export function stripNameAddress(text, locale, situation = "", { titles = false } = {}) {
  let t = String(text || "");
  const names = situationNames(situation, locale);
  for (const name of titles ? [...names, ...surnameTitles(t, locale, situation)] : names) {
    const latin = /^[A-Za-z]/.test(name);
    const lead = (t.match(/^(\s*[「『“"]?)/) || ["", ""])[1];
    if (t.startsWith(name, lead.length) && !(latin && /^[a-z]/.test(t[lead.length + name.length] || ""))) {
      const rest = t.slice(lead.length + name.length);
      if (!latin && /^[你妳]/.test(rest)) t = lead + rest;
      else if (/^\s*[，,、：:！!—]\s*\S/.test(rest)) {
        const after = rest.replace(/^\s*[，,、：:！!—]\s*/, "");
        t = lead + (latin ? after[0].toUpperCase() + after.slice(1) : after);
      }
    }
    if (latin) t = t.replace(new RegExp(`,\\s*${name}(?=\\s*[.!?])`, "g"), "");
  }
  return t;
}

/// What is wrong with a draft that only a new draft can fix. `titled` lists
/// the surname + title forms among `names` (always empty without `titles`);
/// it only adds a clause to the retry nudge, so it is not counted twice.
export function draftDefects(text, locale, situation = "", { titles = false } = {}) {
  const latin = strayLatin(text, locale, situation);
  const simplified = simplifiedChars(text, locale);
  const repeats = repeatedUnits(text, locale);
  const names = echoedNames(text, locale, situation, { titles });
  const titled = titles ? surnameTitles(text, locale, situation) : [];
  return { latin, simplified, repeats, names, titled, count: latin.length + simplified.length + repeats.length + names.length };
}

/// True when draft `b` is better than draft `a`: fewer of the user's names,
/// then fewer defects overall.
export function fewerDefects(b, a) {
  if (b.names.length !== a.names.length) return b.names.length < a.names.length;
  return b.count < a.count;
}

/// The defect kinds present, for the operational log (never the words).
export function defectKinds(defects) {
  return ["latin", "simplified", "repeats", "names"].filter((k) => defects && defects[k] && defects[k].length > 0);
}

/// The model for the one quality retry: the model that just answered, so the
/// retry is a fresh draft from the same model with a nudge. If the provider
/// did not say which model answered, the same list the successful call sent
/// (OpenRouter routes it the same way). Never a model that already failed in
/// this request: `candidates` is the list of the call that succeeded.
///
/// Why not the fallback model (the first version did that): forced onto
/// qwen3-next-80b-a3b-instruct with this prompt, 4 of 4 Chinese drafts named
/// the person from the user's situation (陳志明 ×3, 王强 ×1), usually as the
/// first word, against the explicit no-names rule; the primary named nobody
/// in 23 gate drafts (gate 2026-10-22). Retrying there swapped a stray English
/// word for an identifying detail that may end up on a share image. And after
/// a tail retry the old choice went back to the primary that had just failed.
export function retryModels(candidates, used) {
  const list = (candidates || []).filter(Boolean);
  if (used && list.includes(used)) return [used];
  return list;
}

/// One extra line for the retry's user prompt, naming the kind of defect —
/// never quoting the draft. The surname + title clause is added only when
/// draftDefects found that form (styled drafts only), so every other retry
/// prompt is unchanged — including one for a full name that merely looks like
/// surname + title (「陳先生又…」 detected as the name 陳先生).
export function retryNudge(defects, locale) {
  const latin = Boolean(defects && defects.latin && defects.latin.length > 0);
  const simp = Boolean(defects && defects.simplified && defects.simplified.length > 0);
  const rep = Boolean(defects && defects.repeats && defects.repeats.length > 0);
  const names = Boolean(defects && defects.names && defects.names.length > 0);
  const titled = names && Boolean(defects.titled && defects.titled.length > 0);
  if (!latin && !simp && !rep && !names) return "";
  const code = String(locale || "").toLowerCase();
  const parts = [];
  if (isTraditionalChinese(locale)) {
    if (latin && simp) parts.push("這次全文只用中文，不要夾英文單字，而且每一個字都要是繁體字。");
    else if (latin) parts.push("這次全文只用中文，不要夾英文單字。");
    else if (simp) parts.push("這次每一個字都要是繁體字，不要出現任何簡體字。");
    if (rep) parts.push("同一個詞不要連著重複。");
    if (names) parts.push("不要寫出任何人名，連開頭稱呼也不要，用「那個主管」「對方」這類稱呼。");
    if (titled) parts.push("也不要用姓氏加職稱的叫法，只寫職稱或「對方」。");
  } else if (code.startsWith("zh")) {
    if (latin) parts.push("这次全文只用中文，不要夹英文单词。");
    if (rep) parts.push("同一个词不要连着重复。");
    if (names) parts.push("不要写出任何人名，连开头称呼也不要，用「那个领导」「对方」这类称呼。");
    if (titled) parts.push("也不要用姓氏加职称的叫法，只写职称或「对方」。");
  } else if (code.startsWith("ja")) {
    if (latin) parts.push("今回は英単語を混ぜず、すべて日本語で書くこと。");
    if (rep) parts.push("同じ言葉を続けて繰り返さないこと。");
  } else if (names) {
    parts.push("Do not use anyone's name anywhere, not even to address them; say \"you\" or their role.");
  }
  return parts.join("");
}
