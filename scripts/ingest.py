#!/usr/bin/env python3
"""
Merge RSS/Atom feeds from ingestion/sources.json into a single JSON bundle for the app.

  python3 scripts/ingest.py
  python3 scripts/ingest.py --out devbites/ingested_feed.json --max-total 150

Requires: Python 3.10+, curl on PATH (for TLS). Stdlib only.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import sys
from pathlib import Path
import urllib.error
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Any
from urllib.parse import urlparse, urlunparse

from feed_common import SOURCES_PATH, fetch, load_sources

IMG_RE = re.compile(r"""<img[^>]+src\s*=\s*["']([^"']+)["']""", re.I)


def local_tag(tag: str) -> str:
    """Strip XML namespace from a tag name (pass `element.tag`, not the element)."""
    return tag.split("}")[-1] if "}" in tag else tag


def text_or_none(el: ET.Element | None) -> str | None:
    if el is None:
        return None
    s = "".join(el.itertext()).strip()
    return s if s else None


def strip_tags(s: str) -> str:
    t = re.sub(r"<[^>]+>", " ", html.unescape(s))
    return " ".join(t.split())


def first_img_url(html_blob: str | None) -> str | None:
    if not html_blob:
        return None
    m = IMG_RE.search(html_blob)
    return m.group(1).strip() if m else None


def parse_date(raw: str | None) -> datetime | None:
    if not raw:
        return None
    s = raw.strip()
    if not s:
        return None
    try:
        dt = parsedate_to_datetime(s)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except (TypeError, ValueError):
        pass
    try:
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except ValueError:
        return None


def to_iso(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def normalize_url(url: str) -> str:
    u = url.strip()
    p = urlparse(u)
    scheme = p.scheme or "https"
    netloc = (p.netloc or "").lower()
    path = p.path if p.path else "/"
    return urlunparse((scheme, netloc, path, "", p.query, ""))


def stable_id(url: str) -> str:
    n = normalize_url(url)
    return hashlib.sha256(n.encode("utf-8")).hexdigest()[:20]


@dataclass
class RawArticle:
    title: str
    source_name: str
    url: str
    published_at: datetime | None
    summary: str | None
    image_url: str | None


_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


def raw_to_json_dict(r: RawArticle) -> dict[str, Any]:
    url = normalize_url(r.url)
    pub = r.published_at or _EPOCH
    d: dict[str, Any] = {
        "id": stable_id(url),
        "title": r.title.strip(),
        "sourceName": r.source_name,
        "url": url,
        "publishedAt": to_iso(pub),
        "summary": r.summary,
        "imageURL": r.image_url,
    }
    return d


def _rss_image(item: ET.Element) -> str | None:
    for child in item:
        ln = local_tag(child.tag)
        if ln == "enclosure":
            t = (child.get("type") or "").lower()
            if t.startswith("image/"):
                u = child.get("url")
                if u:
                    return u.strip()
        if ln == "thumbnail" and child.get("url"):
            return child.get("url", "").strip()
    return None


def _rss_item_link(item: ET.Element) -> str | None:
    guid = item.findtext("guid")
    if guid and guid.strip().startswith("http"):
        return guid.strip()
    link = item.findtext("link")
    if link and link.strip():
        return link.strip()
    if guid:
        return guid.strip()
    return None


def _rss_item_content(item: ET.Element) -> tuple[str | None, str | None]:
    """description, content_encoded."""
    desc = item.findtext("description")
    encoded = None
    for child in item:
        if local_tag(child.tag) == "encoded":
            encoded = text_or_none(child)
            break
    return desc, encoded


def _child_by_local(parent: ET.Element, name: str) -> ET.Element | None:
    for c in parent:
        if local_tag(c.tag) == name:
            return c
    return None


def parse_rss(root: ET.Element, source_name: str, max_items: int) -> list[RawArticle]:
    out: list[RawArticle] = []
    channel = root.find("channel")
    if channel is None:
        channel = _child_by_local(root, "channel")
    if channel is None:
        return out
    items = channel.findall("item")
    if not items:
        items = [c for c in channel if local_tag(c.tag) == "item"]
    for item in items:
        if len(out) >= max_items:
            break
        title = item.findtext("title")
        if not title or not title.strip():
            continue
        link = _rss_item_link(item)
        if not link:
            continue
        pub = parse_date(item.findtext("pubDate"))
        desc, encoded = _rss_item_content(item)
        blob = encoded or desc or ""
        summary = strip_tags(blob)[:400] if blob else None
        if summary == "":
            summary = None
        img = _rss_image(item) or first_img_url(blob)
        out.append(
            RawArticle(
                title=" ".join(title.split()),
                source_name=source_name,
                url=link,
                published_at=pub,
                summary=summary,
                image_url=img,
            )
        )
    return out


def parse_atom(root: ET.Element, source_name: str, max_items: int) -> list[RawArticle]:
    out: list[RawArticle] = []
    ns = "{http://www.w3.org/2005/Atom}"
    entries = root.findall(f"{ns}entry")
    if not entries:
        entries = [c for c in root if local_tag(c.tag) == "entry"]
    for entry in entries:
        if len(out) >= max_items:
            break
        title_el = entry.find(f"{ns}title")
        title = text_or_none(title_el)
        if not title:
            continue
        link_href = None
        for link in entry.findall(f"{ns}link"):
            rel = (link.get("rel") or "alternate").lower()
            if rel == "alternate" or rel == "":
                link_href = link.get("href")
                if link_href:
                    break
        if not link_href:
            id_el = entry.find(f"{ns}id")
            if id_el is not None and (id_el.text or "").strip().startswith("http"):
                link_href = id_el.text.strip()
        if not link_href:
            continue
        pub = None
        for tag in ("published", "updated"):
            el = entry.find(f"{ns}{tag}")
            if el is not None and el.text:
                pub = parse_date(el.text)
                if pub:
                    break
        summary_el = entry.find(f"{ns}summary")
        content_el = entry.find(f"{ns}content")
        blob = text_or_none(content_el) or text_or_none(summary_el) or ""
        summary = strip_tags(blob)[:400] if blob else None
        if summary == "":
            summary = None
        img = first_img_url(blob)
        out.append(
            RawArticle(
                title=" ".join(title.split()),
                source_name=source_name,
                url=link_href.strip(),
                published_at=pub,
                summary=summary,
                image_url=img,
            )
        )
    return out


def parse_feed_bytes(data: bytes, source_name: str, max_items: int) -> tuple[list[RawArticle], str]:
    try:
        root = ET.fromstring(data)
    except ET.ParseError as e:
        return [], f"parse-error: {e}"
    tag = local_tag(root.tag)
    if tag == "rss":
        return parse_rss(root, source_name, max_items), "rss"
    if tag == "feed":
        return parse_atom(root, source_name, max_items), "atom"
    return [], f"unknown-root:{tag}"


def merge_and_sort(
    articles: list[RawArticle],
    max_total: int,
) -> list[dict[str, Any]]:
    seen: set[str] = set()
    unique: list[RawArticle] = []
    for a in articles:
        key = normalize_url(a.url)
        if key in seen:
            continue
        seen.add(key)
        unique.append(a)

    def sort_key(r: RawArticle) -> float:
        if r.published_at is None:
            return 0.0
        return r.published_at.timestamp()

    unique.sort(key=sort_key, reverse=True)
    trimmed = unique[:max_total]
    return [raw_to_json_dict(r) for r in trimmed]


def main() -> int:
    parser = argparse.ArgumentParser(description="Build ingested_feed.json from ingestion/sources.json")
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "devbites" / "ingested_feed.json",
        help="Output JSON path",
    )
    parser.add_argument("--max-per-source", type=int, default=25, help="Max entries per feed")
    parser.add_argument("--max-total", type=int, default=200, help="Max articles after merge")
    args = parser.parse_args()

    if not SOURCES_PATH.is_file():
        print(f"Missing {SOURCES_PATH}", file=sys.stderr)
        return 1

    sources = load_sources()
    all_raw: list[RawArticle] = []
    errors: list[str] = []

    for src in sources:
        sid = src["id"]
        name = src.get("name", sid)
        url = src["feed_url"]
        try:
            code, body = fetch(url)
        except urllib.error.HTTPError as e:
            errors.append(f"{sid}: HTTP {e.code}")
            continue
        except urllib.error.URLError as e:
            errors.append(f"{sid}: {e.reason}")
            continue
        except Exception as e:
            errors.append(f"{sid}: {e!r}")
            continue

        if code >= 400 or not body:
            errors.append(f"{sid}: HTTP {code}")
            continue

        items, fmt = parse_feed_bytes(body, name, args.max_per_source)
        if not items:
            errors.append(f"{sid}: no entries ({fmt})")
            continue
        all_raw.extend(items)
        print(f"{sid}: {fmt} +{len(items)}", file=sys.stderr)

    payload = {"articles": merge_and_sort(all_raw, args.max_total)}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Wrote {len(payload['articles'])} articles to {args.out}", file=sys.stderr)
    for e in errors:
        print(f"warn: {e}", file=sys.stderr)
    if not payload["articles"]:
        print("warn: feed is empty — check sources or network", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
