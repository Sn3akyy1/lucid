#!/usr/bin/env python3
# builds lucid's sound set into assets/sounds. the sounds are synthesised here
# from sines, fm and plucked harmonics; only the tiny feedback ticks start from
# kenney's interface sounds (cc0, support/sounds/kenney). each is levelled to
# one loudness so a volume setting means the same thing for all of them. needs
# numpy and ffmpeg. run after changing a sound:
#   python3 support/sounds/build-sounds.py [--out DIR] [--wav] [names...]
import argparse
import os
import subprocess
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "sounds")
SAMPLES = os.path.join(ROOT, "support", "sounds", "kenney")
SR = 48000
# the freedesktop set's level after the trims the shell used to give it, so a
# volume someone already chose sounds the same with these
TARGET = -12.5
STEPS = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name):
    return 440.0 * 2 ** ((12 * (int(name[-1]) + 1) + STEPS[name[:-1]] - 69) / 12)


# with no length given, a voice runs until its decay reaches -60 dB
def secs(dur, attack=0.0, tau=0.0):
    if dur is None:
        dur = attack + 6.9 * tau
    return np.arange(int(round(dur * SR))) / SR


# a raised-sine attack into an exponential decay
def env(t, attack, tau):
    a = np.clip(t / attack, 0, 1) if attack > 0 else np.ones_like(t)
    return np.sin(a * np.pi / 2) ** 2 * np.exp(-np.maximum(t - attack, 0) / tau)


def phase(f):
    return 2 * np.pi * np.cumsum(f) / SR


# a pitch that starts at start * f and settles on f
def glide(t, f, start=1.0, ms=0.0):
    if ms <= 0 or start == 1.0:
        return np.full_like(t, f)
    return f * (1 + (start - 1) * np.exp(-t / (ms / 1000)))


# ---------------------------------------------------------------- voices

# two-operator fm: a bright metallic strike that thins to a pure tone
def bell(f, dur=None, tau=0.35, ratio=2.0, index=1.5, itau=0.06, attack=0.002, start=1.0, ms=0.0):
    t = secs(dur, attack, tau)
    # keep the sidebands that matter under nyquist
    index = min(index, max(0.0, (19000 / f - 1) / ratio - 1.5))
    ph = phase(glide(t, f, start, ms))
    return np.sin(ph + index * np.exp(-t / itau) * np.sin(ph * ratio)) * env(t, attack, tau)


# a sine with a quick pitch drop at the front, the digital "bip"
def blip(f, dur=None, tau=0.05, start=1.3, ms=8.0, second=0.12):
    t = secs(dur, 0.0015, tau)
    ph = phase(glide(t, f, start, ms))
    return (np.sin(ph) + second * np.sin(2 * ph)) * env(t, 0.0015, tau)


# a band-limited soft square, for the chiptune-ish runs
def chip(f, dur=None, tau=0.05, odd=5, soft=1.7):
    t = secs(dur, 0.0015, tau)
    ph = phase(np.full_like(t, f))
    y = np.zeros_like(t)
    for k in range(1, 2 * odd, 2):
        if f * k < 18000:
            y += np.sin(ph * k) / k ** soft
    return y * env(t, 0.0015, tau)


# a saw whose upper harmonics die first, like a closing filter: a synth pluck
def pluck(f, dur=None, tau=0.25, n=14, close=16.0, attack=0.0015):
    t = secs(dur, attack, tau)
    ph = phase(np.full_like(t, f))
    y = np.zeros_like(t)
    for k in range(1, n + 1):
        if f * k < 18000:
            y += np.sin(ph * k) / k * np.exp(-t * close * (k - 1))
    return y * env(t, attack, tau)


# two slightly detuned sines, slow at the front
def pad(f, dur=None, attack=0.03, tau=0.5, cents=5.0, second=0.15, start=1.0, ms=0.0):
    t = secs(dur, attack, tau)
    y = np.zeros_like(t)
    for c in (-cents, cents):
        ph = phase(glide(t, f * 2 ** (c / 1200), start, ms))
        y += np.sin(ph) + second * np.sin(2 * ph)
    return y / 2 * env(t, attack, tau)


# an exponential glide from f0 to f1 over `over` seconds, then held
def sweep(f0, f1, over=0.15, attack=0.01, tau=0.2, second=0.2, swell=False):
    t = secs(None, attack, tau)
    f = f0 * (f1 / f0) ** np.clip(t / over, 0, 1)
    ph = phase(f)
    y = np.sin(ph) + second * np.sin(2 * ph)
    e = env(t, attack, tau)
    if swell:
        e = e * np.clip(t / over, 0, 1) ** 1.5
    return y * e


# a recorded tick, as stereo; the shorter ones stop a hair early, so fade them
def sample(name):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(SAMPLES, name + ".ogg"),
                          "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(float).reshape(-1, 2).T.copy()
    k = int(0.004 * SR)
    x[:, -k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    return x


# ---------------------------------------------------------------- mixing

def tail(x, s):
    return np.pad(x, ((0, 0), (0, int(s * SR))))


class Mix:
    def __init__(self):
        self.buf = np.zeros((2, 0))

    def add(self, y, at=0.0, gain=1.0, pan=0.0):
        # nothing stops dead: a decay cut off mid-way clicks
        k = min(len(y) // 4, int(0.02 * SR))
        y = y.copy()
        y[len(y) - k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
        i = int(round(at * SR))
        if i + len(y) > self.buf.shape[1]:
            self.buf = tail(self.buf, (i + len(y) - self.buf.shape[1]) / SR + 1 / SR)
        th = (pan + 1) * np.pi / 4
        self.buf[0, i:i + len(y)] += y * gain * np.cos(th) * np.sqrt(2)
        self.buf[1, i:i + len(y)] += y * gain * np.sin(th) * np.sqrt(2)
        return self


def spectral(x, fn):
    n = x.shape[-1]
    f = np.fft.rfftfreq(n, 1 / SR)
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * fn(np.maximum(f, 1.0)), n, axis=-1)


def lowpass(x, fc):
    return spectral(x, lambda f: 1 / np.sqrt(1 + (f / fc) ** 4))


# laptop speakers have nothing below ~200 Hz; energy there is only headroom lost
def highpass(x, fc):
    return spectral(x, lambda f: 1 / np.sqrt(1 + (fc / f) ** 4))


# echoes that alternate sides and darken as they go
def pingpong(x, ms=120.0, fb=0.35, mix=0.25, taps=8, fc=7000.0):
    d = int(ms / 1000 * SR)
    x = tail(x, taps * ms / 1000)
    out = x.copy()
    n = x.shape[1]
    echo = x.mean(0)
    for k in range(1, taps + 1):
        echo = lowpass(echo, fc * 0.8 ** k)
        out[(k - 1) % 2, k * d:] += mix * fb ** (k - 1) * echo[:n - k * d]
    return out


def _impulse(rt, seed):
    rng = np.random.default_rng(seed)
    n = int(rt * 1.4 * SR)
    t = np.arange(n) / SR
    out = []
    for _ in range(2):
        noise = rng.standard_normal(n)
        low = lowpass(noise, 2500)
        ir = low * np.exp(-6.9 * t / rt) + 0.5 * (noise - low) * np.exp(-6.9 * t / (rt * 0.4))
        ir[:240] *= np.linspace(0, 1, 240)
        ir = np.concatenate([np.zeros(int(0.011 * SR)), ir])
        out.append(ir / np.sqrt((ir ** 2).sum()))
    return out


# a small bright room, convolved
def room(x, rt=0.6, mix=0.18, seed=7):
    irs = _impulse(rt, seed)
    x = tail(x, len(irs[0]) / SR)
    n = x.shape[1]
    out = x.copy()
    for ch, ir in enumerate(irs):
        size = 1 << int(np.ceil(np.log2(n + len(ir))))
        out[ch] += mix * np.fft.irfft(np.fft.rfft(x[ch], size) * np.fft.rfft(ir, size), size)[:n]
    return out


# max short-term power over 50 ms, with a rough k-weighting so the bright
# sounds are not judged quieter than they land
def loudness(x):
    w = spectral(x, lambda f: 10 ** (4 / 20 * (1 / (1 + (1700 / f) ** 2))) / np.sqrt(1 + (60 / f) ** 4))
    p = (w ** 2).mean(0)
    # a tick shorter than the window is measured whole
    win, hop = min(int(0.05 * SR), len(p)), int(0.01 * SR)
    c = np.concatenate([[0], np.cumsum(p)])
    best = max((c[i + win] - c[i]) / win for i in range(0, len(p) - win + 1, hop))
    return 10 * np.log10(best + 1e-12)


def finish(x, level=0.0):
    x = lowpass(highpass(x, 190), 15000)
    g = 10 ** ((TARGET + level - loudness(x)) / 20)
    ceiling = 10 ** (-1.5 / 20)
    g = min(g, ceiling / (np.abs(x).max() + 1e-12))
    x = x * g
    # drop the silent tail, then fade what is left into it
    loud = np.where(np.abs(x).max(0) > 10 ** (-56 / 20))[0]
    end = min(x.shape[1], (loud[-1] if len(loud) else 0) + int(0.02 * SR))
    x = x[:, :end]
    fade = min(int(0.03 * SR), end)
    x[:, end - fade:] *= np.cos(np.linspace(0, np.pi / 2, fade)) ** 2
    return x


# ---------------------------------------------------------------- the set
# notes stay in E major so the set sounds like one family. each returns stereo
# before levelling; `level` nudges a sound off the shared target in dB

SOUNDS = {}


def sound(name, level=0.0):
    def reg(fn):
        SOUNDS[name] = (fn, level)
        return fn
    return reg


# notifications

@sound("glint")
def glint():
    m = Mix()
    m.add(bell(hz("E6"), tau=0.28, ratio=3.0, index=1.4, itau=0.035), 0.0, 0.9, -0.15)
    m.add(bell(hz("B6"), tau=0.34, ratio=3.0, index=1.2, itau=0.035), 0.075, 0.8, 0.15)
    return room(m.buf, 0.7, 0.16)


@sound("pulse")
def pulse():
    m = Mix()
    m.add(blip(hz("C#6"), tau=0.055), 0.0, 1.0, -0.1)
    m.add(blip(hz("C#6"), tau=0.07), 0.13, 0.85, 0.1)
    return room(pingpong(m.buf, 165, 0.3, 0.16), 0.5, 0.1)


@sound("chime")
def chime():
    m = Mix()
    for i, (n, pan) in enumerate((("E5", -0.35), ("B5", 0.0), ("E6", 0.35))):
        m.add(bell(hz(n), tau=0.42, ratio=2.0, index=2.0, itau=0.08), i * 0.085, 0.8, pan)
    m.add(bell(hz("G#6"), tau=0.45, ratio=4.0, index=0.6, itau=0.05), 0.255, 0.35, 0.2)
    return room(m.buf, 0.9, 0.2)


@sound("tap")
def tap():
    m = Mix()
    m.add(pluck(hz("G#5"), tau=0.13, n=12, close=26.0), 0.0, 0.9)
    m.add(blip(hz("G#4"), tau=0.05, start=1.0, second=0.0), 0.0, 0.35)
    return room(m.buf, 0.4, 0.1)


@sound("orbit")
def orbit():
    m = Mix()
    for i, (n, pan) in enumerate((("E6", -0.4), ("G#6", -0.13), ("B6", 0.13), ("E7", 0.4))):
        m.add(chip(hz(n), tau=0.045), i * 0.048, 0.85 - i * 0.08, pan)
    return room(pingpong(m.buf, 110, 0.35, 0.28), 0.5, 0.1)


@sound("halo")
def halo():
    m = Mix()
    m.add(pad(hz("E5"), attack=0.025, tau=0.38), 0.0, 0.7, -0.2)
    m.add(pad(hz("G#5"), attack=0.025, tau=0.38), 0.02, 0.6, 0.2)
    m.add(bell(hz("E7"), tau=0.3, ratio=2.0, index=0.8, itau=0.04), 0.0, 0.18)
    return room(m.buf, 1.0, 0.24)


@sound("beacon")
def beacon():
    m = Mix()
    m.add(bell(hz("B5"), tau=0.42, ratio=2.0, index=1.0, itau=0.05), 0.0, 0.75)
    m.add(bell(hz("B6"), tau=0.3, ratio=2.0, index=0.7, itau=0.03), 0.0, 0.3)
    return room(pingpong(m.buf, 190, 0.4, 0.32, taps=6, fc=5000), 0.8, 0.14)


@sound("alert", level=2.0)
def alert():
    m = Mix()
    for at, n in zip((0.0, 0.12, 0.3, 0.42), ("D6", "A5", "D6", "A5")):
        m.add(bell(hz(n), tau=0.09, ratio=1.0, index=1.3, itau=0.2), at, 0.9)
    return room(m.buf, 0.5, 0.12)


# devices

@sound("usb-in")
def usb_in():
    m = Mix()
    for at, n, tau, pan in ((0.0, "C#6", 0.18, -0.25), (0.095, "G#6", 0.3, 0.25)):
        m.add(pluck(hz(n), tau=tau, close=19.0), at, 0.8, pan)
        m.add(bell(hz(n), tau=tau, ratio=2.0, index=0.8, itau=0.04), at, 0.3, pan)
    return room(m.buf, 0.6, 0.14)


@sound("usb-out")
def usb_out():
    m = Mix()
    m.add(pluck(hz("G#6"), tau=0.14, n=10, close=24.0), 0.0, 0.75, 0.25)
    m.add(pluck(hz("C#6"), tau=0.24, n=10, close=24.0), 0.095, 0.7, -0.25)
    return room(m.buf, 0.6, 0.14)


@sound("bt-in")
def bt_in():
    m = Mix()
    for i, (n, pan) in enumerate((("B5", -0.3), ("E6", 0.0), ("G#6", 0.3))):
        m.add(pad(hz(n), attack=0.008, tau=0.28 + i * 0.06, cents=3, start=0.89, ms=18), i * 0.07, 0.75, pan)
    return room(m.buf, 0.8, 0.22)


@sound("bt-out")
def bt_out():
    m = Mix()
    m.add(pad(hz("G#6"), attack=0.008, tau=0.18, cents=3, start=1.12, ms=18), 0.0, 0.7, 0.25)
    m.add(pad(hz("B5"), attack=0.008, tau=0.3, cents=3, start=1.12, ms=18), 0.09, 0.7, -0.25)
    return room(m.buf, 0.8, 0.2)


# power

@sound("power-in")
def power_in():
    m = Mix()
    m.add(sweep(330, hz("E6"), over=0.17, attack=0.005, tau=0.07, second=0.3, swell=True), 0.0, 0.55)
    m.add(bell(hz("E6"), tau=0.42, ratio=2.0, index=1.6, itau=0.06), 0.165, 0.75, -0.15)
    m.add(bell(hz("B6"), tau=0.38, ratio=2.0, index=1.0, itau=0.05), 0.165, 0.45, 0.15)
    return room(m.buf, 0.8, 0.18)


@sound("power-out")
def power_out():
    m = Mix()
    m.add(sweep(hz("B5"), 470, over=0.16, attack=0.004, tau=0.11, second=0.25), 0.0, 0.8)
    return room(m.buf, 0.5, 0.14)


@sound("charged")
def charged():
    m = Mix()
    for i, (n, pan) in enumerate((("E6", -0.3), ("G#6", -0.1), ("B6", 0.1), ("E7", 0.3))):
        m.add(bell(hz(n), tau=0.32, ratio=2.0, index=1.0, itau=0.04), i * 0.055, 0.7, pan)
    return room(m.buf, 0.9, 0.22)


@sound("battery-low", level=1.5)
def battery_low():
    m = Mix()
    m.add(bell(hz("D6"), tau=0.17, ratio=1.0, index=1.1, itau=0.25, attack=0.004), 0.0, 0.85)
    m.add(bell(hz("B5"), tau=0.26, ratio=1.0, index=1.1, itau=0.25, attack=0.004), 0.16, 0.85)
    return room(m.buf, 0.5, 0.12)


@sound("battery-critical", level=2.5)
def battery_critical():
    m = Mix()
    for at in (0.0, 0.13, 0.26):
        m.add(bell(hz("D6"), tau=0.07, ratio=1.0, index=1.5, itau=0.25, attack=0.003), at, 0.9)
    m.add(bell(hz("A5"), tau=0.24, ratio=1.0, index=1.5, itau=0.25, attack=0.003), 0.39, 0.9)
    return room(m.buf, 0.5, 0.12)


# the camera starting and stopping: glides into a pair of high blips

@sound("camera-on")
def camera_on():
    m = Mix()
    m.add(blip(hz("B6"), tau=0.06, start=0.75, ms=14, second=0.08), 0.0, 0.8, -0.15)
    m.add(blip(hz("E7"), tau=0.11, start=0.85, ms=10, second=0.05), 0.065, 0.7, 0.15)
    m.add(bell(hz("E6"), tau=0.25, ratio=3.0, index=0.8, itau=0.03), 0.065, 0.3)
    return room(m.buf, 0.6, 0.16)


@sound("camera-off")
def camera_off():
    m = Mix()
    m.add(blip(hz("E7"), tau=0.05, start=1.2, ms=12, second=0.05), 0.0, 0.7, 0.15)
    m.add(blip(hz("B6"), tau=0.09, start=1.25, ms=14, second=0.08), 0.065, 0.7, -0.15)
    return room(m.buf, 0.6, 0.14)


# the rest

@sound("capture")
def capture():
    m = Mix()
    m.add(bell(hz("A6"), tau=0.022, ratio=1.0, index=3.0, itau=0.01), 0.0, 0.7, -0.1)
    m.add(blip(hz("E7"), tau=0.03, start=1.15, ms=4, second=0.0), 0.06, 0.5, 0.15)
    return room(m.buf, 0.45, 0.12)


# two taps, then a ringing dyad, twice: a reminder coming due

@sound("reminder", level=1.0)
def reminder():
    m = Mix()
    for g in range(2):
        at = g * 0.9
        m.add(bell(hz("B5"), tau=0.07, ratio=2.0, index=1.4, itau=0.04), at, 0.7, -0.2)
        m.add(bell(hz("B5"), tau=0.07, ratio=2.0, index=1.4, itau=0.04), at + 0.14, 0.7, 0.2)
        m.add(bell(hz("E6"), tau=0.36, ratio=2.0, index=1.6, itau=0.06), at + 0.28, 0.75, -0.1)
        m.add(bell(hz("G#6"), tau=0.32, ratio=2.0, index=1.2, itau=0.05), at + 0.28, 0.55, 0.1)
    return room(m.buf, 0.8, 0.18)


@sound("alarm", level=4.0)
def alarm():
    m = Mix()
    for g in range(3):
        for i, n in enumerate(("E6", "B6", "E6", "B6")):
            m.add(chip(hz(n), tau=0.05, odd=4), g * 0.75 + i * 0.1, 0.8, (-0.15, 0.15)[i % 2])
        m.add(bell(hz("E7"), tau=0.12, ratio=2.0, index=0.8, itau=0.03), g * 0.75 + 0.4, 0.35)
    return room(m.buf, 0.5, 0.12)


# tiny feedback for something you just did: volume, brightness, caps lock and
# the microphone. kept well under the rest, since they come in runs

@sound("volume", level=-8.0)
def volume():
    return sample("glass_006")


@sound("brightness", level=-8.0)
def brightness():
    return sample("glass_005")


@sound("caps-on", level=-8.0)
def caps_on():
    return sample("toggle_002")


@sound("caps-off", level=-8.0)
def caps_off():
    return sample("toggle_001")


@sound("mic-on", level=-8.0)
def mic_on():
    return sample("select_001")


@sound("mic-off", level=-8.0)
def mic_off():
    return sample("select_002")


# ---------------------------------------------------------------- output

def encode(x, path, wav):
    pcm = np.ascontiguousarray(x.T, dtype=np.float32).tobytes()
    codec = ["-c:a", "pcm_s16le"] if wav else ["-c:a", "libvorbis", "-q:a", "6"]
    # bitexact keeps the ogg serial fixed, so a rebuild changes nothing in git
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    *codec, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", path],
                   input=pcm, check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--wav", action="store_true")
    ap.add_argument("names", nargs="*")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for name in args.names or SOUNDS:
        fn, level = SOUNDS[name]
        x = finish(fn(), level)
        path = os.path.join(args.out, name + (".wav" if args.wav else ".oga"))
        encode(x, path, args.wav)
        print("%-18s %.2fs  peak %5.1f dB  loudness %5.1f dB" % (
            name, x.shape[1] / SR, 20 * np.log10(np.abs(x).max()), loudness(x)))


if __name__ == "__main__":
    sys.exit(main())
