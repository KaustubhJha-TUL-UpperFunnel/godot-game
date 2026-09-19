"""Build Google Play listing images from captured gameplay frames.

Writes:
  googleplayresources/common/app-icon.png          512x512 RGBA
  googleplayresources/common/feature-graphic.png   1024x500 RGB
  googleplayresources/phone/*.png                  1920x1080 RGB
  googleplayresources/tablet/*.png                 2560x1440 RGB
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "googleplayresources"
RAW = OUT / "_raw"
COMMON = OUT / "common"
PHONE = OUT / "phone"
TABLET = OUT / "tablet"
PORTRAIT = ROOT / "descent" / "assets" / "game" / "portrait.png"
MOCKUP = ROOT / "finished-game-mockup.png"
GENERATED_ICON = Path(
    r"C:\Users\User\.cursor\projects\d-startup-ideas-godot-game\assets\descent-app-icon.png"
)

PHONE_SIZE = (1920, 1080)
TABLET_SIZE = (2560, 1440)
FEATURE_SIZE = (1024, 500)
ICON_SIZE = 512
BG = (7, 16, 27)
GOLD = (226, 174, 82)
CYAN = (88, 230, 255)


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    windir = Path(r"C:\Windows\Fonts")
    names = ("georgiab.ttf", "georgia.ttf") if bold else ("georgia.ttf",)
    for name in names:
        path = windir / name
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = image.convert("RGB")
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def _fit_exact(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return image.convert("RGB").resize(size, Image.Resampling.LANCZOS)


def _rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def build_icon() -> None:
    dest = COMMON / "app-icon.png"
    if GENERATED_ICON.exists():
        icon = Image.open(GENERATED_ICON).convert("RGBA")
        icon = icon.resize((ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS)
        icon.save(dest, "PNG")
        print(f"icon -> {dest} {icon.size} (from generated art)")
        return

    canvas = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (*BG, 255))
    inner = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (16, 27, 40, 255))
    portrait = Image.open(PORTRAIT).convert("RGBA")
    crop_w = int(portrait.width * 0.78)
    portrait = portrait.crop((0, 0, crop_w, portrait.height))
    scale = 390 / max(portrait.width, portrait.height)
    portrait = portrait.resize(
        (max(1, round(portrait.width * scale)), max(1, round(portrait.height * scale))),
        Image.Resampling.NEAREST,
    )
    inner.paste(
        portrait,
        ((ICON_SIZE - portrait.width) // 2, (ICON_SIZE - portrait.height) // 2 + 8),
        portrait,
    )
    canvas.paste(inner, (0, 0), inner)
    draw = ImageDraw.Draw(canvas)
    inset = 18
    draw.rounded_rectangle(
        (inset, inset, ICON_SIZE - inset - 1, ICON_SIZE - inset - 1),
        radius=72,
        outline=GOLD,
        width=14,
    )
    canvas.putalpha(_rounded_mask(ICON_SIZE, 96))
    canvas.save(dest, "PNG")
    print(f"icon -> {dest} {canvas.size}")


def _feature_source(screens: list[Path]) -> Path:
    for path in screens:
        if "ice_throne" in path.name:
            return path
    if screens:
        return screens[0]
    return MOCKUP


def build_feature(screens: list[Path]) -> None:
    source_path = _feature_source(screens)
    source = Image.open(source_path).convert("RGB")
    w, h = source.size
    source = source.crop((0, int(h * 0.16), int(w * 0.90), int(h * 0.82)))
    art = _fit_cover(source, FEATURE_SIZE)
    shade = Image.new("RGB", FEATURE_SIZE, BG)
    art = Image.blend(art, shade, 0.28)
    overlay = Image.new("RGBA", FEATURE_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.rectangle((0, 0, 470, FEATURE_SIZE[1]), fill=(7, 16, 27, 150))
    draw.text((48, 148), "DESCENT", font=_font(72, bold=True), fill=GOLD)
    draw.text((50, 236), "Eight floors. One way down.", font=_font(22), fill=(220, 230, 235, 255))
    draw.line([(50, 280), (250, 280)], fill=CYAN, width=4)
    composed = Image.alpha_composite(art.convert("RGBA"), overlay).convert("RGB")
    dest = COMMON / "feature-graphic.png"
    composed.save(dest, "PNG")
    print(f"feature -> {dest} {composed.size} (from {source_path.name})")


def export_screens(screens: list[Path]) -> None:
    PHONE.mkdir(parents=True, exist_ok=True)
    TABLET.mkdir(parents=True, exist_ok=True)
    for path in screens:
        image = Image.open(path)
        _fit_exact(image, PHONE_SIZE).save(PHONE / path.name, "PNG")
        _fit_exact(image, TABLET_SIZE).save(TABLET / path.name, "PNG")
        print(f"screen -> {path.name}")


def main() -> None:
    COMMON.mkdir(parents=True, exist_ok=True)
    PHONE.mkdir(parents=True, exist_ok=True)
    TABLET.mkdir(parents=True, exist_ok=True)
    screens = sorted(RAW.glob("*.png")) if RAW.exists() else []
    build_icon()
    build_feature(screens)
    if not screens:
        raise SystemExit("No raw gameplay captures in googleplayresources/_raw")
    export_screens(screens)


if __name__ == "__main__":
    main()
