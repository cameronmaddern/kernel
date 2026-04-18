#!/usr/bin/env python3
"""
Fetch each feed in ingestion/sources.json and print HTTP status, size, and entry count.

Usage:
  python3 scripts/test_feed_pulls.py
  python3 scripts/test_feed_pulls.py --dump   # save raw XML under ingestion/samples/

Requires: Python 3.9+ (stdlib only).
"""

from __future__ import annotations

import argparse
import os
import sys
import urllib.error
import xml.etree.ElementTree as ET
from pathlib import Path

from feed_common import SAMPLES_DIR, SOURCES_PATH, fetch, load_sources

ATOM_NS = "{http://www.w3.org/2005/Atom}"


def parse_feed_stats(data: bytes) -> tuple[int, str | None, list[str]]:
    """Return (entry_count, format_hint, first_few_titles)."""
    try:
        root = ET.fromstring(data)
    except ET.ParseError as e:
        return 0, f"xml-parse-error: {e}", []

    tag = root.tag.split("}", 1)[-1] if "}" in root.tag else root.tag

    titles: list[str] = []

    if tag == "rss":
        channel = root.find("channel")
        if channel is None:
            return 0, "rss-missing-channel", []
        items = channel.findall("item")
        for it in items[:5]:
            t = it.findtext("title")
            if t:
                titles.append(" ".join(t.split()))
        return len(items), "rss2", titles

    if tag == "feed":
        entries = root.findall(f"{ATOM_NS}entry")
        for ent in entries[:5]:
            t_el = ent.find(f"{ATOM_NS}title")
            if t_el is not None and (t_el.text or "").strip():
                titles.append(" ".join((t_el.text or "").split()))
            elif t_el is not None and len(t_el):
                titles.append(" ".join("".join(t_el.itertext()).split()))
        return len(entries), "atom", titles

    items = root.findall(".//item")
    if items:
        for it in items[:5]:
            t = it.findtext("title")
            if t:
                titles.append(" ".join(t.split()))
        return len(items), "rss-fallback", titles

    return 0, f"unknown-root:{tag}", []


def main() -> int:
    parser = argparse.ArgumentParser(description="Test RSS/Atom pulls from ingestion/sources.json")
    parser.add_argument("--dump", action="store_true", help=f"Write raw responses to {SAMPLES_DIR}/")
    args = parser.parse_args()

    if not SOURCES_PATH.is_file():
        print(f"Missing {SOURCES_PATH}", file=sys.stderr)
        return 1

    sources = load_sources()
    if args.dump:
        SAMPLES_DIR.mkdir(parents=True, exist_ok=True)

    rows: list[tuple[str, str, str, str, str]] = []
    for src in sources:
        sid = src["id"]
        name = src.get("name", sid)
        url = src["feed_url"]
        try:
            code, body = fetch(url)
        except urllib.error.HTTPError as e:
            rows.append((sid, name, str(e.code), "0", str(e.reason)))
            continue
        except urllib.error.URLError as e:
            rows.append((sid, name, "ERR", "0", str(e.reason)))
            continue
        except Exception as e:
            rows.append((sid, name, "ERR", "0", repr(e)))
            continue

        if args.dump:
            out = SAMPLES_DIR / f"{sid}.xml"
            out.write_bytes(body)

        n, fmt, titles = parse_feed_stats(body)
        hint = fmt
        if n == 0 and "error" not in hint:
            hint = f"{fmt} (0 entries?)"
        preview = titles[0][:72] + "…" if titles and len(titles[0]) > 72 else (titles[0] if titles else "")
        rows.append((sid, name, str(code), str(n), f"{hint} | {preview}" if preview else hint))

    w0 = max(len(r[0]) for r in rows)
    w1 = max(len(r[1]) for r in rows)
    print(f"{'id':<{w0}}  {'name':<{w1}}  HTTP  items  detail")
    print("-" * (w0 + w1 + 32))
    for sid, name, code, n, detail in rows:
        print(f"{sid:<{w0}}  {name:<{w1}}  {code:>4}  {n:>5}  {detail}")

    failed = sum(1 for r in rows if not r[2].isdigit() or (r[2].isdigit() and int(r[2]) >= 400))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
