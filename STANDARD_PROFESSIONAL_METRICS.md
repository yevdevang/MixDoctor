# 📊 Standard Professional Mix/Master Metrics

This guide provides industry-standard target ranges for professional mixing and mastering, helping you evaluate audio quality and identify potential issues during analysis.

---

## 🎚️ LEVELS & DYNAMICS

### **Peak Level**

| Stage | Target Range | Notes |
|-------|-------------|-------|
| **Mix (Pre-Master)** | -3 to -6 dB | Leaves headroom for mastering processing |
| **Master (Final)** | -0.1 to -0.3 dB | Industry standard for streaming/digital distribution |

**Guidelines:**
- Never exceed 0 dB to avoid digital clipping
- Leave at least 0.1 dB headroom for codec/conversion artifacts
- Some platforms prefer -1 dB peak for safety margin

---

### **RMS Level**

| Stage | Target Range | Genre Considerations |
|-------|-------------|---------------------|
| **Mix (Pre-Master)** | -18 to -10 dB | Depends on genre and dynamic content |
| **Master (Final)** | -8 to -6 dB | Loud genres (pop/rock/electronic) |

**Context:**
- Streaming platforms normalize around -14 to -16 LUFS
- Overly loud masters may be turned down by streaming services
- Classical/jazz can be quieter for artistic reasons

---

### **Dynamic Range (DR)**

| Content Type | Mix Range | Master Range | Notes |
|-------------|-----------|---------------|-------|
| **Pop/Rock** | 10-16 dB | 8-12 dB | Competitive loudness, controlled dynamics |
| **Acoustic/Jazz** | 12-20 dB | 12-18 dB | Natural dynamics preserved |
| **Electronic/EDM** | 8-14 dB | 6-10 dB | Heavy compression for energy |
| **Classical** | 15-25 dB | 15-22 dB | Wide dynamic range essential |

**Analysis:**
- DR < 6 dB: Over-compressed, fatiguing
- DR 6-8 dB: Heavily compressed but acceptable for some genres
- DR 8-12 dB: Modern commercial standard
- DR > 15 dB: Natural dynamics, audiophile quality

---

### **Clipping**

| Acceptable Level | Action Required |
|-----------------|------------------|
| **Never** | Any clipping indicates technical problems |

**Types of Clipping:**
- **Digital Clipping:** Hard limiting at 0 dBFS - sounds harsh
- **Analog-Style Clipping:** Soft saturation - may be intentional
- **Inter-Sample Peaks:** Can cause problems in D/A conversion

---

## 🌊 PHASE & STEREO

### **Phase Coherence**

| Range | Rating | Implications |
|-------|--------|-------------|
| **0.7 - 1.0** | Excellent | Mono compatible, stable stereo image |
| **0.5 - 0.7** | Acceptable | Some phase issues but generally okay |
| **< 0.5** | Problems | Significant phase cancellation, mono collapse |

**Considerations:**
- Lower values normal for wide stereo effects
- Check bass frequencies specifically (should be >0.9)
- Stereo guitars/keyboards may naturally lower coherence

---

### **Stereo Correlation**

| Range | Assessment | Characteristics |
|-------|------------|----------------|
| **+0.3 to +0.7** | Good stereo width | Balanced stereo image with good separation |
| **> +0.8** | Too narrow | Limited stereo information, approaching mono |
| **< 0** | Phase issues | Out-of-phase content, mono cancellation risk |

**Interpretation:**
- +1.0 = Perfect mono (identical L/R)
- +0.5 = Good stereo balance
- 0.0 = Uncorrelated channels (very wide)
- -1.0 = Perfect anti-phase (complete cancellation in mono)

---

### **Bass/Kick Phase**

| Target | Requirement | Reason |
|--------|-------------|---------|
| **> 0.9** | Must be centered | Ensures mono compatibility and system compatibility |

**Critical Points:**
- Low frequencies below 120Hz should be mono-centered
- Sub-bass content must maintain phase coherence
- Kick drum and bass guitar particularly important

---

## 🎯 FREQUENCY-SPECIFIC STANDARDS

### **Low End Management**

| Frequency Range | Phase Requirement | Stereo Width |
|----------------|------------------|--------------|
| **20-80Hz** | Mono (>0.95) | Centered |
| **80-120Hz** | Near-mono (>0.9) | Minimal width |
| **120-250Hz** | Good coherence (>0.7) | Controlled width |

---

### **Midrange Standards**

| Parameter | Target | Purpose |
|-----------|--------|---------|
| **Vocal Presence** | Clear and forward | Primary focus element |
| **Phase Coherence** | >0.6 in vocal range | Maintain clarity and focus |
| **Stereo Width** | Moderate | Allow vocal to cut through |

---

### **High Frequency Guidelines**

| Aspect | Standard | Notes |
|--------|----------|-------|
| **Brightness** | Genre-dependent | Avoid harsh resonances |
| **Stereo Width** | Can be wider | High-freq content allows more creativity |
| **Phase** | Less critical | Shorter wavelengths, less mono issues |

---

## ⚠️ RED FLAGS & WARNING SIGNS

### **Critical Issues**

| Problem | Indicator | Impact |
|---------|-----------|---------|
| **Digital Clipping** | Any samples at 0 dBFS | Harsh distortion, unprofessional |
| **Phase Cancellation** | <0.3 coherence in bass | Disappears in mono, system issues |
| **Over-Compression** | DR < 4 dB | Listener fatigue, lack of dynamics |
| **Under-Processing** | DR > 25 dB (non-classical) | May lack commercial competitiveness |

### **Quality Concerns**

| Issue | Range | Recommended Action |
|-------|-------|-------------------|
| **Narrow Stereo** | Correlation > 0.85 | Enhance stereo imaging |
| **Phase Issues** | Coherence 0.3-0.5 | Check for phase problems |
| **Loud but Weak** | High RMS, low perceived power | Review compression/limiting |

---

## 📈 PLATFORM-SPECIFIC CONSIDERATIONS

### **Streaming Services**

| Platform | Target LUFS | Notes |
|----------|-------------|-------|
| **Spotify** | -14 LUFS | Normalizes to this level |
| **Apple Music** | -16 LUFS | Sound Check normalization |
| **YouTube** | -13 to -15 LUFS | Variable normalization |
| **Tidal** | -14 LUFS | MQA considerations |

### **Physical Media**

| Format | Peak Level | Dynamic Range |
|--------|------------|---------------|
| **CD** | -0.1 dB max | 8-16 dB typical |
| **Vinyl** | -6 dB recommended | 10-18 dB optimal |
| **Cassette** | -3 dB recommended | 8-12 dB |

---

## 🔧 MEASUREMENT TOOLS & TECHNIQUES

### **Essential Meters**

1. **Peak/RMS Meters** - Level monitoring
2. **Spectrum Analyzer** - Frequency balance
3. **Phase Correlation Meter** - Stereo relationship
4. **Loudness Meter (LUFS)** - Perceived loudness
5. **Dynamic Range Meter** - DR measurement

### **Analysis Best Practices**

- **Measure entire track** - Not just excerpts
- **Check mono compatibility** - Sum to mono and listen
- **Use reference tracks** - Compare to professional releases
- **Consider genre conventions** - Standards vary by style
- **Test on multiple systems** - Headphones, speakers, car, phone

---

## 💡 PROFESSIONAL TIPS

### **Mixing Stage**
- Aim for conservative levels with good dynamics
- Focus on balance and clarity over loudness
- Maintain phase coherence, especially in low end
- Leave headroom for mastering processing

### **Mastering Stage**
- Use reference tracks from same genre
- Consider target playback systems
- Balance loudness with dynamics
- Ensure mono compatibility
- Check phase relationships after processing

### **Quality Assurance**
- A/B test against reference material
- Check on multiple playback systems
- Verify mono compatibility
- Confirm no clipping or artifacts
- Test at various volume levels

Remember: These are guidelines based on industry standards. Creative decisions may sometimes justify departing from these metrics, but understanding the standards helps make informed choices.