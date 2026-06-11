from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "raw"
OUT = ROOT / "promo"
ICON = ROOT.parent.parent / "RoastMate/Assets.xcassets/AppIcon.appiconset/icon_1024.png"

W, H = 1242, 1656
BG = "#0B0B0D"
PANEL = "#151518"
PANEL_2 = "#1C1C20"
WHITE = "#F7F7F5"
MUTED = "#A2A2A8"
LINE = "#303036"
ORANGE = "#FF6B35"
ORANGE_DARK = "#5A260F"

FONT_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"
HEITI_PATH = "/System/Library/Fonts/STHeiti Medium.ttc"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(FONT_PATH, size=size, index=2 if bold else 0)
    except OSError:
        return ImageFont.truetype(HEITI_PATH, size=size)


def rr(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text(draw, xy, value, size, fill=WHITE, bold=False, spacing=10, anchor=None):
    draw.multiline_text(
        xy,
        value,
        font=font(size, bold),
        fill=fill,
        spacing=spacing,
        anchor=anchor,
    )


def canvas():
    image = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 14, H), fill=ORANGE)
    return image


def brand_tag(draw, label="RoastMate · 帮你骂"):
    fnt = font(27, True)
    bbox = draw.textbbox((0, 0), label, font=fnt)
    width = bbox[2] - bbox[0] + 44
    rr(draw, (64, 54, 64 + width, 108), 27, ORANGE_DARK)
    draw.text((86, 65), label, font=fnt, fill=ORANGE)


def page_mark(draw, current):
    text(draw, (1154, 1602), f"{current:02d}/06", 24, fill=MUTED, bold=True, anchor="mm")


def underline(draw, x, y, width):
    draw.rounded_rectangle((x, y, x + width, y + 12), radius=6, fill=ORANGE)


def rounded(image, radius):
    image = image.convert("RGBA")
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, image.width, image.height), radius=radius, fill=255
    )
    image.putalpha(mask)
    return image


def fit_crop(image, width, height, anchor_y=0.5):
    image = image.convert("RGBA")
    scale = max(width / image.width, height / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)), Image.LANCZOS
    )
    left = max(0, (resized.width - width) // 2)
    top = round(max(0, resized.height - height) * anchor_y)
    return resized.crop((left, top, left + width, top + height))


def shadow(size, box, radius=42, blur=28, offset=(0, 18), opacity=150):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x1, y1, x2, y2 = box
    ox, oy = offset
    draw.rounded_rectangle(
        (x1 + ox, y1 + oy, x2 + ox, y2 + oy),
        radius=radius,
        fill=(0, 0, 0, opacity),
    )
    return layer.filter(ImageFilter.GaussianBlur(blur))


def screenshot_card(base, source_name, source_crop, box, radius=44, anchor_y=0.5):
    x1, y1, x2, y2 = box
    width, height = x2 - x1, y2 - y1
    source = Image.open(RAW / source_name).convert("RGBA").crop(source_crop)
    source = fit_crop(source, width - 20, height - 20, anchor_y=anchor_y)

    base_rgba = base.convert("RGBA")
    base_rgba.alpha_composite(shadow(base_rgba.size, box, radius=radius), (0, 0))

    frame = Image.new("RGBA", (width, height), PANEL_2)
    frame_draw = ImageDraw.Draw(frame)
    rr(frame_draw, (0, 0, width - 1, height - 1), radius, PANEL_2, outline=LINE, width=3)
    frame.alpha_composite(rounded(source, radius - 10), (10, 10))
    base_rgba.alpha_composite(rounded(frame, radius), (x1, y1))
    return base_rgba.convert("RGB")


def icon_badge(base, box, label=None):
    x1, y1, x2, y2 = box
    width, height = x2 - x1, y2 - y1
    icon = Image.open(ICON).convert("RGBA")
    icon.thumbnail((width, height), Image.LANCZOS)
    base_rgba = base.convert("RGBA")
    base_rgba.alpha_composite(shadow(base_rgba.size, box, radius=38, blur=24), (0, 0))
    base_rgba.alpha_composite(rounded(icon, 38), (x1, y1))
    result = base_rgba.convert("RGB")
    if label:
        draw = ImageDraw.Draw(result)
        rr(draw, (x1 - 8, y2 + 18, x2 + 8, y2 + 68), 25, PANEL_2, outline=LINE, width=2)
        text(draw, ((x1 + x2) // 2, y2 + 43), label, 23, bold=True, anchor="mm")
    return result


def subtitle_block(draw, value, y):
    rr(draw, (64, y, 1178, y + 76), 26, PANEL)
    draw.rectangle((64, y, 76, y + 76), fill=ORANGE)
    text(draw, (98, y + 19), value, 31, fill=MUTED, bold=True)


def save(image, filename):
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / filename, format="PNG", optimize=True)


# 01 cover
image = canvas()
draw = ImageDraw.Draw(image)
brand_tag(draw)
image = icon_badge(image, (1040, 50, 1148, 158))
draw = ImageDraw.Draw(image)
text(draw, (64, 154), "室友半夜外放打游戏", 104, bold=True)
text(draw, (64, 276), "我让 3 个 AI 舍友", 112, bold=True)
text(draw, (64, 408), "替我骂回去", 116, fill=ORANGE, bold=True)
underline(draw, 64, 540, 360)
image = screenshot_card(
    image,
    "xhs-04-roommate-chat.png",
    (20, 220, 1300, 1840),
    (146, 574, 1096, 1534),
)
draw = ImageDraw.Draw(image)
rr(draw, (208, 1452, 1034, 1520), 34, ORANGE)
text(
    draw,
    (621, 1486),
    "虚拟舍友群 · 合成角色非真人",
    30,
    fill="#141414",
    bold=True,
    anchor="mm",
)
page_mark(draw, 1)
save(image, "01-cover.png")


# 02 pain
image = canvas()
draw = ImageDraw.Draw(image)
brand_tag(draw, "真实痛点")
text(draw, (64, 150), "气头上脑子一片空白", 94, bold=True)
text(draw, (64, 266), "事后才想起", 104, bold=True)
text(draw, (64, 388), "该怎么回？", 108, fill=ORANGE, bold=True)
subtitle_block(draw, "先骂个爽，再发那条能赢的", 510)
image = screenshot_card(
    image,
    "xhs-01-generator-filled.png",
    (30, 300, 1290, 1840),
    (156, 628, 1086, 1538),
    anchor_y=0,
)
draw = ImageDraw.Draw(image)
page_mark(draw, 2)
save(image, "02-pain.png")


# 03 roommate group
image = canvas()
draw = ImageDraw.Draw(image)
brand_tag(draw, "v1.1 新功能")
text(draw, (64, 158), "虚拟舍友群", 116, fill=ORANGE, bold=True)
text(draw, (64, 304), "护短的、毒舌的、清醒的", 76, bold=True)
text(draw, (64, 400), "3 个 AI 舍友接力替你出气", 62, fill=MUTED, bold=True)
underline(draw, 64, 492, 500)
image = screenshot_card(
    image,
    "xhs-03-roommate-setup.png",
    (24, 220, 1296, 2030),
    (156, 548, 1086, 1538),
    anchor_y=0,
)
draw = ImageDraw.Draw(image)
rr(draw, (864, 496, 1100, 554), 28, ORANGE_DARK)
text(draw, (982, 525), "合成角色 · 非真人", 24, fill=ORANGE, bold=True, anchor="mm")
page_mark(draw, 3)
save(image, "03-roommate.png")


# 04 echoes
image = canvas()
draw = ImageDraw.Draw(image)
brand_tag(draw, "替你出气")
text(draw, (64, 154), "你还没开口", 104, bold=True)
text(draw, (64, 278), "已经有人", 104, bold=True)
text(draw, (64, 402), "帮你骂了", 112, fill=ORANGE, bold=True)
subtitle_block(draw, "先共情、再帮腔，最后劝你别上头", 526)
image = screenshot_card(
    image,
    "xhs-06-echoes-chat.png",
    (24, 210, 1296, 1880),
    (156, 640, 1086, 1538),
    anchor_y=0,
)
draw = ImageDraw.Draw(image)
page_mark(draw, 4)
save(image, "04-echoes.png")


# 05 rewrite
image = canvas()
draw = ImageDraw.Draw(image)
brand_tag(draw, "从发泄回到表达")
text(draw, (64, 148), "骂爽了之后", 104, bold=True)
text(draw, (64, 272), "一键改写成", 104, bold=True)
text(draw, (64, 396), "能发出去的版本", 102, fill=ORANGE, bold=True)
subtitle_block(draw, "锐利、有立场，但不越界", 524)
image = screenshot_card(
    image,
    "xhs-07-bridge-rewrite.png",
    (24, 680, 1296, 1940),
    (156, 638, 1086, 1538),
)
draw = ImageDraw.Draw(image)
rr(draw, (820, 568, 1086, 626), 28, ORANGE_DARK)
text(draw, (953, 597), "骂完 → 改写", 26, fill=ORANGE, bold=True, anchor="mm")
page_mark(draw, 5)
save(image, "05-rewrite.png")


# 06 CTA
image = canvas()
draw = ImageDraw.Draw(image)
brand_tag(draw, "iPhone · Mac · Apple Watch")
text(draw, (64, 156), "App Store 搜", 98, bold=True)
text(draw, (64, 278), "RoastMate", 118, fill=ORANGE, bold=True)
text(draw, (64, 424), "中文名：帮你骂", 48, fill=MUTED, bold=True)
image = icon_badge(image, (88, 548, 398, 858), "免费可试")
image = screenshot_card(
    image,
    "xhs-02-explore-tiles.png",
    (28, 220, 1292, 2260),
    (506, 510, 1124, 1338),
)
draw = ImageDraw.Draw(image)
benefits = [
    "无广告 · 无追踪",
    "大部分功能\n纯本机运行",
]
for index, item in enumerate(benefits):
    y = 958 + index * 138
    rr(draw, (64, y, 452, y + 108), 26, PANEL, outline=LINE, width=2)
    rr(draw, (86, y + 37, 120, y + 71), 17, ORANGE)
    text(draw, (142, y + 22), item, 29, bold=True, spacing=5)
rr(draw, (64, 1376, 1178, 1512), 42, ORANGE)
text(draw, (621, 1444), "现在去 App Store 搜 RoastMate", 42, fill="#141414", bold=True, anchor="mm")
page_mark(draw, 6)
save(image, "06-cta.png")


print(f"Wrote six Xiaohongshu promo images to {OUT}")
