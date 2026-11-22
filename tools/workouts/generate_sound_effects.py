"""Generate GainPath's original short effects using only Python stdlib."""

import math
import struct
import wave
from pathlib import Path

RATE = 24000
OUTPUT = Path(__file__).resolve().parents[2] / "apps/mobile/assets/audio/effects"

# Duration in ms and (start, frequency Hz, note duration, amplitude).
EFFECTS = {
    "ready": (150, [(0, 659, 145, .30)]),
    "rep": (75, [(0, 510, 73, .26)]),
    "workoutComplete": (440, [(0, 523, 240, .28), (115, 784, 315, .27)]),
    "pointsClaimed": (390, [(0, 784, 210, .29), (90, 1047, 292, .25)]),
    "gameHit": (95, [(0, 440, 92, .34)]),
    "combo": (280, [(0, 587, 125, .27), (65, 740, 145, .27), (125, 880, 150, .26)]),
    "roundEnd": (360, [(0, 659, 185, .29), (110, 523, 242, .26)]),
}


def sample(time, notes):
    signal = 0.0
    for onset, frequency, duration, gain in notes:
        t = time - onset / 1000
        length = duration / 1000
        if 0 <= t < length:
            envelope = min(1, t / .005, (length - t) / .018) * math.exp(-4 * t / length)
            phase = 2 * math.pi * frequency * t
            signal += gain * envelope * (
                math.sin(phase) + .22 * math.sin(2 * phase) + .08 * math.sin(3 * phase)
            )
    return round(32767 * max(-1, min(1, signal)))


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, (duration, notes) in EFFECTS.items():
        frames = [sample(i / RATE, notes) for i in range(duration * RATE // 1000)]
        with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as output:
            output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            output.writeframes(struct.pack(f"<{len(frames)}h", *frames))


if __name__ == "__main__":
    main()
