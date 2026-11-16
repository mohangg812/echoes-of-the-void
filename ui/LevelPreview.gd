# res://ui/LevelPreview.gd
# Миниатюра карты уровня для карточек выбора миссии (рисуется из JSON-схемы).
class_name LevelPreview
extends Control

var data: Dictionary = {}
var _t: float = 0.0
var locked: bool = false


func setup(d: Dictionary) -> void:
	data = d
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if data.is_empty():
		return
	var layout: Array = data["layout"]
	var gh: int = layout.size()
	var gw: int = 0
	for l in layout:
		gw = maxi(gw, String(l).length())
	var cs: float = minf(size.x / float(gw), size.y / float(gh))
	var ox: float = (size.x - cs * gw) * 0.5
	var oy: float = (size.y - cs * gh) * 0.5
	var tint: float = 0.35 if locked else 1.0
	for y in range(gh):
		var line: String = String(layout[y])
		for x in range(line.length()):
			var ch: String = line[x]
			var r := Rect2(ox + x * cs, oy + y * cs, cs + 0.5, cs + 0.5)
			match ch:
				"#", "S":
					draw_rect(r, Color(0.08, 0.28, 0.38, 0.9 * tint))
				"=":
					draw_rect(r, Color(0.3, 0.75, 0.95, 0.7 * tint))
				"V":
					draw_rect(r, Color(0.2, 0.3, 0.55, tint))
				"C":
					draw_rect(r, Color(0.35, 0.22, 0.55, tint))
				"E":
					draw_rect(r, Color(0.1, 0.95, 0.55, tint))
				"G":
					draw_rect(r, Color(0.05, 0.1, 0.15, tint))
					draw_circle(r.get_center(), cs * (1.0 + 0.3 * sin(_t * 5.0)), Color(2.0, 1.6, 0.3, tint))
				" ":
					pass
				_:
					draw_rect(r, Color(0.04, 0.09, 0.14, tint))
	for d in data.get("doors", []):
		var p: Array = d["pos"]
		var col: Color = {"RED": Color("#FF1E42"), "BLUE": Color("#2D7CFF"), "YELLOW": Color("#FFD700")}.get(String(d.get("required_keycard", "")), Color(0.5, 0.7, 0.9))
		draw_rect(Rect2(ox + int(p[0]) * cs, oy + int(p[1]) * cs, cs + 0.5, cs + 0.5), Color(col.r, col.g, col.b, tint))
	for g in data.get("guards", []):
		var s: Array = g["start"]
		var gc: Color = Color(1.8, 0.2, 0.3)
		match String(g.get("type", "standard")):
			"elite": gc = Color(1.5, 0.3, 1.9)
			"hound": gc = Color(2.0, 0.9, 0.2)
			"drone": gc = Color(0.4, 1.8, 0.8)
		draw_circle(Vector2(ox + (int(s[0]) + 0.5) * cs, oy + (int(s[1]) + 0.5) * cs), cs * 0.7, Color(gc.r, gc.g, gc.b, tint))
	for c in data.get("cameras", []):
		var p2: Array = c["pos"]
		draw_rect(Rect2(ox + int(p2[0]) * cs, oy + int(p2[1]) * cs, cs, cs), Color(1.8, 1.0, 0.1, tint))
	for l in data.get("lasers", []):
		var p3: Array = l["pos"]
		draw_rect(Rect2(ox + int(p3[0]) * cs, oy + int(p3[1]) * cs, cs, cs), Color(2.0, 0.2, 0.3, tint))
