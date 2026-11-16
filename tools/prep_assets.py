"""Чистит ассеты из github.com/mohangg812/echoes-of-the-void: убирает фон-хромакей
(пурпурный / зелёный / чёрный / белый) и кладёт готовые PNG в res://assets/.
Запуск:  python -I tools/prep_assets.py <путь к клону репозитория>
"""
import sys, os, glob
from collections import deque
from PIL import Image

SRC = sys.argv[1]
DST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")


def is_magenta(p, loose=False):
    r, g, b = p[:3]
    if loose:
        return r > 150 and b > 150 and g < 120 and abs(r - b) < 70
    return r > 200 and b > 200 and g < 70


def is_green(p, loose=False):
    r, g, b = p[:3]
    if loose:
        return g > 150 and r < 110 and b < 110 and g > r + 80 and g > b + 80
    return g > 190 and r < 70 and b < 70


def is_black(p):
    return p[0] + p[1] + p[2] < 26


def is_white(p):
    return p[0] > 244 and p[1] > 244 and p[2] > 244


def key_global(im, fn):
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if fn(px[x, y], False):
                px[x, y] = (0, 0, 0, 0)
    # defringe: соседи прозрачных пикселей с остаточным оттенком ключа
    for _ in range(2):
        kill = []
        for y in range(h):
            for x in range(w):
                if px[x, y][3] == 0 or not fn(px[x, y], True):
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] == 0:
                        kill.append((x, y))
                        break
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)
    return im


def key_flood(im, fn):
    px = im.load()
    w, h = im.size
    seen = set()
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if (x, y) in seen or x < 0 or y < 0 or x >= w or y >= h:
            continue
        seen.add((x, y))
        if not fn(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


MAGENTA = [
    "player/player_idle_topdown", "player/player_dash_topdown", "player/player_damaged",
    "player/player_vent_crawl", "player/player_eliminated",
    "security/security_camera_active", "security/security_camera_disabled",
    "security/sentry_turret_active", "security/sentry_turret_sleep",
    "interactables/loot_crypto_chip", "interactables/interact_power_switch",
    "interactables/item_medkit_stim", "interactables/item_shield_battery",
    "interactables/loot_classified_briefcase", "interactables/loot_isotope_rod",
    "interactables/loot_vip_pass",
]
GREEN = [
    "enemies/guard_standard_patrol", "enemies/guard_standard_keycard", "enemies/guard_standard_stunned",
    "enemies/guard_knocked_out", "enemies/guard_elite_idle", "enemies/guard_elite_overdrive",
    "enemies/guard_elite_walk", "enemies/drone_scout_idle", "enemies/drone_scout_alarm",
    "enemies/guard_cyber_hound", "security/laser_emitter_node",
]
BLACK = [
    "interactables/loot_vault_gold_core", "interactables/item_keycards_set",
    "gadgets/gadget_flashbang", "gadgets/gadget_hologram_decoy", "gadgets/gadget_noise_decoy",
    "gadgets/item_cyber_deck", "gadgets/item_taser_stunner", "gadgets/vfx_emp_pulse",
    "gadgets/vfx_electric_arc", "gadgets/vfx_muzzle_flash", "gadgets/vfx_plasma_bullet",
    "gadgets/vfx_target_reticle", "player/player_cloak_active", "ui/ui_hud_shield_and_siren",
    "ui/ui_ai_status_badges", "gadgets/vfx_explosion_small", "ui/ui_minimap_blips",
]
WHITE = ["gadgets/vfx_smoke_cloud_tile"]
COPY = [
    "tiles/*", "interactables/door_*", "interactables/interact_*", "portraits/*",
    "overlays/*", "ui/ui_cursor_*", "ui/ui_rating_stars", "ui/ui_slot_frame*",
    "ui/ui_dialog_panel", "ui/ui_stealth_meter", "gadgets/vfx_footstep_ripple",
    "ui/ui_prompt_interact_e", "ui/ui_rank_medals", "security/light_radial_glow",
    "security/light_flashlight_cone", "gadgets/vfx_blood_splatter",
]

os.makedirs(DST, exist_ok=True)
base = os.path.join(SRC, "assets", "sprites_48px")


def load(rel):
    return Image.open(os.path.join(base, rel + ".png")).convert("RGBA")


def save(im, rel):
    out = os.path.join(DST, rel + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out)


done = set()
for rel in MAGENTA:
    save(key_global(load(rel), is_magenta), rel); done.add(rel)
for rel in GREEN:
    save(key_global(load(rel), is_green), rel); done.add(rel)
for rel in BLACK:
    save(key_flood(load(rel), is_black), rel); done.add(rel)
for rel in WHITE:
    save(key_flood(load(rel), is_white), rel); done.add(rel)
for pat in COPY:
    for f in glob.glob(os.path.join(base, pat + ("" if "*" in pat else ".png")) if "*" in pat else os.path.join(base, pat + ".png")):
        rel = os.path.relpath(f, base).replace("\\", "/")[:-4]
        if rel in done:
            continue
        save(Image.open(f).convert("RGBA"), rel); done.add(rel)

# светящиеся маски -> белый цвет, альфа = яркость (для аддитивных спрайтов)
for rel in ["security/light_radial_glow", "security/light_flashlight_cone"]:
    im = load(rel)
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            v = max(r, g, b)
            px[x, y] = (255, 255, 255, v)
    save(im, rel)

# ключ-карты: 3 штуки в одном 48x48 листе -> режем по цвету (красная/синяя/жёлтая)
kc = load("interactables/item_keycards_set")
kc = key_flood(kc, is_black)
save(kc, "interactables/item_keycards_set")

# HD-логотип
logo = Image.open(os.path.join(SRC, "assets", "sprites", "ui", "ui_game_logo.png")).convert("RGBA")
logo.thumbnail((768, 384), Image.LANCZOS)
save(logo, "ui/logo")
print("assets:", len(done) + 1)
