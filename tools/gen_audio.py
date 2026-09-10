#!/usr/bin/env python3
"""Gera os efeitos sonoros e a trilha de fundo do jogo (GDD §41), sintetizados por
código em ondas quadradas/triangulares 8-bit — sem dependências externas nem samples.
Uso: python3 tools/gen_audio.py
Saída em assets/audio/sfx/*.wav e assets/audio/music/*.wav.
"""
import math
import os
import struct
import wave

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT_SFX = os.path.join(ROOT, "assets", "audio", "sfx")
OUT_MUSIC = os.path.join(ROOT, "assets", "audio", "music")
RATE = 22050


def _wave_sample(shape: str, phase: float) -> float:
    """phase em [0,1). Retorna amostra em [-1, 1]."""
    if shape == "square":
        return 1.0 if phase < 0.5 else -1.0
    if shape == "triangle":
        return 4.0 * abs(phase - 0.5) - 1.0
    if shape == "sine":
        return math.sin(phase * 2.0 * math.pi)
    if shape == "saw":
        return 2.0 * phase - 1.0
    return 0.0


def note(freq: float, dur: float, shape: str = "square", vol: float = 0.5,
         attack: float = 0.006, release: float = 0.03, glide_to: float = None) -> list:
    """Uma nota (ou blip de ruído se freq<=0) como lista de floats [-1,1]."""
    n = max(1, int(RATE * dur))
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if glide_to is None else freq + (glide_to - freq) * (i / n)
        phase += f / RATE
        phase -= int(phase)
        s = _wave_sample(shape, phase)
        env = 1.0
        if t < attack:
            env = t / attack
        elif dur - t < release:
            env = max(0.0, (dur - t) / release)
        out.append(s * env * vol)
    return out


def seq(*notes: list) -> list:
    out = []
    for n in notes:
        out.extend(n)
    return out


def mix(*tracks: list) -> list:
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    peak = max(1.0, max(abs(v) for v in out) if out else 1.0)
    return [v / peak * 0.92 for v in out]


def silence(dur: float) -> list:
    return [0.0] * int(RATE * dur)


def write_wav(path: str, samples: list) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames.extend(struct.pack("<h", int(v * 32000)))
        wf.writeframes(bytes(frames))
    print("ok", os.path.relpath(path, ROOT), f"{len(samples) / RATE:.2f}s")


# Notas em Hz (escala de dó maior, algumas oitavas)
C4, D4, E4, F4, G4, A4, B4 = 261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9
C5, D5, E5, F5, G5, A5, B5 = 523.3, 587.3, 659.3, 698.5, 784.0, 880.0, 987.8
C6, E6, G6 = 1046.5, 1318.5, 1568.0


def gen_sfx():
    # contratação: dois tons ascendentes, amigável
    write_wav(os.path.join(OUT_SFX, "hire.wav"), seq(
        note(C5, 0.08, "square", 0.5), note(E5, 0.11, "square", 0.5)))

    # pagamento: "cling" de moeda, agudo e curto
    write_wav(os.path.join(OUT_SFX, "payment.wav"), seq(
        note(B5, 0.045, "triangle", 0.55), note(E6, 0.09, "triangle", 0.55)))

    # projeto concluído: fanfarra de 4 notas
    write_wav(os.path.join(OUT_SFX, "project_complete.wav"), seq(
        note(C5, 0.09, "square", 0.45), note(E5, 0.09, "square", 0.45),
        note(G5, 0.09, "square", 0.45), note(C6, 0.16, "square", 0.5)))

    # level up: glissando ascendente
    write_wav(os.path.join(OUT_SFX, "level_up.wav"),
              note(A4, 0.22, "saw", 0.4, attack=0.01, release=0.05, glide_to=A5 * 1.4))

    # evento: dois bips neutros
    write_wav(os.path.join(OUT_SFX, "event.wav"), seq(
        note(A5, 0.06, "square", 0.4), silence(0.03), note(A5, 0.06, "square", 0.4)))

    # cliente feliz: par de notas brilhante (terça maior)
    write_wav(os.path.join(OUT_SFX, "client_happy.wav"),
              mix(note(C6, 0.14, "triangle", 0.4), note(E6, 0.14, "triangle", 0.32)))

    # crise: tom descendente e áspero
    write_wav(os.path.join(OUT_SFX, "crisis.wav"), seq(
        note(A4, 0.1, "square", 0.45, attack=0.002, release=0.01),
        note(F4, 0.1, "square", 0.45, attack=0.002, release=0.01),
        note(D4, 0.18, "square", 0.45, attack=0.002, release=0.06)))

    # promoção: arpejo triunfante em triângulo
    write_wav(os.path.join(OUT_SFX, "promotion.wav"), seq(
        note(G4, 0.07, "triangle", 0.5), note(C5, 0.07, "triangle", 0.5),
        note(E5, 0.07, "triangle", 0.5), note(G5, 0.16, "triangle", 0.55)))

    # clique de interface: blip curto e discreto
    write_wav(os.path.join(OUT_SFX, "click.wav"),
              note(G5, 0.025, "square", 0.22, attack=0.002, release=0.015))


def gen_music():
    # trilha leve e repetível: arpejo de baixo (triângulo) + melodia esparsa (quadrada suave)
    # em Dó maior, 96 bpm, 8 compassos em loop.
    beat = 60.0 / 96.0
    bass_pattern = [C4, E4, G4, E4] * 8
    bass = seq(*[note(f, beat * 0.9, "triangle", 0.22, attack=0.01, release=beat * 0.2) for f in bass_pattern])

    lead_notes = [
        None, E5, G5, None, C5, None, D5, E5,
        None, G5, None, E5, D5, None, C5, None,
        None, E5, G5, A5, G5, None, E5, None,
        None, D5, None, C5, D5, E5, None, None,
    ]
    lead = []
    for f in lead_notes:
        if f is None:
            lead.extend(silence(beat / 2))
        else:
            lead.extend(note(f, beat / 2 * 0.85, "square", 0.16, attack=0.015, release=beat / 2 * 0.3))
            lead.extend(silence(beat / 2 * 0.15))
    # o lead tem metade da duração por evento (colcheias); repete 1x para casar com o baixo (2 compassos por linha)
    lead = lead * 1
    total = max(len(bass), len(lead))
    bass = bass + [0.0] * (total - len(bass))
    lead = lead + [0.0] * (total - len(lead))
    write_wav(os.path.join(OUT_MUSIC, "theme_loop.wav"), mix(bass, lead))


if __name__ == "__main__":
    gen_sfx()
    gen_music()
