# Echoes of the Void — «Теневой вор: Побег по пикселям»

Пошаговый тактический киберпанк стелс-экшен на **Godot 4.3+** (7 миссий кампании, 4 гаджета, 4 типа противников, камеры, турели, лазеры, система стиля, 10 достижений и процедурный звук).

Подробное описание геймплея и управления — в [`GAME.md`](GAME.md).  
Документация по тестам — в [`tests/README.md`](tests/README.md).  
Проектная документация (спецификация требований, ЛР26/ЛР28, задачи) — в папке [`Documentation/`](Documentation/).

---

## 🚀 Быстрый запуск

Требуется **Godot 4.3+** (проверено на 4.3 и 4.6.2):

```bash
git clone https://github.com/mohangg812/echoes-of-the-void.git
cd echoes-of-the-void
godot --path .
```

Либо откройте папку проекта в редакторе Godot и нажмите **F5**.

---

## 📦 Сборка для Windows Desktop

В репозитории настроен пресет экспорта [`export_presets.cfg`](export_presets.cfg) (`Windows Desktop`, встроенный `.pck`, включён фильтр `*.json` для уровней кампании).

Локальная сборка через CLI:

```bash
mkdir -p export
godot --headless --path . --export-release "Windows Desktop" export/EchoesOfTheVoid.exe
```

> **Примечание:** папка `export/` добавлена в `.gitignore` и не попадает в Git.  
> Готовый артефакт `EchoesOfTheVoid-Windows-x64` также собирается автоматически через GitHub Actions (`.github/workflows/build-windows.yml`).

---

## 🧪 Автотесты и CI/CD

Запуск локально в headless-режиме:

```bash
godot --headless --path . --script res://tests/unit_tests.gd
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/replay.gd
```

Настроенные GitHub Actions workflow:
* **`.github/workflows/ci.yml`** — валидация JSON всех 7 уровней кампании + прогон `unit_tests.gd` и `smoke.gd` на каждый push / Pull Request в `main` и `develop`.
* **`.github/workflows/build-windows.yml`** — автоматический экспорт `export/EchoesOfTheVoid.exe` и публикация артефакта сборки.

---

## 📁 Структура проекта

* `core/` — `GridManager`, `TurnManager` (6-фазный конвейер симуляции), `AlarmManager`, `TacticalHistory`
* `systems/vision/` — `VisionCone2D` (Брезенхэм), `AcousticSystem`
* `entities/` — игрок, патрульные/элита/киберпёс/дрон, камеры, турели, лазеры, двери, рубильники, лут
* `levels/` — `LevelLoader`, `MainGame`, слои отрисовки и `levels/campaign/` (**7 уровней** от `level_01_training.json` до `level_07_ai_core.json`)
* `assets/` — игровые PNG-спрайты (плоские каталоги `player/`, `enemies/`, `security/`, `tiles/`, `interactables/`, `gadgets/`, `ui/`, `portraits/`, `overlays/`, очищенные от хромакея через `tools/prep_assets.py`); исходники HD и 48×48 — в `assets/sprites/` и `assets/sprites_48px/`
* `ui/`, `vfx/`, `autoload/` — интерфейс, шейдеры, шина событий, процедурный звук
* `tests/` — headless юнит-тесты, smoke, replay, solver
* `tools/` — генерация уровней и подготовка ассетов
* `Documentation/` — спецификация требований, отчёты и задачи

---

## 👥 Команда проекта

| Роль | Участник | GitHub |
| :--- | :--- | :--- |
| CEO / Team Lead | Арсений Кеда | [`@arsenigiff-hub`](https://github.com/arsenigiff-hub) |
| UI/UX Designer | Ангелина Ковчур | [`@angelinakovcur`](https://github.com/angelinakovcur) |
| Game Developer | Илья Гутман | [`@XXxilusha`](https://github.com/XXxilusha) |
| Developer / QA | Алексей Шишкану | [`@AlekseyShyshkanu123`](https://github.com/AlekseyShyshkanu123) |
| Developer / DevOps | Михаил Бондарчук | [`@mohangg812`](https://github.com/mohangg812) |

---

## 🔀 Правила работы с Git

1. **`main`** — стабильная релизная ветка. Прямые коммиты в `main` не используются.
2. **`develop`** — основная интеграционная ветка разработки.
3. Новая задача выполняется в отдельной ветке от `develop` (`feat/...`, `fix/...`, `docs/...`, `devops/...`).
4. Слияние в `develop` / `main` — только через **Pull Request** с код-ревью и прохождением CI.
5. Формат коммитов: `область: краткое действие` (например: `build: добавлен export_presets.cfg`, `ci: настроены GitHub Actions`, `fix: валидация JSON уровней`).
