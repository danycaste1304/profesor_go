#!/usr/bin/env python3
"""Render the original Profesor GO game soundtrack with Python's standard library.

The tune and waveforms are made for this game. Run this script after changing
the scores to regenerate all WAV files under assets/audio/.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22_050
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
SCORE = [
    ("E5", "G5", "A5", "G5", "E5", "D5", "C5", "D5"),
    ("E5", "G5", "C6", "B5", "A5", "G5", "E5", "D5"),
    ("F5", "A5", "C6", "A5", "F5", "E5", "D5", "E5"),
    ("G5", "B5", "D6", "B5", "A5", "G5", "E5", "D5"),
    ("E5", "G5", "A5", "G5", "E5", "D5", "C5", "D5"),
    ("F5", "A5", "C6", "A5", "G5", "E5", "D5", "C5"),
    ("D5", "F5", "A5", "F5", "E5", "G5", "B5", "G5"),
    ("E5", "G5", "C6", "G5", "E5", "D5", "C5", "G4"),
]
BASS = ("C3", "A2", "F2", "G2", "C3", "F2", "G2", "C3")
CHORDS = (
    ("C4", "E4", "G4"),
    ("A3", "C4", "E4"),
    ("F3", "A3", "C4"),
    ("G3", "B3", "D4"),
    ("C4", "E4", "G4"),
    ("F3", "A3", "C4"),
    ("G3", "B3", "D4"),
    ("C4", "E4", "G4"),
)

# A quicker minor-key encounter cue and a brief major-key reward cue. Their
# melodic contours are original and separate from the campus exploration cue.
BATTLE_SCORE = [
    ("E5", "E5", "A5", "C6", "B5", "A5", "G5", "E5"),
    ("F5", "A5", "C6", "D6", "C6", "A5", "G5", "E5"),
    ("G5", "B5", "D6", "B5", "A5", "G5", "F5", "E5"),
    ("E5", "G5", "B5", "G5", "E5", "D5", "C5", "B4"),
    ("A4", "C5", "E5", "A5", "G5", "E5", "C5", "E5"),
    ("F5", "A5", "C6", "A5", "G5", "F5", "E5", "D5"),
    ("E5", "G5", "B5", "D6", "C6", "B5", "G5", "E5"),
    ("A5", "G5", "E5", "C5", "B4", "C5", "E5", "G5"),
]
BATTLE_BASS = ("A2", "F2", "G2", "E2", "A2", "F2", "E2", "A2")
BATTLE_CHORDS = (
    ("A3", "C4", "E4"), ("F3", "A3", "C4"),
    ("G3", "B3", "D4"), ("E3", "G3", "B3"),
    ("A3", "C4", "E4"), ("F3", "A3", "C4"),
    ("E3", "G3", "B3"), ("A3", "C4", "E4"),
)
VICTORY_SCORE = [
    ("C5", "E5", "G5", "C6", "G5", "E5", "G5", "C6"),
    ("D6", "C6", "G5", "E5", "G5", "C6", "C6", "C6"),
]
VICTORY_BASS = ("C3", "C3")
VICTORY_CHORDS = (("C4", "E4", "G4"), ("C4", "E4", "G4"))


def hz(note: str) -> float:
    pitch = "C C# D D# E F F# G G# A A# B".split()
    name, octave = note[:-1], int(note[-1])
    midi = (octave + 1) * 12 + pitch.index(name)
    return 440 * 2 ** ((midi - 69) / 12)


def synth(buffer: list[float], note: str, start: float, length: float,
          volume: float, kind: str) -> None:
    frequency = hz(note)
    beginning = round(start * RATE)
    count = min(round(length * RATE), len(buffer) - beginning)
    if count <= 0:
        return
    for i in range(count):
        t = i / RATE
        phase = (t * frequency) % 1.0
        attack = min(1.0, t / 0.008)
        release = min(1.0, (length - t) / 0.055)
        envelope = max(0.0, min(attack, release))
        if kind == "lead":
            # Two pulse voices detuned by one octave, with softened edges.
            wave_value = (1.0 if phase < 0.25 else -0.33)
            wave_value += 0.18 * (1.0 if (phase * 2) % 1 < 0.25 else -0.33)
        elif kind == "bass":
            wave_value = 1.0 - 4.0 * abs(phase - 0.5)
        else:
            wave_value = (1.0 if phase < 0.125 else -0.143)
            envelope *= math.exp(-5 * t / length)
        buffer[beginning + i] += wave_value * envelope * volume


def drums(buffer: list[float], start: float, snare: bool) -> None:
    rng = random.Random(round(start * 1000) + (1 if snare else 0))
    beginning = round(start * RATE)
    length = 0.075 if snare else 0.11
    for i in range(round(length * RATE)):
        t = i / RATE
        if beginning + i >= len(buffer):
            break
        noise = rng.uniform(-1, 1)
        body = math.sin(2 * math.pi * (95 - 55 * t / length) * t)
        buffer[beginning + i] += math.exp(-38 * t) * (
            (0.055 * noise + 0.012 * body) if snare
            else (0.045 * body + 0.008 * noise)
        )


def render_theme(name: str, score: list[tuple[str, ...]],
                 bass: tuple[str, ...], chords: tuple[tuple[str, ...], ...],
                 bpm: int) -> None:
    beat = 60 / bpm
    bar_length = 4 * beat
    total = len(score) * bar_length
    buffer = [0.0] * round(total * RATE)
    for bar, melody in enumerate(score):
        offset = bar * bar_length
        for step, note in enumerate(melody):
            synth(buffer, note, offset + step * beat / 2, beat * 0.43,
                  0.13, "lead")
        for beat_index in range(4):
            synth(buffer, bass[bar], offset + beat_index * beat,
                  beat * 0.9, 0.115, "bass")
            drums(buffer, offset + beat_index * beat,
                  snare=beat_index in (1, 3))
        for step in range(8):
            note = chords[bar][step % 3]
            synth(buffer, note, offset + step * beat / 2,
                  beat * 0.22, 0.045, "arp")

    # Keep the exact beat length so the melody repeats cleanly.
    peak = max(abs(value) for value in buffer)
    gain = 0.75 / max(peak, 0.75)
    pcm = b"".join(struct.pack("<h", round(max(-1, min(1, value * gain))
                                             * 32767)) for value in buffer)
    output = Path(__file__).resolve().parents[1] / "assets/audio" / name
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm)
    print(f"Wrote {output} ({total:.1f}s, original chiptune)")


def main() -> None:
    render_theme("campus_loop.wav", SCORE, BASS, CHORDS, BPM)
    render_theme("battle_loop.wav", BATTLE_SCORE, BATTLE_BASS,
                 BATTLE_CHORDS, 148)
    render_theme("victory.wav", VICTORY_SCORE, VICTORY_BASS,
                 VICTORY_CHORDS, 138)


if __name__ == "__main__":
    main()
