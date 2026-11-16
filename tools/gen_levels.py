"""Генератор уровней 2-5 (инструмент разработчика). Уровень 1 написан руками.
Результат — JSON в levels/campaign/. Запуск:  python -I tools/gen_levels.py
Сетка строится прямоугольниками, чтобы не ошибаться в длине строк."""
import json, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "levels", "campaign")


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["#"] * w for _ in range(h)]

    def rect(self, x1, y1, x2, y2, ch="."):
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                self.g[y][x] = ch

    def put(self, x, y, ch):
        self.g[y][x] = ch

    def lines(self):
        return ["".join(r) for r in self.g]


def save(name, data):
    path = os.path.join(OUT, name)
    with open(path, "w", encoding="utf8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("==", name)
    print("\n".join(data["layout"]))


# ───────────────────────── Уровень 2: Лазерный Метроном (22 x 14) ─────────────────────────
def level2():
    c = Canvas(22, 14)
    c.rect(1, 9, 5, 12)            # старт
    c.put(1, 12, "E")
    c.put(3, 8, ".")
    c.rect(1, 5, 20, 7)            # главный коридор
    c.rect(8, 9, 13, 12)           # южная комната с рубильником
    c.put(10, 8, ".")
    c.rect(1, 1, 5, 3)             # северо-западная комната
    c.put(3, 4, ".")
    c.rect(15, 1, 20, 3)           # хранилище
    c.put(16, 4, ".")
    c.put(19, 4, "=")              # стекло: хранилище видно из коридора
    c.put(20, 4, "=")
    c.put(20, 2, "G")
    c.put(14, 12, "S")
    c.rect(1, 1, 1, 1, "S") if False else None
    # декор
    c.put(8, 12, "H")
    data = {
        "level_id": 2,
        "title": "ОПЕРАЦИЯ 02: ЛАЗЕРНЫЙ МЕТРОНОМ",
        "subtitle": "Лазеры бьют по ритму: читайте цикл и входите в тот такт, когда луч выключен",
        "briefing": [
            "Здесь коридор перерезан лазерными решётками. Красный луч на карте — это то, что сработает В СЛЕДУЮЩЕМ такте.",
            "Цикл 1/1 — вкл, выкл, вкл... Цикл 2/1 — два такта вкл, один выкл. Пережидайте между лучами: свободная клетка между решётками безопасна.",
            "Два рубильника: один гасит лазеры 2/1, второй — камеру у хранилища. Хранилище просматривается через стекло."
        ],
        "par_turns": 100,
        "starting_gadgets": {"smoke": 1, "decoy": 0, "emp": 1, "cloak": 0, "shock": 1},
        "layout": c.lines(),
        "guards": [
            {"type": "standard", "start": [9, 11], "facing": [1, 0], "waypoints": [[9, 11], [13, 11]], "ping_pong": True, "keycard": ""},
            {"type": "standard", "start": [16, 6], "facing": [1, 0], "waypoints": [[16, 6], [20, 6]], "ping_pong": True, "keycard": ""},
        ],
        "cameras": [
            {"pos": [17, 4], "initial_facing": [0, 1], "rotation_mode": "cw_90", "period": 1, "group_id": "cam"},
        ],
        "lasers": [
            {"pos": [5, 4], "dir": [0, 1], "on_turns": 1, "off_turns": 1, "phase": 0, "group_id": ""},
            {"pos": [8, 4], "dir": [0, 1], "on_turns": 1, "off_turns": 1, "phase": 1, "group_id": ""},
            {"pos": [12, 4], "dir": [0, 1], "on_turns": 2, "off_turns": 1, "phase": 0, "group_id": "ga"},
            {"pos": [14, 4], "dir": [0, 1], "on_turns": 2, "off_turns": 1, "phase": 1, "group_id": "ga"},
        ],
        "switches": [
            {"pos": [13, 9], "target_group_id": "ga", "description": "Лазеры 2/1 обесточены", "kind": "switch"},
            {"pos": [1, 1], "target_group_id": "cam", "description": "Камера хранилища отключена", "kind": "terminal"},
        ],
        "doors": [],
        "secondary_loot": [
            {"pos": [5, 1], "value": 500, "name": "Крипто-чип Альфа"},
            {"pos": [8, 12], "value": 500, "name": "Крипто-чип Бета"},
            {"pos": [15, 1], "value": 500, "name": "Крипто-чип Гамма"},
        ],
    }
    save("level_02_laser_hall.json", data)


# ───────────────────────── Уровень 3: Тень в Вентиляции (24 x 14) ─────────────────────────
def level3():
    c = Canvas(24, 14)
    c.rect(1, 9, 5, 12)             # старт
    c.put(1, 12, "E")
    c.rect(7, 2, 14, 11)            # главный зал
    c.put(6, 10, ".")
    c.rect(16, 3, 22, 8)            # хранилище
    c.put(15, 6, "D")
    c.put(21, 5, "G")
    # вентиляция: из стартовой комнаты под залом и вверх вдоль восточной стены
    c.put(5, 12, "V")
    c.rect(6, 12, 15, 12, "V")
    c.rect(15, 7, 15, 11, "V")
    c.put(14, 9, "C")               # шкаф-засада у конца вентиляции
    c.put(7, 5, "C")
    c.put(7, 8, "C")
    c.put(10, 2, "C")
    c.put(12, 11, "C")
    c.put(4, 9, "S")
    data = {
        "level_id": 3,
        "title": "ОПЕРАЦИЯ 03: ТЕНЬ В ВЕНТИЛЯЦИИ",
        "subtitle": "Желтая ключ-карта у патрульного. У двери — часовой. Выманите его шумом",
        "briefing": [
            "Дверь хранилища открывается жёлтой картой. Её носит патрульный, который кружит по залу.",
            "У двери стоит часовой и вращается на месте. Его не обойти — выманите его Шумовой гранатой (клавиша 2, затем куда бросить).",
            "Вентиляция (V) скрывает полностью, но каждый шаг в шахте стоит 2 хода. Шкафы (C) тоже прячут — если вы вошли в них незамеченным."
        ],
        "par_turns": 100,
        "starting_gadgets": {"smoke": 1, "decoy": 2, "emp": 0, "cloak": 1, "shock": 1},
        "layout": c.lines(),
        "guards": [
            {"type": "standard", "start": [8, 3], "facing": [1, 0], "waypoints": [[8, 3], [13, 3], [13, 10], [8, 10]], "ping_pong": False, "keycard": "YELLOW"},
            {"type": "standard", "start": [14, 6], "facing": [-1, 0], "waypoints": [[14, 6]], "ping_pong": False, "keycard": "", "scan": True},
        ],
        "cameras": [],
        "lasers": [],
        "switches": [],
        "doors": [
            {"pos": [15, 6], "required_keycard": "YELLOW"},
        ],
        "secondary_loot": [
            {"pos": [2, 9], "value": 500, "name": "Крипто-чип Альфа"},
            {"pos": [7, 2], "value": 500, "name": "Крипто-чип Бета"},
            {"pos": [22, 3], "value": 500, "name": "Крипто-чип Гамма"},
        ],
    }
    save("level_03_vent_network.json", data)


# ───────────────────────── Уровень 4: Казармы Элиты (24 x 16) ─────────────────────────
def level4():
    c = Canvas(24, 16)
    c.rect(1, 7, 22, 8)             # горизонтальный коридор
    c.rect(11, 1, 12, 14)           # вертикальный коридор
    c.rect(1, 1, 9, 5)              # СЗ комната
    c.put(5, 6, ".")
    c.rect(14, 1, 22, 5)            # хранилище (СВ)
    c.put(18, 6, "D")
    c.rect(1, 10, 9, 14)            # ЮЗ комната (старт)
    c.put(5, 9, ".")
    c.rect(14, 10, 22, 14)          # ЮВ казарма
    c.put(18, 9, ".")
    c.put(10, 3, ".")
    c.put(10, 12, ".")
    c.put(13, 12, ".")
    c.put(1, 14, "E")
    c.put(21, 2, "G")
    for x in (3, 4):                # серверные стойки
        c.put(x, 1, "S")
    c.put(16, 14, "S")
    c.put(6, 11, "H")
    data = {
        "level_id": 4,
        "title": "ОПЕРАЦИЯ 04: КАЗАРМЫ ЭЛИТЫ",
        "subtitle": "Элита слышит каждый шаг рядом. Дымовая завеса и ЭМИ — ваши лучшие друзья",
        "briefing": [
            "Элитные гвардейцы слышат всё в окне 3x3 вокруг себя, видят на 6 клеток и в тревоге делают по 2 шага. Шокер на них не действует.",
            "Синяя карта от хранилища — у элитного стража в юго-восточной казарме. ЭМИ-импульс (клавиша 3) оглушает его на 4 хода: за это время ключ-карту можно спокойно снять.",
            "Дымовая шашка (клавиша 1) гасит конусы зрения и лазерные лучи. Кидайте её через перекрёсток."
        ],
        "par_turns": 150,
        "starting_gadgets": {"smoke": 2, "decoy": 1, "emp": 1, "cloak": 0, "shock": 1},
        "layout": c.lines(),
        "guards": [
            {"type": "elite", "start": [11, 3], "facing": [0, 1], "waypoints": [[11, 3], [11, 12]], "ping_pong": True, "keycard": ""},
            {"type": "elite", "start": [16, 12], "facing": [1, 0], "waypoints": [[16, 12], [21, 12]], "ping_pong": True, "keycard": "BLUE"},
            {"type": "standard", "start": [3, 7], "facing": [1, 0], "waypoints": [[3, 7], [8, 7]], "ping_pong": True, "keycard": ""},
        ],
        "cameras": [
            {"pos": [11, 0], "initial_facing": [0, 1], "rotation_mode": "cw_90", "period": 2, "group_id": ""},
        ],
        "lasers": [
            {"pos": [16, 6], "dir": [0, 1], "on_turns": 1, "off_turns": 1, "phase": 0, "group_id": ""},
            {"pos": [20, 6], "dir": [0, 1], "on_turns": 2, "off_turns": 1, "phase": 1, "group_id": ""},
        ],
        "switches": [],
        "doors": [
            {"pos": [18, 6], "required_keycard": "BLUE"},
        ],
        "secondary_loot": [
            {"pos": [1, 1], "value": 500, "name": "Крипто-чип Альфа"},
            {"pos": [22, 14], "value": 500, "name": "Крипто-чип Бета"},
            {"pos": [14, 1], "value": 500, "name": "Крипто-чип Гамма"},
        ],
    }
    save("level_04_elite_sector.json", data)


# ───────────────────────── Уровень 5: Сердце Хранилища (28 x 18) ─────────────────────────
def level5():
    c = Canvas(28, 18)
    c.rect(1, 1, 26, 16)            # внешнее кольцо (всё свободно)
    c.rect(4, 4, 23, 13, "#")       # внутренний блок
    c.rect(5, 5, 22, 12)            # среднее кольцо
    c.rect(8, 7, 19, 10, "#")       # ядро
    c.rect(10, 8, 17, 9)            # внутренний зал хранилища
    c.put(13, 4, "D")               # внешнее -> среднее (красная)
    c.put(14, 4, "D")
    c.put(13, 7, "D")               # среднее -> ядро (синяя)
    c.put(14, 7, "D")
    c.put(1, 16, "E")
    c.put(17, 9, "G")
    c.put(2, 14, "H")
    c.put(25, 3, "S")
    c.put(25, 4, "S")
    # шкафы в коридорах
    c.put(2, 8, "C")
    c.put(25, 9, "C")
    c.put(6, 5, "C")
    c.put(21, 12, "C")
    data = {
        "level_id": 5,
        "title": "ОПЕРАЦИЯ 05: СЕРДЦЕ ХРАНИЛИЩА",
        "subtitle": "Три кольца обороны. Взяв Ядро, вы разбудите всё остальное",
        "briefing": [
            "Финал. Внешнее кольцо — красная карта у патрульного. Среднее кольцо — синяя карта у Элиты. Внутри — Ядро.",
            "Протокол усиления безопасности: как только вы возьмёте Ядро, в зале включатся резервные лазеры и турели, камеры станут зорче, а в среднем кольце проснётся резервный Элитный гвардеец.",
            "Турель берёт цель в захват на один ход — у вас всегда есть такт, чтобы сойти с линии огня. Откат хода — Backspace. Удачи."
        ],
        "par_turns": 170,
        "starting_gadgets": {"smoke": 2, "decoy": 2, "emp": 2, "cloak": 1, "shock": 2},
        "layout": c.lines(),
        "guards": [
            {"type": "standard", "start": [2, 2], "facing": [1, 0], "waypoints": [[2, 2], [25, 2], [25, 15], [2, 15]], "ping_pong": False, "keycard": "RED"},
            {"type": "elite", "start": [6, 6], "facing": [1, 0], "waypoints": [[6, 6], [21, 6], [21, 11], [6, 11]], "ping_pong": False, "keycard": "BLUE"},
            {"type": "elite", "start": [9, 11], "facing": [1, 0], "waypoints": [[9, 11], [18, 11]], "ping_pong": True, "keycard": "", "dormant": True},
        ],
        "cameras": [
            {"pos": [4, 2], "initial_facing": [0, 1], "rotation_mode": "cw_90", "period": 2, "group_id": ""},
            {"pos": [23, 14], "initial_facing": [-1, 0], "rotation_mode": "ccw_90", "period": 2, "group_id": ""},
        ],
        "lasers": [
            {"pos": [9, 8], "dir": [1, 0], "on_turns": 1, "off_turns": 1, "phase": 0, "group_id": "", "activate_on_loot": True},
            {"pos": [16, 4], "dir": [0, 1], "on_turns": 2, "off_turns": 1, "phase": 0, "group_id": "", "activate_on_loot": True},
            {"pos": [11, 4], "dir": [0, 1], "on_turns": 1, "off_turns": 1, "phase": 1, "group_id": ""},
        ],
        "turrets": [
            {"pos": [10, 8], "facing": [1, 0], "climax": True},
            {"pos": [17, 8], "facing": [-1, 0]},
        ],
        "switches": [],
        "doors": [
            {"pos": [13, 4], "required_keycard": "RED"},
            {"pos": [14, 4], "required_keycard": "RED"},
            {"pos": [13, 7], "required_keycard": "BLUE"},
            {"pos": [14, 7], "required_keycard": "BLUE"},
        ],
        "secondary_loot": [
            {"pos": [26, 1], "value": 500, "name": "Крипто-чип Альфа"},
            {"pos": [5, 12], "value": 500, "name": "Крипто-чип Бета"},
            {"pos": [26, 16], "value": 500, "name": "Крипто-чип Гамма"},
        ],
    }
    save("level_05_central_vault.json", data)


# ───────────────────────── Уровень 6: Кибер-зверинец (26 x 16) ─────────────────────────
def level6():
    c = Canvas(26, 16)
    c.rect(1, 12, 5, 14)            # старт
    c.put(1, 14, "E")
    c.put(6, 13, ".")
    c.rect(7, 2, 18, 13)            # вольер
    c.rect(10, 5, 11, 6, "#")       # колонны-перегородки
    c.rect(14, 9, 15, 10, "#")
    c.rect(8, 8, 8, 8, "#")
    c.rect(20, 2, 24, 6)            # хранилище
    c.put(19, 4, "D")
    c.put(23, 3, "G")
    c.put(7, 14, "S")
    c.put(18, 14, "S")
    c.put(2, 12, "H")
    data = {
        "level_id": 6,
        "title": "ОПЕРАЦИЯ 06: КИБЕР-ЗВЕРИНЕЦ",
        "subtitle": "Гончие бегают вдвое быстрее и слышат шаги. Дроны видят дальше. Шокер им не друг",
        "briefing": [
            "Корпорация выпустила в вольер киберпсов и разведывательных дронов. Гончая делает ДВА шага за ход и слышит любой шум рядом.",
            "Жёлтая карта висит на гончей, что бегает по нижней дорожке. Шокер на дронов не действует, а ЭМИ вырубает всех: и гончих, и дронов.",
            "Дымовая шашка и манок помогут развести зверей по разным углам. Считайте такты: у гончей конус короче, но она быстрее вас."
        ],
        "intro": [["handler", "Это вольер. Здесь пахнет маслом и страхом. Не твоим."], ["ai", "ПСЫ ГОЛОДНЫ. ДРОНЫ ЗОРКИ."]],
        "lines": {"alarm": [["ai", "ГОНЧИЕ, ФАС."], ["ai", "СЛЫШУ ТВОЁ СЕРДЦЕ."]], "gold": [["handler", "Ядро твоё! Выходи тем же путём, звери проснулись."]]},
        "par_turns": 150,
        "starting_gadgets": {"smoke": 2, "decoy": 2, "emp": 2, "cloak": 1, "shock": 2},
        "layout": c.lines(),
        "guards": [
            {"type": "hound", "start": [8, 3], "facing": [1, 0], "waypoints": [[8, 3], [17, 3]], "ping_pong": True, "keycard": ""},
            {"type": "hound", "start": [9, 12], "facing": [1, 0], "waypoints": [[9, 12], [17, 12]], "ping_pong": True, "keycard": "YELLOW"},
            {"type": "drone", "start": [12, 8], "facing": [0, 1], "waypoints": [[12, 4], [12, 12]], "ping_pong": True, "keycard": ""},
            {"type": "drone", "start": [17, 7], "facing": [0, -1], "waypoints": [[17, 4], [17, 11]], "ping_pong": True, "keycard": ""},
        ],
        "cameras": [
            {"pos": [12, 1], "initial_facing": [0, 1], "rotation_mode": "cw_90", "period": 2, "group_id": ""},
        ],
        "lasers": [],
        "switches": [],
        "doors": [{"pos": [19, 4], "required_keycard": "YELLOW"}],
        "secondary_loot": [
            {"pos": [8, 2], "value": 500, "name": "Крипто-чип Альфа"},
            {"pos": [18, 13], "value": 500, "name": "Крипто-чип Бета"},
            {"pos": [24, 6], "value": 500, "name": "Крипто-чип Гамма"},
        ],
    }
    save("level_06_cyber_kennel.json", data)


# ───────────────────────── Уровень 7: Ядро ИИ (30 x 18) ─────────────────────────
def level7():
    c = Canvas(30, 18)
    c.rect(1, 2, 8, 15)             # стартовый зал
    c.put(1, 15, "E")
    c.rect(10, 4, 17, 13)           # приёмная
    c.rect(19, 2, 25, 15)           # лаборатория
    c.rect(27, 7, 28, 10)           # ядро
    for y in (8, 9):
        c.put(9, y, "D")
        c.put(18, y, "D")
        c.put(26, y, "D")
    c.put(28, 8, "G")
    c.put(1, 8, "C")
    c.put(6, 14, "C")
    c.put(10, 12, "C")
    c.put(17, 5, "C")
    c.put(20, 14, "C")
    c.put(3, 2, "S")
    c.put(4, 2, "S")
    c.put(2, 14, "H")
    data = {
        "level_id": 7,
        "title": "ОПЕРАЦИЯ 07: ЯДРО ИИ",
        "subtitle": "Финал. Три двери, три ключа, одна машина, которая знает вас по имени",
        "briefing": [
            "Мы у цели. Внутри ЯДРО — сам Искусственный Интеллект, что держит корпорацию. Красная карта у дрона в первом зале, синяя у элиты в приёмной, жёлтая у гончей в лаборатории.",
            "Когда вы коснётесь Ядра, включатся все лазеры и турели, а резервные Элита и Гончая проснутся на пути назад. Заранее продумайте отход: ЭМИ и дым понадобятся именно там.",
            "Откат хода (Backspace) — ваш лучший друг. Он не ругается. Удачи, вор."
        ],
        "intro": [["handler", "Это финал. Я рядом, но помочь могу только словами."], ["ai", "ДОБРО ПОЖАЛОВАТЬ В МОЁ ЯДРО, ВОР."], ["boss", "Ты не первый, кто пытался. Ты — последний."]],
        "lines": {
            "alarm": [["ai", "Я ЧИТАЮ ТВОИ ШАГИ, КАК КНИГУ."], ["ai", "ТЫ — ОШИБКА В МОЁМ КОДЕ."], ["boss", "Взять его живым. Или не живым."]],
            "gold": [["boss", "Ты украл не данные. Ты украл МЕНЯ."]],
            "climax": [["ai", "ПРОТОКОЛ «ПРОБУЖДЕНИЕ». ВСЕ ЦЕЛИ — НА ПОРАЖЕНИЕ."], ["boss", "Беги, маленькая тень. Беги."]],
            "lost": [["boss", "Предсказуемо."]],
        },
        "par_turns": 190,
        "starting_gadgets": {"smoke": 2, "decoy": 2, "emp": 3, "cloak": 1, "shock": 2},
        "layout": c.lines(),
        "guards": [
            {"type": "drone", "start": [2, 4], "facing": [1, 0], "waypoints": [[2, 4], [7, 4], [7, 12], [2, 12]], "ping_pong": False, "keycard": "RED"},
            {"type": "elite", "start": [11, 5], "facing": [1, 0], "waypoints": [[11, 5], [16, 5], [16, 12], [11, 12]], "ping_pong": False, "keycard": "BLUE"},
            {"type": "hound", "start": [20, 3], "facing": [1, 0], "waypoints": [[20, 3], [24, 3], [24, 14], [20, 14]], "ping_pong": False, "keycard": "YELLOW"},
            {"type": "elite", "start": [11, 12], "facing": [1, 0], "waypoints": [[11, 12], [16, 12]], "ping_pong": True, "keycard": "", "dormant": True},
            {"type": "hound", "start": [20, 14], "facing": [1, 0], "waypoints": [[20, 14], [24, 14]], "ping_pong": True, "keycard": "", "dormant": True},
        ],
        "cameras": [
            {"pos": [13, 3], "initial_facing": [0, 1], "rotation_mode": "cw_90", "period": 2, "group_id": ""},
            {"pos": [22, 1], "initial_facing": [0, 1], "rotation_mode": "cw_90", "period": 2, "group_id": ""},
        ],
        "lasers": [
            {"pos": [14, 3], "dir": [0, 1], "on_turns": 1, "off_turns": 1, "phase": 0, "group_id": ""},
            {"pos": [27, 6], "dir": [0, 1], "on_turns": 1, "off_turns": 1, "phase": 0, "group_id": "", "activate_on_loot": True},
            {"pos": [21, 16], "dir": [0, -1], "on_turns": 2, "off_turns": 1, "phase": 0, "group_id": "", "activate_on_loot": True},
        ],
        "turrets": [
            {"pos": [22, 5], "facing": [1, 0], "climax": True},
            {"pos": [23, 12], "facing": [-1, 0]},
        ],
        "switches": [],
        "doors": [
            {"pos": [9, 8], "required_keycard": "RED"}, {"pos": [9, 9], "required_keycard": "RED"},
            {"pos": [18, 8], "required_keycard": "BLUE"}, {"pos": [18, 9], "required_keycard": "BLUE"},
            {"pos": [26, 8], "required_keycard": "YELLOW"}, {"pos": [26, 9], "required_keycard": "YELLOW"},
        ],
        "secondary_loot": [
            {"pos": [1, 2], "value": 500, "name": "Крипто-чип Альфа"},
            {"pos": [10, 4], "value": 500, "name": "Крипто-чип Бета"},
            {"pos": [25, 15], "value": 500, "name": "Крипто-чип Гамма"},
        ],
    }
    save("level_07_ai_core.json", data)


if __name__ == "__main__":
    level2()
    level3()
    level4()
    level5()
    level6()
    level7()
