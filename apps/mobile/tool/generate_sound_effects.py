#!/usr/bin/env python3
"""Render original, short 8-bit cues for the capture sequence.

Only Python's standard library is needed. The five WAV files are deterministic
and intentionally distinct from the longer music tracks.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22_050
OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio"


def tone(
    samples: list[float],
    start: float,
    duration: float,
    first_hz: float,
    last_hz: float,
    volume: float,
    *,
    triangle: bool = False,
) -> None:
    phase = 0.0
    offset = round(start * RATE)
    count = min(round(duration * RATE), len(samples) - offset)
    for i in range(max(0, count)):
        progress = i / max(1, count)
        frequency = first_hz + (last_hz - first_hz) * progress
        phase = (phase + frequency / RATE) % 1.0
        voice = (1 - 4 * abs(phase - 0.5)) if triangle else (
            1.0 if phase < 0.28 else -0.39
        )
        attack = min(1.0, i / (RATE * 0.006))
        envelope = attack * (1 - progress) ** 1.6
        samples[offset + i] += voice * envelope * volume


def noise(samples: list[float], duration: float, volume: float, seed: int) -> None:
    rng = random.Random(seed)
    count = min(round(duration * RATE), len(samples))
    for i in range(count):
        progress = i / count
        attack = min(1.0, i / (RATE * 0.004))
        samples[i] += rng.uniform(-1, 1) * volume * attack * (1 - progress) ** 2


def write(name: str, samples: list[float]) -> None:
    peak = max(abs(sample) for sample in samples)
    scale = 0.48 / max(peak, 0.48)
    pcm = b"".join(
        struct.pack("<h", round(max(-1.0, min(1.0, sample * scale)) * 32767))
        for sample in samples
    )
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / name
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm)
    print(f"Wrote {path.name} ({len(samples) / RATE:.2f}s)")


def main() -> None:
    samples = [0.0] * round(0.32 * RATE)
    tone(samples, 0, 0.30, 420, 1150, 0.18, triangle=True)
    noise(samples, 0.25, 0.07, 17)
    write("throw.wav", samples)

    samples = [0.0] * round(0.28 * RATE)
    tone(samples, 0, 0.21, 740, 920, 0.23)
    tone(samples, 0.06, 0.20, 1110, 1320, 0.14)
    noise(samples, 0.075, 0.05, 31)
    write("impact.wav", samples)

    samples = [0.0] * round(0.16 * RATE)
    tone(samples, 0, 0.13, 520, 390, 0.17, triangle=True)
    noise(samples, 0.045, 0.055, 43)
    write("shake.wav", samples)

    samples = [0.0] * round(0.63 * RATE)
    for start, frequency in ((0, 523), (0.12, 659), (0.24, 784), (0.37, 1047)):
        tone(samples, start, 0.21, frequency, frequency, 0.15)
    write("success.wav", samples)

    samples = [0.0] * round(0.55 * RATE)
    for start, frequency in ((0, 659), (0.15, 523), (0.30, 392)):
        tone(samples, start, 0.22, frequency, frequency * 0.92, 0.17)
    write("escape.wav", samples)


if __name__ == "__main__":
    main()
