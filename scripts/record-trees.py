#!/usr/bin/env python3
"""Record Spotify view trees from the iPhone over USB, one file per screen, into trees/.

    scripts/record-trees.py              # interactive: pick screens, record each, save trees/<name>.txt
    scripts/record-trees.py --import LOG NAME  # parse an existing capture into trees/NAME.txt

The FLEX build of the tweak dumps the visible screen when Spotify goes to the background (and the
full player once it appears). Screens live in trees/screens.txt as "name | hint"; new ones are added
from the menu.
"""
import datetime
import os
import re
import subprocess
import sys
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TREES = os.path.join(ROOT, "trees")
SCREENS = os.path.join(TREES, "screens.txt")

DEFAULT_SCREENS = [
    ("startup", "force-quit Spotify and open it again, wait for Home (captures the launch lines)"),
    ("home", "Home tab"),
    ("search", "Search tab"),
    ("library", "Library tab"),
    ("create", "the + tab"),
    ("now-playing", "tap the now playing bar to open the full player, wait 2 s"),
    ("playlist", "open any playlist"),
    ("album", "open any album"),
    ("artist", "open any artist page"),
    ("queue", "open the queue from the player"),
    ("lyrics", "open the lyrics from the player"),
    ("settings", "avatar → settings"),
]

TIMESTAMP = re.compile(r"^[A-Z][a-z]{2} +\d+ \d\d:\d\d:\d\d\.\d+ ")
TAG = re.compile(r"\[spotifyglass\] (.*)$")
PART = re.compile(r"^(.*) (\d+)/(\d+)$")
PAGE = re.compile(r"<((?:Home_|Browse_|Search_|Library_|Create|NowPlaying_Scroll|Playlist|Album|Artist|Queue|Lyrics|Settings)[A-Za-z_]*\.[A-Za-z]+)")


def load_screens():
    if not os.path.exists(SCREENS):
        os.makedirs(TREES, exist_ok=True)
        with open(SCREENS, "w") as f:
            f.writelines(f"{name} | {hint}\n" for name, hint in DEFAULT_SCREENS)
    screens = []
    for line in open(SCREENS):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, _, hint = line.partition("|")
        screens.append((name.strip(), hint.strip()))
    return screens


def add_screen(name, hint):
    with open(SCREENS, "a") as f:
        f.write(f"{name} | {hint}\n")


def parse(lines):
    """Split raw syslog lines into single messages and stitched dumps. Returns (singles, dumps)."""
    messages, current = [], None
    for raw in lines:
        line = raw.rstrip("\n")
        if TIMESTAMP.match(line):
            current = None
            m = TAG.search(line)
            if m:
                current = [m.group(1), []]
                messages.append(current)
        elif current is not None:
            current[1].append(line)
    singles, dumps = [], []
    for header, body in messages:
        m = PART.match(header)
        if not m:
            singles.append(header + ("\n" + "\n".join(body) if body else ""))
            continue
        tag, index, total = m.group(1), int(m.group(2)), int(m.group(3))
        if index == 1 or not dumps or dumps[-1]["tag"] != tag:
            dumps.append({"tag": tag, "total": total, "parts": {}})
        dumps[-1]["parts"][index] = "\n".join(body)
    complete = []
    for d in dumps:
        got = len(d["parts"])
        text = "\n".join(d["parts"][i] for i in sorted(d["parts"]))
        complete.append({"tag": d["tag"], "complete": got == d["total"], "got": got, "total": d["total"], "text": text})
    return singles, complete


def describe(dump):
    pages = sorted(set(PAGE.findall(dump["text"])))
    return f"{dump['tag']}, {dump['text'].count(chr(10))} lines, pages: {', '.join(pages) or 'none recognised'}"


def write_tree(name, singles, dump):
    path = os.path.join(TREES, f"{name}.txt")
    with open(path, "w") as f:
        f.write(f"# screen: {name}\n# recorded: {datetime.datetime.now():%Y-%m-%d %H:%M}\n")
        if dump:
            f.write(f"# {describe(dump)}\n")
        if singles:
            f.write("# messages:\n" + "\n".join(singles) + "\n")
        if dump:
            f.write("# tree:\n" + dump["text"] + "\n")
    return path


class Capture:
    def __init__(self):
        self.lines = []
        self.lock = threading.Lock()
        self.connected = False
        self.proc = subprocess.Popen(["idevicesyslog", "-p", "Spotify", "-m", "spotifyglass"],
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        threading.Thread(target=self._pump, daemon=True).start()

    def _pump(self):
        for line in self.proc.stdout:
            if line.startswith("[connected"):
                self.connected = True
            elif line.startswith("[disconnected"):
                self.connected = False
                print("\n  !! phone disconnected, reconnect the cable", flush=True)
            with self.lock:
                self.lines.append(line)

    def mark(self):
        with self.lock:
            return len(self.lines)

    def since(self, mark):
        with self.lock:
            return self.lines[mark:]

    def stop(self):
        self.proc.terminate()


def pick(screens):
    print("\nScreens in trees/:")
    for i, (name, hint) in enumerate(screens, 1):
        path = os.path.join(TREES, f"{name}.txt")
        status = f"recorded {datetime.datetime.fromtimestamp(os.path.getmtime(path)):%Y-%m-%d %H:%M}" if os.path.exists(path) else "missing"
        print(f"  {i:2d}. {name:<14} {status:<26} {hint}")
    print("\nSelect: numbers or ranges (1,3-5), 'a' all, 'm' missing only [default], 'n' add a new screen, 'q' quit")
    while True:
        answer = input("> ").strip().lower()
        if answer in ("q", "quit"):
            return None
        if answer == "n":
            name = input("  new screen name (letters, digits, dashes): ").strip().lower()
            if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name):
                print("  invalid name")
                continue
            hint = input("  hint (how to get there): ").strip()
            add_screen(name, hint)
            screens.append((name, hint))
            print(f"  added {name}")
            return pick(screens)
        if answer in ("", "m"):
            return [s for s in screens if not os.path.exists(os.path.join(TREES, f"{s[0]}.txt"))]
        if answer == "a":
            return list(screens)
        chosen = []
        try:
            for token in answer.split(","):
                token = token.strip()
                if "-" in token:
                    lo, hi = token.split("-")
                    chosen.extend(range(int(lo), int(hi) + 1))
                elif token:
                    chosen.append(int(token))
            if all(1 <= c <= len(screens) for c in chosen):
                return [screens[c - 1] for c in chosen]
        except ValueError:
            pass
        print("  didn't understand that")


def record(capture, name, hint):
    exists = os.path.exists(os.path.join(TREES, f"{name}.txt"))
    print(f"\n▶ Now recording: {name}{'  (will overwrite)' if exists else ''}")
    print(f"  {hint}, then swipe up to the iOS home screen so the tree gets sent.")
    print("  [Enter] save   [r] retry (discard what arrived so far)   [s] skip   [q] quit")
    mark = capture.mark()
    while True:
        answer = input("  > ").strip().lower()
        if answer == "q":
            return "quit"
        if answer == "s":
            return "skipped"
        if answer == "r":
            mark = capture.mark()
            print("  buffer cleared, go again")
            continue
        singles, dumps = parse(capture.since(mark))
        done = [d for d in dumps if d["complete"]]
        partial = [d for d in dumps if not d["complete"]]
        if done:
            dump = done[-1]
            path = write_tree(name, singles, dump)
            print(f"  saved {os.path.relpath(path, ROOT)}: {describe(dump)}")
            return "saved"
        if partial:
            d = partial[-1]
            print(f"  a dump is still arriving ({d['got']}/{d['total']} parts), wait a moment and press Enter again")
            continue
        if singles:
            print(f"  no tree arrived, only {len(singles)} message line(s):")
            for line in singles[:4]:
                print("    " + line.splitlines()[0][:110])
            if input("  save those anyway? [y/N] ").strip().lower() == "y":
                path = write_tree(name, singles, None)
                print(f"  saved {os.path.relpath(path, ROOT)}")
                return "saved"
            continue
        if not capture.connected:
            print("  nothing captured and no phone connected; plug it in, unlock it, then press Enter")
        else:
            print("  nothing captured yet. Is Spotify open? Did you swipe to the iOS home screen? Press Enter to check again")


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--import":
        singles, dumps = parse(open(sys.argv[2], errors="replace"))
        done = [d for d in dumps if d["complete"]]
        if not done and not singles:
            sys.exit("nothing usable in that log")
        path = write_tree(sys.argv[3], singles, done[-1] if done else None)
        print(f"saved {path}" + (f": {describe(done[-1])}" if done else " (messages only)"))
        return
    if len(sys.argv) > 1:
        sys.exit(__doc__)
    if subprocess.run(["idevice_id", "-l"], capture_output=True, text=True).stdout.strip() == "":
        sys.exit("no iPhone on USB: plug it in, unlock it, tap Trust if asked, then run again")
    screens = load_screens()
    chosen = pick(screens)
    if not chosen:
        return
    capture = Capture()
    try:
        for name, hint in chosen:
            if record(capture, name, hint) == "quit":
                break
    except KeyboardInterrupt:
        print()
    finally:
        capture.stop()
    print("done, trees are in trees/")


if __name__ == "__main__":
    main()
