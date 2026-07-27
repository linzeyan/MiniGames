"""Synthesize chiptune BGM + SFX for the app (all original, no licensing).

8-bit style square/triangle voices, 22.05kHz 16-bit mono WAVs written into
SmallGame/Resources/Audio/.
"""
import math
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
    print("wrote", name, f"{len(samples)/SR:.2f}s")


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def square(t, freq):
    return 1.0 if (t * freq) % 1 < 0.5 else -1.0


def triangle(t, freq):
    p = (t * freq) % 1
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def noise(t, _freq, state=[12345]):
    state[0] = (state[0] * 1103515245 + 12345) & 0x7FFFFFFF
    return state[0] / 0x3FFFFFFF - 1.0


def add_tone(buf, start, dur, freq, vol=0.2, wave_fn=square, attack=0.005, release=0.05):
    n0 = int(start * SR)
    n1 = min(len(buf), int((start + dur) * SR))
    for i in range(n0, n1):
        t = (i - n0) / SR
        env = min(1.0, t / attack) * min(1.0, (n1 - i) / SR / release)
        buf[i] += wave_fn(t, freq) * vol * env


def slide(buf, start, dur, f0, f1, vol=0.2):
    n0 = int(start * SR)
    n1 = min(len(buf), int((start + dur) * SR))
    phase = 0.0
    for i in range(n0, n1):
        p = (i - n0) / max(1, n1 - n0)
        freq = f0 + (f1 - f0) * p
        phase += freq / SR
        env = min(1.0, (i - n0) / (0.005 * SR)) * (1 - p)
        buf[i] += (1.0 if phase % 1 < 0.5 else -1.0) * vol * env


# --- BGM: 8-bar cheerful pentatonic loop, 112 BPM ---
BPM = 112
BEAT = 60.0 / BPM
BARS = 8
total = BARS * 4 * BEAT
bgm = [0.0] * int(total * SR)

# C-pentatonic melody, one note per beat (midi numbers, 0 = rest)
melody = [72, 76, 79, 76, 69, 72, 76, 72, 65, 69, 72, 69, 67, 71, 74, 71,
          72, 76, 79, 81, 79, 76, 72, 76, 74, 71, 67, 71, 72, 76, 72, 0]
bass = [48, 45, 41, 43, 48, 45, 41, 43]  # roots per bar

for i, n in enumerate(melody):
    if n:
        add_tone(bgm, i * BEAT, BEAT * 0.9, midi(n), vol=0.14, wave_fn=square)
for bar, n in enumerate(bass):
    for beat in (0, 2):
        add_tone(bgm, (bar * 4 + beat) * BEAT, BEAT * 1.6, midi(n), vol=0.16, wave_fn=triangle)
for i in range(BARS * 8):  # off-beat hats
    if i % 2 == 1:
        add_tone(bgm, i * BEAT / 2, 0.03, 6000, vol=0.05, wave_fn=noise)
write_wav("bgm", bgm)

# --- SFX ---
sfx = [0.0] * int(0.25 * SR)
slide(sfx, 0, 0.12, 500, 950, vol=0.3)
write_wav("sfx_jump", sfx)

sfx = [0.0] * int(0.15 * SR)
add_tone(sfx, 0, 0.1, 130, vol=0.35, wave_fn=triangle, release=0.09)
write_wav("sfx_land", sfx)

sfx = [0.0] * int(0.4 * SR)
for i, n in enumerate((72, 76, 79, 84)):  # coin arpeggio
    add_tone(sfx, i * 0.07, 0.09, midi(n), vol=0.25)
write_wav("sfx_catch", sfx)

sfx = [0.0] * int(0.3 * SR)
slide(sfx, 0, 0.25, 400, 120, vol=0.3)
add_tone(sfx, 0, 0.12, 0, vol=0.12, wave_fn=noise)
write_wav("sfx_hurt", sfx)

sfx = [0.0] * int(0.2 * SR)
slide(sfx, 0, 0.15, 900, 300, vol=0.2)
write_wav("sfx_throw", sfx)

sfx = [0.0] * int(0.3 * SR)
slide(sfx, 0, 0.25, 300, 1400, vol=0.3)
write_wav("sfx_spring", sfx)

sfx = [0.0] * int(1.0 * SR)
for i, n in enumerate((67, 63, 60, 55)):  # sad descent
    add_tone(sfx, i * 0.22, 0.24, midi(n), vol=0.25, wave_fn=triangle, release=0.1)
write_wav("sfx_gameover", sfx)

sfx = [0.0] * int(0.7 * SR)
for i, n in enumerate((72, 76, 79, 84, 79, 84)):  # fanfare
    add_tone(sfx, i * 0.09, 0.12, midi(n), vol=0.22)
write_wav("sfx_frenzy", sfx)
