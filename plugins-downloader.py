#!/usr/bin/env python3
"""
plugins-downloader.py

Download a WordPress plugin zip straight from downloads.wordpress.org,
either the latest release or a pinned historical version — handy for
reproducing a specific CVE in a local vuln lab.

Examples:
  ./plugins-downloader.py --url https://wordpress.org/plugins/wedevs-project-manager/
  ./plugins-downloader.py --url https://wordpress.org/plugins/wedevs-project-manager/ -v 4.1.2
  ./plugins-downloader.py --url https://wordpress.org/plugins/wedevs-project-manager/ -v 4.1.2 -o ./plugins
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import urllib.error
import urllib.request

SLUG_RE = re.compile(r"/plugins/([^/]+)/?")


def extract_slug(url: str) -> str:
    match = SLUG_RE.search(url)
    if not match:
        sys.exit(f"[!] Could not extract a plugin slug from: {url}")
    return match.group(1)


def build_download_url(slug: str, version: str | None) -> str:
    filename = f"{slug}.{version}.zip" if version else f"{slug}.zip"
    return f"https://downloads.wordpress.org/plugin/{filename}"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument(
        "--url",
        required=True,
        help="Plugin page URL, e.g. https://wordpress.org/plugins/<slug>/",
    )
    parser.add_argument(
        "-v",
        "--version",
        default=None,
        help="Specific version to download (e.g. 4.1.2). Omit for the latest release.",
    )
    parser.add_argument(
        "-o",
        "--outdir",
        default=".",
        help="Directory to save the zip into (default: current directory).",
    )
    args = parser.parse_args()

    slug = extract_slug(args.url)
    download_url = build_download_url(slug, args.version)
    filename = os.path.basename(download_url)

    os.makedirs(args.outdir, exist_ok=True)
    dest_path = os.path.join(args.outdir, filename)

    print(f"[*] Slug      : {slug}")
    print(f"[*] Version   : {args.version or 'latest'}")
    print(f"[*] Fetching  : {download_url}")

    try:
        req = urllib.request.Request(download_url, headers={"User-Agent": "plugins-downloader/1.0"})
        with urllib.request.urlopen(req) as response, open(dest_path, "wb") as out_file:
            out_file.write(response.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"[!] Download failed ({e.code}): {download_url}\n"
                  f"    Check the slug/version — wordpress.org returns 404 for unknown ones.")
    except urllib.error.URLError as e:
        sys.exit(f"[!] Network error: {e}")

    print(f"[+] Saved to  : {dest_path}")


if __name__ == "__main__":
    main()
