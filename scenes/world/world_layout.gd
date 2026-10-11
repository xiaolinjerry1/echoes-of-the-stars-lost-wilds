class_name WorldLayout
extends RefCounted
## WorldLayout（森林区域布局常量）
## 职责：集中定义 256×256 米森林的坐标、道路/溪流折线、兴趣点与分块划分，
## 供地形生成、分块内容与测试共用；北 = -Z，南 = +Z，东 = +X，西 = -X。

const SIZE := 256.0
const HALF := 128.0
const CHUNK_SIZE := 128.0

## 营地区域（西南）
const CAMP := Vector3(-78, 0, 84)
const CAMP_RADIUS := 26.0
const CAMPFIRE := Vector3(-78, 0, 84)
## 森林野狼区（东，任务 1）
const WOLF_AREA := Vector3(62, 0, 40)
const RANGER_POS := Vector3(56, 0, 46)
## 旧观测所遗迹（东北，任务 2 回响碑）
const OBSERVATORY := Vector3(68, 0, -54)
## 猎人小屋（西北，任务 5）
const CABIN := Vector3(-72, 0, -58)
## 瀑布（东南）
const WATERFALL := Vector3(18, 0, 56)
## 精英苔牙野猪巢穴（中部偏北）
const BOAR_NEST := Vector3(14, 0, -10)
## 原林间秘境整体并入森林：营地北方，南门步行进入，无世界切换。
const GROVE := Vector3(-85, 0, -5)
const GROVE_ENTRANCE := Vector3(-85, 0, 25)
const WYVERN_NEST := Vector3(45, 0, -96)

## 道路折线（x, z），从营地出发连接各兴趣点
const ROADS := [
	[Vector2(-80, 60), Vector2(-85, 40), Vector2(-85, 25)],
	[Vector2(-85, -35), Vector2(-85, -45), Vector2(-72, -56)],
	[Vector2(-62, 72), Vector2(-34, 54), Vector2(4, 44), Vector2(38, 42), Vector2(62, 40)],
	[Vector2(4, 44), Vector2(28, 18), Vector2(50, -12), Vector2(64, -44), Vector2(68, -54)],
	[Vector2(-34, 54), Vector2(-34, 18), Vector2(-45, -15), Vector2(-45, -44), Vector2(-72, -56)],
	[Vector2(4, 44), Vector2(10, 22), Vector2(14, -10)],
	[Vector2(4, 44), Vector2(12, 50), Vector2(18, 56)],
]

## 溪流折线（x, z），自瀑布向南流出地图
const CREEK := [
	Vector2(18, 58), Vector2(16, 76), Vector2(20, 96), Vector2(16, 116), Vector2(18, 128),
]

## 需要铲平的兴趣点台地（中心 + 半径），台地高度取中心原始地形高度
const PADS := [
	[Vector3(68, 0, -54), 14.0],  # 观测所
	[Vector3(-72, 0, -58), 12.0], # 猎人小屋
	[Vector3(62, 0, 40), 16.0],   # 野狼区
	[Vector3(14, 0, -10), 12.0],  # 巢穴
	[Vector3(56, 0, 46), 6.0],    # 受伤巡林者
	[Vector3(18, 0, 56), 10.0],   # 瀑布水潭
]

## 分块 id → 原点（-x,-z 角）
const CHUNKS := {
	"forest_chunk_00": Vector2(-128, -128),
	"forest_chunk_01": Vector2(0, -128),
	"forest_chunk_10": Vector2(-128, 0),
	"forest_chunk_11": Vector2(0, 0),
}


## 从折线采样：返回 [{pos: Vector2, base_h: float}]（高度回调由调用方提供）。
static func sample_polyline(points: Array, spacing: float, height_provider: Callable) -> Array:
	var result: Array = []
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length := a.distance_to(b)
		var steps := maxi(int(length / spacing), 1)
		for s in steps:
			var p := a.lerp(b, float(s) / float(steps))
			result.append({"pos": p, "base_h": float(height_provider.call(p.x, p.y))})
	return result


## 折线最近采样（返回 {dist, base_h}）。
static func nearest_sample(samples: Array, x: float, z: float) -> Dictionary:
	var best_dist := INF
	var best_h := 0.0
	for sample in samples:
		var p: Vector2 = sample["pos"]
		var d := Vector2(x - p.x, z - p.y).length()
		if d < best_dist:
			best_dist = d
			best_h = float(sample["base_h"])
	return {"dist": best_dist, "base_h": best_h}


## 是否靠近任一道路（用于散布排除），margin 为最小距离。
static func near_road(samples: Array, x: float, z: float, margin: float) -> bool:
	return float(nearest_sample(samples, x, z)["dist"]) < margin


## 距离最近的兴趣点中心（含营地）。
static func nearest_poi_distance(x: float, z: float) -> float:
	var best := Vector2(x - CAMP.x, z - CAMP.z).length() - CAMP_RADIUS
	best = minf(best, maxf(absf(x - GROVE.x), absf(z - GROVE.z)) - 32.0)
	best = minf(best, Vector2(x - WYVERN_NEST.x, z - WYVERN_NEST.z).length() - 20.0)
	for pad in PADS:
		var center: Vector3 = pad[0]
		var d := Vector2(x - center.x, z - center.z).length() - float(pad[1])
		best = minf(best, d)
	return best
