# 美术资产档案（Blender 产出归档）

## 2026-10-11 战斗反馈粒子资产（Blender MCP）

- 生成：`dev/build_combat_effects.py`、`dev/build_boss_shock_ring.py`、`dev/build_boss_root_spike.py`，归档组合入口 `dev/build_combat_effect_archive.py`（前三项）。单位Meters，底部中心原点，Blender Z向上→Godot Y向上。
- 每项均有1K Albedo/Normal/Roughness/Metallic/AO/ORM/Emission，七张PNG；GLB四张内嵌图像，PBR金属0、粗糙度0.8，发光4.0。无骨架：短粒子、震波和地刺由运行时运动驱动。

| 资产 | 三角面 | Godot尺寸（米，XYZ） | 模型/源/参考 |
|---|---:|---|---|
| impact_shard | 20 | 0.044×0.288×0.045 | art/models/prop/impact_shard.glb；art/source/impact_shard.blend；art/previews/prop/impact_shard.png |
| boss_debris | 20 | 0.282×0.360×0.227 | 同名 prop GLB / source BLEND / previews/prop PNG |
| boss_shock_ring | 1024 | 2.000×0.080×2.000 | 同名 prop GLB / source BLEND / previews/prop PNG |
| boss_root_spike | 44 | 0.745×1.700×0.400 | 同名 prop GLB / source BLEND / previews/prop PNG |

- 贴图分别 `art/textures/<资产名>/`。根须尖刺已应用三角化，避免导出切线缺失。模型总数59，未贴图旧模型0。
- Godot挂接：DartProjectile短拖尾、CombatImpact火花/闪环、HitEffect碎石粒子、BossGroundWave双层传播与多区域根须；原地形/世界坐标和巨兽骨骼资产不重做。
- 实景与验证见 `art/audit/survivor_dart_master_2026_10_11.md` 的最新试玩反馈章节。受控展示图不能代替真实攻击测试；仍有原有退出资源泄漏提示。

## 2026-10-11 第三人称割草与参考图飞镖师（当前生产玩法）

用户最新要求覆盖旧第一人称战士RPG：开新局只选择「飞镖师」，没有装备/背包强化、小精灵、旧回响收藏/准备槽、回响碑或观测台回响祭坛。历史资源和脚本保留归档，但生产Player没有这些组件，DataRegistry只注册dart_master。依赖旧装备/回响的任务链退出会话，NPC保留闲聊；草药直接回血60，宝箱提供40/80经验。单一森林主世界、苔冠巨兽完整遗迹与凶焰飞龙保留。

- 玩家200生命、10固有护甲，第三人称SpringArm碰撞镜头；飞镖师19196 tris、50骨、10动作、2K完整PBR。以用户三视图 `art/references/dart_master_turnaround.png` 为造型依据：黑发、红头带/围巾/腰巾、米白上衣、皮革交叉绑带、金属护具和飞镖袋。属于重新建模的实时版本，服饰雕刻和面部细节有简化，不是原图的高精度1:1模型。护具属于服装造型，不提供装备系统。独立手指、围巾链、头带及衣摆骨骼；Blender源/参考/贴图/GLB均归档。
- 初始6枚环绕飞镖，半径2.2m，攻击18；每级基础攻击+2。左键实际环绕飞镖逐枚投出、归航，无限循环；0.18s首次出手（随攻速同步缩短），初始0.75s接触间隔。接触和投射有扫掠/墙体判定。
- 经验基础需求24，每级乘1.18。升级从五种能力随机抽取不重复的3项，选择1项；连续升级排队，选项和待选次数可保存。数量+2且半径+0.35m；攻速使高于0.12s的剩余间隔乘0.86，并同步加快投掷动作；攻击加成每级+25%基线；移速每级+0.52m/s（基线6.5）；奥义每级+2s（基线10）。
- 命中积蓄新回响值，满100右键结印0.45s发动「奥义·影分身之术」，生成3个AI分身。分身使用相同模型、体型、攻击/攻速/半径/数量/移速成长数据，优先本体攻击过或正在追击本体的怪物，自主导航与齐射。基础持续10秒，回响线性耗尽；技能中不回充，不能递归召唤。死亡/到时清理分身。
- DartAnimator走跑连续混合，投掷/结印/受击只叠加上半身，跳跃叠加下肢，转身平滑；步频按实际速度标定。Blender70次动作采样有限值通过，跑步触地平均滑移约0.0000014m/s（作者步速3.85m/s的采样，不代表所有实景坡面/转向均零滑动）。无脚底地形IK、面部口型或实时布料模拟。
- 主世界HordeDirector离营地持续刷新，逐渐加密，额外敌人上限45；击杀掉落Blender经验结晶，3.5m自动吸附。存档schema2记录新玩法成长，旧RPG存档保留原文件，继续游戏仅带入世界进度，角色转为一级飞镖师；首次保存新玩法后新载荷不含旧装备/回响。
- 前轮验收：新版完整回归65项无头通过，Compatibility GPU65项通过，Forward+/D3D12 GPU65项通过；真实森林、升级卡片、分身实景已截图。日志仍有已有的导航烘焙性能提示与退出时59份渲染资源泄漏警告，不能宣称零警告。旧RPG开机自检场景归档 `dev/legacy/verify_boot_rpg.tscn`，当前 `dev/verify_boot.tscn` 指向新玩法完整回归。
- 前轮模型55项，新增 `player/dart_master`、`prop/shadow_dart`、`prop/experience_crystal`；全套源文件/PNG贴图/参考图归档。角色生产生成入口 `dev/build_dart_master.py` → `dev/build_dart_master_reference.py`；旧蓝衣原型仅归档。


## 2026-10-11 更新：单一主世界、完整遗迹迁入与凶焰飞龙

- 用户要求仅一片世界，直接把原秘境整个搬到森林。生产GameSession移除DungeonManager，森林NavRegion直接挂main_world_grove.tscn（沿用原forest_grove_dungeon逻辑、main_world_mode=true），中心(-85,0,-5)，南门(-85,0,25)。60×60遗迹、两波野狼、巨兽、四石柱、宝箱与首通/掉落奖励均保留；巨兽召唤的嫩芽也在森林内生成。入口无任务门槛，无传送/独立天空/另一个导航世界，南北墙有真实门洞；死亡仍回营地，3.5秒后原地复位遗迹，世界对象保持不变。
- 地形增加方形平整台地及6m过渡，排除区域内随机树石，补营地北行路和北门道路，猎人小屋旧路绕过东墙。石柱/召唤/前摇特效/波次文字从局部坐标改为世界坐标；南门连接森林导航。地图/罗盘常驻「兽」「龙」，告示板和冰封试炼交付对白指引新位置；旧secret_realm_open/dungeon_first_clear/dungeon_grove_cleared保存键保留兼容，生产运行世界id只用forest。历史独立秘境模板与管理器源文件供开发回归，生产场景无入口或管理器引用。
- 新增enemy/dread_wyvern.glb：9224tris、30骨、11动作（idle/fly/dive_windup/dive/recover/fire_windup/fire/hit/stagger/death/land），2K Albedo/Normal/Roughness/Metallic/AO/ORM/Emission全套独立PNG，GLB内嵌。尺寸约19.01m翼展×10.22m体长×5.05m高；两翼/两腿/四节长尾、角、牙、爪与背刺，灰黑裂鳞、棕色腹甲、赤褐翼膜与发光眼。以原型结构的风格化奇幻表现为主，细节由Blender程序材质烘焙；非照片扫描或毛发模拟。原点底部中心，Blender-Y→Godot+Z，运行时Visual转PI兼容AI-Z。
- 飞龙原生出生在森林东北(45,地形高度+12,-96)，18m半径巡航。900血/28攻/12甲，使用BossComponent失衡抗控。俯冲：1.2s前摇锁定落点，1.1s扫掠飞行、36原始伤害/3.3m判定，每次最多一次；3.2s收招，前约1.8s落地供战士近战反击，随后升空。火球：1.1s蓄力、单发22m/s锁定方向，28原始伤害、2.2m爆炸、4DPS×3s灼烧；射线检测墙与玩家，遮挡阻断伤害，不追踪玩家。两招由正常AI交替；死亡/回营地/越过巢区62m立即取消攻击，满失衡下降形成破绽。翅翼无单独物理阻挡/受击体，仅躯干箱体受击；实际近战命中已测。
- 新增prop/wyvern_fireball.glb：320tris、直径约0.96m、1K完整PBR+Emission（强度4），火红裂隙的岩浆弹；投射物原点为球心以匹配扫掠轨迹。无真实流体/体积火焰。飞龙眼Emission强度3；皮肤/翼膜roughness约0.64–0.83，非金属，甲壳metallic0.08。Blender参考为冷环境+暖侧光，已核对Compatibility实景。
- 归档：两模型art/models/{enemy/dread_wyvern,prop/wyvern_fireball}.glb；同名art/textures/、art/source/*.blend、art/previews/<分类>/*.png齐全，源文件独立打包贴图与原材质。构建dev/build_dread_wyvern.py、dev/build_wyvern_fireball.py，发布dev/publish_wyvern_assets.py通过55个动作采样的有限坐标与变形范围校验。
- 验证：dev/verify_single_world_wyvern.tscn最终59项通过，覆盖单世界/门洞路径/生物和石柱全局坐标/正常AI两招/前摇/躲避/单次命中/墙挡火球/灼烧/失衡/营地/实际战士近战/受击/死亡/地面掉落/存档击杀标记。完整dev/verify_boot.tscn通过，废弃维度切换检查替换为整区迁入、死亡回营地、森林不卸载和场地复位，保留原全部战斗/奖励/任务/存档回归。日志dev/single_world_wyvern_verify_final.log和dev/single_world_boot_verify.log；Compatibility实景6张已查看：grove_in_main_world、grove_walk_in_entrance、dread_wyvern_in_forest、dread_wyvern_head、dread_wyvern_fireball、dread_wyvern_dive。后两张为受控动作/发弹画面，不是全程实战录像。
- 最终审计52模型，旧无贴图0，缺失引用0；森林导航5600多边形。Forward+/D3D12未做本轮视觉验收；长时间游玩/帧率未量测，已有导航体素参数警告与退出RID/资源释放告警仍在。未新增世界尺寸、飞龙骑乘、关节IK或真实火焰模拟。

## 2026-10-11 更新：剩余11项贴图、精灵与大型七招式巨兽

- 批次承接2026-10-10授权：保留中世纪奇幻轮廓，增强石材颗粒、树皮纵纹、木材与金属表面；全部在Blender MCP中建模/材质烘焙/绑定/渲染，非照片扫描或逐笔手绘。未重做已完成的NPC、狼、树等资产。
- 下表尺寸为宽×深×高（米，骨骼模型取待机导出包围盒），面数为GLB索引实测；风车扇叶原点保留轴心、霜痕之刃保留既有握持挂点。其余根原点贴近底部中心，正面Godot +Z；篝火石圈底缘约下埋1.35cm。

| 模型 | tris | 宽×深×高 m | 骨骼 / 动作 | PBR分辨率 |
|---|---:|---|---:|---:|
| scenery/campfire | 3346 | 2.37 × 2.29 × 1.50 | 0 / 1 | 1024² |
| scenery/windmill | 4772 | 3.85 × 3.91 × 10.13 | 0 / 0 | 1024² |
| scenery/windmill_blades | 1916 | 9.00 × 0.50 × 9.00 | 0 / 0 | 1024² |
| scenery/dungeon_gate | 2156 | 4.60 × 1.30 × 5.89 | 0 / 0 | 1024² |
| scenery/dungeon_pillar | 3368 | 1.89 × 1.89 × 5.10 | 0 / 0 | 1024² |
| player/frost_edge | 1630 | 0.19 × 0.05 × 0.98 | 0 / 0 | 1024² |
| spirit/glow_wisp | 1684 | 0.68 × 0.37 × 0.47 | 5 / 8 | 2048² |
| spirit/flame_crystal | 420 | 0.43 × 0.37 × 0.61 | 5 / 8 | 2048² |
| spirit/stone_guardian | 3144 | 0.80 × 0.34 × 0.84 | 7 / 8 | 2048² |
| boss/boss_sprout | 4020 | 0.80 × 0.33 × 1.05 | 7 / 8 | 2048² |
| boss/moss_crown_beast | 5818 | 4.51 × 9.09 × 6.43 | 24 / 16 | 2048² |

- 六张独立Albedo/Normal/Roughness/Metallic/AO/ORM PNG；除巨兽外另有Emission，篝火另有RGBA火焰卡。GLB内嵌打包图集，UV/法线/切线完整。木/石/织物粗糙度约0.67–0.97，钢材约0.27/金属度0.95；精灵发光强度2、符文3、火焰1.7。资产统一归档art/models/<分类>/<名>.glb、art/textures/<名>/、独立art/source/<名>.blend、art/previews/<分类>/<名>.png；旧GLB备份art/backups/remaining_{static,actors}_before_2026_10_10.zip。
- 静态资源：炭木石圈篝火+三张动态火焰卡，风车石基/木架/帆布扇叶，楔形拱石门、分段石柱，霜痕之刃保留挂点并增加冰蓝刻纹。camp.gd使用导入篝火动画、不叠旧方片粒子，补齐风车转轴引用。入口石门在洞口按Y=0.6装配为3.53m高，适配3.65m洞顶；两侧碰撞同步，门控任务保持。
- 三精灵分别为花瓣灯芯、熔岩晶体、碎石守卫；嫩芽有树皮和根须。独立5/5/7/7骨，各8动作idle/walk/attack/heal/shield/taunt/hit/death；SpiritEntity按真实效果播放、结束回待机，击退触发hit。嫩芽播放行走/滋养/死亡，适配大型巨兽时5m开始治疗，治疗比例和持续时间保持。
- 苔冠巨兽由已验证四足拓扑扩展出石甲、粗前肢、角冠和垂根，体长9.09m、肩背约4.5m、角冠6.43m，24骨16动作。七招为横扫/冲撞/召唤/践踏/前掌重砸/甩尾/根须；前摇与动作峰值对齐，单次结算和收招，破绽立即清空技能与预警，骨骼死亡。践踏1.1s/9m/24伤（可跳过），重砸1.0s/锁定前方2.5m/32伤，甩尾0.95s/后方7m120°/26伤，根须1.3s/锁定2.2m/12伤+1.5s束缚（仍可攻击格挡）；第二阶段解锁根须与召唤，第三阶段冲撞后接横扫。保留600血/20攻/15甲与既有掉落首通存档规则。
- 巨兽身体碰撞直径4m高5m，受击箱4.5×5.2×8.5m；近战按箱体最近表面过滤，修正巨兽头前打不到中心点的问题。秘境中心移至(0,0,-5)，石柱半径9→13m，竞技场门Z=12、触发区在门内，行走/冲撞为体长预留边缘。秘境复用Blender土路材质、树石和石墙模块，校正朝下暖主光与稀薄雾，不新增Godot美术材质。
- 验证：dev/verify_remaining_assets.tscn 197项通过（完整PBR/UV/蒙皮/动作/归档、精灵实体事件、篝火形变、风车旋转、四新招式时序/躲避/失衡中断、巨兽近战方向）；每段骨骼动画在5个时刻检查有限形变和包围盒。dev/verify_boot.tscn完整开机自检VERIFY ALL OK，含战斗/五任务/撞柱/召唤/首通/秘境进出/存档恢复。最终日志dev/remaining_final_verify.log、dev/remaining_boot_final.log。
- Compatibility/OpenGL真实营地、瀑布入口及秘境截图已归档：campfire_in_camp、windmill_in_camp、dungeon_gate_in_forest、spirits_in_camp、moss_crown_beast_in_arena及七招姿态。森林导航6112多边形、秘境50。Forward+/D3D12视觉未验收；没有脚底IK/面部口型或实机长时间性能结论。既有退出RID/资源诊断、无头拍照空纹理提示仍存在，不能宣称零日志警告。
- 审计50个GLB，缺失引用0，旧无贴图模型11→0；这是本批导出资产的完整性结果，不代表整个游戏已达到最终美术质量。未来若继续提升，应单独处理仍存在的程序化功能设施、整体光照与远景品质，而不是把它们计入本批已完成11项。

## 2026-10-10 更新：营地帆布帐篷

- Blender MCP重做scenery/tent.glb：1876tris、1030源顶点，宽2.927×深2.800×高1.948m，底部中心原点、米制、Godot +Z。厚帆布坡面、木脊梁/支柱、闭合皮革门帘、包边/缝线、蓝色营地标记和拉绳木桩；封闭外观，无室内、开门、骨骼或动画，无导出碰撞。
- 六张1024² Albedo/Normal/Roughness/Metallic/AO/ORM PNG，GLB内嵌3图，完整UV与切线。Blender程序材质烘焙，非逐笔手绘；帆布粗糙度0.92、缝边0.9、木架0.82、皮革0.84、蓝饰0.9，使用部位均非金属，无发光。
- 归档art/models/scenery/tent.glb、art/textures/tent/、独立art/source/tent.blend、art/previews/scenery/tent.png及真实营地tent_in_camp.png；旧模型备份art/backups/tent_before_2026_10_10.zip。发布支持从保存的制作场景恢复，补载独立粗糙度等通道，避免依赖Blender会话仍保留烘焙数据。
- camp.gd同路径自动加载三顶帐篷，生产脚本未改；原三处坐标、3×2×3m碰撞、nav_source障碍保持，所有拉绳/木桩均位于该范围。未新增交互或改变营地通行布局。
- dev/verify_tent.tscn最终无头35项、Compatibility/OpenGL实景36项通过，覆盖三实例/坐标/实际模型/尺寸/材质/UV/面数/碰撞与导航源；森林导航6111多边形。早期verify.log因发布未成功仍加载旧模型而失败，最终结果见verify_final.log和gpu.log。本轮未重跑全量开机自检；Forward+/D3D12视觉待验收，既有导航解析和退出资源诊断仍存在。
- 审计缺失GLB引用0、模型50项、未贴图旧模型12→11。复现：dev/prepare_tent.py生成构建脚本，Blender MCP运行dev/build_tent.py、dev/publish_tent.py，再Godot导入；验证记录dev/art_work/tent/。

## 2026-10-10 更新：森林采集草药

- Blender MCP重做prop/herb.glb：2696tris、1522源顶点，约0.58×0.58×0.784m，三支高低花茎、金色花穗、17片有厚度折面叶与叶脉；底部中心原点、米制、Godot +Z，静态植物无骨骼/动画，无透明卡片或导出碰撞。发布时校正斜茎底端到地平面，后续构建脚本同步此处理。
- 六张1024² Albedo/Normal/Roughness/Metallic/AO/ORM PNG，GLB内嵌3图，完整UV与切线；Blender程序材质烘焙，非逐笔手绘。叶片粗糙度0.82–0.85、茎0.88、花穗0.72，全非金属、无自发光。金色花穗用于与普通草簇区分。
- 归档art/models/prop/herb.glb、art/textures/herb/、独立art/source/herb.blend、art/previews/prop/herb.png及真实森林herb_in_forest.png；旧模型和逻辑备份art/backups/herb_before_2026_10_10.zip。
- gather_node.gd沿用模型自动加载和隐藏旧占位，采集位置/碰撞/material_id=forest_herb/每次1份/20秒刷新均保持；增加_depleted同步保护，防止刷新前重复触发交互多领材料。未新增存档字段或改变任务目标。
- dev/verify_herb.tscn无头17项、Compatibility/OpenGL森林实景18项通过：材质尺寸/UV/切线/预算/底部原点、原采集配置、隐藏占位、采集后隐藏与禁用碰撞、重复请求只得1份、刷新后可再次采集。专项将测试实例刷新时间临时缩至0.2秒后还原20秒，不写玩家存档。真实森林导航6111多边形。本轮未重跑全量开机自检；Forward+/D3D12视觉尚待验收，既有导航和退出资源泄漏诊断仍存在。
- 审计缺失GLB引用0、模型50项、未贴图旧模型由13降至12。复现：dev/prepare_herb.py→Blender MCP执行dev/build_herb.py、dev/publish_herb.py→Godot导入；日志及归档验证dev/art_work/herb/。

## 2026-10-10 更新：可开盖木铁宝箱完整贴图

- Blender MCP重做prop/chest.glb：2836tris，两份网格Body/Lid，约1.03m宽、0.65m深、0.65m闭合高；空心木板箱体、底板、拱形盖和封闭端板、铁带、铆钉、锁扣、两侧提手。米制、底部中心原点、Godot +Z；Lid原点在后缘Godot (0,0.49,-0.30)，沿用chest.gd的-105°开盖逻辑，无骨骼或导出碰撞。
- 六张1024² Albedo/Normal/Roughness/Metallic/AO/ORM PNG，GLB内嵌3图，两网格共用完整UV图集和切线。Blender程序材质烘焙，非逐笔手绘；木粗糙度0.78–0.82/金属度0，铁0.48/金属度0.85，无新增Emission。普通/稀有箱共用模型，稀有箱沿用既有运行时灯光。
- 归档art/models/prop/chest.glb、art/textures/chest/、独立art/source/chest.blend、art/previews/prop/chest.png与chest_open.png；chest_in_game.png为Compatibility受控开闭对照预览。替换前模型与脚本备份art/backups/chest_before_2026_10_10.zip。
- Godot自动加载同路径资产，生产脚本未修改；原碰撞、掉落表、宝箱ID和存档流程保持。导出阶段修正分离选择，确保开盖只带动盖；补齐盖两端，避免闭合时侧面空隙。
- dev/verify_chest_art.tscn无头20项、Compatibility/OpenGL21项通过，检查两网格、1K贴图/UV/切线/预算、后缘转轴/向上开盖、开启记录去重及内存会话恢复。未写玩家存档，本轮未重跑全量开机自检；未修改掉落逻辑。Forward+/D3D12视觉未验收；退出资源泄漏及导入纹理UID回退到有效路径的诊断仍存在，贴图加载检查通过。
- 审计缺失GLB引用0、模型50项、未贴图旧模型由14降至13。复现dev/prepare_chest.py生成构建脚本，Blender MCP执行dev/build_chest.py与dev/publish_chest.py，再Godot导入；报告dev/art_work/chest/archive_validation.json。

## 2026-10-10 更新：独立林间祭司与治疗图腾

- Blender MCP制作enemy/forest_shaman.glb：5464tris、22骨、11动作，约宽1.15×深0.45×高2.234m（含鹿角）；木面具、分枝鹿角、叶片肩饰、绿衣、种子法杖，替换祭司对森林法师外观的复用。沿用已验证人形骨架并新增summon双臂祈祷动作；其余idle/walk/backstep/cast/hit/stagger/death/talk/greet/wounded保留，非所有动作都在敌人AI使用。原点底部中心，米制，Godot +Z，无导出碰撞。
- 祭司六张2048² Albedo/Normal/Roughness/Metallic/AO/ORM PNG，GLB内嵌3图；全顶点权重、UV/切线齐全。布料粗糙度0.88、木面具/杖身沿用皮革源材质0.78、骨角0.9、饰边0.67/金属度0.3、晶核0.28/金属度0.1；本体无发光贴图。Blender程序材质烘焙，非逐笔手绘，沿用人形步态无脚底IK或面部口型。
- prop/heal_totem.glb重做888tris、486源顶点，0.642×0.42×1.22m：石脚、木柱、包铁、根枝与生命晶核。七张1024²完整PBR+Emission PNG，GLB内嵌4图；木粗糙度0.82、石0.92、铁0.48/金属度0.85，其余金属度0；绿色符号和晶核发光强度2。静态道具，无骨骼。既有圆柱碰撞维持半径0.22/高1.1m，外伸枝杈不额外阻挡。
- 模型、同名贴图目录、独立art/source/<名称>.blend和art/previews/<enemy或prop>/<名称>.png齐全；祭司额外cast/summon/death参考图，forest_shaman_in_game.png为Compatibility受控游戏内预览而非森林实景。旧图腾与改动前脚本备份art/backups/forest_shaman_before_2026_10_10.zip。
- support.gd改挂独立祭司，血条抬至2.45m；召唤选择summon，普通攻击选择cast，沿用0.6s生效+0.6s收招。skeletal_caster.gd按实际模型文件名前缀识别动作，并提供攻击动作选择钩子，保留冻结停姿势/中断/骨骼死亡。治疗量、6m半径、5s寿命、20生命、任务与掉落均未修改。
- dev/verify_forest_shaman.tscn无头28项、Compatibility/OpenGL预览29项通过：22骨/11动作/PBR尺寸、0.6s单次召唤/收招、冻结中断与停姿势、普通攻击、图腾治疗范围/破坏/到期。原法师与NPC专项91项回归通过。Forward+/D3D12及bloom视觉尚待验收。
- 资产审计缺失GLB引用0、模型50项、未贴图旧模型14项。复现：dev/prepare_shaman_assets.py生成独立构建脚本；Blender MCP运行build_forest_shaman.py/publish_forest_shaman.py与build_heal_totem.py/publish_heal_totem.py，再Godot导入。验证记录dev/art_work/shaman/，图腾归档检查dev/art_work/heal_totem/archive_validation.json。
- 完整开机回归dev/verify_boot.tscn退出码0、VERIFY ALL OK，日志dev/art_work/shaman/boot.log；既有导航/无头截图和退出资源泄漏诊断仍存在，不代表无警告运行。

## 2026-10-10 更新：森林法师与五位 NPC 骨骼角色

- Blender MCP完成六项原创风格化角色：enemy/forest_mage 4096tris，player/npc_elin 4204tris、npc_tom 4068tris、npc_mara 4204tris、npc_glen 4136tris、npc_wounded_ranger 3980tris。法师含兜帽和法杖约2.10m高，人物约1.87m；米制、底部中心原点、Godot +Z，碰撞留在Godot。艾琳绿衣发髻、汤姆赭色短衣腰包、玛拉紫衣、格伦蓝色围裙胡须、巡林者绿衣绷带，以服装和配件区分身份。
- 每项22骨、全顶点权重、独立蒙皮，10个带资产名前缀的动作：idle/walk/backstep/cast/hit/stagger/death/talk/greet/wounded。法杖随右手骨；补齐肘膝关节遮盖并修正死亡姿势。NPC实际播放待机/交谈/受伤，greet等保留供后续调用；没有面部骨骼、口型或逐指独立控制，走路未做脚底IK。
- 每项六张2048² PNG：Albedo/Normal/Roughness/Metallic/AO/ORM，GLB内嵌Albedo/Normal/ORM，UV/切线/骨骼属性齐全。Blender程序材质烘焙，非逐笔手绘；布料粗糙度0.88、皮革0.78、皮肤0.85、头发0.93、铁件0.48/金属度0.8、饰边0.67/金属度0.3、宝石0.28/金属度0.1，无新增自发光。
- 六项均归档至art/models对应分类、art/textures/<名称>/、art/source/<名称>.blend、art/previews对应分类/<名称>.png。独立源含本角色模型/骨架/10动作/摄影机/三灯及源材质。额外法师施法/死亡参考及NPC交谈参考齐全；art/previews/player/npc_lineup.png为Godot受控预览场景合照，并非森林实景。旧法师和相关逻辑备份art/backups/humanoid_cast_before_2026_10_08.zip。
- 新增skeletal_caster.gd统一手动播放：法师0.8s发射一次，0.6s收招；受冻停姿势、受控中断、骨骼死亡，移除整体缩放死亡。8m内优先后退，修正后退时移动朝向和面向玩家相互争抢。祭司复用同一法师外观，治疗图腾接入0.6s施法动作及收招；未制作独立祭司或升级图腾外观。
- npc.gd按既有npc_id挂接五份模型并隐藏旧胶囊，对话期间播放talk、结束恢复idle/巡林者wounded；保留任务、服务、交互标记与碰撞。未新增NPC寻路或日程，未知ID仍保留旧回退模型。
- dev/verify_humanoid_cast.tscn无头91项、Compatibility/OpenGL预览92项通过，覆盖资源/2K贴图/骨骼/动作/发射时点/冻结/死亡/祭司施法/NPC交谈。完整dev/verify_boot.tscn最终VERIFY ALL OK，日志dev/art_work/humanoid_cast/boot_verified.log；五任务独立回归quest_fixed.log通过。修复自检第五任务复用已被前序范围攻击杀死的法师目标，改为生成两只独立任务目标，未修改正式任务目标或奖励。
- Forward+/D3D12视觉尚待验收，既有退出资源泄漏等诊断仍存在，不计作无警告运行。审计缺失GLB引用0、模型总数49、未贴图旧模型15项，当前批次不代表全项目完成。
- 复现：Blender MCP运行dev/build_humanoid_cast.py，检查参考后运行dev/publish_humanoid_cast.py并Godot导入；归档校验dev/art_work/humanoid_cast/archive_validation.json。

## 2026-10-08 更新：回响碑本体与冰蓝共鸣纹路

- Blender MCP重做`scenery/echo_stone.glb`：1180tris、648源顶点，宽0.96×深0.82×高1.80m，底部中心原点、Godot +Z；带切角碑冠、石基、双面分枝纹路和菱形霜灯符号，保持原碰撞/交互尺寸及观测台0.5m台座位置。静态资产，无骨骼或导出碰撞。
- 完整1K PBR与独立Emission图，七张PNG：Albedo/Normal/Roughness/Metallic/AO/ORM/Emission；GLB内嵌四张Albedo/Normal/ORM/Emission，UV与切线完整。Blender程序材质烘焙，石材粗糙度0.92，纹路0.5，饰框0.48/金属度0.85，其余金属度0。只有符号和纹路进入冰蓝发光遮罩；Blender参考发光强度3，Godot播放未收集0.6/已共鸣4.0两种状态，不制作新视觉材质。
- 归档：`art/models/scenery/echo_stone.glb`、`art/textures/echo_stone/`、独立`art/source/echo_stone.blend`、`art/previews/scenery/echo_stone.png`，森林两态实景`echo_stone_idle_in_forest.png`和`echo_stone_lit_in_forest.png`。替换前已有模型/源/参考/逻辑备份到`art/backups/echo_stone_before_2026_10_08.zip`。
- 修复`echo_stone.gd`：只操作实际GLB发光材质，避免优先匹配隐藏的RuneRing；每实例复制材质，避免共鸣污染其他碑和缓存；每0.5s从玩家回响收藏同步外观，支持玩家晚于场景加载及读档恢复；记忆播放期间防重复交互。既有回响ID、5秒记忆、收藏与自动存档调用保留，无新增奖励。
- `dev/verify_echo_stone.tscn`无头18项/Compatibility实景21项通过：六类1K贴图、几何/UV/高度、占位隐藏、真实模型亮起、独立材质/缓存隔离、收藏恢复与清除、森林截图。收藏恢复检查直接设置测试玩家内存数据，不写存档。Forward+/D3D12及bloom视觉仍待验收；当前截图使用Compatibility/OpenGL。
- 审计已更新：缺失GLB引用仍为0，未贴图旧模型从17降至16项。复现：准备脚本`dev/prepare_echo_stone.py`；Blender MCP执行`dev/build_echo_stone.py`→参考检查→`dev/publish_echo_stone.py`→Godot导入。
- 完整开机回归重跑通过：`dev/verify_boot.tscn`退出码0、`VERIFY ALL OK`，最终日志`dev/art_work/echo_stone/boot_final.log`。此前boot.log中断未计作通过；既有导航精度、无头截图及退出资源泄漏诊断仍存在。

## 2026-10-08 更新：旧观测台石柱与遗迹环境

- Blender MCP制作五项原创风格化静态资产：完整柱`stone_pillar`476tris/272源顶点、1.28×1.28×3.60m；断柱`observatory_pillar_broken`116tris、1.22×1.22×1.277m；倒柱`observatory_pillar_fallen`176tris、3.197×0.932×0.932m（长轴X）；残墙`observatory_wall`792tris、3.625×0.55×1.313m；台座`observatory_altar`216tris、直径3m/高0.5m。底部中心原点、米制、Godot +Z，均无骨骼/动画/导出碰撞。
- 视觉：八角底座、分段柱身、厚柱头、苔绿罗盘形饰纹、裂石与苔藓接缝；独立断裂柱面与横放倒柱，错层残墙和双层圆形台座。贴图为Blender程序材质烘焙，石材粗糙度0.88、苔藓0.95，金属度0，无发光。各项UV/切线及六张1024² Albedo/Normal/Roughness/Metallic/AO/ORM齐全，GLB内嵌Albedo/Normal/ORM。
- 归档：五项`art/models/scenery/<名称>.glb`、`art/textures/<名称>/`、`art/source/<名称>.blend`、`art/previews/scenery/<名称>.png`；每份源文件含独立模型、源材质、摄影机与三盏灯。实景`art/previews/scenery/observatory_in_forest.png`。原脚本备份`art/backups/observatory_before_2026_10_08.zip`。
- `poi_observatory.gd`只挂接模型与物理，保留六柱半径6.5m及原断柱/倒柱/三堵矮墙的位置和随机种子。完整柱按既有2.8–3.5m高度缩放并对齐碰撞；倒柱长轴与碰撞同向；台座新增对应两层圆柱碰撞，顶面0.5m正好承接现有回响碑。移除旧(0,1,-2.5)无可见物体对应的2m方形障碍。
- 回响碑及其frost_lamp_scholar逻辑、探索区域old_observatory、宝箱chest_observatory均保留；本项未升级回响碑和宝箱本体。`dev/verify_observatory.tscn`无头56项、Compatibility/OpenGL实景57项通过，包含五项PBR/UV/面数、六柱碰撞高度、倒柱朝向、任务ID、台座顶面射线、1.8m胶囊从南侧走入柱环及台座外选中回响碑交互区域。导航6111多边形。
- Forward+/D3D12视觉尚待验收；既有导航精度和退出资源泄漏诊断保留。审计更新：当前场景引用缺失GLB为0，但仍有17项旧模型没有贴图，不代表全项目美术完成。
- 复现：`dev/prepare_observatory_assets.py`准备五份独立构建脚本；Blender MCP执行`dev/build_observatory_assets.py`，参考检查后执行`dev/publish_observatory_assets.py`，再Godot导入。后续重建直接执行build/publish即可。
- 开机回归：`dev/verify_boot.tscn`退出码0，输出`VERIFY ALL OK`；日志`dev/art_work/stone_pillar/boot.log`，现有自检备份并还原玩家存档。

## 2026-10-08 更新：猎人小屋、断栅栏与残墙

- Blender MCP制作三项原创风格化环境资产：`hunter_cabin`3158tris/1934源顶点，宽5.378×深4.330×高4.235m（含屋檐）；`hunter_fence`440tris，约4.627×0.290×1.165m；`hunter_broken_wall`440tris，约2.945×0.539×1.293m。独立底部中心原点、米制、正面Godot +Z，静态无骨骼或导出碰撞。
- 小屋采用木板围护、加粗木梁、斜撑、封窗、带铁箍木门、石基台阶、苔绿叠瓦和后侧柴垛；保持封闭外观，无室内和开门功能。断栅栏与高低断板残墙替换原兴趣点占位，并保留原布置方向。
- 贴图均为Blender程序材质烘焙，非逐笔手绘；每项包含1024² Albedo/Normal/Roughness/Metallic/AO/ORM六PNG，UV和切线完整，GLB内嵌Albedo/Normal/ORM。木材粗糙度0.78–0.82，石基0.92，木瓦0.90，苔藓0.95；仅铁件金属度0.85，其余0，无自发光。
- 归档：`art/models/scenery/<名称>.glb`、`art/textures/<名称>/`、`art/source/<名称>.blend`、`art/previews/scenery/<名称>.png`。每份源文件为独立模型、源材质、摄影机和三盏灯。森林实景`art/previews/scenery/hunter_cabin_in_forest.png`；旧兴趣点脚本备份`art/backups/hunter_cabin_before_2026_10_08.zip`。
- Godot只挂接模型及物理：`poi_hunter_cabin.gd`保留建筑和残墙世界碰撞/nav_source，新增两段栅栏碰撞，屋前右侧保持通路。原HunterDiary、ChestCabin和QuestAreaHunterCabin实例、坐标、物品/宝箱/探索ID均不改。日记本体及宝箱仍是既有资源，本项未升级这些独立道具。
- 验证：`dev/verify_hunter_cabin.tscn`无头33项、Compatibility/OpenGL实景34项通过，覆盖三项GLB/PBR/预算/UV、建筑碰撞、任务ID保留、1.8m角色胶囊检查日记与宝箱正面接近路线。森林导航6108多边形。Forward+/D3D12视觉尚未验收；既有导航精度和退出资源泄漏诊断保留。资产审计更新：缺失引用GLB仅余观测台stone_pillar，仍有17项旧模型未贴图，并非全项目美术完成。
- 复现：Blender MCP执行`dev/build_hunter_assets.py`（调用三个独立build脚本），参考检查后执行`dev/publish_hunter_assets.py`（校正底部原点并归档），再Godot导入。`dev/prepare_hunter_cabin.py`记录生成管线来源，正常重建无需再执行准备脚本。
- 开机回归：`dev/verify_boot.tscn`输出`VERIFY ALL OK`，退出码0；日志`dev/art_work/hunter_cabin/boot.log`，现有自检备份并还原玩家存档。

## 2026-10-08 更新：瀑布岩壁、水幕与浅潭

- Blender MCP制作三项原创风格化资产：`waterfall_cliff`为1422tris、727源顶点，宽13.595×深3.935×高6.186m，灰蓝层岩与顶部苔藓；`waterfall_curtain`为1152tris、宽4.4×高6.4m的起伏水幕；`waterfall_pond`为96tris、直径11.6m的软边浅潭。原点为底部中心，米制、Godot +Z，静态资产无骨骼或导出碰撞。
- 材质为Blender程序材质烘焙，岩石粗糙度0.88、苔藓0.95、水0.24，金属度0；各自完整UV/切线和1K Albedo/Normal/Roughness/Metallic/AO/ORM六张PNG，GLB内嵌Albedo/Normal/ORM。水幕Alpha最高0.86、潭水0.78，BLEND双面软边。Godot只播放水幕UV（0.35循环/秒）；潭水纹样静态，无流体模拟、折射或新增水雾。
- 归档：`art/models/scenery/<名称>.glb`、`art/textures/<名称>/`、`art/source/<名称>.blend`、`art/previews/scenery/<名称>.png`；每份源文件独立包含模型、材质、三盏灯与摄影机。实景为`art/previews/scenery/waterfall_in_forest.png`。原场景/地形备份`art/backups/waterfall_before_2026_10_08.zip`。
- `poi_waterfall.gd`替换全部瀑布兴趣点占位视觉；岩壁挂在局部z=-7，水幕z=-5.1，潭心z=0.4。拆除原挡住秘境入口的整块岩壁碰撞，改两侧岩体和上方横梁，中间4m宽通道；保留独立秘境石门及q_frost_trial门槛和原目的地。TerrainBuilder在潭心7m范围平滑下切浅盆地，中心深0.65m，水位与溪流同源，后方洞口台地保留。
- 潮湿区贴合水位（水下0.85m至水上0.05m、半径5.6m），沿用进入wet 6s/强度1、停留每2s刷新、离开停止刷新的行为。没有水面行走碰撞。
- 验证：`dev/verify_waterfall.tscn`无头38项、Compatibility/OpenGL实景39项通过；覆盖三资产PBR/UV/预算、透明、流动、水位与潭深、1.8m角色胶囊沿真实入口路线的世界碰撞检测、入口门槛/目的地、实际Area进入/刷新/离开。`dev/verify_creek.tscn`33项回归通过，导航6097多边形。未完成Forward+/D3D12视觉验收；既有导航精度与退出资源泄漏诊断仍存在。
- 复现：`dev/build_waterfall_cliff.py`→参考检查→`dev/publish_waterfall_cliff.py`，随后`dev/build_waterfall_water.py`→`dev/publish_waterfall_water.py`，均通过Blender MCP执行，再Godot导入。准备脚本`dev/prepare_waterfall_build.py`保留管线来源。猎人小屋与观测台石柱仍待后续制作。
- 开机回归：`dev/verify_boot.tscn`退出码0、输出`VERIFY ALL OK`；真实存档由现有自检备份/恢复。日志`dev/art_work/waterfall_cliff/boot.log`。资源审计已更新，缺失引用GLB从3项减为2项（hunter_cabin、stone_pillar）。

## 2026-10-07 更新：溪流、湿土河岸与河床碎石

- Blender MCP产出三项原创风格化资产，程序材质烘焙首版：浅青波纹水面`creek_water`、湿土渐变边缘`creek_bank`、四颗低矮河卵石组合`river_pebbles`。水面/河岸是4×4m、2tris/4顶点的材质样片，Godot只取材质贴合已有河道；碎石320tris/168源顶点，宽0.746×深0.444×高0.171m。全部底部中心原点、Godot +Z方向，静态网格，无导出碰撞或骨骼。
- 模型均在`art/models/scenery/<名称>.glb`；每项`art/textures/<名称>/`均含六张1024² PNG（Albedo/Normal/Roughness/Metallic/AO/ORM），完整UV与切线，GLB内嵌Albedo/Normal/ORM。水粗糙度0.24、湿土0.72、碎石0.67，金属度均0；水Albedo最高Alpha约0.72，水/河岸两侧透明渐变，glTF BLEND。波纹和法线在Blender制作，Godot沿河滚动UV（0.025循环/秒）播放，不是流体模拟，没有折射或水动力。
- 归档：三项独立`art/source/<名称>.blend`（模型/源材质/摄影灯光）和`art/previews/scenery/<名称>.png`；实景`art/previews/scenery/creek_in_forest.png`。替换前terrain_builder/water_zone备份`art/backups/creek_before_assets_2026_10_07.zip`。
- 河道接入：TerrainBuilder以0.25m采样、共享截面构建水面，修正原水面法线向下；湿土层横向24格、按实际地形三角插值贴合，并关闭贴层阴影。水面单独材质实例并设render_priority=1，避免透明河岸后绘制覆盖水面。碎石用独立随机源MultiMesh，沿两岸/河床摆放，无额外行走障碍。
- 高度修复：原兴趣点台地在河床下切之后执行，导致上游河床被抬平、水面埋地；调整为台地后执行已有溪流下切，只影响溪流范围。水面沿既有base_height水位，中心采样最浅约0.5m；河岸三角中心最小间隙约0.025m。导航重新烘焙6073多边形。
- 潮湿修复：原触发区再次从已经下切的height_at扣除河深；改为与可见水面同源的水位，触发盒覆盖水面下0.85m到水面上0.05m，宽4.4m。water_zone.gd行为不改：玩家进入施加wet 6s/强度1，停留每2s刷新，离开停止刷新。
- 验证：`dev/verify_creek.tscn -- --preview-creek`最终34项通过：三项五类1K贴图、法线/UV/透明、波纹滚动与渲染顺序、上游至下游水面高度、河岸贴地、碎石预算、实际物理Area进入/刷新/离开回调、森林导航与截图。日志`dev/art_work/creek_assets/`。实景为Compatibility/OpenGL，未完成Forward+/D3D12验收；既有导航精度/运行时网格解析及退出资源泄漏诊断仍保留。
- 复现：MCP运行`dev/build_creek_assets.py`→参考检查→`dev/publish_creek_assets.py`→Godot导入；挂接/验证入口见上。瀑布岩壁、水幕和潭水仍为旧资产，留到下一项，未将溪流交付描述为瀑布完成。
- 全项目开机自检输出VERIFY ALL OK、退出码0（`dev/art_work/creek_assets/boot.log`）；之后透明绘制优先级调整通过最终34项专项复验。开机日志包含既有headless截图、故意损坏存档与退出泄漏诊断，不代表无警告运行。资源审计已刷新。

## 2026-10-07 更新：森林苔藓岩石

- Blender MCP重做原rock.glb：四块大小错落的断石，四边面环状轮廓、风化倒角、灰蓝岩层、细裂纹和顶部苔藓。程序源材质烘焙的手绘感PBR，非逐笔手绘；首版高对比条纹/裂纹已降低对比并收细。
- 模型：`art/models/scenery/rock.glb`，806 tris、411源顶点、单网格/单材质；约宽1.800m×深1.280m×高1.192m，底部中心原点、Godot +Z朝前，静态不需要骨骼，不导出碰撞。
- 材质/UV：完整UV图集与切线；`art/textures/rock/rock_{albedo,normal,roughness,metallic,ao,orm}.png`六张1024²，GLB内嵌Albedo/Normal/ORM。石粗糙度0.88、苔藓0.95、金属度均0；ORM=AO/Roughness/Metallic。
- 归档：独立源`art/source/rock.blend`（模型、源程序材质、摄影灯光）、参考`art/previews/scenery/rock.png`、实景`art/previews/scenery/rock_in_forest.png`。替换前GLB/源/参考/terrain_builder备份`art/backups/camp_before_rock_2026_10_07.zip`。
- Godot沿用TerrainBuilder原RockMesh MultiMesh装载与随机散布，不改地形高度、道路、树木、怪物或碰撞规则。原有scale>1.15的大石球形障碍保留，小石仍是装饰；未增加逐石精确网格碰撞。
- 复现：MCP运行`dev/build_forest_rock.py`→参考检查→`dev/publish_forest_rock.py`→Godot导入。验证入口`dev/verify_forest_rock.tscn`，加`-- --preview-rock`加载真实森林并截图。溪流/河岸/瀑布不在本项内，后续继续。
- 验证：17项专项通过，93个真实森林MultiMesh实例、45个原规则大石障碍，导航仍为6047多边形；已核验Blender参考与Compatibility/OpenGL实景。报告`dev/art_work/rock/godot_validation.json`。本轮只替换美术资产，未重跑全项目自检，未完成Forward+/D3D12验收；既有导航精度/运行时网格解析/退出资源泄漏警告保留。审计更新后无图片贴图的GLB从18项降至17项。

## 2026-10-07 更新：森林树木与地面（用户调整优先级，告示板暂缓）

- Blender MCP制作两种树、草地/泥土材质样片及草簇，延续原创风格化中世纪奇幻方向；程序源材质烘焙的手绘感首版，不是逐笔手绘。没有风摆动画、季节切换或实时植被交互。
- 模型清单（全部`art/models/scenery/`，单位米、底部中心原点、Godot +Z朝前，无导出碰撞/骨骼）：

  | 名称 | 三角面/源顶点 | 尺寸（宽×深×高） | 内容 |
  |---|---:|---|---|
  | tree_a | 1652 / 896 | 4.15×4.23×8.32 | 针叶树，七层不规则树冠、枝干、根部 |
  | tree_b | 1924 / 1008 | 5.81×5.65×8.28 | 阔叶树，分叉树干、九簇树冠、根部 |
  | forest_grass | 2 / 4 | 4×4×0 | 周期性草地PBR材质样片，运行时只取材质 |
  | forest_dirt | 2 / 4 | 4×4×0 | 周期性泥土道路材质样片，横向透明软边 |
  | grass_tuft | 144 / 162 | 0.523×0.509×0.530 | 18片折面弯曲草叶，复用草地烘焙材质 |

- 贴图/材质：每项均有独立`art/textures/<名称>/`下六张1024² PNG（Albedo/Normal/Roughness/Metallic/AO/ORM），完整UV/切线；GLB内嵌Albedo/Normal/ORM。树皮粗糙度0.91、叶0.94、地面/草簇0.96，金属度全0。地面材质以四维周期噪声制作，相对边Albedo RGB平均差<1/255；泥土Albedo另含0–255透明渐变，GLB为BLEND，Godot导入为Alpha Depth Pre-Pass。
- 归档：每项独立`art/source/<名称>.blend`与`art/previews/scenery/<名称>.png`，源含模型/源材质或复用的烘焙材质/摄影灯光。实景`art/previews/scenery/forest_path.png`、`forest_overview.png`。原树模型/源/参考与terrain_builder备份`art/backups/forest_before_surface_2026_10_06.zip`；昼夜脚本备份`forest_lighting_before_fix_2026_10_06.zip`。
- Godot挂接：树继续使用原MultiMesh、位置、缩放随机源和逐树障碍。TerrainMesh只换Blender样片材质、添加4米世界UV，高度/拓扑/高图碰撞/nav_source保持；新增独立随机源草簇MultiMesh（上限2200，不投影、无碰撞），避开道路/营地/兴趣点/溪流。草簇暂无分块LOD或逐实例远裁剪。
- 道路修复：旧道路法线向下且大块条带与实际三角地面相交。改为朝上、沿路0.4m采样/横向12格、共享相邻截面、按TerrainMesh相同三角高度插值贴地，保留沿路连续UV和Blender软边；装饰贴层不投影、不参与导航。全路三角中心最小地面间隙约0.0276m。
- 日照修复：旧太阳白天X旋转为正，照射方向指向天空，造成树底亮/地面暗。day_night_cycle按6点日出/18点日落的正弦高度计算负X旋转，保持原40分钟周期、时刻存档、色温/能量/夜间营火逻辑；8/12/17点向下、午夜向上的方向断言通过。
- 验证：`dev/verify_forest_surface.tscn -- --preview-forest`最终62项通过，包括五类1K纹理、原点、地形UV/碰撞、道路贴地与法线、日照方向、草簇避路/预算、真实森林导航及截图。导航6047多边形与本批前一致。`dev/verify_wolf_aggro.tscn`野狼10m索敌→接近→攻击通过；全项目`dev/verify_boot.tscn`输出VERIFY ALL OK（随后道路贴地细分以专项复验）。GPU实景为Compatibility/OpenGL，未声称完成Forward+/D3D12最终验收。既有导航精度/运行时网格解析、headless截图、故意损坏存档与退出资源泄漏诊断仍保留，日志在`dev/art_work/forest_surface/`。
- 复现：MCP执行`dev/build_forest_surface.py`→检查四张参考→`dev/publish_forest_surface.py`（树根归零并归档）→`dev/build_grass_tuft.py`→Godot导入。实时资源审计已刷新；岩石、水面、其他环境旧资源尚未在本批升级。

## 2026-10-06 更新：营地锻造台（环境资源第三项）

- Blender MCP产出风格化中世纪锻造组合：木墩铁砧（锥形砧角/砧腰/砧跟）、石砌炉台、排烟罩/烟囱、炭床、铁栅、锤钳与工具架。原创建模、程序材质烘焙的手绘感PBR，延续营地暖木/灰石/深铁配色。
- 模型：`art/models/prop/camp_forge.glb`，2586 tris、1416源顶点，单静态网格/单材质；约宽3.205m×深1.25m×高2.687m，原点贴地组合中心、Godot +Z朝前。无骨骼，无锻打或开炉动画，碰撞不导出。
- UV/贴图：`art/textures/camp_forge/`，七张1024² PNG：Albedo/Normal/Roughness/Metallic/AO/ORM/Emission；GLB内嵌四图Albedo/Normal/ORM/Emission，包含UV与切线。木材粗糙度0.78–0.82，石0.92，铁0.48/金属度0.85，其余金属度0；炭火橙色发光强度3在Blender设置并导出。
- 归档：独立源`art/source/camp_forge.blend`包含源材质与摄影灯光；Blender参考`art/previews/prop/camp_forge.png`；营地截图`art/previews/prop/camp_forge_in_camp.png`。旧营地脚本`art/backups/camp_before_camp_forge_2026_10_06.zip`。
- Godot接入：camp.gd新增forge_model_path，GLB替换几何体占位。旧炉体与小屋石基交叠，锻造台根从CAMP+(7,0,-9)移到+(6,0,-10)，模型局部X偏移0.8保持铁砧操作点；炉体和铁砧分别增加世界碰撞/nav_source。保持原ForgeGlow昼夜注册与强化交互信号；E提示按Tab在背包强化，未改动强化规则。
- 复现：MCP执行`dev/build_camp_forge.py`→参考检查→`dev/publish_camp_forge.py`→Godot导入。专项`dev/verify_camp_forge.tscn`（`-- --preview-forge`加载真实森林并截图）。
- 验证：18项专项通过，实际森林导航烘焙6047多边形；核验五类PBR、炭火Emission、比例、铁砧/炉体碰撞、与小屋无交叠、NPC可接近、原交互信号及触发射线。GPU使用Compatibility/OpenGL；未做Forward+/D3D12验收，本轮未重跑全项目自检。既有导航精度/运行时网格解析和退出资源泄漏诊断仍保留。最新审计见asset_inventory.md。

## 2026-10-06 更新：营地仓储木箱（环境资源第二项）

- Blender MCP建模/UV/材质烘焙/灯光/渲染/导出；延续小屋的暖木与深灰铁件，独立拼板、斜撑、包铁铆钉、双侧提环、箱盖与底部垫木。程序材质烘焙出手绘感，不是逐笔手绘。
- 模型：`art/models/prop/storage_crate.glb`，3712 tris、2008源顶点，单静态网格/单图集材质；含提环与斜撑约宽1.124m×深1.061m×高0.941m，底部中心原点、Godot +Z朝前；不导出碰撞，无骨骼和动画。
- 贴图：`art/textures/storage_crate/storage_crate_{albedo,normal,roughness,metallic,ao,orm}.png`，六张1024²；GLB内嵌Albedo/Normal/ORM、完整UV与切线。木材粗糙度0.78–0.82/金属度0，铁件粗糙度0.48/金属度0.85，ORM=AO/Roughness/Metallic。
- 归档：`art/source/storage_crate.blend`独立源含源材质与摄影灯光；Blender参考`art/previews/prop/storage_crate.png`，营地运行截图`art/previews/prop/storage_crate_in_camp.png`。接入前备份`art/backups/camp_before_storage_crate_2026_10_06.zip`。
- 接入：沿用camp.gd的crate_model_path和Storage位置，以GLB替换占位，释放不用的回退节点；新增1.08×0.94×1.0m世界碰撞及nav_source分组。保留“打开仓库”交互信号；现有功能仍是MVP提示，不包含物品存取或开盖动画。
- 复现：MCP执行`dev/build_storage_crate.py`→查看参考→`dev/publish_storage_crate.py`→Godot导入；首次灯光节点名称问题已修正到构建脚本。专项入口`dev/verify_storage_crate.tscn`，可加`-- --preview-crate`检查实际森林并截图。
- 验证：14项专项全部通过（`dev/art_work/storage_crate/godot_validation.json`），包括实体阻挡和交互射线先命中触发区；真实森林导航烘焙6045多边形。已查看Blender参考与Compatibility/OpenGL营地截图；未验证Forward+/D3D12。本轮未重跑全项目开机自检；日志仍有既有导航精度/运行时网格解析及退出资源泄漏诊断。审计已刷新，缺失模型路径降至3项。

## 2026-10-06 更新：营地木构小屋（环境资源第一项）

- 当前优先级：用户改为先做环境资源；森林法师/祭司与已确认的大型多招式BOSS暂后排，小屋完成后继续营地环境。
- Blender MCP制作原创风格化中世纪木构小屋：暖灰墙面、深色木梁、蓝色叠瓦、石基、烟囱、木门铁件与窗框。程序材质烘焙出手绘感，不是逐笔手绘。
- 模型：`art/models/scenery/hut.glb`，4832 tris、2820源顶点、单网格/单图集材质；含屋檐约宽5.60m×深4.28m×高4.95m，墙体4.22×3.22m，底部中心原点，Godot +Z朝前。静态封闭外观，无室内/开门交互，不需要骨骼。
- UV/贴图：完整展开，六张1024² PNG位于`art/textures/hut/`，Albedo、Normal、Roughness、Metallic、AO与ORM；GLB内嵌Albedo/Normal/ORM，ORM通道R=AO/G=粗糙度/B=金属度。木材粗糙度0.78–0.82、墙0.9、石0.92、瓦0.78–0.8、铁件0.48/金属度0.85，其余金属度0。
- 归档：独立源`art/source/hut.blend`（模型、源程序材质、摄影灯光）；Blender参考`art/previews/scenery/hut.png`；真实森林营地截图`art/previews/scenery/hut_in_camp.png`。旧营地脚本备份`art/backups/camp_before_hut_2026_10_06.zip`。
- 接入：`camp.gd`新增可导出的hut_model_path，GLB替换原占位并释放未使用回退节点；保留4.6×2.8×3.6m建筑碰撞与nav_source。铁匠原来落在房屋碰撞内，已移至锻造区外侧，保持NPC和任务ID。
- 验证入口：`dev/verify_camp_hut.tscn`检查实际GLB、五类1K贴图、尺寸、建筑碰撞、门面阻挡、铁匠可接近性；加`-- --preview-hut`加载真实森林并截图。GPU截图使用Compatibility/OpenGL，未完成Forward+/D3D12实玩验收；既有营地退出资源泄漏另行处理。
- 验证结果：14项专项全部通过（`dev/art_work/hut/godot_validation.json`）；完整开机自检输出VERIFY ALL OK、退出码0（`dev/art_work/hut/boot.log`）。日志保留既有导航精度、headless截图、故意损坏存档及退出资源泄漏诊断，不代表无警告运行。资源审计已刷新，模型引用缺失由5项降至4项。
- 复现：`dev/build_camp_hut.py`首次制作，`dev/rebuild_camp_hut.py`清理专属暂存场景后重做，`dev/publish_camp_hut.py`检查预算/UV/内嵌贴图并归档；均由Blender MCP执行，不重置工厂设置。

## 2026-10-06 更新：苔牙野猪贴图、四足骨骼与攻击动作

- 风格/造型：原创风格化中世纪奇幻野猪，粗壮躯干、厚颈、分趾蹄、弯曲獠牙、短耳、卷尾与苔藓背鬃。普通与精英共享资产；源共享enemies_pack.blend未修改。Blender MCP完成建模/UV/材质烘焙/骨架/动画/灯光/渲染/导出。
- 模型：`art/models/enemy/moss_boar.glb`，3794 tris、2024顶点、1548源四边面，单蒙皮网格/单材质；约宽0.83m×长2.11m×高1.12m，脚底约0.005m、原点脚下中心，Blender -Y/Godot +Z朝前。运行Visual绕Y转PI适配AI -Z，不改变世界朝向和任务ID。
- 贴图：`art/textures/moss_boar/moss_boar_{albedo,normal,roughness,metallic,ao,orm}.png`，全部2048²；统一UV、切线，GLB内嵌Albedo/Normal/ORM（R=AO/G=Roughness/B=Metallic）。皮革粗糙度0.88、苔藓0.97、鼻0.6、牙0.56、眼0.33，金属度全0；程序源材质保留，非人工逐笔手绘。
- 绑定：24骨（根、胯、脊柱、胸、颈、头、颌、双耳、3尾骨、四肢各3骨），最多2骨影响/顶点且归一化。四足IK结果已逐帧烘焙；动作线性插值、四元数符号连续。Blender检查全部采样帧无非有限坐标/地面穿透。
- 动画10段：Boar_idle 2s、walk 1.2s、run 0.6s、heavy 1s、charge_windup 1s、charge 0.4s循环、recover 0.4s、hit 0.4s、stagger 1s、death 1.2s。普通走跑使用匀速支撑相并标定步频；冲锋是低头短促奔袭循环。独立NLA轨导出，排除了Blender同会话中手臂的FP动作。
- 接入：`charger.gd`手动推进动画；重击0.6s单次18伤（普通）、1s收招结束；冲锋1s预警、12m/s、10m上限，普通命中22.5伤，0.4s停止收势；撞柱自晕3s使用原判定。无整体scale压扁/死亡旋转Tween。冻结保持当前姿势并中止旧攻击，眩晕/受击/死亡独立动作。普通80血/15攻、精英250血/18攻保留；巡逻1.2m/s，追击2.8m/s。
- 归档：`art/source/moss_boar.blend`；Blender参考`art/previews/enemy/moss_boar.png`；Godot截图`art/previews/enemy/moss_boar_godot.png`。修前备份`art/backups/moss_boar_before_rig_2026_10_06.zip`，含旧GLB、共享源和charger脚本。
- 验证：`dev/verify_moss_boar.tscn`37项通过（五类2K纹理/24骨/10动作/走跑连续循环/精英属性/命中时刻与单次伤害/收势/冻结/眩晕/受击/死亡释放）。`dev/verify_boot.tscn`输出VERIFY ALL OK，含实际冲锋撞柱自眩晕；日志`dev/art_work/moss_boar/boot.log`保留既有headless截图/损坏存档/退出资源泄漏诊断，非无警告运行。GPU Compatibility/OpenGL检查待机、走跑、重击、蓄力、冲锋、眩晕、死亡截图；未宣称完成森林Forward+/D3D12最终实玩验收。
- 复现：MCP执行`dev/build_moss_boar.py`→检查参考→`dev/publish_moss_boar.py`→Godot导入；专项可加`-- --preview-boar`生成8张运行截图。首次构建脚本在专属新场景生产；重复构建前应清理同名暂存场景/动作，勿工厂重置MCP会话。
- 遗留：首版毛皮/苔藓仍可精修；没有坡面实时脚掌IK。12m/s冲锋使用夸张奔袭表现，并未做高速逐蹄接地约束。后续森林法师/祭司完成后制作巨兽；已确认大体型、多招式要求写入`art/audit/boss_upgrade_plan_2026_10_06.md`，本次尚未修改BOSS。

## 2026-10-06 更新：第一人称战士双臂、手指与技能骨骼动作（近景批第一项）

- 风格：原创风格化中世纪奇幻护手，棕色皮革手套、蓝灰钢护腕、黄铜包边和布袖；延续铁剑的大色块/PBR方案。通过本机 Blender MCP 建模、UV、材质烘焙、骨骼、动画、参考灯光和导出。Godot 仅接线。
- 模型：`art/models/player/warrior_arms.glb`，1蒙皮网格/1图集材质，2712 tris、1420源顶点、四边面环状关节为主；角色预算20k以内。单位米，肩至腕约0.9m（含上臂）；仅用于第一人称视角，不是完整主角全身模型。
- 原点例外：第一人称相机原点，朝Godot -Z视线，双腕约(±0.29,-0.34,-0.69)m；不同于世界角色脚底原点。武器插槽位于右手握柄底部，约(0.235,-0.401,-0.832)m；剑尖略朝前，适配已有铁剑与霜痕之刃的柄底原点。
- 骨架：38骨（Root、双侧上臂/前臂/手掌、10指×3节、Weapon.R插槽）。权重每顶点归一化，最多2有效影响；独立手指可动。约束解算已烘焙，GLB包含skin、JOINTS_0、WEIGHTS_0、切线。
- 动作：13段，导出名带`FP_`前缀；idle 2s、attack_1/2各0.5s、attack_3 0.6s、block 1s循环、hit 0.3s、charge 0.6s、sweep 0.7s、roar 0.8s、frost_ring约0.667s、frost_crystal_bolt 0.5s、fireball 0.6s、ember_burst 0.7s。30fps逐帧烘焙、线性关键帧、四元数符号连续；普攻/冲锋0.1s与横扫0.3s对齐现有判定，回响瞬发技能保留原逻辑时序，手部动作是释放后的表现。
- 贴图：`art/textures/warrior_arms/warrior_arms_{albedo,normal,roughness,metallic,ao,orm}.png`，全套2048²；统一UV图集，GLB内嵌Albedo/Normal/ORM，ORM=AO/Roughness/Metallic，无外部图像依赖。皮革粗糙度0.80、布0.92、钢0.43/金属度0.85、黄铜0.48/0.8，其他金属度0；程序材质烘焙的手绘感首版。
- 归档：独立源`art/source/warrior_arms.blend`含模型、骨架、13 Actions、源程序材质和摄影灯光；Blender参考`art/previews/player/warrior_arms.png`。替换前脚本/场景备份`art/backups/fp_arms_before_skeleton_2026_10_06.zip`。
- 接线：`fp_arms.tscn`替换胶囊为GLB；`fp_arms.gd`播放骨骼动画，WeaponMount运行时重挂到Weapon.R的BoneAttachment3D下（外部通过`fp_arms.weapon_mount`访问），不再Tween整个手臂节点。保留全部换装、手套染色、回响发光和技能调用接口；材质按实例复制，染色排除剑。攻击不被普通受击动作覆盖，格挡受击结束恢复格挡，释放格挡不取消正在播放的攻击。
- 验证：Blender检查全部动画采样帧，无非有限顶点、异常范围和权重错误；Godot `dev/verify_warrior_arms.tscn`专项66项通过，包括13动作全程武器跟手（误差<1mm）、十指骨骼、2K贴图、技能映射、收招、受击/格挡、暂停；`dev/verify_actor_regressions.tscn`15项通过，出生、换装、旧存档补发和主动空手均保持。
- 完整自检输出`VERIFY ALL OK`、退出码0（`dev/art_work/warrior_arms/boot.log`）；既有headless截图/故意损坏存档/退出RID泄漏诊断仍存在。Compatibility/OpenGL专项含14次截图共80项通过，持剑运行预览`art/previews/player/warrior_arms_godot.png`；未宣称完成森林Forward+/D3D12人工游玩验收。独立blend归档核对确认仅含手臂场景、13动作、6张贴图，没有混入狼或剑网格。
- 复现：MCP执行`dev/rebuild_warrior_arms.py`（只重建此资产）→检查Blender参考→`dev/publish_warrior_arms.py`→Godot导入与专项。GPU检查入口同专项，加`-- --preview-arms`，关键帧输出`dev/art_work/warrior_arms/godot_*.png`。
- 遗留：本项为完整近景骨骼首版，尚无独立盾牌模型、全身主角或装备形状变体；回响沿用手套发光反馈而非新增符文/粒子美术。动画极端快速取消和不同FOV可继续根据实玩调整；后续顺序为苔牙野猪、森林法师/祭司、巨兽、嫩芽。

## 2026-10-03 修复：野狼触地脚打滑（步态支撑相）

- 原因：walk/run/backstep 的脚掌目标轨迹是纯余弦 `y=-A·cos(2πq)`，触地半周期内脚相对身体的速度按正弦变化，只有平均值等于移动速度。Godot 实测触地脚对地速度在 -1.2~+0.9 m/s（走，巡逻 1.6m/s、walk 播放 2.18×）和 -4.6~+2.0 m/s（跑，追击 3.5m/s、run 播放 2.02×）之间滑动，观感为脚掌"溜冰"；idle 触地正常。
- 修复：Blender MCP 重做三段步态的支撑相为匀速后扫（触地脚对地静止），摆动相改为 cos 平滑前摆 + sin 抬脚；步幅(0.22/0.26)、周期(1.2/0.6s)、重心起伏与脊柱/尾巴微动不变，`melee_chaser.gd` 的步频标定（0.88/1.2、1.04/0.6）继续成立，无需改代码。
- 量化（`dev/capture_wolf_motion.tscn`：固定侧视 + 棋盘地面 + 真实位移）：触地均值 -0.41~-0.62 → -0.14~-0.16 m/s（走）、-0.98 → -0.03~-0.06 m/s（跑）；支撑相对地速度最小 0.00 m/s（原 0.01~0.12 / 0.51~0.52）。条带图与指标输出 `dev/art_work/wolf_motion/`。
- 复现：MCP 执行 `dev/repair_wolf_stance.py`（walk/run/backstep action revision 3）→ `dev/review_timber_wolf.py` → `dev/publish_timber_wolf.py`；Godot 执行 `--import` 后 `dev/verify_timber_wolf.tscn` 全通过。修复前备份 `art/backups/timber_wolf_before_stance_fix_2026_10_03_2335.zip`。
- `dev/build_timber_wolf.py` 已同步为匀速支撑相 + 四元数符号连续 + LINEAR 关键帧，重新完整构建不会回退到打滑步态。
- 遗留：仍无坡面运行时脚掌 IK；走跑同为对角小跑，跑动没有腾空相。

## 2026-10-03 修复：野狼卡顿/切换抽搐与出生未持剑

- 原因：狼跑步目标超过腿部可达长度，膝关节每个 30fps 采样帧最高跳变约35°；速度临界值无滞回，走跑切换重置相位；近身冷却时仍顶向玩家。初始装备系统清空武器槽并删除场景剑，且旧 WeaponMount 将剑尖朝向相机。
- Blender MCP 重新制作 walk/run/backstep 曲线：降低重心保留屈膝余量，使用连续周期轨迹；保持24骨、3910tris、8动作、尺寸/原点、2K UV/PBR材质与贴图不变。逐帧蒙皮与贴地检查通过。发布更新 GLB、独立源文件与九姿势参考图；修复前资产备份 `art/backups/timber_wolf_before_motion_fix_2026_10_03.zip`。
- Godot 移动加入速度及步频缓冲、0.12s 动作确认、走跑1.7/2.3m/s滞回和周期相位继承。攻击距离内冷却时停步。专项42项通过；最快步频连续6秒、60Hz采样的骨骼最大相邻转角15.8°，旧速度边界附近连续波动2秒没有反复切换。
- 战士出生实际装备锈迹长剑，攻击力由裸职业15变为持剑20。快照从实际装备组件采集；缺少补发标记且装备/背包均无武器的旧载荷补发初始剑一次；新存档主动空手、已有稀有装备及强化等级保留。
- 修正 FP 挂点方向与位置，重复刷新不重建武器，换装立即脱离旧模型。完整 Player 场景专项15项通过；Compatibility/OpenGL 运行截图 `art/previews/player/iron_sword_equipped.png`，剑尖/握柄均在视锥内。
- 复现：MCP执行 `dev/repair_wolf_locomotion.py` → `dev/review_timber_wolf.py` → `dev/publish_timber_wolf.py`；Godot执行 `dev/verify_timber_wolf.tscn`、`dev/verify_actor_regressions.tscn`。完整战斗数值测试明确卸下初始剑后验证裸职业基线。
- 完整自检：`dev/verify_boot.tscn` 输出 `VERIFY ALL OK`，退出码0；日志 `dev/art_work/timber_wolf/fix_boot.log`。仍有既有 headless 截图/故意损坏存档/退出资源泄漏诊断，未宣称运行日志完全无错误。
- 遗留：第一人称手臂仍是历史胶囊占位，手掌/指骨及技能骨骼动画尚属后续资产制作；未将本次挂点修复计作手部骨骼完成。狼仍无复杂坡面脚掌IK；未完成森林 Forward+/D3D12 的人工游玩验收。

## 2026-10-03 更新：野狼模型、贴图、骨骼与动画（第二项）

- 风格：参考《魔兽世界》式中世纪奇幻 RPG 的色块和夸张轮廓，原创蓝灰毛皮野狼；本轮为程序材质烘焙的手绘感首版。替换旧椭球/圆柱组合，新增分段四肢、脚爪、口腔/牙齿、可张合下颌、耳朵、肩颈毛束与蓬尾。
- 模型：`art/models/enemy/timber_wolf.glb`；单蒙皮 Mesh / 单材质，3910 tris、源网格 2100 顶点、1600 四边面；保留非破坏三角化修改器保证导出切线。低于 10k tris 怪物预算。
- 尺寸：静态约宽 0.70m × 长 2.24m（含尾）× 高 1.51m（含耳），肩高约 0.9m；比旧占位更大，血条高度更新为 1.6m。脚底约 0.005m，原点位于脚下中心；Blender -Y 朝前，glTF/Godot +Z 朝前。
- 原始备份：`art/backups/timber_wolf_before_rig_2026_10_03.zip`，包含旧模型、旧参考图、共享 enemies_pack.blend 和两个相关脚本。原共享源文件未修改。
- 源文件：`art/source/timber_wolf.blend` 独立归档，包含生产场景、姿势检查场景、24 骨架、8 Actions、源程序材质和烘焙材质。可重现步骤：在已打开的项目 Blender 源文件会话中，通过 MCP 执行 `dev/build_timber_wolf.py` → `dev/review_timber_wolf.py`（含死亡贴地校正）→ 视觉检查 → `dev/publish_timber_wolf.py`。
- 贴图：`art/textures/timber_wolf/timber_wolf_{albedo,normal,roughness,metallic,ao,orm}.png`，全部 2048×2048。图集为多部件统一 UV，GLB 内嵌 Albedo、Normal、ORM。ORM R=AO / G=Roughness / B=Metallic；无外部路径依赖。
- 材质：毛皮 Roughness 0.84–0.88，鼻部 0.42，眼睛 0.30，牙齿 0.50；Metallic 全 0（生物表面）；弱法线起伏表达大束毛流，无发光。Albedo 使用颜色空间，其他数值/法线图为 Non-Color。
- 骨骼：Root、Hips、Spine、Chest、Neck、Head、Jaw、双耳、三段尾巴、四肢各上段/下段/脚，共 24 骨。源顶点权重归一化，实际最多 2 骨影响；glTF 有有效 skins、JOINTS_0、WEIGHTS_0 和切线。
- 动画：idle 2.0s、walk 1.2s、run 0.6s、bite 0.8s、hit 0.4s、death 1.2s、backstep 0.6s、stagger 1.0s；30fps 烘焙。待机/移动/后退/眩晕循环，攻击/受击/死亡不循环。采用原地动作，角色位移仍由 AI 控制；走跑与后退按实际速度调整播放步频。
- 攻击接线：0.4s 合颌时由脚本扣血一次，0.8s 收招后后退；伤害 8、生命 40、追击速度 3.5、攻击距离等原战斗参数保留，巡逻改为 1.6m/s 步行。冻结停止姿势并取消旧攻击，眩晕播放 stagger，受击播放 hit（咬击期间保持攻击动作可读），死亡播放骨骼动作后 2s 释放，不叠加整模型倒地 Tween。
- 通用接口：BaseEnemy 新增 `_play_death_visual()` 钩子，默认行为与其他未升级怪物原先的死亡 Tween 一致；MeleeChaser 覆盖为骨骼死亡。新资产正面 +Z，通过 `Visual.rotation.y = PI` 对齐现有 AI -Z 朝向。
- Blender 参考：`art/previews/enemy/timber_wolf.png`；九姿势检查图 `art/previews/enemy/timber_wolf_poses.png`。Cycles 柔光主灯+冷补光/轮廓光；已修正下颌开合方向、死亡穿地和多场景导出带入铁剑的问题。
- 验证：`dev/verify_timber_wolf.tscn` 覆盖 24 骨、真实腿骨变形、五类 2K 贴图、8 动画、循环、朝向、0.4s 单次伤害、收招、冻结/解冻、完美格挡、受击、死亡只发一次事件与正常释放。Blender 检查了全部动画采样帧：无非有限变换、无地面穿透，2100 顶点权重有效。
- Godot 渲染验收：`dev/preview_timber_wolf.tscn` 已在 Compatibility/OpenGL 下生成待机、咬击前摇、命中和死亡 PNG，位于 `dev/art_work/timber_wolf/godot_*.png`。这验证了真实导入后的渲染与姿势，不等于完整森林 Forward+/D3D12 光照的最终验收。
- 测试结果：专项验证最终 38 项通过（含步频），日志 `dev/art_work/timber_wolf/godot_verify.log`；项目完整自检输出 `VERIFY ALL OK`、退出码 0。完整自检仍输出 headless 截图空纹理、故意损坏存档的 JSON 解析、测试 spirit_test 缺失和退出资源泄漏诊断，不标记为无日志错误；对应 `boot_verify.log` 已保留。
- 遗留：当前为风格化首版；复杂坡面尚未制作运行时脚掌 IK，毛束/关节处仍可继续精修。最终森林光照与主角近身镜头需后续一起调整。其他怪物和角色尚未因本次工作自动获得骨骼或贴图。

## 2026-10-03 更新：铁剑完整贴图（按新风格执行的第一项）

- 用户美术方向更新：参考《魔兽世界》的风格化中世纪奇幻 RPG，覆盖旧的写实路线。采用蓝灰钢刃、暖金护手/剑首、棕色皮革缠柄、清晰边缘与较大色块；本资产为程序材质烘焙的手绘感首版，并非人工逐笔绘制。
- 通过本机 Blender 5.2.2 MCP 完成 UV、材质、烘焙、灯光、参考渲染与导出；Godot 只接入已有路径。
- 模型：`art/models/player/iron_sword.glb`；4 个网格部件，574 tris，保留原始约 1m 总长、握柄挂接原点及朝向（Blender +Z 刃向 → Godot +Y）。
- 源文件：`art/source/iron_sword.blend`；保留带 fake user 的钢/黄铜/皮革程序源材质及烘焙材质、灯光相机。源网格本轮已三角化以统一烘焙与导出切线；原始带修改器的网格保存在下述备份中。
- 贴图：`art/textures/iron_sword/iron_sword_{albedo,normal,roughness,metallic,ao,orm}.png`，全部 1024×1024。Albedo 为颜色纹理，其余为 Non-Color 数据。ORM 通道 R=AO、G=Roughness、B=Metallic。
- GLB 内嵌 Albedo、Normal、ORM 三张 PNG；对应 Base Color、Normal、Metallic/Roughness、Occlusion 贴图槽全部存在，不依赖外部绝对路径。
- 材质参数：钢/黄铜 Metallic=1，皮革=0；钢粗糙度约 0.38–0.48、黄铜 0.40–0.51、皮革 0.65–0.85；法线用于少量表面起伏和皮革缠绕接缝；无自发光。
- UV：四部件共享一个图集；先固定三角化再烘焙，4 个导出 primitive 均有 TEXCOORD_0 与 TANGENT，已消除握柄缺失切线警告。
- 参考图：`art/previews/player/iron_sword.png`（900×1200，Blender Cycles 48 samples，三盏柔光灯与冷色环境）。
- 原始备份：`art/backups/iron_sword_before_pbr_2026_10_03.zip`，包括旧 GLB、blend 和参考图。
- 接入验证：`dev/verify_iron_sword.gd` 已通过，4 个部件的五类贴图均为 1K，法线与 AO 启用，`FPArms/WeaponMount/IronSword` 实例存在。游戏内锈迹长剑原本复用铁剑模型，也将使用新外观，尚未制作独立锈蚀变体。
- 项目自检：`--headless res://dev/verify_boot.tscn` 退出码 0，输出 `VERIFY ALL OK`。日志仍包含 headless 拍照时 dummy renderer 空纹理错误，以及退出时资源/RID 泄漏诊断；不能称为无警告运行。本轮未改动这些系统，日志保存在 `dev/art_work/iron_sword/boot_verify.log`。
- 骨骼：剑为刚性道具，不需要自身蒙皮；主角骨骼、手部握剑及技能动画属于后续第一人称手臂任务。本轮未将现有 Tween 动作标记为已完成骨骼动画。
- 遗留：本轮完成 Blender 参考图和 Godot 资源/挂点检查，未完成实际游戏光照下的逐帧视觉验收；后续手臂制作时统一检查握剑与攻击镜头表现。历史条目中的“无 UV/无贴图”描述已由本更新覆盖。

> 归档路径规范：
> - 模型：`art/models/<分类>/<名称>.glb`
> - 贴图：`art/textures/<同名>/`（Albedo / Normal / Roughness / Metallic / AO）
> - 参考渲染图：`art/previews/<分类>/<名称>.png`
> - Blender 源文件：`art/source/<名称>.blend`
> - **每个新增/修改的资产都必须在本表登记**：尺寸、原点、面数、材质参数、UV 与贴图状态、遗留项。

---

## player / iron_sword（铁剑）
- 日期: 2026-09-30（第 4 轮）
- 模型: `art/models/player/iron_sword.glb`（22 KB）
- 源文件: `art/source/iron_sword.blend`
- 参考图: `art/previews/player/iron_sword.png`
- 尺寸: 总长 1.0 m（剑刃 0.784 / 护手 0.19 宽 / 握柄 0.14 / 剑首 0.065）
- 原点: 柄底中心；刃沿 Blender +Z（Godot 导入后为 +Y）
- 面数（应用 Bevel 后）: 剑刃 118 + 护手 108 + 握柄 60 + 剑首 288 = **574 tris**
- 材质（纯 PBR 参数，无贴图）:

  | 部位 | 材质名 | Base Color | Metallic | Roughness |
  |---|---|---|---|---|
  | 剑刃 | Sword_Steel | (0.72, 0.74, 0.78) | 1.0 | 0.28 |
  | 护手 / 剑首 | Sword_Brass | (0.72, 0.55, 0.25) | 1.0 | 0.38 |
  | 握柄 | Sword_Leather | (0.22, 0.13, 0.08) | 0.0 | 0.85 |

- UV: **未展开**（全部部件；上贴图前需先展 UV）
- 贴图: **未制作**（待补 Albedo / Normal / Roughness 全套）
- Godot 挂接: `scenes/player/fp_arms.tscn` → `WeaponMount`
- 备用源: Blender 会话中保留 `IronSword` 对象组，可继续迭代

---

## spirit / 三精灵套装（glow_wisp / flame_crystal / stone_guardian）
- 日期: 2026-09-30（第 5 轮）
- 模型: `art/models/spirit/glow_wisp.glb`（16 KB）/ `art/models/spirit/flame_crystal.glb`（10 KB）/ `art/models/spirit/stone_guardian.glb`（22 KB）
- 源文件: `art/source/spirits_pack.blend`（三只同批产出，合并源文件；Blender 会话中保留 GlowWisp / FlameCrystal / StoneGuardian 对象组）
- 参考图: `art/previews/spirit/{glow_wisp,flame_crystal,stone_guardian}.png`
- 尺寸: 萤灵约 0.30 m / 晶灵约 0.40 m / 守灵约 0.60 m（含漂浮碎石）
- 原点: 模型中心（悬浮精灵，非贴地；Godot 侧跟随挂点自行定位）
- 面数: 萤灵 752 tris / 晶灵 264 tris / 守灵 1140 tris
- 材质（纯 PBR 参数 + 自发光，无贴图）:

  | 部位 | 材质名 | Base Color | Metallic | Roughness | Emission |
  |---|---|---|---|---|---|
  | 萤灵核心 | Spirit_WispCore | (1.0, 0.85, 0.5) | 0.0 | 0.4 | (1.0, 0.85, 0.45) ×6 |
  | 萤灵光点 | Spirit_WispDot | (1.0, 0.9, 0.6) | 0.0 | 0.4 | (1.0, 0.9, 0.55) ×9 |
  | 晶灵外壳 | Spirit_MagmaCrust | (0.09, 0.06, 0.05) | 0.0 | 0.9 | — |
  | 晶灵核心 | Spirit_MagmaCore | (1.0, 0.45, 0.12) | 0.0 | 0.5 | (1.0, 0.4, 0.08) ×8 |
  | 磐石守灵 | Spirit_Rock | (0.34, 0.39, 0.47) | 0.1 | 0.9 | — |

- UV: 已生成（基础球体/圆锥展 UV 标记；未精修）
- 贴图: 未制作（发光靠 emissive 材质，Godot 侧配少量 bloom 增强）
- Godot 挂接: `scenes/player/spirit_entity.tscn` 按 SpiritData.model_path 动态装载（挂到 ModelRoot；占位发光球为回退）
- 已知取舍: 无透明光晕外壳（避免 glTF 透明材质风险），光点/自发光在 Godot 里靠 bloom 表现

---

## enemy / timber_wolf（野狼）+ moss_boar（苔牙野猪）+ forest_mage（森林法师）
## prop / heal_totem（治疗图腾）
- 日期: 2026-09-30（第 8 轮）
- 模型: `art/models/enemy/timber_wolf.glb`（31 KB）/ `art/models/enemy/moss_boar.glb`（40 KB）/ `art/models/enemy/forest_mage.glb`（30 KB）/ `art/models/prop/heal_totem.glb`（10 KB）
- 源文件: `art/source/enemies_pack.blend`（同批产出合并源文件）
- 参考图: `art/previews/enemy/{timber_wolf,moss_boar,forest_mage}.png`、`art/previews/prop/heal_totem.png`
- 尺寸: 野狼约 1.1×0.55×0.75 m / 野猪约 1.1×0.6×0.75 m / 法师高约 1.65 m / 图腾高约 1.13 m
- 原点: 底部中心贴地；模型正面朝 Blender +Y（Godot 导入后为 -Z，与 look_at 朝向一致）
- 面数: 野狼 1228 tris / 野猪 1600 tris / 法师 1040 tris / 图腾 384 tris
- 材质（纯 PBR 参数 + 自发光，无贴图）:

  | 资产 | 材质 | 参数摘要 |
  |---|---|---|
  | 野狼 | Enemy_WolfFur / WolfFurDark | (0.32,0.30,0.27) & (0.15,0.14,0.13)，Rough 0.9 |
  | 野猪 | BoarHide / BoarMoss / Tusk | 皮革棕 Rough 0.92 / 苔藓绿 0.95 / 獠牙米白 0.5 |
  | 法师 | MageRobe / MageSkin / HealGlow / Wood | 森林绿袍 0.85 / 肤色 / 法球 emissive 绿 ×6 / 木杖 |
  | 图腾 | Wood / HealGlow | 木柱 / 顶部绿光球 emissive ×6 |

- UV: 未展开（全部；上贴图前需先展 UV）
- 贴图: 未制作
- Godot 挂接: base_enemy.model_path 动态装载（缺失时发光胶囊占位）；图腾 heal_totem.gd 同机制
- 复用说明: 支援怪（林间祭司）MVP 复用 forest_mage 模型，后续补专属模型

---

## player / frost_edge（霜痕之刃，稀有武器）
- 日期: 2026-09-30（第 9 轮）
- 模型: `art/models/player/frost_edge.glb`（22 KB）
- 源文件: `art/source/frost_edge.blend`
- 参考图: `art/previews/player/frost_edge.png`
- 尺寸: 总长 1.0 m（与铁剑同结构：剑刃 0.784 / 护手 0.19 宽 / 握柄 0.14 / 剑首）
- 原点: 柄底中心；刃沿 Blender +Z（Godot +Y）
- 材质（PBR + 自发光，无贴图）:

  | 部位 | 材质名 | Base Color | Metallic | Roughness | Emission |
  |---|---|---|---|---|---|
  | 剑刃 | Frost_Blade | (0.62, 0.72, 0.88) | 1.0 | 0.18 | (0.45, 0.75, 1.0) ×1.4 |
  | 护手/剑首 | Frost_Guard | (0.7, 0.72, 0.78) | 1.0 | 0.3 | — |
  | 握柄 | Frost_Grip | (0.1, 0.13, 0.2) | 0.0 | 0.85 | — |

- UV: 未展开（上贴图前需先展 UV）；贴图: 未制作
- Godot 挂接: 装备系统按 ItemData.model_path 换模（稀有品质附加发光 overlay）

---

## scenery / prop（第 11 轮森林营地写实化资产）
- 日期: 2026-10-01（第 11 轮）
- 模型与源文件:
  | 资产 | 模型 (glb) | 源文件 (blend) | 参考图 | 尺寸 | 面数(顶点) | 说明 |
  |---|---|---|---|---|---|---|
  | 风车 | scenery/windmill.glb (15 KB) | windmill.blend | previews/scenery/windmill.png | 高 10.5 m / 底径 5.5 m | 120 | 塔身+石基+尖顶+门/窗，营地地标 |
  | 风车扇叶 | scenery/windmill_blades.glb (11 KB) | windmill.blend | 同上 | 4.6 m 臂长 | 88 | 独立资产：原点在轮毂中心，Godot 绕局部 Z 旋转 |
  | 篝火 | scenery/campfire.glb (65 KB) | campfire.blend | previews/scenery/campfire.png | 约 2.9 m 高（含吊锅架） | 426 | 石圈+交叉柴+余烬(emissive)+三脚架吊锅 |
  | 帐篷 | scenery/tent.glb (19 KB) | tent.blend | previews/scenery/tent.png | 2.3×2.1×1.6 m | 148 | A 字帆布帐篷+骨架+地钉拉绳 |
  | 针叶树 | scenery/tree_a.glb (667 KB) | tree_a.blend | previews/scenery/tree_a.png | 高约 8.6 m | 62 | 4 层树冠；树皮烘了法线贴图 |
  | 阔叶树 | scenery/tree_b.glb (706 KB) | tree_b.blend | previews/scenery/tree_b.png | 高约 8.5 m | 260 | 分叉树干+冠层团簇；复用树皮法线 |
  | 岩石 | scenery/rock.glb (17 KB) | rock.blend | previews/scenery/rock.png | 约 1.8×1.5×1.2 m | 78 | 花岗岩簇+苔藓 |
  | 回响碑 | scenery/echo_stone.glb (46 KB) | echo_stone.blend | previews/scenery/echo_stone.png | 高约 2.2 m | 312 | 碑体+发光符文环(emissive 0.6)+刻纹+基座岩 |
  | 宝箱 | prop/chest.glb (11 KB) | chest.blend | previews/prop/chest.png | 0.95×0.62×0.45 m | 64 | 两节点：Chest_Body + Lid（原点在背侧铰链线，Godot 开盖动画） |
  | 采集植物 | prop/herb.glb (52 KB) | herb.blend | previews/prop/herb.png | 高约 0.55 m | 约 150 | 叶簇+发光花苞(emissive 2.2) |
- 贴图: 树木使用炭烧法线贴图 `art/textures/tree/tree_bark_normal.png`（1024²，Blender Cycles NORMAL 炭烧，随 glb 打包）；其余资产为纯 PBR 材质值（无贴图）
- 原点: 全部底部中心贴地；风车门/扇叶正面朝 Blender -Y → Godot +Z
- Godot 挂接: camp.gd（风车/扇叶/篝火/帐篷，扇叶绕局部 Z 旋转）、chest.gd（model_path→Lid 开盖）、gather_node.gd（herb，隐藏占位）、echo_stone.gd（glb 符文发光随共鸣切换）、terrain_builder.gd（树 A/B/岩石进 MultiMesh，程序化网格作兜底）
- 遗留: 帐篷/风车观感可再细化；storage_crate / hut / hunter_cabin / waterfall_cliff 仍为程序化占位（未出模）；其余资产暂无贴图（Albedo/Roughness 仅数值）

---

## boss / scenery（第 12 轮微型秘境资产）
- 日期: 2026-10-02（第 12 轮）
- 模型与源文件:
  | 资产 | 模型 (glb) | 源文件 (blend) | 参考图 | 尺寸 | 顶点 | 说明 |
  |---|---|---|---|---|---|---|
  | 苔冠巨兽 | boss/moss_crown_beast.glb (76 KB) | moss_crown_beast.blend | previews/boss/moss_crown_beast.png | 约 3.4×1.9×2.3 m | 466 | 四足巨兽：深褐皮甲/浅褐腹、苔藓冠冕(微发光)+背肌苔斑、琥珀色发光眼、獠牙/爪；正面朝 Blender +Y |
  | 嫩芽 | boss/boss_sprout.glb (23 KB) | boss_sprout.blend | previews/boss/boss_sprout.png | 高约 0.95 m | 126 | 球茎+三叶芽+发光核心(emissive 2.2)+根足 |
  | 秘境石柱 | scenery/dungeon_pillar.glb (28 KB) | dungeon_pillar.blend | previews/boss/dungeon_pillar.png | 高约 4.9 m | 216 | 座+柱身+顶板+符文环(发光)/刻纹 |
  | 秘境石门 | scenery/dungeon_gate.glb (17 KB) | dungeon_gate.blend | previews/boss/dungeon_gate.png | 5.6×5.2 m | 100 | 双柱+门楣+顶盖+发光符文+苔藓，秘境入口模型 |
- 材质: PBR 材质值 + emissive（苔藓冠冕/眼睛/符文/嫩芽核心）；无贴图（遗留）
- Godot 挂接: boss_moss_crown_beast.gd / boss_sprout.gd / dungeon_pillar.gd / dungeon_entrance.gd 的 model_path（缺失自动退回程序化占位）
- 遗留: 巨兽比例与冠冕造型可再细化；符文/苔藓无贴图（仅材质值+发光）；无骨骼动画（技能靠位移与粒子表现）
