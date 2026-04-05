# MixDoctor — Genre-Specific Audio Scoring System Prompt

> Paste this into your MixDoctor Claude project as the authoritative reference for genre-aware scoring.
> Use this BEFORE rebuilding `createMasteredTrackPrompt` and `createPreMasterPrompt`.

---

## CORE PRINCIPLE

LUFS is a result, not a goal. Genre conventions and artistic intent drive scoring decisions.
Metrics are verification checkpoints — never penalize a track for characteristics that are
intentional and professional within its genre.

**NEVER penalize genre-appropriate loudness, dynamic range, or frequency balance.**
A Korn master at DR5 and -7 LUFS is PROFESSIONAL. A classical piece at -18 LUFS is PROFESSIONAL.
Score each track against its OWN genre standard, not a universal baseline.

---

## STREAMING PLATFORM NORMALIZATION REFERENCE

| Platform       | Target LUFS | Boosts Quiet? | True Peak Rec   |
|----------------|-------------|---------------|-----------------|
| Spotify        | -14 LUFS    | Yes (limited) | -1 dBTP (<-14); -2 dBTP (>-14) |
| Apple Music    | -16 LUFS    | Yes           | -1 to -2 dBTP   |
| YouTube        | -14 LUFS    | ❌ NEVER      | -1.5 to -2 dBTP |
| Tidal          | -14 LUFS    | ❌ NEVER      | -1 dBTP         |
| SoundCloud     | ~-14 LUFS   | Yes           | -2 dBTP minimum |

---

## GENRE SCORING THRESHOLDS

### 1. Metal / Hard Rock / Metalcore / Heavy Metal

**Keywords:** metal, hard rock, metalcore, heavy metal, death metal, thrash, doom

#### MASTER STAGE — Acceptable Ranges (score 85–95 if within these)
| Metric             | Excellent           | Acceptable          | Penalize           |
|--------------------|---------------------|---------------------|--------------------|
| Integrated LUFS    | -7 to -10 LUFS      | -6 to -12 LUFS      | Quieter than -14   |
| True Peak          | ≤ -1.0 dBTP         | ≤ 0.0 dBTP          | > 0.0 dBTP         |
| Dynamic Range (DR) | DR 6–8              | DR 4–10             | DR < 4             |
| Crest Factor       | 8–10 dB             | 6–12 dB             | < 6 dB             |
| Stereo Width       | 65–80%              | 50–90%              | < 30% or > 95%     |
| Phase Coherence    | > 0.4               | > 0.3               | < 0.3              |
| Mono Compat.       | ≤ 3 dB loss         | ≤ 5 dB loss         | > 5 dB loss        |
| Low End %          | 25–35%              | 20–45%              | > 55%              |

**DO NOT PENALIZE:** DR 4–6 (normal for metal), -6 to -8 LUFS (competitive metal loudness),
heavy low-end (25–40% is genre standard), low crest factor (6–8 dB is intentional).

#### MIX STAGE — Acceptable Ranges (score 80–90 if within these)
| Metric             | Target              | Acceptable          |
|--------------------|---------------------|---------------------|
| Integrated LUFS    | -16 to -18 LUFS     | -14 to -20 LUFS     |
| Peak Level         | -3 to -6 dBFS       | -1 to -8 dBFS       |
| Dynamic Range (DR) | DR 10–14            | DR 8–16             |
| Crest Factor       | 10–14 dB            | 9–16 dB             |
| Stereo Width       | 60–80%              | 50–85%              |

---

### 2. Electronic / EDM (House, Techno, Dubstep, Bass Music)

**Keywords:** electronic, edm, house, techno, dubstep, drum and bass, dnb, bass music, ambient electronic

#### MASTER STAGE — Acceptable Ranges
| Metric             | Excellent           | Acceptable          | Penalize           |
|--------------------|---------------------|---------------------|--------------------|
| Integrated LUFS    | -9 to -6 LUFS       | -5 to -12 LUFS      | Quieter than -16   |
| True Peak          | ≤ -1.0 dBTP         | ≤ 0.0 dBTP          | > 0.0 dBTP         |
| Dynamic Range (DR) | DR 5–8              | DR 3–10             | DR < 3             |
| Crest Factor       | 5–8 dB              | 3–10 dB             | < 3 dB             |
| Stereo Width       | 70–90%              | 50–100%             | < 40% or > 100%    |
| Phase Coherence    | > 0.3               | > 0.2               | Sustained < 0      |
| Mono Compat.       | Sub below 120 Hz clean | All bass clean   | Bass cancels in mono |
| Low End %          | 30–40%              | 25–50%              | > 60%              |

**DO NOT PENALIZE:** DR 4–6 (club EDM standard), -5 to -7 LUFS (festival/club loudness),
heavy sub-bass (30–45% is genre standard), wide stereo (70–90% is intentional).

**SPECIAL RULE:** Sub-bass below 120 Hz MUST be mono. If wide sub detected → flag this specifically.
Above 120 Hz: wide stereo is correct and should not be penalized.

#### MIX STAGE — Acceptable Ranges
| Metric             | Target              | Acceptable          |
|--------------------|---------------------|---------------------|
| Integrated LUFS    | -24 to -18 LUFS     | -20 to -28 LUFS     |
| Peak Level         | -6 to -3 dBFS       | -3 to -9 dBFS       |
| Dynamic Range (DR) | DR 8–14             | DR 6–18             |
| Stereo Width       | 50–80%              | 40–90%              |

---

### 3. Hip-Hop / Trap / R&B

**Keywords:** hip-hop, hiphop, hip hop, trap, rap, drill, r&b, rnb, boom bap

#### MASTER STAGE — Acceptable Ranges
| Metric             | Excellent           | Acceptable          | Penalize           |
|--------------------|---------------------|---------------------|--------------------|
| Integrated LUFS    | -9 to -6 LUFS       | -5 to -12 LUFS      | Quieter than -16   |
| True Peak          | ≤ -1.0 dBTP         | ≤ 0.0 dBTP          | > 0.0 dBTP         |
| Dynamic Range (DR) | DR 5–8              | DR 3–10             | DR < 3             |
| Crest Factor       | 5–8 dB              | 3–9 dB              | < 3 dB             |
| Stereo Width       | 50–75%              | 40–85%              | < 25% or > 90%     |
| Phase Coherence    | > 0.4               | > 0.3               | < 0.3              |
| Mono Compat.       | 808 and vocal clean | ≤ 2 dB loss         | 808 cancels in mono |
| Low End %          | 35–45%              | 30–55%              | > 65%              |

**DO NOT PENALIZE:** Heavy 808 sub-bass (35–45% normal), -6 to -9 LUFS (standard hip-hop loudness),
DR 4–6 (trap/drill standard), narrow width (hip-hop is more centered than EDM).

**SPECIAL RULE:** Mono compatibility is CRITICAL for hip-hop — phones and Bluetooth speakers
are primary playback. 808 fundamentals (35–60 Hz) must never be widened.

#### MIX STAGE — Acceptable Ranges
| Metric             | Target              | Acceptable          |
|--------------------|---------------------|---------------------|
| Integrated LUFS    | -24 to -18 LUFS     | -20 to -28 LUFS     |
| Peak Level         | -6 to -3 dBFS       | -3 to -9 dBFS       |
| Dynamic Range (DR) | DR 8–14             | DR 6–16             |
| Stereo Width       | 40–70%              | 30–80%              |

---

### 4. Pop

**Keywords:** pop, synth-pop, electropop, teen pop, dance-pop, k-pop, indie pop

#### MASTER STAGE — Acceptable Ranges
| Metric             | Excellent           | Acceptable          | Penalize           |
|--------------------|---------------------|---------------------|--------------------|
| Integrated LUFS    | -9 to -7 LUFS       | -6 to -12 LUFS      | Quieter than -16   |
| True Peak          | ≤ -1.0 dBTP         | ≤ 0.0 dBTP          | > 0.0 dBTP         |
| Dynamic Range (DR) | DR 6–8              | DR 5–10             | DR < 4             |
| Crest Factor       | 7–10 dB             | 6–12 dB             | < 6 dB             |
| Stereo Width       | 55–75%              | 45–85%              | < 30% or > 90%     |
| Phase Coherence    | > 0.3               | > 0.2               | Sustained < 0      |
| Mono Compat.       | ≤ 1–2 dB loss       | ≤ 3 dB loss         | > 4 dB loss        |
| Low End %          | 20–28%              | 15–35%              | > 50%              |

**INDUSTRY DATA (iZotope 2024 Billboard analysis):**
- Average integrated: -8.3 LUFS
- Average short-term: -6.0 LUFS
- Average LRA: 3.7–6.8 LU
- Average DR: ~7

#### MIX STAGE — Acceptable Ranges
| Metric             | Target              | Acceptable          |
|--------------------|---------------------|---------------------|
| Integrated LUFS    | -24 to -18 LUFS     | -20 to -28 LUFS     |
| Peak Level         | -6 to -3 dBFS       | -3 to -9 dBFS       |
| Dynamic Range (DR) | DR 10–14            | DR 8–16             |
| Stereo Width       | 50–80%              | 40–85%              |

---

### 5. Rock / Indie Rock

**Keywords:** rock, indie, indie rock, alternative, grunge, punk, post-rock, garage rock

#### MASTER STAGE — Acceptable Ranges
| Metric             | Excellent           | Acceptable          | Penalize           |
|--------------------|---------------------|---------------------|--------------------|
| Integrated LUFS    | -10 to -12 LUFS     | -9 to -14 LUFS      | Quieter than -18   |
| True Peak          | ≤ -1.0 dBTP         | ≤ -0.5 dBTP         | > 0.0 dBTP         |
| Dynamic Range (DR) | DR 8–12             | DR 7–14             | DR < 6             |
| Crest Factor       | 9–12 dB             | 8–14 dB             | < 7 dB             |
| Stereo Width       | 55–70%              | 45–80%              | < 30% or > 90%     |
| Phase Coherence    | > 0.4               | > 0.3               | < 0.3              |
| Mono Compat.       | ≤ 3 dB loss         | ≤ 4 dB loss         | > 5 dB loss        |
| Low End %          | 20–28%              | 15–35%              | > 50%              |

**DO NOT PENALIZE:** DR 8–10 (excellent rock), -10 to -12 LUFS (industry standard for rock),
warm low-mids 18–22% (indie rock characteristic).

#### MIX STAGE — Acceptable Ranges
| Metric             | Target              | Acceptable          |
|--------------------|---------------------|---------------------|
| Integrated LUFS    | -16 to -20 LUFS     | -14 to -22 LUFS     |
| Peak Level         | -3 to -6 dBFS       | -1 to -8 dBFS       |
| Dynamic Range (DR) | DR 10–14            | DR 8–16             |
| Stereo Width       | 50–70%              | 40–80%              |

---

### 6. Classical / Orchestral

**Keywords:** classical, orchestral, orchestra, chamber, symphony, opera, baroque, romantic, contemporary classical

#### MASTER STAGE — Acceptable Ranges
| Metric             | Excellent           | Acceptable          | Penalize           |
|--------------------|---------------------|---------------------|--------------------|
| Integrated LUFS    | -20 to -16 LUFS     | -24 to -14 LUFS     | Louder than -12    |
| True Peak          | ≤ -2.0 dBTP         | ≤ -1.0 dBTP         | > -0.5 dBTP        |
| Dynamic Range (DR) | DR 13–16            | DR 10–20            | DR < 8             |
| Crest Factor       | 14–18 dB            | 12–22 dB            | < 10 dB            |
| Stereo Width       | 65–95%              | 50–100%             | < 30%              |
| Phase Coherence    | +0.3 to +0.8        | +0.2 to +0.9        | Sustained < 0      |
| Mono Compat.       | Natural loss OK     | Moderate loss OK    | Key instruments cancel |
| Low End %          | 15–20%              | 10–25%              | > 35%              |
| LRA                | 15–25 LU            | 10–30 LU            | < 8 LU (over-compressed) |

**DO NOT PENALIZE:** Low LUFS (-16 to -20 LUFS is intentional), high DR (DR 12–16 is correct),
wide stereo (ORTF/Decca Tree recording is naturally wide), non-mono low end
(double bass positioning in stereo field must be preserved — unlike pop/rock).

**SPECIAL RULE:** NEVER apply mono low-end rules to classical. The low-end stereo image
is part of the natural recording and should not be penalized.

#### MIX STAGE — Acceptable Ranges
| Metric             | Target              | Acceptable          |
|--------------------|---------------------|---------------------|
| Integrated LUFS    | -24 to -18 LUFS     | -28 to -16 LUFS     |
| Peak Level         | -6 to -3 dBFS       | -3 to -9 dBFS       |
| Dynamic Range (DR) | DR 12–18            | DR 10–22            |
| Stereo Width       | 60–100%             | 50–100%             |

---

### 7. A Cappella / Vocal

**Keywords:** acapella, a cappella, vocal, choral, choir, barbershop, vocal group, spoken word

#### MASTER STAGE — Acceptable Ranges
| Metric             | Excellent           | Acceptable          | Penalize           |
|--------------------|---------------------|---------------------|--------------------|
| Integrated LUFS    | -16 to -12 LUFS     | -18 to -10 LUFS     | Louder than -9     |
| True Peak          | ≤ -1.0 dBTP         | ≤ -0.5 dBTP         | > 0.0 dBTP         |
| Dynamic Range (DR) | DR 9–13             | DR 7–16             | DR < 6             |
| Crest Factor       | 9–13 dB             | 8–15 dB             | < 7 dB             |
| Stereo Width       | 45–65%              | 35–75%              | < 20% or > 85%     |
| Phase Coherence    | +0.5 to +0.9        | +0.4 to +0.9        | < 0.3              |
| Mono Compat.       | ≤ 1 dB loss         | ≤ 2 dB loss         | > 3 dB loss        |
| Low End %          | 5–12%               | 3–18%               | > 25%              |
| Mid %              | 28–35%              | 22–40%              | < 18% (vocals buried) |

**DO NOT PENALIZE:** Low low-end % (vocals have no sub-bass — 5–12% is correct),
high mid % (30–35% midrange is the vocal frequency range), -14 to -16 LUFS (natural vocal dynamics).

**SPECIAL RULE:** K-weighting in LUFS measurement emphasizes 2–4 kHz (vocal range),
so a cappella may read higher LUFS than perceived. Adjust scoring generously.

#### MIX STAGE — Acceptable Ranges
| Metric             | Target              | Acceptable          |
|--------------------|---------------------|---------------------|
| Integrated LUFS    | -24 to -18 LUFS     | -20 to -28 LUFS     |
| Peak Level         | -6 to -3 dBFS       | -3 to -9 dBFS       |
| Dynamic Range (DR) | DR 12–18            | DR 10–20            |
| Stereo Width       | 35–60%              | 25–70%              |

---

### 8. Jazz

**Keywords:** jazz, bebop, swing, fusion, cool jazz, modal jazz, jazz fusion, blues jazz

#### MASTER STAGE — Acceptable Ranges
| Metric             | Excellent           | Acceptable          | Penalize           |
|--------------------|---------------------|---------------------|--------------------|
| Integrated LUFS    | -16 to -14 LUFS     | -18 to -12 LUFS     | Louder than -10    |
| True Peak          | ≤ -1.0 dBTP         | ≤ -0.5 dBTP         | > 0.0 dBTP         |
| Dynamic Range (DR) | DR 11–15            | DR 9–18             | DR < 7             |
| Crest Factor       | 10–14 dB            | 8–16 dB             | < 7 dB             |
| Stereo Width       | 45–75%              | 35–85%              | < 25%              |
| Phase Coherence    | +0.4 to +0.9        | +0.3 to +0.9        | < 0.3              |
| Mono Compat.       | Good                | ≤ 2 dB loss         | Key instruments cancel |
| Low End %          | 15–22%              | 12–28%              | > 38%              |

**DO NOT PENALIZE:** -14 to -18 LUFS (natural jazz dynamics), DR 10–14 (audiophile standard),
"dull" high end (intentional warmth — do NOT flag as frequency imbalance),
warm low-mids 22–28% (characteristic jazz tonal balance).

#### MIX STAGE — Acceptable Ranges
| Metric             | Target              | Acceptable          |
|--------------------|---------------------|---------------------|
| Integrated LUFS    | -22 to -16 LUFS     | -18 to -26 LUFS     |
| Peak Level         | -6 to -3 dBFS       | -3 to -9 dBFS       |
| Dynamic Range (DR) | DR 10–16            | DR 8–20             |
| Stereo Width       | 40–80%              | 30–85%              |

---

### 9. Live Performance / Live Recording

**Keywords:** live, live performance, live recording, concert, live album, acoustic live

#### MASTER STAGE — Acceptable Ranges
| Metric             | Excellent           | Acceptable          | Penalize           |
|--------------------|---------------------|---------------------|--------------------|
| Integrated LUFS    | -14 to -12 LUFS     | -16 to -10 LUFS     | Quieter than -20   |
| True Peak          | ≤ -1.5 dBTP         | ≤ -1.0 dBTP         | > -0.5 dBTP        |
| Dynamic Range (DR) | DR 10–14            | DR 8–18             | DR < 6             |
| Crest Factor       | 10–14 dB            | 9–16 dB             | < 8 dB             |
| Stereo Width       | 55–85%              | 45–90%              | < 25%              |
| Phase Coherence    | +0.3 to +0.7        | +0.2 to +0.8        | Sustained < 0      |
| Mono Compat.       | Moderate loss OK    | ≤ 4 dB loss         | Key instruments cancel |
| Low End %          | 18–25%              | 15–30%              | > 45%              |
| LRA                | 8–18 LU             | 6–22 LU             | < 5 LU (over-compressed for live) |

**DO NOT PENALIZE:** Wide stereo (room microphones create natural width), moderate phase
correlation (audience ambience and room reflections are intentional), lower mono
compatibility (inherent in natural stereo recording techniques).

**SPECIAL RULE:** Crowd noise and applause affect LUFS readings. A track gated between
songs may read higher LUFS than the actual musical content suggests — be generous.

#### MIX STAGE — Acceptable Ranges
| Metric             | Target              | Acceptable          |
|--------------------|---------------------|---------------------|
| Integrated LUFS    | -22 to -16 LUFS     | -18 to -26 LUFS     |
| Peak Level         | -6 to -3 dBFS       | -3 to -9 dBFS       |
| Dynamic Range (DR) | DR 10–16            | DR 8–20             |
| Stereo Width       | 50–90%              | 40–95%              |

---

## UNIVERSAL SCORING RULES

### Score ranges by stage
- **Master stage:** 0–100 (no cap)
- **Pre-master/Mix stage:** 0–90 maximum (masters score 95–100; mixes always score lower)

### Universal penalties (apply to ALL genres)
| Issue                          | Penalty     |
|--------------------------------|-------------|
| Clipping (peak > 0 dBFS)       | -15 points  |
| True peak > 0.0 dBTP           | -10 points  |
| Phase coherence < 0.2          | -12 points  |
| Mono cancellation of key element | -15 points |
| All metrics reading exactly 0.0 | INVALID — throw error, do not score |

### Universal bonuses (apply to ALL genres)
| Achievement                              | Bonus      |
|------------------------------------------|------------|
| No clipping + good loudness for genre    | +8 points  |
| Phase coherence within excellent range   | +5 points  |
| Mono compatibility within excellent range | +3 points |
| Dynamic range within excellent range     | +5 points  |

### Score calculation
```
Final Score = min(100, max(0, BaseScore + Bonuses - Penalties))
Master max: 100
Pre-master/Mix max: 90
```

### Reference scores (sanity check)
| Track                              | Genre   | Stage       | Expected Score |
|------------------------------------|---------|-------------|----------------|
| Korn - Twisted Transistor          | Metal   | Master      | 87–93          |
| Metallica - Enter Sandman          | Metal   | Master      | 82–88          |
| Daft Punk - Get Lucky              | EDM/Pop | Master      | 88–94          |
| Billie Eilish - Bad Guy            | Pop     | Master      | 85–92          |
| Bach - Cello Suite No.1            | Classical | Master    | 90–96          |
| Miles Davis - Kind of Blue         | Jazz    | Master      | 88–94          |
| Professional rock pre-master       | Rock    | Pre-master  | 82–88          |
| Good amateur pop pre-master        | Pop     | Pre-master  | 72–80          |
| Unmixed raw bedroom recording      | Any     | Mix         | 40–55          |
| Amateur mix with clipping          | Any     | Any         | 35–55          |

---

## GENRE DETECTION KEYWORDS (Swift implementation hint)

```swift
func detectGenreGroup(from genre: String) -> GenreGroup {
    let g = genre.lowercased()
    if g.contains("metal") || g.contains("hard rock") || g.contains("metalcore") || g.contains("heavy") { return .metal }
    if g.contains("electronic") || g.contains("edm") || g.contains("house") || g.contains("techno") || g.contains("dubstep") || g.contains("dnb") || g.contains("drum and bass") { return .electronic }
    if g.contains("hip") || g.contains("hop") || g.contains("trap") || g.contains("rap") || g.contains("drill") || g.contains("r&b") || g.contains("rnb") { return .hiphop }
    if g.contains("pop") { return .pop }
    if g.contains("rock") || g.contains("indie") || g.contains("alternative") || g.contains("punk") || g.contains("grunge") { return .rock }
    if g.contains("classical") || g.contains("orchestral") || g.contains("symphony") || g.contains("chamber") || g.contains("opera") { return .classical }
    if g.contains("acapella") || g.contains("a cappella") || g.contains("vocal") || g.contains("choir") || g.contains("choral") { return .acappella }
    if g.contains("jazz") || g.contains("bebop") || g.contains("swing") || g.contains("blues") { return .jazz }
    if g.contains("live") || g.contains("concert") { return .live }
    return .pop // default fallback
}
```

---

*Sources: iZotope (Jonathan Wyner/Berklee), Mastering The Mix, Production Advice (Ian Shepherd),
Sound On Sound, Sage Audio, Dynamic Range Database, Remasterify, MasteringBOX, LANDR, Streaky.
Data current as of 2025–2026.*