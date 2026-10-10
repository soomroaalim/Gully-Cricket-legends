#!/usr/bin/env python3
"""Synthesize original SFX + music loop WAVs for Gully Cricket Legends.

Stdlib only (wave, struct, math, random). All sounds are generated from
scratch -- no samples, no copyrighted material. Seeded RNG makes the output
deterministic, so the script is idempotent: re-running overwrites identical
files. Output: mono 22050 Hz 16-bit WAVs in assets/sfx/.
"""

import math
import os
import random
import struct
import wave

SR = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "assets", "sfx")
RNG = random.Random(20261008)  # fixed seed -> deterministic, idempotent


def n_samples(seconds: float) -> int:
    return int(SR * seconds)


def sine(f: float, t: float) -> float:
    return math.sin(2.0 * math.pi * f * t)


def square(f: float, t: float) -> float:
    return 1.0 if math.sin(2.0 * math.pi * f * t) >= 0.0 else -1.0


def decay(t: float, tau: float) -> float:
    return math.exp(-t / tau) if t >= 0.0 else 0.0


def noise() -> float:
    return RNG.uniform(-1.0, 1.0)


def lowpass_noise(alpha: float):
    """Simple one-pole lowpass filter for shaping noise."""
    y = 0.0

    def step(x: float) -> float:
        nonlocal y
        y = y * alpha + x * (1.0 - alpha)
        return y

    return step


def write_wav(name: str, samples) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    peak = max(max(abs(s) for s in samples), 1e-9)
    gain = 0.89 / peak
    frames = struct.pack(
        "<" + "h" * len(samples),
        *[int(max(-1.0, min(1.0, s * gain)) * 32767) for s in samples],
    )
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print("wrote %s (%.2fs)" % (path, len(samples) / SR))


def pluck(f: float, tl: float, tau: float, bright: float = 0.35) -> float:
    """Plucky tone: fundamental + soft 2nd harmonic, fast attack, exp decay."""
    if tl < 0.0:
        return 0.0
    attack = min(tl / 0.005, 1.0)
    return (sine(f, tl) + bright * sine(2.0 * f, tl)) * attack * decay(tl, tau)


def make_hit():
    """Bat hit: short noise burst + 180 Hz thump, ~0.25s."""
    n = n_samples(0.25)
    out = []
    for i in range(n):
        t = i / SR
        thump = sine(180.0, t) * decay(t, 0.05)
        burst = noise() * decay(t, 0.008) * 0.6 if t < 0.03 else 0.0
        out.append(thump + burst)
    write_wav("hit", out)


def make_bounce():
    """Soft 300 Hz blip decay, ~0.15s."""
    n = n_samples(0.15)
    out = [ (sine(300.0, i / SR) + 0.25 * sine(600.0, i / SR))
            * decay(i / SR, 0.03) for i in range(n) ]
    write_wav("bounce", out)


def make_wicket():
    """Wooden crack: two detuned square bursts + noise, ~0.4s."""
    n = n_samples(0.40)
    out = []
    for i in range(n):
        t = i / SR
        v = square(220.0, t) * decay(t, 0.035) * 0.7
        t2 = t - 0.12
        if t2 >= 0.0:
            v += square(233.0, t2) * decay(t2, 0.05) * 0.7
        if t < 0.16:
            v += noise() * decay(t, 0.02) * 0.5
        out.append(v)
    write_wav("wicket", out)


def make_crowd():
    """Filtered noise swell, 1.2s (approximate crowd cheer)."""
    n = n_samples(1.2)
    lp = lowpass_noise(0.92)
    out = []
    for i in range(n):
        t = i / SR
        x = lp(noise()) * 3.0
        env = min(t / 0.30, 1.0) * decay(max(0.0, t - 0.30), 0.90)
        out.append(x * env)
    write_wav("crowd", out)


def make_click():
    """Tiny 800 Hz square blip, ~0.07s."""
    n = n_samples(0.07)
    out = [square(800.0, i / SR) * decay(i / SR, 0.015) * 0.6
           for i in range(n)]
    write_wav("click", out)


def make_win():
    """Rising major arpeggio C-E-G-C, ~0.9s."""
    notes = [(261.63, 0.000), (329.63, 0.225),
             (392.00, 0.450), (523.25, 0.675)]
    n = n_samples(0.9)
    out = [0.0] * n
    for f, start in notes:
        for i in range(n):
            t = i / SR
            tl = t - start
            if 0.0 <= tl:
                out[i] += pluck(f, tl, 0.22) * 0.7
    write_wav("win", out)


def make_loss():
    """Descending minor A-F-D, ~0.9s."""
    notes = [(220.00, 0.0), (174.61, 0.3), (146.83, 0.6)]
    n = n_samples(0.9)
    out = [0.0] * n
    for f, start in notes:
        for i in range(n):
            t = i / SR
            tl = t - start
            if 0.0 <= tl:
                vib = 1.0 + 0.004 * sine(5.0, tl)
                out[i] += pluck(f * vib, tl, 0.28, bright=0.15) * 0.7
    write_wav("loss", out)


def make_coin():
    """Two sine pings 990 -> 1320 Hz, ~0.3s."""
    n = n_samples(0.30)
    out = []
    for i in range(n):
        t = i / SR
        if t < 0.10:
            v = sine(990.0, t) * decay(t, 0.06)
        else:
            tl = t - 0.10
            v = sine(1320.0, tl) * decay(tl, 0.12)
        out.append(v)
    write_wav("coin", out)


def make_unlock():
    """Sparkle arpeggio up: C5 D5 E5 G5 C6, ~0.7s."""
    freqs = [523.25, 587.33, 659.25, 783.99, 1046.50]
    step = 0.14
    n = n_samples(0.7)
    out = [0.0] * n
    for k, f in enumerate(freqs):
        start = k * step
        for i in range(n):
            tl = i / SR - start
            if 0.0 <= tl:
                out[i] += pluck(f, tl, 0.10, bright=0.5) * 0.55
    write_wav("unlock", out)


def make_six():
    """Rising whoosh + crowd-ish noise swell, ~1.0s."""
    n = n_samples(1.0)
    lp = lowpass_noise(0.90)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 200.0 + 700.0 * t  # rising sweep 200 -> 900 Hz
        phase += 2.0 * math.pi * f / SR
        sweep = math.sin(phase) * (t ** 1.5) * 0.5
        whoosh = lp(noise()) * 3.0 * (t ** 2.0) * 0.8
        end_swell = 0.0
        if t > 0.7:
            e = (t - 0.7) / 0.3
            end_swell = noise() * math.sin(math.pi * e) * 0.9
        out.append(sweep + whoosh + end_swell)
    write_wav("six", out)


def make_four():
    """Short clap burst + blip, ~0.5s."""
    n = n_samples(0.5)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        v = 0.0
        for clap_t in (0.0, 0.09, 0.18):
            tl = t - clap_t
            if 0.0 <= tl:
                v += noise() * decay(tl, 0.02) * 0.8
        tl = t - 0.27
        if 0.0 <= tl:
            v += (sine(500.0, tl) + 0.2 * sine(1000.0, tl)) * decay(tl, 0.06) * 0.7
        out[i] = v
    write_wav("four", out)


def make_ball():
    """Soft 500 Hz tick, ~0.08s."""
    n = n_samples(0.08)
    out = [sine(500.0, i / SR) * decay(i / SR, 0.02) * 0.8
           for i in range(n)]
    write_wav("ball", out)


# ---------------------------------------------------------------- music loop
# Cheerful 8.0s seamless loop: 120 BPM -> 0.5s per beat, 16 beats.
# Chord progression: C - F - G - C (4 beats each). Plucky square-ish melody,
# root-note bass, soft chord pad, kick + hat percussion.

_BEAT = 0.5
_MIDI_A4 = 69


def _midi_to_freq(m: int) -> float:
    return 440.0 * (2.0 ** ((m - _MIDI_A4) / 12.0))


def make_music_loop():
    beats = 16
    dur = beats * _BEAT
    n = n_samples(dur)
    out = [0.0] * n

    # Bass roots per bar (C2, F2, G2, C2), quarter-note plucks.
    bass_roots = [36, 41, 43, 36]  # MIDI: C2 F2 G2 C2
    for bar in range(4):
        root = bass_roots[bar]
        for beat in range(4):
            start = (bar * 4 + beat) * _BEAT
            f = _midi_to_freq(root)
            i0 = int(start * SR)
            i1 = min(n, i0 + n_samples(_BEAT))
            for i in range(i0, i1):
                tl = i / SR - start
                out[i] += (sine(f, tl) * 0.9 + 0.25 * square(f, tl)) \
                    * min(tl / 0.01, 1.0) * decay(tl, 0.18) * 0.50

    # Soft chord pad per bar: triads, slow attack, released at bar end.
    chords = [
        [48, 52, 55],  # C3 E3 G3
        [53, 57, 60],  # F3 A3 C4
        [55, 59, 62],  # G3 B3 D4
        [48, 52, 55],  # C3 E3 G3
    ]
    for bar, triad in enumerate(chords):
        start = bar * 4 * _BEAT
        span = 4 * _BEAT
        i0 = int(start * SR)
        i1 = min(n, i0 + n_samples(span))
        for i in range(i0, i1):
            tl = i / SR - start
            env = min(tl / 0.4, 1.0) * min((span - tl) / 0.2, 1.0)
            v = 0.0
            for m in triad:
                v += sine(_midi_to_freq(m), tl)
            out[i] += v * env * 0.055

    # Cheerful plucky melody, quarter notes (MIDI).
    melody = [64, 67, 69, 67,   # E4 G4 A4 G4  (over C)
              69, 72, 69, 67,   # A4 C5 A4 G4  (over F)
              67, 71, 74, 71,   # G4 B4 D5 B4  (over G)
              72, 67, 64, 60]   # C5 G4 E4 C4  (over C)
    for b, m in enumerate(melody):
        start = b * _BEAT
        f = _midi_to_freq(m)
        i0 = int(start * SR)
        i1 = min(n, i0 + n_samples(_BEAT))
        for i in range(i0, i1):
            tl = i / SR - start
            tone = sine(f, tl) + 0.45 * square(f, tl)
            out[i] += tone * min(tl / 0.005, 1.0) * decay(tl, 0.16) * 0.22

    # Kick on bar downbeats (120 Hz thump), hat tick every beat.
    for b in range(beats):
        start = b * _BEAT
        i0 = int(start * SR)
        if b % 4 == 0:
            i1 = min(n, i0 + n_samples(0.15))
            for i in range(i0, i1):
                tl = i / SR - start
                out[i] += sine(120.0, tl) * decay(tl, 0.05) * 0.45
        i1 = min(n, i0 + n_samples(0.04))
        for i in range(i0, i1):
            tl = i / SR - start
            out[i] += noise() * decay(tl, 0.008) * 0.12

    # Tiny end fade so the loop seam is click-free.
    fade = n_samples(0.005)
    for i in range(fade):
        out[n - 1 - i] *= i / fade

    write_wav("music_loop", out)


def main() -> None:
    make_hit()
    make_bounce()
    make_wicket()
    make_crowd()
    make_click()
    make_win()
    make_loss()
    make_coin()
    make_unlock()
    make_six()
    make_four()
    make_ball()
    make_music_loop()
    print("done: 13 WAV files in %s" % OUT_DIR)


if __name__ == "__main__":
    main()
