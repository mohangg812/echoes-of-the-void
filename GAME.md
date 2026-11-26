# Теневой вор: Побег по пикселям (Echoes of the Void)

Пошаговый тактический стелс-экшен на Godot 4 по ТЗ «Shadow Thief: Pixel Escape» (+ 2 бонусные миссии, 7 уровней).
Ассеты — из github.com/mohangg812/echoes-of-the-void (спрайты 48px, очищены от хромакея скриптом `tools/prep_assets.py`).
Звук и музыка синтезируются кодом (`autoload/ProceduralSFX.gd`).

## Запуск
Нужен Godot 4.3+ (проверено на 4.6.2).
```
godot --path . 
```
или откройте папку в редакторе и нажмите F5.

## Что внутри
- 7 миссий: от обучения до финала с «Ядром ИИ»; новые враги — киберпсы (2 шага за ход, острый слух) и дроны (длинный узкий конус).
- Очки за стиль: кража, оглушение, «впритык» складываются в множитель до x5; тревога обрывает цепочку.
- Диалоги с портретами: Куратор помогает, Система Безопасности издевается, Вор огрызается, на финале вмешивается Глава корпорации.
- Радар, задачи, журнал событий, 10 достижений, анимированный экран победы с рейтингом S/A/B/C.
- Эффекты: частицы, шлейфы рывка, ударные волны, замедление времени, зум-удары, глитч-шейдер, цифровой дождь, вступительная «проявка» уровня.

## Управление
WASD/стрелки — шаг · Space/Z — пропуск хода · Shift+шаг — рывок · E — рубильник/терминал · F — шокер со спины ·
1 Дым, 2 Манок (потом цель стрелками/мышью, Space/клик), 3 ЭМИ, 4 Плащ · Backspace — откат хода · R — рестарт · Esc — пауза · M — звук · T — показать/скрыть текущие рамки конусов.

Яркие красные/жёлтые зоны и красные лучи — это то, что сработает В СЛЕДУЮЩЕМ такте. Тонкие рамки — где конусы стоят сейчас.

## Структура
- `core/` — GridManager (сетка + AStarGrid2D), TurnManager (конвейер из 6 фаз и вся симуляция), AlarmManager, TacticalHistory (откат)
- `systems/vision/` — VisionCone2D (Брезенхэм), AcousticSystem (шум)
- `entities/` — игрок, охрана (FSM), камеры, турели, лазеры, двери, рубильники, лут
- `levels/` — LevelLoader, MainGame, слои отрисовки; `levels/campaign/*.json` — 7 уровней
- `assets/` — игровые PNG-спрайты (очищены от хромакея скриптом `tools/prep_assets.py`); исходники и версии 48×48 хранятся в `assets/sprites/` и `assets/sprites_48px/`
- `ui/`, `vfx/`, `autoload/` — меню, HUD, модалки, шейдеры, шина событий, звук
- `tests/` — headless-проверки: `unit_tests.gd` (юнит/интеграционные тесты симуляции), `solver.gd` (поиск прохождения), `replay.gd` (регрессия), `smoke.gd`, `debug.gd`
- `tools/` — подготовка ассетов и генератор уровней
- `export_presets.cfg` — пресет сборки для Windows Desktop (`export/EchoesOfTheVoid.exe`, папка `export/` исключена из Git)

## Сборка для Windows Desktop
```
mkdir -p export
godot --headless --path . --export-release "Windows Desktop" export/EchoesOfTheVoid.exe
```
Также сборка автоматически запускается в GitHub Actions (`.github/workflows/build-windows.yml`).

## Проверка уровней и автотесты
```
godot --headless --path . --script res://tests/unit_tests.gd
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/replay.gd
```
