#!/usr/bin/env python3

import json
import os
import sys
import time
from pathlib import Path


BATTERY_PATH = Path("/sys/class/power_supply/BAT0")
POWER_NOW_PATH = BATTERY_PATH / "power_now"
STATUS_PATH = BATTERY_PATH / "status"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
STATE_FILE = STATE_DIR / "waybar-power-draw.json"
MODE_FILE = STATE_DIR / "waybar-power-draw-mode"
MAX_AGE_SECONDS = 30 * 60
SPARKLINE_BARS = "▁▂▃▄▅▆▇█"
DISPLAY_MODES = ("instant", "avg5", "avg10", "avg30")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def read_power_watts() -> float:
    return int(read_text(POWER_NOW_PATH)) / 1_000_000


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


def save_history(history: list[dict[str, float]]) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(history), encoding="utf-8")


def clear_history() -> None:
    try:
        STATE_FILE.unlink()
    except FileNotFoundError:
        pass


def current_mode() -> str:
    if not MODE_FILE.exists():
        return "avg10"
    mode = MODE_FILE.read_text(encoding="utf-8").strip()
    if mode in DISPLAY_MODES:
        return mode
    return "avg10"


def save_mode(mode: str) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    MODE_FILE.write_text(mode, encoding="utf-8")


def next_mode() -> str:
    mode = current_mode()
    index = DISPLAY_MODES.index(mode)
    next_value = DISPLAY_MODES[(index + 1) % len(DISPLAY_MODES)]
    save_mode(next_value)
    return next_value


def average_since(history: list[dict[str, float]], now: float, seconds: int) -> float:
    samples = [entry["watts"] for entry in history if now - entry["ts"] <= seconds]
    if not samples:
        return history[-1]["watts"]
    return sum(samples) / len(samples)


def format_watts(value: float) -> str:
    return f"{value:.1f}W"


def format_compact(value: float) -> str:
    return f"AVG {value:.1f}W"


def format_mode_label(mode: str, instant: float, avg_5m: float, avg_10m: float, avg_30m: float) -> str:
    if mode == "instant":
        return f"NOW {instant:.1f}W"
    if mode == "avg5":
        return f"AVG5 {avg_5m:.1f}W"
    if mode == "avg30":
        return f"AVG30 {avg_30m:.1f}W"
    return f"AVG10 {avg_10m:.1f}W"


def classify(instant: float) -> str:
    if instant >= 14:
        return "high"
    if instant >= 9:
        return "medium"
    return "low"


def history_stats(history: list[dict[str, float]]) -> tuple[float, float]:
    watts = [entry["watts"] for entry in history]
    return min(watts), max(watts)


def sparkline(history: list[dict[str, float]], buckets: int = 12) -> str:
    if not history:
        return ""

    watts = [entry["watts"] for entry in history]
    if len(watts) <= buckets:
        samples = watts
    else:
        chunk_size = len(watts) / buckets
        samples = []
        for index in range(buckets):
            start = int(index * chunk_size)
            end = max(start + 1, int((index + 1) * chunk_size))
            chunk = watts[start:end]
            samples.append(sum(chunk) / len(chunk))

    low = min(samples)
    high = max(samples)
    if high - low < 0.2:
        return SPARKLINE_BARS[0] * len(samples)

    bars = []
    span = high - low
    for value in samples:
        normalized = (value - low) / span
        bar_index = min(len(SPARKLINE_BARS) - 1, int(round(normalized * (len(SPARKLINE_BARS) - 1))))
        bars.append(SPARKLINE_BARS[bar_index])
    return "".join(bars)


def main() -> None:
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == "clear-history":
            clear_history()
            print(json.dumps({"ok": True, "action": command}))
            return
        if command == "next-mode":
            print(json.dumps({"ok": True, "mode": next_mode()}))
            return

    if not POWER_NOW_PATH.exists():
        print(
            json.dumps(
                {
                    "text": "PWR n/a",
                    "tooltip": "Battery power_now is unavailable",
                    "class": ["unknown"],
                }
            )
        )
        return

    now = time.time()
    status = read_text(STATUS_PATH) if STATUS_PATH.exists() else "Unknown"
    if status.lower() in {"charging", "full", "not charging"}:
        clear_history()
        print(
            json.dumps(
                {
                    "text": "",
                    "tooltip": "",
                    "class": ["hidden", "charging-state", status.lower()],
                }
            )
        )
        return

    instant = read_power_watts()
    history = load_history(now)
    history.append({"ts": now, "watts": instant})
    history = [entry for entry in history if now - entry["ts"] <= MAX_AGE_SECONDS]
    save_history(history)

    avg_5m = average_since(history, now, 5 * 60)
    avg_10m = average_since(history, now, 10 * 60)
    avg_30m = average_since(history, now, 30 * 60)

    min_watts, max_watts = history_stats(history)
    mode = current_mode()
    text = format_mode_label(mode, instant, avg_5m, avg_10m, avg_30m)
    tooltip = "\n".join(
        [
            f"Display: {mode}",
            f"Status: {status}",
            f"Instant: {format_watts(instant)}",
            f"5 min avg: {format_watts(avg_5m)}",
            f"10 min avg: {format_watts(avg_10m)}",
            f"30 min avg: {format_watts(avg_30m)}",
            f"Range: {format_watts(min_watts)} .. {format_watts(max_watts)}",
            f"Trend: {sparkline(history)}",
            f"Samples: {len(history)}",
            "",
            "Middle click: next display mode",
            "Right click: clear history",
        ]
    )
    output = {
        "text": text,
        "tooltip": tooltip,
        "class": [classify(avg_10m), status.lower()],
    }
    print(json.dumps(output))


if __name__ == "__main__":
    main()
