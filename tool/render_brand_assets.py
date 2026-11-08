"""Render the app icon and splash sources from the Refetch logo mark.

The mark comes from refetch.io (see docs/BRANDING.md): a #4E1CB3 disc with
white arrows. Per the web DESIGN.md it is never placed on a purple
background, so the icon is the purple mark on white, like the site's
maskable-512.png and apple-touch-icon.png.

    pip install resvg_py pillow
    python tool/render_brand_assets.py
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create

Writes the SVG sources next to the PNGs so the art stays editable.
"""

from pathlib import Path

import resvg_py

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "assets" / "icon"
BRAND = ROOT / "assets" / "brand"
PLAY = ROOT / "android" / "fastlane" / "metadata" / "android" / "en-US" / "images"
FONTS = ROOT / "assets" / "fonts"

PURPLE = "#4E1CB3"
VIEW = (10.9, 2.1, 198.8)  # x, y, size of the mark's own viewBox

# The disc with the arrows cut out, from the site's logo SVG.
DISC = (
    "M110.3,2.2C55.4,2.2,10.9,46.6,10.9,101.5s44.5,99.4,99.4,99.4,99.4-44.5,"
    "99.4-99.4S165.1,2.2,110.3,2.2ZM90.3,124.4l-36.3.6c-.6,0-1.1-.5-1.1-1.1v-36.6"
    "c0-.9,1.1-1.4,1.8-.8l11.9,11.9,36.4-36.4c1.1-1.1,2.8-1.1,3.9,0l8.1,8.1c1.1,1.1,"
    "1.1,2.8,0,3.9l-36.4,36.4,12.3,12.2c.7.7.2,1.8-.7,1.8h0ZM166.5,117.4l-12.8-10.9"
    "-36.6,36.2c-1.1,1.1-2.8,1.1-3.9,0l-8.1-8.2c-1.1-1.1-1.1-2.8,0-3.9l36.6-36.2"
    "-11.2-13.1c-.7-.7-.2-1.8.7-1.8l35.6.5c.6,0,1.1.5,1.1,1.1l.5,35.7c0,.9-1.1,"
    "1.4-1.8.7h0Z"
)


def mark(scale: float, size: int = 1024, arrows: str | None = "#FFFFFF", fill: str = PURPLE) -> str:
    """The mark centred on a size x size canvas, its disc `scale` of the width."""
    x, y, s = VIEW
    d = size * scale
    k = d / s
    off = (size - d) / 2
    back = f'<circle cx="110.3" cy="101.5" r="86" fill="{arrows}"/>' if arrows else ""
    return (
        f'<g transform="translate({off:.2f} {off:.2f}) scale({k:.5f}) translate({-x} {-y})">'
        f'{back}<path d="{DISC}" fill="{fill}"/></g>'
    )


def svg(body: str, size: int = 1024, background: str | None = None) -> str:
    bg = f'<rect width="{size}" height="{size}" fill="{background}"/>' if background else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {size} {size}">{bg}{body}</svg>\n'
    )


def write(path: Path, source: str, size: int = 1024) -> None:
    path.with_suffix(".svg").write_text(source, encoding="utf-8")
    png = resvg_py.svg_to_bytes(svg_string=source, width=size, height=size)
    path.with_suffix(".png").write_bytes(bytes(png))
    print("wrote", path.with_suffix(".png").relative_to(ROOT))


def feature_graphic() -> None:
    """Play feature graphic (1024x500): the full logo and the site's tagline
    on the light canvas (#F5F5F7), never on purple (DESIGN.md)."""
    logo = (BRAND / "logo-wordmark.svg").read_text(encoding="utf-8")
    logo = logo.replace('fill="currentColor"', 'fill="#1D1D1F"')
    inner = logo[logo.index(">") + 1 : logo.rindex("</svg>")]
    # Logo viewBox is 913 x 203; draw it 520 wide, centred.
    k = 520 / 913
    x = (1024 - 520) / 2
    source = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500" viewBox="0 0 1024 500">'
        '<rect width="1024" height="500" fill="#F5F5F7"/>'
        f'<g transform="translate({x:.1f} 150) scale({k:.5f})">{inner}</g>'
        '<text x="512" y="352" text-anchor="middle" font-family="Inter" font-weight="500" '
        'font-size="34" fill="#6E6E73">The front page for builders</text>'
        "</svg>\n"
    )
    png = resvg_py.svg_to_bytes(
        svg_string=source,
        width=1024,
        height=500,
        skip_system_fonts=True,
        font_files=[str(FONTS / "Inter-Medium.ttf")],
    )
    (PLAY / "featureGraphic.png").write_bytes(bytes(png))
    print("wrote", (PLAY / "featureGraphic.png").relative_to(ROOT))


def main() -> None:
    # Launcher icon (iOS, macOS, Windows, web, legacy Android): white tile,
    # the disc at 62% like the site's touch icon.
    write(ICON / "icon", svg(mark(0.62), background="#FFFFFF"))
    # Android adaptive foreground: the visible circle is 72/108 of the canvas,
    # so 58% keeps the disc clear of every launcher mask.
    write(ICON / "icon_foreground", svg(mark(0.58)))
    # Android 13 themed icon: one colour, arrows cut out (alpha only).
    write(ICON / "icon_monochrome", svg(mark(0.58, arrows=None, fill="#000000")))
    # Splash: the mark alone on a transparent canvas; the splash background
    # colour comes from the theme (#F5F5F7 light, #0E0D13 dark).
    write(BRAND / "splash_mark", svg(mark(0.5)), size=768)
    # Play listing icon (512, no alpha) and feature graphic.
    png = resvg_py.svg_to_bytes(svg_string=svg(mark(0.62), background="#FFFFFF"), width=512, height=512)
    (PLAY / "icon.png").write_bytes(bytes(png))
    print("wrote", (PLAY / "icon.png").relative_to(ROOT))
    feature_graphic()


if __name__ == "__main__":
    main()
