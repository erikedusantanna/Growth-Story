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
OUT_AMB = os.path.join(ROOT, "assets", "audio", "ambience")
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


def noise(dur: float, vol: float = 0.2, decay: float = 0.03, seed: int = 7) -> list:
    """Ruído branco curto com decaimento exponencial (chimbal/caixa 8-bit)."""
    import random
    rng = random.Random(seed)
    n = max(1, int(RATE * dur))
    return [(rng.random() * 2.0 - 1.0) * vol * math.exp(-i / RATE / decay) for i in range(n)]


def kick(dur: float = 0.14, vol: float = 0.5) -> list:
    """Bumbo: senoide descendo de 150 para 45 Hz."""
    return note(150.0, dur, "sine", vol, attack=0.002, release=dur * 0.6, glide_to=45.0)


C3, D3, E3, F3, G3, A3, B3 = 130.8, 146.8, 164.8, 174.6, 196.0, 220.0, 246.9
C2, F2, G2, A2 = 65.4, 87.3, 98.0, 110.0


def gen_music():
    """Trilha de fundo em loop (~77 s): Dó maior, 100 bpm, 32 compassos em três seções
    (A: I-vi-IV-V, B: vi-IV-I-V com melodia mais alta, A': variação). Acordes em triângulo,
    baixo em quadrada, melodia em quadrada suave, bateria de ruído/senoide."""
    bpm = 100.0
    beat = 60.0 / bpm
    bar = beat * 4
    eighth = beat / 2

    chords = {  # baixo, tríade (triângulos), oitava do baixo
        "C": (C2, (C4, E4, G4)), "Am": (A2, (A3, C4, E4)), "F": (F2, (F3, A3, C4)), "G": (G2, (G3, B3, D4)),
        "Dm": (D3, (D4, F4, A4)), "Em": (E3, (E4, G4, B4)),
    }
    section_a = ["C", "Am", "F", "G"] * 2
    section_b = ["Am", "F", "C", "G", "Am", "F", "Dm", "G"]
    progression = section_a + section_b + section_a

    # --- acordes sustentados (pad) ---
    pad = []
    for ch in progression:
        _, tri = chords[ch]
        block = None
        for f in tri:
            n = note(f, bar * 0.98, "triangle", 0.085, attack=0.05, release=bar * 0.25)
            block = n if block is None else [a + b for a, b in zip(block, n)]
        pad.extend(block)
        pad.extend(silence(bar * 0.02))

    # --- baixo: raiz, raiz, quinta, raiz (semínimas) ---
    bass = []
    for ch in progression:
        root, _ = chords[ch]
        fifth = root * 1.5
        for f in (root, root, fifth, root):
            bass.extend(note(f, beat * 0.8, "square", 0.14, attack=0.005, release=beat * 0.2))
            bass.extend(silence(beat * 0.2))

    # --- melodia por seção (colcheias; None = pausa) ---
    mel_a = [
        E5, None, G5, None, A5, G5, E5, None,   C5, None, E5, None, D5, None, None, None,
        F5, None, A5, None, G5, F5, E5, None,   D5, None, G5, None, E5, None, None, None,
        E5, G5, A5, None, C6, None, A5, G5,     E5, None, D5, C5, D5, None, None, None,
        F5, None, E5, D5, C5, None, D5, None,   E5, None, D5, None, C5, None, None, None,
    ]
    mel_b = [
        A5, None, C6, None, B5, A5, G5, None,   F5, None, A5, None, G5, None, None, None,
        E5, None, G5, None, E5, None, D5, None, G5, None, F5, E5, D5, None, None, None,
        A5, None, C6, None, B5, A5, G5, None,   F5, None, A5, None, C6, None, None, None,
        D5, None, F5, A5, G5, None, F5, None,   E5, None, D5, None, C5, None, None, None,
    ]
    mel_a2 = [
        E5, None, G5, None, A5, G5, E5, None,   C5, None, E5, None, D5, None, E5, D5,
        F5, None, A5, None, G5, F5, E5, None,   D5, None, G5, None, E5, None, None, None,
        E5, G5, A5, None, C6, None, A5, G5,     E5, None, D5, C5, D5, None, E5, None,
        F5, None, E5, D5, C5, None, D5, None,   C5, None, None, None, None, None, None, None,
    ]
    lead = []
    for f in mel_a + mel_b + mel_a2:
        if f is None:
            lead.extend(silence(eighth))
        else:
            lead.extend(note(f, eighth * 0.82, "square", 0.11, attack=0.012, release=eighth * 0.3))
            lead.extend(silence(eighth * 0.18))

    # --- bateria: bumbo nos tempos 1 e 3, caixa no 2 e 4, chimbal nas colcheias ---
    drums = []
    for i in range(len(progression)):
        for b in range(4):
            hit = kick(0.14, 0.42) if b in (0, 2) else noise(0.09, 0.28, 0.035, seed=i * 4 + b)
            hat = noise(0.03, 0.09, 0.012, seed=100 + i * 8 + b)
            first = [a + c for a, c in zip(hit + [0.0] * int(RATE * eighth), (hat + [0.0] * int(RATE * eighth))[: len(hit) + int(RATE * eighth)])]
            first = first[: int(RATE * eighth)]
            second = (hat + [0.0] * int(RATE * eighth))[: int(RATE * eighth)]
            drums.extend(first)
            drums.extend(second)

    total = len(pad)
    tracks = [t + [0.0] * (total - len(t)) if len(t) < total else t[:total] for t in (pad, bass, lead, drums)]
    write_wav(os.path.join(OUT_MUSIC, "theme_loop.wav"), mix(*tracks))


def _add_at(dst: list, src: list, t: float, gain: float = 1.0) -> None:
    start = int(RATE * t)
    for i, v in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += v * gain


def gen_ambience():
    """Som ambiente do escritório em loop (16 s): ar-condicionado grave, teclados em rajadas,
    cliques de mouse, papel e uma notificação de mensagem. Bem baixo, por baixo da música."""
    import random
    dur = 16.0
    n = int(RATE * dur)
    rng = random.Random(11)

    # ar-condicionado: zumbido em 60/120 Hz (ciclos inteiros no loop) + ruído filtrado
    hum = [0.0] * n
    for i in range(n):
        t = i / RATE
        wob = 1.0 + 0.15 * math.sin(2 * math.pi * 0.25 * t)
        hum[i] = (0.05 * math.sin(2 * math.pi * 60 * t) + 0.025 * math.sin(2 * math.pi * 120 * t)) * wob
    raw = [(rng.random() * 2 - 1) for _ in range(n)]
    acc, bed = 0.0, [0.0] * n
    for i, v in enumerate(raw):
        acc += (v - acc) * 0.04          # passa-baixa simples: "vento" do ar-condicionado
        bed[i] = acc * 0.35
    hum = [h + b for h, b in zip(hum, bed)]

    # teclados: 3 pessoas digitando em rajadas irregulares
    keys = [0.0] * n
    for typist in range(3):
        t = rng.uniform(0.0, 1.5)
        pitch = 1400 + typist * 350
        while t < dur:
            burst = rng.randint(4, 11)
            for _ in range(burst):
                click = noise(0.012, 0.6, 0.0035, seed=rng.randint(0, 9999))
                tick = note(pitch, 0.008, "sine", 0.25, attack=0.001, release=0.004)
                _add_at(keys, click, t, rng.uniform(0.5, 1.0))
                _add_at(keys, tick, t, 0.6)
                t += rng.uniform(0.07, 0.13)
            t += rng.uniform(0.6, 2.4)

    # mouse: cliques duplos esparsos
    mouse = [0.0] * n
    for _ in range(9):
        t = rng.uniform(0.0, dur - 0.3)
        _add_at(mouse, noise(0.01, 0.5, 0.003, seed=rng.randint(0, 9999)), t)
        _add_at(mouse, noise(0.01, 0.4, 0.003, seed=rng.randint(0, 9999)), t + 0.11)

    # papel: farfalhar curto e abafado
    paper = [0.0] * n
    for t in (3.2, 9.7, 13.1):
        rustle = noise(0.22, 0.18, 0.09, seed=int(t * 100))
        acc = 0.0
        soft = []
        for v in rustle:
            acc += (v - acc) * 0.25
            soft.append(acc)
        _add_at(paper, soft, t)

    # notificação de mensagem: dois toques suaves em senoide, uma vez por loop
    ping = seq(note(1318.5, 0.07, "sine", 0.22, attack=0.004, release=0.05),
               note(1760.0, 0.11, "sine", 0.2, attack=0.004, release=0.08))
    notif = [0.0] * n
    _add_at(notif, ping, 7.4)

    write_wav(os.path.join(OUT_AMB, "office_loop.wav"), mix(hum, keys, mouse, paper, notif))


if __name__ == "__main__":
    gen_sfx()
    gen_music()
    gen_ambience()
