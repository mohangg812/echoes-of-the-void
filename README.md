# Echoes of the Void — «Теневой вор: Побег по пикселям» (Shadow Thief: Pixel Escape)

Полный набор 2D пиксель-арт спрайтов для проекта на **Godot 4**.

## 📁 Структура каталогов

* `assets/sprites/` — Исходные спрайты высокого разрешения (`1024×1024 px`).
* `assets/sprites_48px/` — Спрайты, точно смасштабированные под базовую сетку игры (`48×48 px` и `32×32 px` для иконок) с фильтром `Nearest Neighbor`.

### Категории:
* `assets/sprites/player/` — Спрайты игрока (ходьба, рывок, вентиляция, камуфляж, урон).
* `assets/sprites/enemies/` — Боты охраны (патрульный, с ключ-картой, оглушенный, элитный гвардеец, овердрайв).
* `assets/sprites/security/` — Камеры, спящие и боевые турели, излучатели и лучи лазеров.
* `assets/sprites/tiles/` — Тайлы пола, стен, бронированного стекла, вентиляционных люков, шкафов-укрытий, эвакуации и пьедестала хранилища.
* `assets/sprites/interactables/` — Квантовое ядро данных, крипто-чипы, ключ-карты, гермодвери, рубильники.
* `assets/sprites/gadgets/` — Дымовая завеса, шумовой манок, электромагнитный импульс (ЭМИ).
* `assets/sprites/ui/` — Индикаторы состояний ИИ, иконки способностей HUD, индикаторы щита/сирены, рейтинговые медали (S, A, B, C).

---

## ⚙️ Настройка в Godot 4

1. **Фильтрация текстур:**
   * В `Project Settings -> Rendering -> Textures -> Canvas Textures` установите **Default Texture Filter** в значение **`Nearest`**.
2. **Ориентация спрайтов:**
   * Все направленные спрайты (Игрок, Охранники, Камеры, Турели) ориентированы строго вправо (East / $0^\circ$), что соответствует `Vector2.RIGHT` и `look_at()`.

---

## 🤖 Команда для Claude Code

> «Подключи сгенерированные пиксельные спрайты из `res://assets/sprites/` ко всем соответствующим сценам (`Player.tscn`, `StandardGuard.tscn`, `EliteGuard.tscn`, `SecurityCamera.tscn`, `SentryTurret.tscn`, `LaserEmitter.tscn`, `LevelLoader.gd` и `HUD.tscn`), сохранив процедурную подсветку `PointLight2D`, `VisionCone2D` и шейдеры `WorldEnvironment Glow`. Убедись, что у всех `Sprite2D` включен фильтр `TEXTURE_FILTER_NEAREST` и размер масштабируется строго под клетку `48x48`».
