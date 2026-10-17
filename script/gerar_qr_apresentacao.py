"""Regenera o QR local quando o endereço público da apresentação mudar.

Requer Python, Pillow e qrcode. Atualize também links.apresentacao em entrega.yml.
"""
from argparse import ArgumentParser
from pathlib import Path
from urllib.parse import urlsplit

import qrcode


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("url", help="URL pública completa, incluindo #s-capa")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "app/assets/images/presentation/acesso/apresentacao-qr.png")
    args = parser.parse_args()
    url = urlsplit(args.url)
    if url.scheme not in ("http", "https") or not url.netloc:
        parser.error("Informe uma URL HTTP ou HTTPS válida.")
    code = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=16, border=4)
    code.add_data(args.url)
    code.make(fit=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    code.make_image(fill_color="#102e27", back_color="white").save(args.output)
    print(args.output)


if __name__ == "__main__":
    main()
