"""Synthesize the five looping BGM tracks (all original, no licensing).

One soft track for the menu plus a tighter, faster one per game, so each
screen has its own mood. SFX live in make_audio.py; this script owns
bgm_*.wav only.

    python3 tools/make_music.py
"""
import os
import struct
import wave

OUT = "/Users/ricky/git/game/SmallGame/Resources/Audio/"
os.makedirs(OUT, exist_ok=True)
SR = 22050


def write_wav(name, samples):
    clipped = [max(-1.0, min(1.0, s)) for s in samples]
    with wave.open(OUT + name + ".wav", "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in clipped))
    print("wrote", name, f"{len(samples) / SR:.2f}s")


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def square(t, freq, duty=0.5):
    return 1.0 if (t * freq) % 1 < duty else -1.0


def triangle(t, freq):
    p = (t * freq) % 1
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def noise(_t, _freq, state=[7919]):
    state[0] = (state[0] * 1103515245 + 12345) & 0x7FFFFFFF
    return state[0] / 0x3FFFFFFF - 1.0


def tone(buf, start, dur, note, vol=0.2, wave_fn=square, attack=0.01, release=0.06):
    """One note. Envelopes stay inside `dur` so the loop point never clicks."""
    n0 = int(start * SR)
    n1 = min(len(buf), int((start + dur) * SR))
    freq = midi(note)
    for i in range(n0, n1):
        t = (i - n0) / SR
        env = min(1.0, t / attack) * min(1.0, (n1 - i) / SR / release)
        buf[i] += wave_fn(t, freq) * vol * env


def hit(buf, start, dur, vol=0.12):
    n0 = int(start * SR)
    n1 = min(len(buf), int((start + dur) * SR))
    for i in range(n0, n1):
        env = 1.0 - (i - n0) / max(1, n1 - n0)
        buf[i] += noise(0, 0) * vol * env * env


def make_buffer(bpm, bars):
    beat = 60.0 / bpm
    return [0.0] * int(bars * 4 * beat * SR), beat


# --- Menu: slow, soft, no percussion. Triangle only, wide spacing. ---
def menu():
    bpm, bars = 72, 8
    buf, beat = make_buffer(bpm, bars)
    arp = [60, 64, 67, 72, 76, 72, 67, 64]
    for bar in range(bars):
        root = [48, 48, 53, 53, 55, 55, 53, 48][bar]
        tone(buf, bar * 4 * beat, 4 * beat, root, vol=0.10,
             wave_fn=triangle, attack=0.35, release=0.6)
        for step in range(8):
            note = arp[(bar + step) % len(arp)]
            tone(buf, (bar * 4 + step * 0.5) * beat, beat * 0.45, note,
                 vol=0.11, wave_fn=triangle, attack=0.06, release=0.18)
    return buf


# --- Tower: bright and climbing. ---
def tower():
    bpm, bars = 138, 8
    buf, beat = make_buffer(bpm, bars)
    run = [60, 62, 64, 67, 69, 72, 74, 76]
    for bar in range(bars):
        for step in range(8):
            note = run[step] + (0 if bar % 2 == 0 else 3)
            tone(buf, (bar * 4 + step * 0.5) * beat, beat * 0.4, note, vol=0.16)
        for beat_index in range(4):
            tone(buf, (bar * 4 + beat_index) * beat, beat * 0.9, 36 + (bar % 2) * 3,
                 vol=0.14, wave_fn=triangle)
            hit(buf, (bar * 4 + beat_index + 0.5) * beat, 0.05, vol=0.07)
    return buf


# --- Shaft: minor and falling, the mirror of tower. ---
def shaft():
    bpm, bars = 144, 8
    buf, beat = make_buffer(bpm, bars)
    fall = [76, 74, 72, 69, 67, 65, 64, 60]
    for bar in range(bars):
        for step in range(8):
            note = fall[step] - (0 if bar % 2 == 0 else 2)
            tone(buf, (bar * 4 + step * 0.5) * beat, beat * 0.38, note, vol=0.15)
        for beat_index in range(4):
            tone(buf, (bar * 4 + beat_index) * beat, beat * 0.5, 33,
                 vol=0.15, wave_fn=triangle)
            hit(buf, (bar * 4 + beat_index) * beat, 0.06, vol=0.09)
    return buf


# --- Fishing: relaxed groove, still moves along. ---
def fishing():
    bpm, bars = 104, 8
    buf, beat = make_buffer(bpm, bars)
    melody = [67, 69, 72, 69, 67, 64, 62, 64]
    for bar in range(bars):
        for step in range(8):
            if step % 2 == 1 and bar % 2 == 0:
                continue  # leave air so it breathes
            note = melody[(step + bar) % len(melody)]
            tone(buf, (bar * 4 + step * 0.5) * beat, beat * 0.42, note,
                 vol=0.13, wave_fn=triangle, attack=0.02, release=0.12)
        for beat_index in (0, 2):
            tone(buf, (bar * 4 + beat_index) * beat, beat * 0.8,
                 [43, 41, 40, 43][bar % 4], vol=0.13)
        hit(buf, (bar * 4 + 2) * beat, 0.05, vol=0.06)
    return buf


# --- Snowball: march, dense drums. ---
def snowball():
    bpm, bars = 150, 8
    buf, beat = make_buffer(bpm, bars)
    theme = [62, 62, 65, 67, 69, 67, 65, 62]
    for bar in range(bars):
        for step in range(8):
            note = theme[step] + (0 if bar % 4 < 2 else 5)
            tone(buf, (bar * 4 + step * 0.5) * beat, beat * 0.3, note,
                 vol=0.15, wave_fn=lambda t, f: square(t, f, 0.25))
        for beat_index in range(4):
            tone(buf, (bar * 4 + beat_index) * beat, beat * 0.45, 38,
                 vol=0.16, wave_fn=triangle)
            if beat_index % 2 == 1:
                hit(buf, (bar * 4 + beat_index) * beat, 0.09, vol=0.13)
            hit(buf, (bar * 4 + beat_index + 0.5) * beat, 0.04, vol=0.05)
    return buf


for track_name, builder in [("bgm_menu", menu), ("bgm_tower", tower),
                            ("bgm_shaft", shaft), ("bgm_fishing", fishing),
                            ("bgm_snowball", snowball)]:
    write_wav(track_name, builder())
