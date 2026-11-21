"""Generate the game's missing 16x16 sprites from text grids, in the Zombie/LazyStone palette.

usage: python gen_sprites.py <out_dir>
Writes one PNG per sprite plus preview_sheet.png (6x scale, labelled).
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

# Palette sampled from Zombie Apocalypse + LazyStone sheets, plus muted material accents.
PAL = {
    "o": "#2c1d35", "k": "#241e1e",                                  # outline, near-black
    "d": "#443830", "b": "#7d6754", "B": "#c3a996",                  # browns
    "g": "#5e5d6b", "G": "#787685", "h": "#a3a4a6", "H": "#c4c3bc",  # greys
    "r": "#873018", "R": "#ad644b",                                  # rust
    "p": "#3e6478", "P": "#6f9db0", "l": "#a9cfd6",                  # plastic
    "q": "#b38b3a",                                                  # murky liquid
    "e": "#4d6b48", "E": "#86a37a", "F": "#c2d6b0",                  # glass
    "y": "#c9a83c", "Y": "#e6cf6a",                                  # banana
    "c": "#9a5a2e", "C": "#d8925a",                                  # copper
    "v": "#2f5a3c", "V": "#4f8a5a",                                  # pcb / organic green
    "a": "#d8b040", "A": "#b03a2e",                                  # hazard yellow / red
    "s": "#7fd68a", "S": "#c8f5cc",                                  # FRU-01 screen glow
    "m": "#6e4c4d", "W": "#d9d2c3",                                  # grease, label plate
}

SPRITES = {}


def sprite(name, rows):
    width = len(rows[0])
    for i, row in enumerate(rows):
        assert len(row) == width, f"{name}: row {i} is {len(row)} wide, expected {width}"
        assert set(row) <= set(PAL) | {"."}, f"{name}: unknown colour in row {i}: {set(row) - set(PAL) - {'.'}}"
    SPRITES[name] = rows


E16 = "." * 16

# ---------- items (inventory + world pickups) ----------
bottle_top = ["......oooo......", "......oppo......", "......oooo......", ".....oPllPo.....",
              "....oPlPPPPo....", "....oPlPPPPo....", "....oPlPPPPo....", "....ohhhhhho....",
              "....ohhhhhho...."]
sprite("bottle_clean", bottle_top + ["....oPlPPPPo....", "....oPlPPPPo....", "....oPlPPPPo....",
                                     "....oPPPPPPo....", "....opPPPPpo....", ".....oooooo.....", E16])
sprite("bottle_full", bottle_top + ["....oqlqqqqo....", "....oqlqqqqo....", "....oqqqqqqo....",
                                    "....oqqqqqqo....", "....opqqqqpo....", ".....oooooo.....", E16])

jar_top = [E16, E16, "....oooooooo....", "....oggGGGGo....", "....oooooooo....", "...oEFFEEEEEo...",
           "...oEFEEEEEEo...", "...oEFEEEEEEo...", "...oEFEEEEEEo..."]
sprite("jar_clean", jar_top + ["...oEFEEEEEEo...", "...oEEEEEEEEo...", "...oEEEEEEEEo...",
                               "...oeEEEEEEeo...", "....oooooooo....", E16, E16])
sprite("jar_dirty", jar_top + ["...oEFEbbEEEo...", "...oEbbdbbEEo...", "...oEbddbbbEo...",
                               "...oebbbbbbeo...", "....oooooooo....", E16, E16])

sprite("can_alu", [E16, E16, ".....oooooo.....", "....ohHHHHho....", "....oooooooo....",
                   "....ohHhGGGo....", "....ohHAAAGo....", "....ohHAAAGo....", "....ohHAAAGo....",
                   "....ohHhGGGo....", "....ohHhGGGo....", "....ohHhGGgo....", "....oooooooo....",
                   E16, E16, E16])

sprite("cardboard", [E16, E16, E16, E16, "..oooooooooooo..", "..oBBBBBdBBBBo..", "..oBBBBBdBBBBo..",
                     "..oooooooooooo..", "..obbbbbbbbbbo..", "..obbbbbbbbbbo..", "..obbbbBBbbbbo..",
                     "..obbbbBBbbbbo..", "..obbbbbbbbbbo..", "..oooooooooooo..", E16, E16])

sprite("pizza_box", [E16, E16, E16, E16, E16, ".oooooooooooooo.", ".oBBBBBBBBBBBBo.",
                     ".oBBmmBBBBBBBBo.", ".oBmmmBBBBAABBo.", ".oBBmBBBBBAABBo.", ".oBBBBBBBmmBBBo.",
                     ".oBBBBBBmmmBBBo.", ".oooooooooooooo.", ".obbbbbbbbbbbbo.", ".oooooooooooooo.", E16])

sprite("peel", [E16, E16, E16, "......oo........", ".....odo........", ".....oYo........",
                "....oYYyo.......", "...oYYyyyo......", "..oYyyoyyyo.....", ".oYyyo.oyyyo....",
                ".oyyo...oyyyo...", ".oyo.....oydyo..", "..o.......oddo..", "...........oo...", E16, E16])

sprite("cable", [E16, E16, E16, ".....oooooo.....", "...ookkkkkkoo...", "..okkgooooggko..",
                 ".okgo......okko.", ".okg.ooooo.ogko.", ".okg.okkko.ogko.", ".okko.....okgo..",
                 "..okkoooooogko..", "...ookkkkkkoo...", ".....ooooooCCo..", "............oC..", E16, E16])

sprite("sheath", [E16, E16, E16, E16, E16, E16, "..oooo..........", ".oPPPPoo........",
                  ".opPPPPPoo......", "..oopPPPPPoo....", "....oopPPPPPoo..", "......oopPPPPo..",
                  "........oooooo..", E16, E16, E16])

sprite("copper_wire", [E16, E16, E16, E16, "....oooooooo....", "...oCCCCCCCCo...", "..oCcooooooCCo..",
                       "..oCo......oCo..", "..oCo.oooo.oCo..", "..oCo.oCCo.oCo..", "..oCco.oo.oCco..",
                       "...oCCooooCCo...", "....oooooooo....", E16, E16, E16])

sprite("phone", [E16, "....oooooooo....", "....okkkkkko....", "....ogggggHo....", "....oggggHgo....",
                 "....ogggHggo....", "....oggHgggo....", "....ogHHgggo....", "....oHggHggo....",
                 "....ogggHHgo....", "....oggggggo....", "....oggggggo....", "....okkkkkko....",
                 "....okkhhkko....", "....oooooooo....", E16])

sprite("battery_phone", [E16, E16, E16, "......oaao......", "...oooooooooo...", "...oggggggggo...",
                         "...oghhhhhhgo...", "...ohAAAAAAho...", "...ohhhhhhhho...", "...ohhHHHHhho...",
                         "...ohhhhhhhho...", "...oggggggggo...", "...oooooooooo...", E16, E16, E16])

sprite("battery_loose", [E16, E16, E16, ".......oo.......", "......oaao......", "....oooooooo....",
                         "...ohhhhhhhho...", "..ohhAAAAAAhho..", "..ohhhhhhhhhho..", ".ohhhhaahhhhhho.",
                         ".ohhhhaahhhhhho.", "..ohhhhhhhhhho..", "..ohhhhhhhhhgo..", "...oggggggggo...",
                         "....oooooooo....", E16])

sprite("circuit_board", [E16, E16, E16, "..oooooooooooo..", "..oVVVVVVVVVVo..", "..oVkkkVVaVVVo..",
                         "..oVkkkVaVVaVo..", "..oVkkkaVVaVVo..", "..oVVaVVVaVVVo..", "..oVaVVkkVVVVo..",
                         "..oVVVVkkVaaVo..", "..oVvvvvvvvvVo..", "..oVaVaVaVaVVo..", "..oooooooooooo..",
                         E16, E16])

sprite("steel_scrap", [E16, E16, E16, E16, "......oooo......", "....ooGGhho.....", "..ooGGGhhHho....",
                       ".oGGGgGhhHho....", ".ogGGGgGhho.....", "..ogGGGgGGoo....", "..oRggGGgGGGo...",
                       "...orRgGGgGGo...", "....oorrggGoo...", "......ooooo.....", E16, E16])

# ---------- FRU-01 companion drone (12x12, 2-frame hover bob) ----------
fru_a = [".....oo.....", ".....oa.....", "....oooo....", "...ohHHho...", "..ohHHHHho..",
         ".ohHokkoHho.", ".ohHoksoHho.", ".oghokkoGgo.", "..ogGGGGgo..", "...oooooo...",
         "....s..s....", "............"]
sprite("fru01_a", fru_a)
sprite("fru01_b", fru_a[1:] + ["....S..S...."])  # one pixel higher, thruster flare

# ---------- sorting bins (16x20): same body, material colours + icon ----------
ICONS = {
    "metal":   [".gggg.", "gHhhhg", "gHhhhg", "gHhhhg", "gHhhhg", ".gggg."],
    "plastic": ["..oo..", ".oPPo.", "oPlPPo", "oPlPPo", "oPPPPo", ".oooo."],
    "paper":   ["oooooo", "oBBBBo", "odddBo", "oBBBBo", "odddBo", "oooooo"],
    "glass":   [".oooo.", "oEFEEo", "oEFEEo", "oEEEEo", "oeEEeo", ".oooo."],
    "organic": ["....oo", "..oVVo", ".oVVVo", "oVVvVo", "oVvVo.", "ov...."],
    "hazard":  ["..oo..", ".oako.", ".oako.", "oaaaao", "oaakao", "oooooo"],
}
BIN_COLOURS = {  # lid, lid shade, body, body shade
    "metal": "hGGg", "plastic": "PpPp", "paper": "Bbbd", "glass": "EeEe", "organic": "Vvbd", "hazard": "Arab",
}
for mat, (lid, lid_s, body, body_s) in BIN_COLOURS.items():
    rows = [E16, ".oooooooooooooo.", ".o" + lid * 12 + "o.", ".o" + lid_s * 12 + "o.", ".oooooooooooooo.",
            "..o" + body * 10 + "o.."]
    plate = ["..o" + body + "W" * 8 + body + "o.." for _ in range(9)]
    for i, icon_row in enumerate(ICONS[mat]):
        r = list(plate[i + 1])
        for j, ch in enumerate(icon_row):
            if ch != ".":
                r[5 + j] = ch
        plate[i + 1] = "".join(r)
    rows += plate + ["..o" + body * 10 + "o..", "..o" + body_s + body * 8 + body_s + "o..",
                     "..oooooooooooo..", "...oo......oo...", E16]
    sprite(f"bin_{mat}", rows)

# ---------- Recovery Bench (32x15) ----------
sprite("recovery_bench", [
    "......oooo......................", "......oGGo.........oo...oo......", "....ooGGGGoo.......oho.oho......",
    "....ogGGGGgo........ohhho.......", "oooooooooooooooooooooooooooooooo", "o" + "B" * 30 + "o",
    "o" + "b" * 30 + "o", "o" * 32, ".obo" + "." * 24 + "obo.", ".obo..oooooooooooooooooooo..obo.",
    ".obo..oddddddddddddddddddo..obo.", ".obo..oooooooooooooooooooo..obo.", ".obo" + "." * 24 + "obo.",
    ".obo" + "." * 24 + "obo.", ".ooo" + "." * 24 + "ooo."])

# ---------- Relay tower (16x32): broken (light off, rusted) and repaired (light on, glow) ----------
def relay(light, glow, rust):
    mast = [".....ohGGho.....", ".....oGhhGo....."] * 6 + [".....ohGGho....."]
    if rust:
        mast[4], mast[5], mast[9] = ".....oRrGho.....", ".....oGrRGo.....", ".....orRRro....."
    return ([f".......{glow}{glow}.......", f"......o{light}{light}o......", ".......oo.......",
             ".......oo.......", ".ooo...oo.......", "ohhho..oo.......", "ohHhoooooo......",
             "ohhho..oo.......", ".ooo...oo......."] + mast +
            ["....ohGGGGho....", "....oGhhhhGo....", "...ohGGGGGGho...", "...oGhhhhhhGo...",
             "..ohGGGGGGGGho..", "..oooooooooooo..", "..obbbbbbbbbbo..", "..obBBBBBBBBbo..",
             "..obbbbbbbbbbo..", "..oooooooooooo.."])


sprite("relay_broken", relay("g", ".", rust=True))
sprite("relay_fixed", relay("a", "s", rust=False))

# ---------- HUD signal meter (16x8): level 0 = no network, 1-4 bars ----------
for level in range(5):
    grid = [["."] * 16 for _ in range(8)]
    for bar in range(4):
        height, x = 2 * (bar + 1), 1 + bar * 4
        for y in range(8 - height, 8):
            for dx in range(3):
                grid[y][x + dx] = "s" if bar < level else "g"
    if level == 0:  # red X over empty bars
        for i in range(5):
            grid[1 + i][10 + i] = "A"
            grid[5 - i][10 + i] = "A"
    sprite(f"signal_{level}", ["".join(r) for r in grid])

sprite("dust", ["BB", "BB"])


def render(rows):
    img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), Image.new("RGB", (1, 1), PAL[ch]).getpixel((0, 0)) + (255,))
    return img


out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
images = {name: render(rows) for name, rows in SPRITES.items()}
for name, img in images.items():
    img.save(out / f"{name}.png")

# Preview sheet: 6x scale, 6 per row, dark background like the dump tint.
SCALE, CELL, COLS = 6, 34 * 6, 6
names = list(images)
sheet_rows = -(-len(names) // COLS)
sheet = Image.new("RGBA", (COLS * CELL, sheet_rows * (CELL + 16)), "#3a332c")
draw = ImageDraw.Draw(sheet)
for i, name in enumerate(names):
    img = images[name].resize((images[name].width * SCALE, images[name].height * SCALE), Image.NEAREST)
    cx, cy = (i % COLS) * CELL, (i // COLS) * (CELL + 16)
    sheet.alpha_composite(img, (cx + (CELL - img.width) // 2, cy + (CELL - img.height) // 2))
    draw.text((cx + 6, cy + CELL), name, fill="#e8e4dc")
sheet.save(out / "preview_sheet.png")
print(f"{len(images)} sprites -> {out}")
