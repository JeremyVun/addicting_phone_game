#!/usr/bin/env python3
"""Generate Settle's sound effects procedurally into app/assets/audio/ (16-bit mono 44.1 kHz WAV).

Usage: tools/sfx/gen_sfx.py [--out DIR] [--play]
  --play  previews each file with afplay after writing (macOS).

Files: place, clear_1..clear_8 (pitch rises a semitone per combo step), combo_3, combo_5,
combo_8, board_clear, game_over, button, coin, level_up. Sound design: docs/contracts/visual.md.
"""
import argparse, os, subprocess, wave
import numpy as np

SR = 44100

def t(seconds):
    return np.arange(int(SR * seconds)) / SR

def env(n, attack=0.004, decay=0.25, curve=6.0):
    x = np.linspace(0, 1, n)
    a = np.clip(x * (1 / max(attack, 1e-4)) * (1 / SR) * n, 0, 1) if attack > 0 else np.ones(n)
    d = np.exp(-curve * x / max(decay, 1e-4) * (n / SR))
    return a * d

def tone(freq, seconds, harmonics=((1, 1.0), (2, 0.35), (3, 0.12)), decay=0.25, attack=0.003, curve=6.0):
    x = t(seconds)
    y = sum(a * np.sin(2 * np.pi * freq * h * x) for h, a in harmonics)
    return y * env(len(x), attack, decay, curve)

def noise(seconds, decay=0.05):
    x = t(seconds)
    rng = np.random.default_rng(7)
    return rng.standard_normal(len(x)) * env(len(x), 0.001, decay, 8.0)

def lowpass(y, alpha):
    out = np.empty_like(y)
    acc = 0.0
    for i, v in enumerate(y):
        acc += alpha * (v - acc)
        out[i] = acc
    return out

def mix(*parts, offset=0.0):
    parts = list(parts)
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out

def seq(notes, gap):
    out = np.zeros(int(SR * (gap * len(notes) + 0.6)))
    for i, y in enumerate(notes):
        s = int(SR * gap * i)
        out[s : s + len(y)] += y
    return out

def normalize(y, peak=0.85):
    m = np.max(np.abs(y)) or 1.0
    return y / m * peak

def write(path, y):
    y = normalize(y)
    fade = min(len(y), int(SR * 0.008))
    y[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((y * 32767).astype(np.int16).tobytes())

def semitone(base, k):
    return base * 2 ** (k / 12)

def build():
    f = {}
    f["place"] = mix(lowpass(noise(0.06, 0.03), 0.08) * 0.9, tone(160, 0.09, ((1, 1.0), (2, 0.2)), decay=0.05, curve=9.0))
    for k in range(1, 9):
        base = semitone(660, k - 1)
        f[f"clear_{k}"] = mix(tone(base, 0.32, decay=0.22), tone(base * 2, 0.22, ((1, 0.5),), decay=0.12) * 0.5)
    triad = lambda root: [tone(semitone(root, s), 0.28, decay=0.2) for s in (0, 4, 7)]
    f["combo_3"] = seq(triad(523.25), 0.05)
    f["combo_5"] = seq(triad(659.25) + [tone(semitone(659.25, 12), 0.35, decay=0.25)], 0.05)
    f["combo_8"] = seq(triad(783.99) + [tone(semitone(783.99, 12), 0.45, decay=0.3), tone(semitone(783.99, 16), 0.5, decay=0.35)], 0.045)
    f["board_clear"] = seq([tone(semitone(523.25, s), 0.5, decay=0.35) for s in (0, 4, 7, 12, 16, 19)], 0.07)
    f["game_over"] = seq([tone(semitone(220, s), 0.6, ((1, 1.0), (2, 0.25), (0.5, 0.4)), decay=0.5, curve=4.0) for s in (0, -3, -7)], 0.22)
    f["button"] = mix(lowpass(noise(0.03, 0.015), 0.3), tone(1000, 0.03, ((1, 0.6),), decay=0.02, curve=10.0))
    f["coin"] = seq([tone(987.77, 0.12, decay=0.08), tone(1318.5, 0.25, decay=0.18)], 0.07)
    f["level_up"] = seq([tone(semitone(523.25, s), 0.4, decay=0.3) for s in (0, 5, 9, 12)] + [tone(semitone(523.25, 12), 0.7, decay=0.5)], 0.11)
    return f

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "..", "app", "assets", "audio"))
    ap.add_argument("--play", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for name, y in build().items():
        path = os.path.join(a.out, f"{name}.wav")
        write(path, y)
        print(f"{name}.wav {len(y) / SR:.2f}s")
        if a.play:
            subprocess.run(["afplay", path])

if __name__ == "__main__":
    main()
