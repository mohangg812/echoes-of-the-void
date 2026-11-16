# res://ui/DialogueBox.gd
# Радиопереговоры: портрет собеседника, побуквенный вывод с «голосовыми» писками.
# Куратор помогает, Система Безопасности издевается, Вор огрызается.
class_name DialogueBox
extends Control

const VOICES: Dictionary = {
	"handler": {"name": "КУРАТОР", "portrait": "portraits/portrait_handler", "blip": "blip_h", "pitch": 1.0, "color": Color("#00F0FF")},
	"ai": {"name": "СИСТЕМА БЕЗОПАСНОСТИ", "portrait": "portraits/portrait_security_ai", "blip": "blip_ai", "pitch": 0.9, "color": Color("#FF1E42")},
	"thief": {"name": "ВОР", "portrait": "portraits/portrait_thief", "blip": "blip_t", "pitch": 1.0, "color": Color("#E8FFFF")},
	"boss": {"name": "ГЛАВА КОРПОРАЦИИ", "portrait": "portraits/portrait_ceo_boss", "blip": "blip_ai", "pitch": 0.7, "color": Color("#FFB800")},
	"scientist": {"name": "ДОКТОР ВЕЙЛ", "portrait": "portraits/portrait_scientist", "blip": "blip_t", "pitch": 1.4, "color": Color("#7CFFB2")},
}

var panel: NeonPanel
var portrait: TextureRect
var name_label: Label
var text_label: Label
var _queue: Array = []
var _current: Dictionary = {}
var _chars: float = 0.0
var _hold: float = 0.0
var _visible_t: float = 0.0
var _shake: float = 0.0
var _talking: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 190)
	size = Vector2(300, 190)
	panel = NeonPanel.new()
	panel.size = size
	add_child(panel)
	portrait = TextureRect.new()
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.position = Vector2(14, 18)
	portrait.size = Vector2(96, 96)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(portrait)
	name_label = UITheme.label("", 15, UITheme.CYAN, true)
	name_label.position = Vector2(120, 16)
	name_label.size = Vector2(170, 40)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(name_label)
	text_label = UITheme.label("", 16, UITheme.TEXT)
	text_label.position = Vector2(14, 122)
	text_label.size = Vector2(272, 62)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.clip_text = true
	add_child(text_label)
	modulate.a = 0.0


# speaker — ключ из VOICES; повторные одинаковые реплики подряд не ставим в очередь.
func say(speaker: String, text: String, hold: float = 2.6) -> void:
	for q in _queue:
		if q["text"] == text:
			return
	if _current.get("text", "") == text:
		return
	_queue.append({"who": speaker, "text": text, "hold": hold})
	if _queue.size() > 3:
		_queue.pop_front()


func clear() -> void:
	_queue.clear()
	_current = {}
	modulate.a = 0.0


func _process(delta: float) -> void:
	if _current.is_empty():
		if _queue.is_empty():
			_visible_t = maxf(0.0, _visible_t - delta * 3.0)
			modulate.a = _visible_t
			return
		_start(_queue.pop_front())
	_visible_t = minf(1.0, _visible_t + delta * 6.0)
	modulate.a = _visible_t
	var total: int = String(_current["text"]).length()
	if _chars < float(total):
		var before: int = int(_chars)
		_chars += delta * 48.0
		var after: int = mini(int(_chars), total)
		if after != before and after % 2 == 0:
			var v: Dictionary = VOICES[_current["who"]]
			ProceduralSFX.play(String(v["blip"]), -8.0, float(v["pitch"]) + 0.06 * float((after * 7) % 5))
		text_label.text = String(_current["text"]).substr(0, after)
		_talking = true
	else:
		_talking = false
		_hold -= delta
		if _hold <= 0.0:
			if _queue.is_empty():
				_current = {}
			else:
				_start(_queue.pop_front())
	# мелкая тряска портрета ИИ и «дыхание» говорящих
	_shake += delta * 30.0
	var jitter: Vector2 = Vector2.ZERO
	if _current.get("who", "") == "ai":
		jitter = Vector2(sin(_shake * 3.1), cos(_shake * 2.3)) * (1.8 if _talking else 0.6)
	elif _talking:
		jitter = Vector2(0, sin(_shake) * 1.2)
	portrait.position = Vector2(14, 18) + jitter


func _start(d: Dictionary) -> void:
	_current = d
	_chars = 0.0
	_hold = float(d["hold"])
	var v: Dictionary = VOICES[d["who"]]
	portrait.texture = UITheme.tex(String(v["portrait"]))
	name_label.text = String(v["name"])
	name_label.add_theme_color_override("font_color", v["color"])
	panel.accent = v["color"]
	panel.flash = 1.0
	text_label.text = ""
