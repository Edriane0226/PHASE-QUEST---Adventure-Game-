"""Render original looping adventure and snowy exploration scores offline."""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "Assets/Audio/Music"
OUT.mkdir(parents=True, exist_ok=True)

def render(snow):
    beat = 60 / (80 if snow else 108)
    length = 64 * beat
    count = round(length * RATE)
    mix = np.zeros((count, 2), dtype=np.float64)
    rng = np.random.default_rng(712 if snow else 214)

    def add(note, start, duration, instrument, gain, pan=0):
        t = np.arange(round(duration * RATE)) / RATE
        f = 440 * 2 ** ((note - 69) / 12)
        attack = np.minimum(t / (0.18 if instrument == "pad" else 0.018), 1)
        release = np.minimum((duration - t) / (0.45 if instrument == "pad" else 0.12), 1)
        if instrument == "pad":
            signal = sum(np.sin(2*np.pi*f*ratio*t + 0.018*np.sin(2*np.pi*0.7*t)) * weight
                         for ratio, weight in [(0.999, .36), (1.001, .36), (2, .10), (3, .035)])
            envelope = attack * release
        elif instrument == "bell":
            signal = (np.sin(2*np.pi*f*t)*np.exp(-t*2.8)
                      + .17*np.sin(2*np.pi*f*2*t)*np.exp(-t*5)
                      + .055*np.sin(2*np.pi*f*3*t)*np.exp(-t*8))
            envelope = attack * release
        elif instrument == "pluck":
            signal = sum(np.sin(2*np.pi*f*h*t)*np.exp(-t*(3+h)) / h**1.6 for h in range(1, 6))
            envelope = attack * release
        else:  # Gentle woodwind lead, rounded bass, and soft string countermelody.
            vibrato = .004*np.sin(2*np.pi*4.5*t)*np.minimum(t/.3, 1)
            phase = 2*np.pi*f*t + vibrato * f/8
            signal = np.sin(phase)+.15*np.sin(phase*2)+.07*np.sin(phase*3)
            envelope = attack*release*(.8+.2*np.exp(-t*3))
        signal *= envelope * gain
        indices = (round(start*RATE) + np.arange(len(t))) % count
        np.add.at(mix[:, 0], indices, signal*np.sqrt((1-pan)/2))
        np.add.at(mix[:, 1], indices, signal*np.sqrt((1+pan)/2))

    chords = [[50,54,57], [47,50,54], [43,47,50], [45,49,52]] if snow else [
        [50,54,57], [43,47,50], [47,50,54], [45,49,52]]
    adventure = [
        [74, 0, 78, 81, 83, 81, 78, 76], [74, 71, 74, 79, 78, 76, 74, 0],
        [71, 74, 78, 81, 83, 81, 78, 74], [73, 76, 81, 0, 79, 78, 76, 73],
        [74, 78, 81, 86, 85, 83, 81, 78], [79, 0, 83, 86, 83, 81, 79, 78],
        [76, 79, 83, 81, 79, 78, 76, 74], [73, 76, 78, 81, 0, 76, 73, 0]]
    winter = [
        [81, 0, 78, 0, 74, 0, 0, 78], [78, 0, 74, 0, 71, 0, 0, 0],
        [79, 0, 78, 0, 74, 0, 71, 0], [76, 0, 73, 0, 69, 0, 0, 0],
        [86, 0, 81, 0, 78, 0, 0, 81], [83, 0, 78, 0, 74, 0, 0, 0],
        [79, 0, 83, 0, 81, 0, 78, 0], [76, 0, 73, 0, 74, 0, 0, 0]]
    for bar in range(16):
        start = bar * 4 * beat
        chord = chords[bar % 4]
        for i, note in enumerate(chord):
            add(note+12, start, beat*4.6, "pad", .055 if snow else .045, (i-1)*.45)
        add(chord[0]-12, start, beat*3.8, "bass", .065 if snow else .10, 0)
        melody = (winter if snow else adventure)[bar % 8]
        for step, note in enumerate(melody):
            if not note:
                continue
            add(note, start+step*.5*beat, beat*(1.8 if snow else .48),
                "bell" if snow else "flute", .12 if snow else .15, -.12)
        for step in range(4 if snow else 8):
            offset = step * (beat if snow else beat*.5)
            add(chord[step % 3]+12, start+offset, beat*1.3, "pluck", .035 if snow else .052, .4)
        if snow:
            if bar % 2 == 0:
                add(chord[2]+24, start+2.5*beat, beat*2.8, "bell", .03, .65)
        else:
            # Quiet low hand-drum pulses keep the adventure moving.
            for step, gain in [(0,.07), (1.5,.035), (2,.055), (3.5,.035)]:
                t = np.arange(round(.18*RATE))/RATE
                drum = (np.sin(2*np.pi*(82*t-75*t*t))*np.exp(-t*25)
                        + rng.uniform(-1,1,len(t))*.08*np.exp(-t*55))
                drum *= gain*np.minimum(t/.004,1)
                indices = (round((start+step*beat)*RATE)+np.arange(len(t))) % count
                np.add.at(mix[:,0],indices,drum*.7)
                np.add.at(mix[:,1],indices,drum*.7)
    # Wrap ambience tails across the loop boundary so the music never cuts off.
    dry = mix.copy()
    for delay, gain in [(0.14,.12),(.27,.09),(.43,.055)]:
        mix += np.roll(dry, round(delay*RATE), axis=0)[:,::-1]*gain
    mix *= .72 / max(float(np.max(np.abs(mix))), .001)
    destination = OUT / ("zone1_snowy.wav" if snow else "adventure_theme.wav")
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes((mix*32767).astype("<i2").tobytes())
    print(f"{destination.name}: {length:.2f}s, peak {np.max(np.abs(mix)):.2f}")

render(False)
render(True)
