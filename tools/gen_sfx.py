# -*- coding: utf-8 -*-
"""Generate soft casual-farm SFX (Stardew / Animal Crossing-inspired palette)."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "sfx"
OUT.mkdir(parents=True, exist_ok=True)
SR = 44100
rng = random.Random(42)


def clamp(x: float, a: float = -1.0, b: float = 1.0) -> float:
	return a if x < a else b if x > b else x


def env_adsr(n: int, a: float = 0.01, d: float = 0.05, s: float = 0.5, r: float = 0.08) -> list[float]:
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


def sine(f: float, t: float) -> float:
	return math.sin(2 * math.pi * f * t)


def tri(f: float, t: float) -> float:
	x = (t * f) % 1.0
	return 4 * abs(x - 0.5) - 1


def soft_noise() -> float:
	return rng.uniform(-1, 1)


def lowpass(samples: list[float], alpha: float = 0.15) -> list[float]:
	y = 0.0
	out: list[float] = []
	for x in samples:
		y = y + alpha * (x - y)
		out.append(y)
	return out


def write_wav(name: str, samples: list[float], peak: float = 0.85) -> None:
	m = max(abs(x) for x in samples) or 1.0
	scale = peak / m
	path = OUT / f"{name}.wav"
	with wave.open(str(path), "w") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		frames = bytearray()
		for x in samples:
			v = int(clamp(x * scale) * 32767)
			frames += struct.pack("<h", v)
		w.writeframes(frames)
	print("wrote", path.name, f"{len(samples) / SR:.3f}s")


def mix(*parts: list[float]) -> list[float]:
	n = max(len(p) for p in parts)
	out = [0.0] * n
	for p in parts:
		for i, v in enumerate(p):
			out[i] += v
	return out


def tone(
	freqs: list[tuple[float, float]],
	dur: float,
	amp: float = 0.5,
	a: float = 0.01,
	d: float = 0.06,
	s: float = 0.45,
	r: float = 0.1,
	kind: str = "sine",
) -> list[float]:
	n = int(dur * SR)
	e = env_adsr(n, a, d, s, r)
	out: list[float] = []
	for i in range(n):
		t = i / SR
		v = 0.0
		for f, g in freqs:
			v += (tri(f, t) if kind == "tri" else sine(f, t)) * g
		out.append(v * e[i] * amp)
	return out


def noise_burst(
	dur: float,
	amp: float = 0.3,
	a: float = 0.002,
	d: float = 0.02,
	s: float = 0.2,
	r: float = 0.05,
	lp: float = 0.25,
) -> list[float]:
	n = int(dur * SR)
	e = env_adsr(n, a, d, s, r)
	raw = [soft_noise() * e[i] * amp for i in range(n)]
	return lowpass(raw, lp)


def delayed(samples: list[float], delay_s: float) -> list[float]:
	return [0.0] * int(delay_s * SR) + samples


# --- UI ---
write_wav(
	"ui_click",
	mix(
		tone([(880, 0.6), (1320, 0.25)], 0.06, 0.35, 0.002, 0.02, 0.2, 0.03),
		noise_burst(0.04, 0.12, 0.001, 0.01, 0.1, 0.02, 0.4),
	),
)
write_wav(
	"ui_tab",
	mix(
		tone([(620, 0.5), (930, 0.3)], 0.08, 0.32, 0.003, 0.03, 0.25, 0.04, "tri"),
		noise_burst(0.06, 0.1, 0.002, 0.02, 0.15, 0.03, 0.35),
	),
)
write_wav(
	"ui_open",
	mix(
		tone([(330, 0.5), (495, 0.35), (660, 0.2)], 0.18, 0.4, 0.01, 0.05, 0.4, 0.08),
		noise_burst(0.12, 0.08, 0.01, 0.04, 0.2, 0.05, 0.2),
	),
)
write_wav(
	"ui_close",
	mix(tone([(495, 0.45), (330, 0.4), (220, 0.25)], 0.16, 0.35, 0.005, 0.04, 0.35, 0.08)),
)
write_wav(
	"ui_confirm",
	mix(tone([(523, 0.5), (659, 0.45), (784, 0.35)], 0.18, 0.42, 0.005, 0.04, 0.35, 0.08)),
)
write_wav(
	"ui_deny",
	mix(
		tone([(220, 0.6), (185, 0.4)], 0.14, 0.38, 0.005, 0.04, 0.3, 0.07, "tri"),
		noise_burst(0.08, 0.12, 0.002, 0.03, 0.2, 0.04, 0.3),
	),
)

# --- Field ---
write_wav(
	"plant",
	mix(
		tone([(180, 0.5), (240, 0.3)], 0.12, 0.4, 0.002, 0.04, 0.25, 0.06, "tri"),
		noise_burst(0.1, 0.28, 0.001, 0.03, 0.2, 0.05, 0.18),
	),
)
write_wav(
	"crop_click",
	mix(
		tone([(740, 0.55), (1110, 0.25)], 0.05, 0.28, 0.001, 0.015, 0.15, 0.025),
		noise_burst(0.035, 0.1, 0.001, 0.01, 0.1, 0.02, 0.45),
	),
)
write_wav(
	"grow_stage",
	mix(tone([(392, 0.4), (523, 0.45), (659, 0.3)], 0.14, 0.35, 0.008, 0.04, 0.3, 0.06)),
)
write_wav(
	"crop_ready",
	mix(tone([(659, 0.45), (784, 0.4), (988, 0.35)], 0.22, 0.4, 0.01, 0.05, 0.35, 0.1)),
)
write_wav(
	"harvest",
	mix(
		tone([(440, 0.35), (554, 0.3)], 0.12, 0.32, 0.002, 0.04, 0.25, 0.06),
		noise_burst(0.14, 0.22, 0.002, 0.04, 0.25, 0.07, 0.22),
	),
)

# --- Economy ---
write_wav(
	"coin",
	mix(tone([(988, 0.55), (1318, 0.4), (1760, 0.2)], 0.16, 0.4, 0.002, 0.03, 0.25, 0.08)),
)
write_wav(
	"sell",
	mix(tone([(659, 0.4), (784, 0.35), (988, 0.3), (1175, 0.25)], 0.22, 0.4, 0.005, 0.05, 0.35, 0.1)),
)
write_wav(
	"buy",
	mix(tone([(523, 0.4), (659, 0.4), (784, 0.35)], 0.2, 0.42, 0.005, 0.05, 0.35, 0.09)),
)
write_wav(
	"skill_buy",
	mix(tone([(392, 0.35), (523, 0.4), (659, 0.35), (830, 0.25)], 0.28, 0.4, 0.01, 0.06, 0.4, 0.12)),
)

# --- Progress ---
write_wav(
	"level_up",
	mix(
		tone([(523, 0.4)], 0.08, 0.35, 0.005, 0.02, 0.4, 0.03),
		delayed(tone([(659, 0.4)], 0.08, 0.38, 0.005, 0.02, 0.4, 0.03), 0.06),
		delayed(tone([(784, 0.45), (988, 0.3)], 0.22, 0.42, 0.005, 0.05, 0.4, 0.12), 0.12),
	),
)
write_wav("combo_tick", tone([(880, 0.5), (1175, 0.25)], 0.07, 0.3, 0.002, 0.02, 0.2, 0.03))
write_wav(
	"combo_frenzy",
	mix(
		tone([(392, 0.35), (523, 0.4), (659, 0.35), (784, 0.3)], 0.32, 0.45, 0.01, 0.08, 0.4, 0.12),
		noise_burst(0.2, 0.1, 0.01, 0.06, 0.2, 0.08, 0.25),
	),
)
write_wav(
	"deliver",
	mix(
		tone([(349, 0.35), (440, 0.4), (523, 0.35)], 0.24, 0.4, 0.008, 0.06, 0.35, 0.1),
		tone([(659, 0.25)], 0.18, 0.25, 0.05, 0.05, 0.3, 0.08),
	),
)
write_wav(
	"mission_claim",
	mix(
		tone([(523, 0.4), (659, 0.4), (784, 0.35)], 0.2, 0.4, 0.005, 0.05, 0.35, 0.08),
		noise_burst(0.06, 0.08, 0.002, 0.02, 0.15, 0.03, 0.3),
	),
)
write_wav(
	"prestige_ready",
	mix(tone([(784, 0.35), (988, 0.4), (1175, 0.35), (1480, 0.25)], 0.35, 0.38, 0.02, 0.08, 0.35, 0.15)),
)
write_wav(
	"machine",
	mix(
		tone([(220, 0.4), (330, 0.25)], 0.1, 0.28, 0.005, 0.03, 0.25, 0.05, "tri"),
		noise_burst(0.08, 0.1, 0.002, 0.03, 0.2, 0.04, 0.35),
	),
)
write_wav(
	"fertilizer",
	mix(
		tone([(660, 0.3), (880, 0.25)], 0.14, 0.28, 0.01, 0.05, 0.3, 0.07),
		noise_burst(0.16, 0.18, 0.01, 0.05, 0.25, 0.08, 0.15),
	),
)

print("done", len(list(OUT.glob("*.wav"))), "files ->", OUT)
