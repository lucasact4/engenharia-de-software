"""Regenera o QR com a marca SGU quando o endereço público mudar.

Requer Python, Pillow e qrcode. Atualize também links.apresentacao em entrega.yml.
"""
from argparse import ArgumentParser
from pathlib import Path
from urllib.parse import urlsplit

import qrcode
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("url", help="URL pública completa, incluindo #s-capa")
    parser.add_argument("--output", type=Path, default=ROOT / "app/assets/images/presentation/acesso/apresentacao-qr.png")
    args = parser.parse_args()
    url = urlsplit(args.url)
    if url.scheme not in ("http", "https") or not url.netloc:
        parser.error("Informe uma URL HTTP ou HTTPS válida.")

    # Alta correção de erros e uma marca pequena preservam a leitura do QR.
    box_size = 16
    code = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=box_size, border=4)
    code.add_data(args.url)
    code.make(fit=True)
    image = code.make_image(fill_color="#102e27", back_color="white").convert("RGB")

    # Centraliza o selo na grade, mantendo a margem branca externa intacta.
    badge_size = (max(7, len(code.modules) // 5) | 1) * box_size
    left = (image.width - badge_size) // 2
    top = (image.height - badge_size) // 2
    ImageDraw.Draw(image).rounded_rectangle(
        (left, top, left + badge_size - 1, top + badge_size - 1),
        radius=box_size, fill="white"
    )
    with Image.open(ROOT / "app/assets/images/brand/sgu-simbolo.png") as source:
        logo = source.convert("RGBA")
        logo = logo.crop(logo.getbbox())
    logo.thumbnail((badge_size - 2 * box_size, badge_size - 2 * box_size), Image.Resampling.LANCZOS)
    image.paste(logo, ((image.width - logo.width) // 2, (image.height - logo.height) // 2), logo)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)
    print(args.output)


if __name__ == "__main__":
    main()
