"""Run prepare_water_steps.gd first to decode the user-supplied recording."""
from pathlib import Path
import wave
import numpy as np

root = Path(__file__).resolve().parents[1]
with wave.open(str(root / "tests/wet-walk-decoded.wav"), "rb") as source:
    rate = source.getframerate()
    audio = np.frombuffer(source.readframes(source.getnframes()), dtype="<i2").astype(float) / 32768

for variant, impact in enumerate([1.38, 2.72, 4.08]):
    start = int((impact - 0.12) * rate)
    clip = audio[start:start + int(0.48 * rate)].copy()
    clip *= 0.65 / max(float(np.max(np.abs(clip))), 0.001)
    attack, release = int(rate * 0.006), int(rate * 0.07)
    clip[:attack] *= np.linspace(0, 1, attack)
    clip[-release:] *= np.linspace(1, 0, release)
    destination = root / f"Assets/Audio/Footsteps/wet_step_{variant}.wav"
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes((clip * 32767).astype("<i2").tobytes())
    print(destination.name)
