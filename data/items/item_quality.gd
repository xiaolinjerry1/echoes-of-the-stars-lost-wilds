class_name ItemQuality
extends RefCounted
## ItemQuality（品质定义工具）
## 职责：品质 → 颜色 / 中文名 / 排序权重 / 边框样式。
## 品质区分不只靠颜色：边框线宽与圆角随品质递增（形状差异）。

const COMMON := "common"
const UNCOMMON := "uncommon"
const RARE := "rare"
const EPIC := "epic"

const COLORS := {
	COMMON: Color(0.85, 0.85, 0.85),
	UNCOMMON: Color(0.35, 0.85, 0.4),
	RARE: Color(0.3, 0.65, 1.0),
	EPIC: Color(0.72, 0.4, 1.0),
}

const LABELS := {
	COMMON: "普通",
	UNCOMMON: "优秀",
	RARE: "稀有",
	EPIC: "史诗",
}

const RANKS := {
	COMMON: 0,
	UNCOMMON: 1,
	RARE: 2,
	EPIC: 3,
}

## 常用品质阈值
const RANK_UNCOMMON := 1
const RANK_RARE := 2
const RANK_EPIC := 3


static func color_for(quality: String) -> Color:
	return COLORS.get(quality, COLORS[COMMON])


static func label_for(quality: String) -> String:
	return LABELS.get(quality, LABELS[COMMON])


static func rank_for(quality: String) -> int:
	return int(RANKS.get(quality, 0))


## 品质边框样式：颜色 + 线宽（1/2/3/4px）+ 圆角（2/4/8/12）共同区分。
static func make_style(quality: String, background := Color(0.09, 0.1, 0.14, 0.95)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = color_for(quality)
	var rank := rank_for(quality)
	style.set_border_width_all(1 + rank)
	var radii := [2, 4, 8, 12]
	style.set_corner_radius_all(radii[rank])
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
