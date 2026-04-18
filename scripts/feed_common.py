#!/usr/bin/env python3
"""Shared helpers for fetching RSS/Atom feeds (ingest + manual tests)."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES_PATH = ROOT / "ingestion" / "sources.json"
SAMPLES_DIR = ROOT / "ingestion" / "samples"

USER_AGENT = "KernelIngest/1.0 (+https://github.com; local RSS ingest)"


def load_sources() -> list[dict]:
    with open(SOURCES_PATH, encoding="utf-8") as f:
        data = json.load(f)
    return data["sources"]


def fetch(url: str, timeout: int = 45) -> tuple[int, bytes]:
    """Fetch URL; prefer curl for TLS parity with macOS trust store."""
    try:
        fd, path = tempfile.mkstemp(suffix=".feed.xml")
        os.close(fd)
        try:
            proc = subprocess.run(
                [
                    "curl",
                    "-sS",
                    "-L",
                    "--max-time",
                    str(timeout),
                    "-A",
                    USER_AGENT,
                    "-H",
                    "Accept: application/rss+xml, application/atom+xml, application/xml, text/xml, */*",
                    "-o",
                    path,
                    "-w",
                    "%{http_code}",
                    url,
                ],
                capture_output=True,
                text=True,
                timeout=timeout + 10,
            )
            err = (proc.stderr or "").strip()
            if proc.returncode != 0:
                raise urllib.error.URLError(err or f"curl exit {proc.returncode}")
            raw_code = (proc.stdout or "").strip()
            code = int(raw_code) if raw_code.isdigit() else 0
            body = Path(path).read_bytes()
            return code, body
        finally:
            try:
                os.unlink(path)
            except OSError:
                pass
    except FileNotFoundError:
        pass
    except (OSError, ValueError) as e:
        raise urllib.error.URLError(str(e)) from e

    req = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT, "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml, */*"},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        code = resp.getcode()
        body = resp.read()
    return code, body
