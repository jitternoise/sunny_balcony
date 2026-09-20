#!/usr/bin/env python3
"""Synthesises every sound effect in game/assets/sfx/ from scratch.

    python3 game/tools/gen_sfx.py            # writes all sounds
    python3 game/tools/gen_sfx.py place win  # just these

The game has no recorded audio: every effect is a few lines of additive
synthesis here, so a sound can be re-tuned by editing its recipe and
re-running, and the .wav files never have to be hand-edited. Output is
16-bit PCM mono at 44.1 kHz, which Godot's WAV importer takes as-is
(AudioStreamWAV, no loop). Noise is seeded per sound, so re-running writes
byte-identical files and git stays quiet unless a recipe changed.

Adding a sound: write a recipe function, add it to SOUNDS under the name
the game will call it by (lowercase letters, digits and underscores -- it
is the file name too), run this, run `godot --headless --import --path
game`, then add the same name to Sfx.SOUNDS in scripts/autoload/Sfx.gd.
Removing one: delete it from both tables (and PEAKS, if it is there) and
delete the .wav and its .import. VerifySfx fails on any drift between the
two tables and the directory; this script reports a stale PEAKS entry and
an orphaned .wav.
"""
import math
import os
import sys
import wave

import numpy as np

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")


# --- building blocks ------------------------------------------------------

def t(seconds):
    """Time axis for a sound of this length."""
    return np.arange(int(RATE * seconds)) / RATE


def sweep(time, f0, f1, shape="sine", curve=1.0):
    """An oscillator gliding from f0 to f1 Hz over the whole of `time`.
    curve > 1 spends longer near f0, < 1 near f1."""
    if len(time) == 0:
        return time
    p = (time / time[-1]) ** curve if time[-1] > 0 else time
    freq = f0 + (f1 - f0) * p
    phase = 2 * math.pi * np.cumsum(freq) / RATE
    if shape == "sine":
        return np.sin(phase)
    if shape == "tri":
        return 2 / math.pi * np.arcsin(np.sin(phase))
    if shape == "square":
        return np.sign(np.sin(phase))
    if shape == "saw":
        return 2 * ((phase / (2 * math.pi)) % 1.0) - 1
    raise ValueError(shape)


def tone(time, freq, shape="sine"):
    return sweep(time, freq, freq, shape)


def noise(time, seed):
    return np.random.default_rng(seed).uniform(-1.0, 1.0, len(time))


def env(time, attack, decay, sustain=0.0, release=0.0, hold=0.0):
    """ADSR-ish envelope: attack up, decay to `sustain`, hold, release to 0."""
    n = len(time)
    a = int(RATE * attack)
    d = int(RATE * decay)
    h = int(RATE * hold)
    r = int(RATE * release)
    e = np.zeros(n)
    i = 0
    if a:
        e[i:i + a] = np.linspace(0, 1, a)[: max(0, n - i)]
        i += a
    if d:
        e[i:i + d] = np.linspace(1, sustain, d)[: max(0, n - i)]
        i += d
    if h:
        e[i:i + h] = sustain
        i += h
    if r:
        e[i:i + r] = np.linspace(sustain, 0, r)[: max(0, n - i)]
        i += r
    return e[:n]


def lowpass(signal, cutoff_hz):
    """One-pole low-pass; `cutoff_hz` may be an array for a sweeping filter."""
    cutoff = np.broadcast_to(np.asarray(cutoff_hz, dtype=float), signal.shape)
    alpha = 1.0 - np.exp(-2 * math.pi * cutoff / RATE)
    out = np.empty_like(signal)
    y = 0.0
    for i in range(len(signal)):
        y += alpha[i] * (signal[i] - y)
        out[i] = y
    return out


def highpass(signal, cutoff_hz):
    return signal - lowpass(signal, cutoff_hz)


def mix(*parts):
    """Sum parts of different lengths, zero-padded to the longest."""
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def delay(signal, seconds):
    return np.concatenate([np.zeros(int(RATE * seconds)), signal])


def normalise(signal, peak=0.8):
    m = np.max(np.abs(signal))
    return signal * (peak / m) if m > 0 else signal


def fade_out(signal, seconds=0.01):
    """A few ms of fade at the very end so no sound stops on a click."""
    n = min(len(signal), int(RATE * seconds))
    if n:
        signal[-n:] *= np.linspace(1, 0, n)
    return signal


# --- the recipes ----------------------------------------------------------
# Each returns a float array in roughly -1..1; normalise() sets the level.

def ui_tap():
    """A soft click for any button."""
    x = t(0.06)
    return sweep(x, 1400, 900) * env(x, 0.002, 0.05) + noise(x, 1) * env(x, 0.0, 0.01) * 0.3


def place():
    """A block set down: a short wooden thock. The body is low, but a phone
    speaker rolls off under ~400 Hz, so a higher partial and the knock carry
    it there -- see PHONE_BAND_HZ."""
    x = t(0.16)
    body = sweep(x, 330, 220, curve=0.5) * env(x, 0.002, 0.12) * 0.35
    partial = sweep(x, 880, 600, curve=0.5) * env(x, 0.002, 0.07) * 0.9
    knock = lowpass(noise(x, 2), 4000) * env(x, 0.0, 0.035) * 1.2
    return body + partial + knock


def pickup():
    """A block lifted off again: the thock, backwards."""
    x = t(0.12)
    return sweep(x, 260, 520) * env(x, 0.005, 0.1) + lowpass(noise(x, 3), 2500) * env(x, 0.0, 0.015) * 0.4


def invalid():
    """A placement the board refused: a short buzz, two steps down. Squares
    at 220/165 Hz through a gentle low-pass, so the harmonics a phone can
    reproduce carry it without the rasp a raw square has."""
    x = t(0.18)
    first = tone(t(0.08), 220, "square") * env(t(0.08), 0.002, 0.07)
    second = tone(t(0.10), 165, "square") * env(t(0.10), 0.002, 0.09)
    return lowpass(mix(first, delay(second, 0.08)), 2500)


def start():
    """The flood released: a rising rush of water."""
    x = t(0.5)
    rush = lowpass(noise(x, 4), 400 + 3600 * (x / x[-1])) * env(x, 0.15, 0.35)
    swell = sweep(x, 180, 420, curve=1.5) * env(x, 0.2, 0.3) * 0.5
    return rush + swell


def drop():
    """One beat of water moving: a very small plip. It is the flood's clock
    -- every 1.2 s for the whole run -- so it is short, soft and pitched
    where it will not fatigue."""
    x = t(0.05)
    return sweep(x, 700, 450) * env(x, 0.002, 0.045)


def pool_fill():
    """A drop landing in a pool: a bloop, rising the way a drip does."""
    x = t(0.14)
    return sweep(x, 320, 760, curve=0.6) * env(x, 0.003, 0.13)


def pool_full():
    """A pool filled: two bright notes ringing together."""
    x = t(0.55)
    a = tone(x, 880) * env(x, 0.005, 0.5)
    b = tone(t(0.45), 1320) * env(t(0.45), 0.005, 0.4)
    return mix(a, delay(b, 0.06) * 0.7)


def fire_out():
    """A fire put out: a hiss of steam dying away."""
    x = t(0.4)
    hiss = highpass(lowpass(noise(x, 5), 6000), 1500) * env(x, 0.005, 0.38)
    sigh = sweep(x, 520, 180) * env(x, 0.01, 0.3) * 0.35
    return hiss + sigh


def geyser():
    """A geyser waking: a rumble under a burst of spray. The spray carries
    the level; the rumble sits at 110/220 Hz rather than 55, which a phone
    speaker would simply lose."""
    x = t(0.6)
    rumble = (tone(x, 110) + tone(x, 220) * 0.5) * env(x, 0.05, 0.5) * 0.4
    spray = lowpass(noise(x, 6), 3000 + 3000 * (1 - x / x[-1])) * env(x, 0.08, 0.45)
    return rumble + spray


def hydro():
    """A plant spinning up: a whirr climbing in pitch."""
    x = t(0.7)
    whirr = sweep(x, 90, 380, "saw", curve=0.8)
    tremolo = 1 - 0.35 * (0.5 + 0.5 * np.sin(2 * math.pi * 18 * x))
    return lowpass(whirr * tremolo, 1800) * env(x, 0.1, 0.55)


def dig():
    """Earth being dug: three quick scrapes."""
    scrape = lowpass(noise(t(0.07), 7), 2200) * env(t(0.07), 0.005, 0.06)
    return mix(scrape, delay(scrape * 0.9, 0.08), delay(scrape * 0.8, 0.16))


def blast():
    """The bomb catapult's charge going off: the crack carries it, the
    thump underneath is felt on headphones and lost on a phone."""
    x = t(0.7)
    thump = sweep(x, 180, 50, curve=0.5) * env(x, 0.002, 0.6) * 0.55
    crack = lowpass(noise(x, 8), 5000 * (1 - x / x[-1]) + 300) * env(x, 0.0, 0.4)
    return thump + crack


def splash():
    """Water lost over the edge: a falling splash."""
    x = t(0.45)
    fall = sweep(x, 700, 180, curve=0.7) * env(x, 0.005, 0.35) * 0.6
    spray = lowpass(noise(x, 9), 3500) * env(x, 0.02, 0.4)
    return fall + spray


def win():
    """The level won: a little rising arpeggio."""
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for i, f in enumerate(notes):
        x = t(0.45 if i < 3 else 0.8)
        parts.append(delay(tone(x, f) * env(x, 0.005, 0.4 if i < 3 else 0.75), 0.11 * i))
    return mix(*parts)


def lose():
    """The level lost: two notes stepping down."""
    x1 = t(0.3)
    x2 = t(0.6)
    a = tone(x1, 329.63, "tri") * env(x1, 0.01, 0.28)
    b = tone(x2, 246.94, "tri") * env(x2, 0.01, 0.55)
    return lowpass(mix(a, delay(b, 0.3)), 2000)


def pause():
    """The pause menu opening: a soft pop downward."""
    x = t(0.09)
    return sweep(x, 520, 300) * env(x, 0.003, 0.08)


def resume():
    """...and closing: the same pop, upward."""
    x = t(0.09)
    return sweep(x, 300, 520) * env(x, 0.003, 0.08)


SOUNDS = {
    "ui_tap": ui_tap,
    "place": place,
    "pickup": pickup,
    "invalid": invalid,
    "start": start,
    "drop": drop,
    "pool_fill": pool_fill,
    "pool_full": pool_full,
    "fire_out": fire_out,
    "geyser": geyser,
    "hydro": hydro,
    "dig": dig,
    "blast": blast,
    "splash": splash,
    "win": win,
    "lose": lose,
    "pause": pause,
    "resume": resume,
}

# Peak level per sound, where the default 0.8 is wrong: the per-beat drop
# is deliberately quiet, the big one-offs a touch louder. A name here that
# is not in SOUNDS is reported by main(), so this table cannot go stale.
PEAKS = {"drop": 0.3, "ui_tap": 0.6, "blast": 0.9, "win": 0.85, "geyser": 0.85}

# What a phone loudspeaker can reproduce, roughly: everything under this is
# lost. main() reports each sound's loudness above it, because a sound that
# is all sub-bass looks fine as a waveform and vanishes on the device the
# game targets. Every sound bar the two quiet ones must beat the drop here.
PHONE_BAND_HZ = 400.0
QUIET_BY_DESIGN = {"drop", "ui_tap"}


def phone_band_db(signal):
    """Loudest 100 ms of the sound above PHONE_BAND_HZ, in dBFS: what a
    phone speaker will actually produce. A 2nd-order Butterworth high-pass
    (RBJ cookbook), then a sliding RMS."""
    w0 = 2 * math.pi * PHONE_BAND_HZ / RATE
    alpha = math.sin(w0) / (2 * math.sqrt(0.5))
    cw = math.cos(w0)
    b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    y = np.zeros_like(signal)
    x1 = x2 = y1 = y2 = 0.0
    for i, x0 in enumerate(signal):
        y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        y[i] = y0
        x2, x1, y2, y1 = x1, x0, y1, y0
    window = int(RATE * 0.1)
    if len(y) <= window:
        rms = math.sqrt(np.mean(y * y)) if len(y) else 0.0
    else:
        sq = np.convolve(y * y, np.ones(window) / window, mode="valid")
        rms = math.sqrt(sq.max())
    return 20 * math.log10(rms) if rms > 0 else -120.0


def write(name, signal):
    signal = fade_out(normalise(signal, PEAKS.get(name, 0.8)))
    data = np.clip(signal, -1.0, 1.0)
    pcm = (data * 32767).astype("<i2")
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    return path, len(pcm) / RATE, phone_band_db(data)


def main(argv):
    os.makedirs(OUT_DIR, exist_ok=True)
    names = argv or list(SOUNDS)
    unknown = [n for n in names if n not in SOUNDS]
    if unknown:
        sys.exit("unknown sound(s): %s -- known: %s" % (", ".join(unknown), ", ".join(SOUNDS)))
    stale = [n for n in PEAKS if n not in SOUNDS]
    if stale:
        sys.exit("PEAKS names sounds that do not exist: %s" % ", ".join(stale))
    orphans = sorted(f[:-4] for f in os.listdir(OUT_DIR) if f.endswith(".wav") and f[:-4] not in SOUNDS)
    if orphans:
        print("warning: .wav with no recipe (delete them and their .import): %s" % ", ".join(orphans))
    loudness = {}
    for name in names:
        path, seconds, db = write(name, SOUNDS[name]())
        loudness[name] = db
        print("%-10s %.2fs  %6.1f dB on a phone  %s" % (name, seconds, db, os.path.relpath(path)))
    if "drop" in loudness:
        buried = [n for n, db in loudness.items() if n not in QUIET_BY_DESIGN and db <= loudness["drop"]]
        if buried:
            print("warning: no louder than the per-beat drop above %d Hz: %s" % (PHONE_BAND_HZ, ", ".join(buried)))


if __name__ == "__main__":
    main(sys.argv[1:])
