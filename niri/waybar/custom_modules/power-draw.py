#!/usr/bin/env python3

import json
import os
import time
from pathlib import Path


BATTERY_PATH = Path("/sys/class/power_supply/BAT0")
POWER_NOW_PATH = BATTERY_PATH / "power_now"
STATUS_PATH = BATTERY_PATH / "status"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
STATE_FILE = STATE_DIR / "waybar-power-draw.json"
MAX_AGE_SECONDS = 30 * 60


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


def average_since(history: list[dict[str, float]], now: float, seconds: int) -> float:
    samples = [entry["watts"] for entry in history if now - entry["ts"] <= seconds]
    if not samples:
        return history[-1]["watts"]
    return sum(samples) / len(samples)


def format_watts(value: float) -> str:
    return f"{value:.1f}W"


def classify(instant: float) -> str:
    if instant >= 12:
        return "high"
    if instant >= 9:
        return "medium"
    return "low"


def main() -> None:
    if not POWER_NOW_PATH.exists():
        print(json.dumps({"text": "PWR n/a", "tooltip": "Battery power_now is unavailable"}))
        return

    now = time.time()
    status = read_text(STATUS_PATH) if STATUS_PATH.exists() else "Unknown"
    if status.lower() in {"charging", "full", "not charging"}:
        clear_history()
        print(json.dumps({"text": "", "tooltip": "", "class": ["hidden", status.lower()]}))
        return

    instant = read_power_watts()
    history = load_history(now)
    history.append({"ts": now, "watts": instant})
    history = [entry for entry in history if now - entry["ts"] <= MAX_AGE_SECONDS]
    save_history(history)

    avg_10m = average_since(history, now, 10 * 60)
    avg_30m = average_since(history, now, 30 * 60)

    text = f"PWR {format_watts(instant)} {format_watts(avg_10m)} {format_watts(avg_30m)}"
    tooltip = "\n".join(
        [
            f"Status: {status}",
            f"Instant: {format_watts(instant)}",
            f"10 min avg: {format_watts(avg_10m)}",
            f"30 min avg: {format_watts(avg_30m)}",
            f"Samples: {len(history)}",
        ]
    )
    output = {
        "text": text,
        "tooltip": tooltip,
        "class": [classify(instant), status.lower()],
    }
    print(json.dumps(output))


if __name__ == "__main__":
    main()
