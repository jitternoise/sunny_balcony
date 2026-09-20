#!/usr/bin/env python3
"""Composes the ten background loops in game/assets/music/, one per ten
levels, from scratch.

    python3 game/tools/gen_music.py               # writes all ten
    python3 game/tools/gen_music.py 03 07         # just decades 3 and 7

Like the effects (gen_sfx.py) nothing is recorded: each track is a SONG
spec below -- a key, a mode, a chord progression, which instruments play
which pattern -- rendered by a tiny sequencer over additive-synthesis
instruments. Everything is periodic and note tails wrap around to the
start, so each file loops seamlessly. All ten run at 100 BPM: a beat is
0.6 s, exactly two of the simulation's 0.3 s beats, so the music's tempo
and the water's agree (the phase does not -- a loop starts when a screen
does, not when Start is pressed); a loop is 8 bars = 19.2 s = 16
measures of play. 16-bit mono at 22.05 kHz -- these are soft synth pads
and plucks with nothing above 10 kHz worth keeping, and the file is half
the size. Noise is seeded per track, so re-running writes byte-identical
files.

The track for a set of levels is Music.TRACKS[Backdrop.index_for_level()]
in scripts/autoload/Music.gd; the names here match the Backdrop palette
names so the two tables read as one.

Adding or changing a track: edit its SONG entry, run this, run
`godot --headless --import --path game`, and keep Music.TRACKS in step
(VerifyMusic fails on any drift). A NEW file imports with
edit/loop_mode=0 (play once): set it to 2 -- Forward; 1 is Disabled --
in the .import and import again. A new decade would need a palette in
Backdrop.PALETTES too.
"""
import math
import os
import sys
import wave

import numpy as np

RATE = 22050
BPM = 100.0
BEAT = 60.0 / BPM          # 0.6 s -- two simulation beats
BARS = 8
BEATS_PER_BAR = 4
LOOP_SECONDS = BARS * BEATS_PER_BAR * BEAT   # 19.2 s
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "music")

MAJOR = [0, 2, 4, 5, 7, 9, 11]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
MIXOLYDIAN = [0, 2, 4, 5, 7, 9, 10]
AEOLIAN = [0, 2, 3, 5, 7, 8, 10]
LYDIAN = [0, 2, 4, 6, 7, 9, 11]
PENTATONIC = [0, 2, 4, 7, 9]


def midi_hz(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


# --- instruments: each returns samples for one note, tail included --------

def _t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def _onset(x, ms=4.0):
    """A few ms of ramp at the start so a note never begins on a click."""
    n = min(len(x), int(RATE * ms / 1000.0))
    if n:
        x[:n] *= np.linspace(0.0, 1.0, n)
    return x


def _release(x, ms=12.0):
    """A half-cosine fade over the last few ms so a note never ENDS on a
    click either: a decaying note is cut wherever its envelope happens to
    be, and a bass hit is still at half amplitude after one beat. The
    review measured -16 dBFS steps at every bar line without this."""
    n = min(len(x), int(RATE * ms / 1000.0))
    if n:
        x[-n:] *= 0.5 * (1.0 + np.cos(np.linspace(0.0, math.pi, n)))
    return x


NYQUIST = RATE / 2.0


def pluck(hz, dur, rng, bright=1.0):
    """A plucked string: harmonics that decay faster the higher they are,
    so the note starts bright and dulls, plus a whisper of pick noise."""
    t = _t(dur)
    out = np.zeros_like(t)
    for k in range(1, 9):
        if hz * k >= NYQUIST:
            break   # a partial past Nyquist would fold back as an inharmonic tone
        amp = (1.0 / k ** 1.1) * (bright if k > 1 else 1.0)
        out += amp * np.sin(2 * math.pi * hz * k * t) * np.exp(-t * (2.5 + 1.6 * k))
    out += rng.uniform(-1, 1, len(t)) * np.exp(-t * 400.0) * 0.08
    return _release(_onset(out * 0.5))


def bell(hz, dur, rng=None):
    """A small bell: a fundamental with two inharmonic partials, ringing."""
    t = _t(dur)
    out = np.zeros_like(t)
    for ratio, amp, decay in ((1.0, 1.0, 1.8), (2.76, 0.45, 3.5), (5.4, 0.2, 6.0)):
        if hz * ratio < NYQUIST:
            out += amp * np.sin(2 * math.pi * hz * ratio * t) * np.exp(-t * decay)
    return _release(_onset(out * 0.5))


def pad(hz, dur, rng=None, attack=0.35, release=0.4):
    """A soft pad: two detuned voices of the first few harmonics, slow in
    and out. `dur` is the sounding length; the release is added after."""
    t = _t(dur + release)
    out = np.zeros_like(t)
    for detune in (-0.004, 0.004):
        f = hz * (1 + detune)
        for k in range(1, 6):
            out += (1.0 / k ** 1.6) * np.sin(2 * math.pi * f * k * t + k * 0.7)
    env = np.ones_like(t)
    a = int(RATE * attack)
    env[:a] = np.linspace(0, 1, a)
    r = int(RATE * release)
    env[-r:] = np.linspace(1, 0, r)
    return out * env * 0.22


def bass(hz, dur, rng=None):
    """A round bass: a sine under a soft triangle, decaying over the note."""
    t = _t(dur + 0.03)   # the release rides past the note's end
    tri = 2 / math.pi * np.arcsin(np.sin(2 * math.pi * hz * t))
    out = np.sin(2 * math.pi * hz * t) + 0.35 * tri
    return _release(_onset(out * np.exp(-t * 1.2) * 0.6), 30.0)


def kick(rng):
    t = _t(0.25)
    return _release(_onset(np.sin(2 * math.pi * np.cumsum(120.0 * np.exp(-t * 18.0) + 42.0) / RATE) * np.exp(-t * 9.0) * 0.9))


def hat(rng, dur=0.05):
    t = _t(dur)
    n = rng.uniform(-1, 1, len(t))
    n = n - np.convolve(n, np.ones(9) / 9.0, mode="same")   # crude high-pass
    return n * np.exp(-t * 60.0) * 0.35


def shaker(rng, dur=0.09):
    t = _t(dur)
    n = rng.uniform(-1, 1, len(t))
    n = n - np.convolve(n, np.ones(5) / 5.0, mode="same")
    return n * np.exp(-t * 35.0) * 0.18


INSTRUMENTS = {"pluck": pluck, "bell": bell, "pad": pad, "bass": bass}


# --- the sequencer ---------------------------------------------------------

class Loop:
    """A buffer exactly one loop long; anything placed past its end wraps to
    the start, which is what makes the loop seamless."""

    def __init__(self):
        self.n = int(round(RATE * LOOP_SECONDS))
        self.buf = np.zeros(self.n)

    def place(self, start_seconds, samples, gain=1.0):
        start = int(round(start_seconds * RATE)) % self.n
        end = start + len(samples)
        if end <= self.n:
            self.buf[start:end] += samples * gain
        else:
            first = self.n - start
            self.buf[start:] += samples[:first] * gain
            rest = samples[first:]
            self.buf[: len(rest)] += rest[: self.n] * gain


def scale_note(root, mode, degree, octave=0):
    """MIDI note of `degree` (0-based, any range) in the scale."""
    return root + 12 * (octave + degree // len(mode)) + mode[degree % len(mode)]


def chord_tones(root, mode, degree, size=3):
    return [scale_note(root, mode, degree + 2 * i) for i in range(size)]


def render(song):
    rng = np.random.default_rng(song["seed"])
    loop = Loop()
    root, mode = song["root"], song["mode"]
    chords = song["chords"]                 # one degree per bar, len BARS
    g = song.get("gains", {})

    # Pad: the chord, held for the bar.
    if song.get("pad", True):
        for bar, degree in enumerate(chords):
            start = bar * BEATS_PER_BAR * BEAT
            for note in chord_tones(root, mode, degree, song.get("pad_size", 3)):
                loop.place(start, pad(midi_hz(note - 12 * song.get("pad_down", 0)), BEATS_PER_BAR * BEAT),
                           g.get("pad", 0.35))

    # Bass: the chord's root, on the given beats of every bar.
    for bar, degree in enumerate(chords):
        for beat, dur in song.get("bass_hits", [(0, 2.0), (2, 2.0)]):
            note = scale_note(root, mode, degree) - 24 + song.get("bass_up", 0)
            loop.place((bar * BEATS_PER_BAR + beat) * BEAT, bass(midi_hz(note), dur * BEAT), g.get("bass", 0.5))

    # Lead: an arpeggio over the chord, `steps` per bar, each an index into
    # the chord tones (-1 rests); the instrument is the song's choice.
    lead = INSTRUMENTS[song.get("lead", "pluck")]
    pattern = song["arp"]
    steps = len(pattern)
    step = BEATS_PER_BAR * BEAT / steps
    for bar, degree in enumerate(chords):
        tones = chord_tones(root, mode, degree, 4)
        for i, idx in enumerate(pattern):
            if idx < 0:
                continue
            note = tones[idx % len(tones)] + 12 * (idx // len(tones)) + 12 * song.get("lead_up", 0)
            lead_kw = {"bright": song["bright"]} if "bright" in song else {}
            samples = lead(midi_hz(note), song.get("lead_len", 1.2), rng, **lead_kw)
            loop.place(bar * BEATS_PER_BAR * BEAT + i * step, samples, g.get("lead", 0.5))

    # Sparkle: an occasional bell, high, on the listed (bar, beat) spots.
    for bar, beat, idx in song.get("bells", []):
        tones = chord_tones(root, mode, chords[bar], 4)
        note = tones[idx % len(tones)] + 12 * (idx // len(tones)) + 12
        loop.place((bar * BEATS_PER_BAR + beat) * BEAT, bell(midi_hz(note), 2.5), g.get("bell", 0.3))

    # Percussion: kick on the listed beats, hats/shaker at a subdivision.
    perc = song.get("perc", "none")
    for bar in range(BARS):
        base = bar * BEATS_PER_BAR
        if perc in ("full",):
            for beat in (0, 2):
                loop.place((base + beat) * BEAT, kick(rng), g.get("kick", 0.7))
            for eighth in range(BEATS_PER_BAR * 2):
                loop.place((base + eighth / 2.0) * BEAT, hat(rng), g.get("hat", 0.5) * (1.0 if eighth % 2 else 0.6))
        elif perc == "light":
            for eighth in range(BEATS_PER_BAR * 2):
                if eighth % 2 == 1:
                    loop.place((base + eighth / 2.0) * BEAT, shaker(rng), g.get("shaker", 0.6))
        elif perc == "soft":
            for beat in (1, 3):
                loop.place((base + beat) * BEAT, hat(rng, 0.03), g.get("hat", 0.3))

    return loop.buf


# --- the songs: one per ten levels, named after the backdrop -------------
# chords: a scale degree per bar (0 = I). arp: chord-tone indices per step
# over the bar (4 = quarters, 8 = eighths, 12 = triplet eighths, 16 =
# sixteenths); -1 is a rest; 4+ climbs an octave.

SONGS = [
    dict(name="01_spring_meadow", seed=101, root=60, mode=MAJOR,
         chords=[0, 4, 5, 3, 0, 4, 3, 4],
         arp=[0, 1, 2, 1, 0, 1, 2, 3], lead="pluck", lead_len=1.0,
         bass_hits=[(0, 2.0), (2, 2.0)], perc="light",
         gains=dict(pad=0.3, bass=0.45, lead=0.5, shaker=0.5)),
    dict(name="02_deep_valley", seed=102, root=57, mode=DORIAN,
         chords=[0, 0, 3, 3, 5, 5, 6, 4],
         arp=[0, -1, 1, -1, 2, -1, 1, -1], lead="pluck", lead_len=1.6, bright=0.7,
         bass_hits=[(0, 4.0)], perc="none",
         bells=[(1, 2, 4), (3, 2, 5), (5, 2, 4), (7, 1, 6)],
         gains=dict(pad=0.45, bass=0.45, lead=0.4, bell=0.25)),
    dict(name="03_morning_riverbank", seed=103, root=67, mode=MAJOR,
         chords=[0, 3, 4, 0, 5, 3, 4, 4],
         arp=[0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 2, 1], lead="pluck", lead_len=0.8,
         bass_hits=[(0, 1.5), (1.5, 1.0), (3, 1.0)], perc="soft",
         gains=dict(pad=0.28, bass=0.45, lead=0.48, hat=0.25)),
    dict(name="04_dry_season", seed=104, root=62, mode=MIXOLYDIAN,
         chords=[0, 0, 6, 6, 0, 0, 3, 6],
         arp=[0, -1, -1, 2, -1, 1, -1, -1], lead="pluck", lead_len=1.8,
         bass_hits=[(0, 3.0), (3, 1.0)], perc="light",
         gains=dict(pad=0.22, bass=0.5, lead=0.45, shaker=0.35)),
    dict(name="05_evening_pines", seed=105, root=64, mode=AEOLIAN,
         chords=[0, 5, 2, 6, 0, 5, 3, 4],
         arp=[0, 2, 1, 3], lead="bell", lead_len=2.0,
         bass_hits=[(0, 4.0)], perc="none", pad_size=4,
         gains=dict(pad=0.42, bass=0.4, lead=0.3)),
    dict(name="06_golden_plains", seed=106, root=65, mode=MAJOR,
         chords=[0, 0, 3, 3, 4, 4, 0, 0],
         arp=[0, 4, 2, 4, 1, 4, 2, 4], lead="pluck", lead_len=0.9,
         bass_hits=[(0, 2.0), (2, 1.0), (3, 1.0)], perc="full", pad_size=2,
         gains=dict(pad=0.3, bass=0.5, lead=0.42, kick=0.6, hat=0.35)),
    dict(name="07_geyser_country", seed=107, root=70, mode=LYDIAN,
         chords=[0, 1, 0, 1, 3, 4, 0, 1],
         arp=[0, 2, 4, 2, 1, 3, 5, 3, 0, 2, 4, 2, 1, 3, 5, 3], lead="pluck", lead_len=0.6, lead_up=1,
         bass_hits=[(0, 1.0), (1, 1.0), (2, 1.0), (3, 1.0)], perc="soft",
         bells=[(0, 0, 6), (2, 0, 7), (4, 0, 6), (6, 0, 8)],
         gains=dict(pad=0.25, bass=0.4, lead=0.36, bell=0.22, hat=0.3)),
    dict(name="08_badger_dusk", seed=108, root=61, mode=AEOLIAN,
         chords=[0, 0, 5, 5, 0, 0, 6, 4],
         arp=[0, -1, -1, -1, 2, -1, -1, -1], lead="bell", lead_len=3.0,
         bass_hits=[(0, 4.0)], perc="none", pad_down=1, pad_size=4,
         gains=dict(pad=0.5, bass=0.45, lead=0.28)),
    dict(name="09_jamboree_sunset", seed=109, root=69, mode=MAJOR,
         chords=[0, 4, 5, 3, 0, 4, 3, 4],
         arp=[0, 1, 2, 4, 3, 2, 1, 2], lead="pluck", lead_len=0.8,
         bass_hits=[(0, 1.0), (1.5, 0.5), (2, 1.0), (3.5, 0.5)], perc="full",
         gains=dict(pad=0.3, bass=0.55, lead=0.5, kick=0.7, hat=0.45)),
    dict(name="10_the_pan", seed=110, root=62, mode=PENTATONIC,
         chords=[0, 0, 3, 3, 1, 1, 4, 4],
         arp=[0, -1, -1, -1, -1, -1, 3, -1], lead="bell", lead_len=3.0, lead_up=1,
         bass_hits=[(0, 4.0)], perc="soft", pad_size=4,
         gains=dict(pad=0.5, bass=0.35, lead=0.25, hat=0.18)),
]


TARGET_RMS_DB = -16.0
PEAK_CEILING = 0.9


def write(name, signal):
    # Level by loudness, not by peak: peak-normalised, the tracks with
    # kicks and hats came out 3 dB quieter than the pad-heavy ones. RMS to
    # TARGET_RMS_DB, then a ceiling no track reaches today.
    signal = signal - np.mean(signal)
    rms = math.sqrt(float(np.mean(signal ** 2)))
    if rms > 0:
        signal = signal * (10 ** (TARGET_RMS_DB / 20.0) / rms)
    peak = float(np.max(np.abs(signal)))
    if peak > PEAK_CEILING:
        signal = signal * (PEAK_CEILING / peak)
    pcm = (np.clip(signal, -1.0, 1.0) * 32767).astype("<i2")
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    rms = math.sqrt(float(np.mean(signal ** 2)))
    # The loop seam: the step from the last sample to the first, against
    # the track's own typical sample-to-sample step. Over ~2x is a click.
    seam = abs(float(signal[0]) - float(signal[-1])) / max(float(np.percentile(np.abs(np.diff(signal)), 95)), 1e-9)
    return path, len(pcm) / RATE, 20 * math.log10(rms), float(np.max(np.abs(signal))), seam


def main(argv):
    os.makedirs(OUT_DIR, exist_ok=True)
    wanted = argv or [s["name"][:2] for s in SONGS]
    known = {s["name"][:2]: s for s in SONGS}
    unknown = [w for w in wanted if w not in known]
    if unknown:
        sys.exit("unknown track(s): %s -- known: %s" % (", ".join(unknown), ", ".join(known)))
    orphans = sorted(f[:-4] for f in os.listdir(OUT_DIR)
                     if f.endswith(".wav") and f[:-4] not in {s["name"] for s in SONGS})
    if orphans:
        print("warning: .wav with no song (delete them and their .import): %s" % ", ".join(orphans))
    for key in wanted:
        song = known[key]
        path, seconds, rms_db, peak, seam = write(song["name"], render(song))
        flag = "  <-- seam click" if seam > 2.0 else ""
        print("%-22s %.1fs  rms %5.1f dB  peak %.2f  seam x%.1f%s  %s"
              % (song["name"], seconds, rms_db, peak, seam, flag, os.path.relpath(path)))


if __name__ == "__main__":
    main(sys.argv[1:])
