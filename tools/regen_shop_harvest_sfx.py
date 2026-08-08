# -*- coding: utf-8 -*-
"""Regenerate cash-register buy + storage harvest SFX."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "sfx"
OUT.mkdir(parents=True, exist_ok=True)
SR = 44100
rng = random.Random(99)


def clamp(x: float, a: float = -1.0, b: float = 1.0) -> float:
	return a if x < a else b if x > b else x


def env(n: int, a: float, d: float, s: float, r: float) -> list[float]:
	out = [0.0] * n
	na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
	ns = max(0, n - na - nd - nr)
	i = 0
	for k in range(na):
		out[i] = k / max(1, na)
		i += 1
	for k in range(nd):
		out[i] = 1.0 - (1.0 - s) * (k / max(1, nd))
		i += 1
	for _ in range(ns):
		out[i] = s
		i += 1
	for k in range(nr):
		if i >= n:
			break
		out[i] = s * (1.0 - k / max(1, nr))
		i += 1
	return out


def lp(samples: list[float], alpha: float) -> list[float]:
	y = 0.0
	out: list[float] = []
	for x in samples:
		y += alpha * (x - y)
		out.append(y)
	return out


def write(name: str, samples: list[float], peak: float = 0.9) -> None:
	m = max(abs(x) for x in samples) or 1.0
	scale = peak / m
	path = OUT / f"{name}.wav"
	with wave.open(str(path), "w") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		b = bytearray()
		for x in samples:
			b += struct.pack("<h", int(clamp(x * scale) * 32767))
		w.writeframes(b)
	print("wrote", name, f"{len(samples) / SR:.3f}s")


def mix(parts: list[list[float]]) -> list[float]:
	n = max(len(p) for p in parts)
	out = [0.0] * n
	for p in parts:
		for i, v in enumerate(p):
			out[i] += v
	return out


def delay(p: list[float], sec: float) -> list[float]:
	return [0.0] * int(sec * SR) + p


# --- Cash register / shop purchase (cha-ching) ---
n1 = int(0.09 * SR)
e1 = env(n1, 0.001, 0.02, 0.25, 0.05)
drawer: list[float] = []
for i in range(n1):
	t = i / SR
	drawer.append(
		math.sin(2 * math.pi * 90 * t) * e1[i] * 0.5
		+ math.sin(2 * math.pi * 140 * t) * e1[i] * 0.25
		+ rng.uniform(-1, 1) * e1[i] * 0.18
	)
drawer = lp(drawer, 0.2)


def ding(freq: float, dur: float, amp: float, start_delay: float = 0.0) -> list[float]:
	n = int(dur * SR)
	e = env(n, 0.001, 0.04, 0.35, 0.18)
	out: list[float] = []
	for i in range(n):
		t = i / SR
		v = (
			math.sin(2 * math.pi * freq * t) * 0.55
			+ math.sin(2 * math.pi * freq * 2.01 * t) * 0.22
			+ math.sin(2 * math.pi * freq * 3.1 * t) * 0.12
			+ math.sin(2 * math.pi * freq * 4.7 * t) * 0.06
		)
		out.append(v * e[i] * amp)
	return delay(out, start_delay)


cash = mix(
	[
		drawer,
		ding(1568, 0.22, 0.55, 0.04),
		ding(2093, 0.28, 0.62, 0.10),
		ding(2637, 0.20, 0.35, 0.16),
	]
)
write("coin", cash, 0.88)

# --- Storage stow ---
n2 = int(0.08 * SR)
e2 = env(n2, 0.002, 0.025, 0.3, 0.04)
crate: list[float] = []
for i in range(n2):
	t = i / SR
	crate.append(
		math.sin(2 * math.pi * 220 * t) * e2[i] * 0.35
		+ math.sin(2 * math.pi * 330 * t) * e2[i] * 0.2
		+ rng.uniform(-1, 1) * e2[i] * 0.22
	)
crate = lp(crate, 0.25)

n3 = int(0.12 * SR)
e3 = env(n3, 0.002, 0.045, 0.28, 0.06)
plop: list[float] = []
for i in range(n3):
	t = i / SR
	f = 280 * math.exp(-t * 8)
	plop.append(
		math.sin(2 * math.pi * f * t) * e3[i] * 0.55
		+ math.sin(2 * math.pi * (f * 0.5) * t) * e3[i] * 0.25
		+ rng.uniform(-1, 1) * e3[i] * 0.12
	)
plop = lp(plop, 0.18)

n4 = int(0.05 * SR)
e4 = env(n4, 0.001, 0.015, 0.2, 0.025)
click: list[float] = []
for i in range(n4):
	t = i / SR
	click.append(
		math.sin(2 * math.pi * 880 * t) * e4[i] * 0.25
		+ rng.uniform(-1, 1) * e4[i] * 0.15
	)
click = lp(click, 0.35)

stow = mix([crate, delay(plop, 0.03), delay(click, 0.09)])
write("harvest", stow, 0.86)
print("done")
