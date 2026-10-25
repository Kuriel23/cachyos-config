#!/usr/bin/env python3
"""Emit JSON-line changes for keyboard locks and Lenovo Fn/backlight LEDs."""
import argparse
import json
import sys
import time
from pathlib import Path

LOCKS = ('capslock', 'numlock', 'scrolllock')
SPECIAL = {'platform::fnlock': 'fnlock', 'platform::kbd_backlight': 'kbd_backlight'}
ROOT = Path('/sys/class/leds')

def discover():
    paths = {p: p.parent.name.rsplit(':', 1)[-1] for lock in LOCKS for p in ROOT.glob('*:' + lock + '/brightness')}
    for led, name in SPECIAL.items():
        p = ROOT / led / 'brightness'
        if p.exists():
            paths[p] = name
    return paths

def read(paths):
    states = {}
    for path, name in paths.items():
        try:
            value = int(path.read_text().strip())
            max_path = path.parent / 'max_brightness'
            maximum = int(max_path.read_text().strip()) if name == 'kbd_backlight' and max_path.exists() else None
            states[path] = (name, value, maximum)
        except (OSError, ValueError):
            continue
    return states

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--once', action='store_true')
    args = parser.parse_args()
    paths = discover()
    previous = read(paths)
    if args.once:
        print(json.dumps({'devices': {str(p): {'name': n, 'value': v, 'max': m} for p, (n, v, m) in previous.items()}, 'available': bool(previous)}))
        return
    last_discovery = time.monotonic()
    last_emitted = {}
    while True:
        now = time.monotonic()
        if now - last_discovery >= 2:
            paths = discover()
            last_discovery = now
        current = read(paths)
        changed = {}
        for path, (name, value, maximum) in current.items():
            if path not in previous or previous[path][1] == value:
                continue
            event = {'lock': name, 'enabled': value > 0}
            if name == 'kbd_backlight':
                event.update(level=value, maximum=maximum, progress=value / maximum if maximum and maximum > 0 else -1)
            changed[name] = event
        previous = current
        for name, event in changed.items():
            identity = (event['enabled'], event.get('level'))
            if last_emitted.get(name) == identity:
                continue
            last_emitted[name] = identity
            print(json.dumps(event), flush=True)
        time.sleep(0.15)

if __name__ == '__main__':
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
