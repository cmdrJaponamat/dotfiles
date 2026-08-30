#!/usr/bin/env python3

import json
import math
import os
import shlex
import statistics
import subprocess
import sys
import time
from pathlib import Path


STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
STATE_FILE = STATE_DIR / "waybar-power-draw.json"
MAX_AGE_SECONDS = 30 * 60
SPARKLINE_BARS = "▁▂▃▄▅▆▇█"


def load_history(now: float) -> list[dict[str, float]]:
    if not STATE_FILE.exists():
        return []

    try:
        raw = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return []

    history = []
    for entry in raw:
        ts = entry.get("ts")
        watts = entry.get("watts")
        if isinstance(ts, (int, float)) and isinstance(watts, (int, float)):
            if 0 <= now - ts <= MAX_AGE_SECONDS:
                history.append({"ts": float(ts), "watts": float(watts)})
    return history


def avg_since(history: list[dict[str, float]], now: float, seconds: int) -> float:
    samples = [entry["watts"] for entry in history if now - entry["ts"] <= seconds]
    if not samples:
        return history[-1]["watts"]
    return sum(samples) / len(samples)


def sparkline(values: list[float], width: int = 30) -> str:
    if not values:
        return ""
    if len(values) <= width:
        samples = values
    else:
        chunk_size = len(values) / width
        samples = []
        for index in range(width):
            start = int(index * chunk_size)
            end = max(start + 1, int((index + 1) * chunk_size))
            chunk = values[start:end]
            samples.append(sum(chunk) / len(chunk))

    low = min(samples)
    high = max(samples)
    if math.isclose(high, low, abs_tol=0.2):
        return SPARKLINE_BARS[0] * len(samples)

    bars = []
    span = high - low
    for value in samples:
        normalized = (value - low) / span
        bar_index = min(len(SPARKLINE_BARS) - 1, int(round(normalized * (len(SPARKLINE_BARS) - 1))))
        bars.append(SPARKLINE_BARS[bar_index])
    return "".join(bars)


def render() -> str:
    now = time.time()
    history = load_history(now)
    if not history:
        return "Power draw history is empty.\nOpen the session and wait for Waybar to collect a few samples.\n"

    watts = [entry["watts"] for entry in history]
    instant = watts[-1]
    avg_5m = avg_since(history, now, 5 * 60)
    avg_10m = avg_since(history, now, 10 * 60)
    avg_30m = avg_since(history, now, 30 * 60)
    minimum = min(watts)
    maximum = max(watts)
    median = statistics.median(watts)
    lines = [
        "Power Draw Report",
        "",
        f"Instant : {instant:.1f}W",
        f"Avg 5m  : {avg_5m:.1f}W",
        f"Avg 10m : {avg_10m:.1f}W",
        f"Avg 30m : {avg_30m:.1f}W",
        f"Median  : {median:.1f}W",
        f"Range   : {minimum:.1f}W .. {maximum:.1f}W",
        f"Samples : {len(watts)}",
        "",
        "Trend 30m",
        sparkline(watts, width=36),
        "",
        "Recent samples",
    ]
    for entry in history[-10:]:
        age_seconds = int(now - entry["ts"])
        lines.append(f"{age_seconds:>4}s ago  {entry['watts']:.1f}W")
    lines.append("")
    lines.append("Press q to close.")
    return "\n".join(lines)


def main() -> int:
    report = render()
    pager = os.environ.get("PAGER", "less -R")
    return subprocess.run(shlex.split(pager), input=report, text=True, check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
