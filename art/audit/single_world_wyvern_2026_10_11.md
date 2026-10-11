# 单一主世界与飞龙验收

## 2026-10-11 更新：单一主世界、完整遗迹迁入与凶焰飞龙

- 用户要求仅一片世界，直接把原秘境整个搬到森林。生产GameSession移除DungeonManager，森林NavRegion直接挂main_world_grove.tscn（沿用原forest_grove_dungeon逻辑、main_world_mode=true），中心(-85,0,-5)，南门(-85,0,25)。60×60遗迹、两波野狼、巨兽、四石柱、宝箱与首通/掉落奖励均保留；巨兽召唤的嫩芽也在森林内生成。入口无任务门槛，无传送/独立天空/另一个导航世界，南北墙有真实门洞；死亡仍回营地，3.5秒后原地复位遗迹，世界对象保持不变。
- 地形增加方形平整台地及6m过渡，排除区域内随机树石，补营地北行路和北门道路，猎人小屋旧路绕过东墙。石柱/召唤/前摇特效/波次文字从局部坐标改为世界坐标；南门连接森林导航。地图/罗盘常驻「兽」「龙」，告示板和冰封试炼交付对白指引新位置；旧secret_realm_open/dungeon_first_clear/dungeon_grove_cleared保存键保留兼容，生产运行世界id只用forest。历史独立秘境模板与管理器源文件供开发回归，生产场景无入口或管理器引用。
- 新增enemy/dread_wyvern.glb：9224tris、30骨、11动作（idle/fly/dive_windup/dive/recover/fire_windup/fire/hit/stagger/death/land），2K Albedo/Normal/Roughness/Metallic/AO/ORM/Emission全套独立PNG，GLB内嵌。尺寸约19.01m翼展×10.22m体长×5.05m高；两翼/两腿/四节长尾、角、牙、爪与背刺，灰黑裂鳞、棕色腹甲、赤褐翼膜与发光眼。以原型结构的风格化奇幻表现为主，细节由Blender程序材质烘焙；非照片扫描或毛发模拟。原点底部中心，Blender-Y→Godot+Z，运行时Visual转PI兼容AI-Z。
- 飞龙原生出生在森林东北(45,地形高度+12,-96)，18m半径巡航。900血/28攻/12甲，使用BossComponent失衡抗控。俯冲：1.2s前摇锁定落点，1.1s扫掠飞行、36原始伤害/3.3m判定，每次最多一次；3.2s收招，前约1.8s落地供战士近战反击，随后升空。火球：1.1s蓄力、单发22m/s锁定方向，28原始伤害、2.2m爆炸、4DPS×3s灼烧；射线检测墙与玩家，遮挡阻断伤害，不追踪玩家。两招由正常AI交替；死亡/回营地/越过巢区62m立即取消攻击，满失衡下降形成破绽。翅翼无单独物理阻挡/受击体，仅躯干箱体受击；实际近战命中已测。
- 新增prop/wyvern_fireball.glb：320tris、直径约0.96m、1K完整PBR+Emission（强度4），火红裂隙的岩浆弹；投射物原点为球心以匹配扫掠轨迹。无真实流体/体积火焰。飞龙眼Emission强度3；皮肤/翼膜roughness约0.64–0.83，非金属，甲壳metallic0.08。Blender参考为冷环境+暖侧光，已核对Compatibility实景。
- 归档：两模型art/models/{enemy/dread_wyvern,prop/wyvern_fireball}.glb；同名art/textures/、art/source/*.blend、art/previews/<分类>/*.png齐全，源文件独立打包贴图与原材质。构建dev/build_dread_wyvern.py、dev/build_wyvern_fireball.py，发布dev/publish_wyvern_assets.py通过55个动作采样的有限坐标与变形范围校验。
- 验证：dev/verify_single_world_wyvern.tscn最终59项通过，覆盖单世界/门洞路径/生物和石柱全局坐标/正常AI两招/前摇/躲避/单次命中/墙挡火球/灼烧/失衡/营地/实际战士近战/受击/死亡/地面掉落/存档击杀标记。完整dev/verify_boot.tscn通过，废弃维度切换检查替换为整区迁入、死亡回营地、森林不卸载和场地复位，保留原全部战斗/奖励/任务/存档回归。日志dev/single_world_wyvern_verify_final.log和dev/single_world_boot_verify.log；Compatibility实景6张已查看：grove_in_main_world、grove_walk_in_entrance、dread_wyvern_in_forest、dread_wyvern_head、dread_wyvern_fireball、dread_wyvern_dive。后两张为受控动作/发弹画面，不是全程实战录像。
- 最终审计52模型，旧无贴图0，缺失引用0；森林导航5600多边形。Forward+/D3D12未做本轮视觉验收；长时间游玩/帧率未量测，已有导航体素参数警告与退出RID/资源释放告警仍在。未新增世界尺寸、飞龙骑乘、关节IK或真实火焰模拟。

