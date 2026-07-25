# Audrey — Manual de Usuario

## Descripción

Audrey es un sintetizador drone feedback-driven, puerto fiel del Audrey-II original (Daisy Seed) para norns. Está basado en el código C++ original de infrasonic/synthi.

El sonido se genera mediante un **bucle de realimentación** auto-oscilante: un generador de ruido blanco a -90dBFS excita un resonador Karplus-Strong, cuya salida pasa por un overdrive, filtros, y reverb, y luego se realimenta a la entrada. Cuando la ganancia de realimentación supera ~0 dB, el sistema se auto-excita y genera drones infinitos.

## Parámetros (11)

| # | Parámetro | Rango | Default | Descripción |
|---|---|---|---|---|
| 1 | Frequency | C0-C5 (12-72 nn) | 40 nn | Frecuencia en notas MIDI. Control continuo con magnetismo a notas exactas |
| 2 | Feedback Gain | -60 a 12 dB | -24 dB | Ganancia del bucle de realimentación. >0 dB = auto-oscilación |
| 3 | Feedback Body | 0.001-0.1 s | 0.001 s | Retardo corporal del feedback (estéreo decorrelado) |
| 4 | Lowpass Cutoff | 100-18000 Hz | 18000 Hz | Filtro paso bajo del bucle de realimentación |
| 5 | Highpass Cutoff | 10-4000 Hz | 250 Hz | Filtro paso alto del bucle de realimentación |
| 6 | Reverb Mix | 0-1 | 0.0 | Mezcla de reverb (dentro del bucle de realimentación) |
| 7 | Reverb Decay | 0.2-1.0 | 0.2 | Decaimiento de la reverb |
| 8 | Echo Send | 0-1 | 0.0 | Envío al eco (BPF 800Hz + saturación tape) |
| 9 | Echo Time | 0.05-5.0 s | 0.5 s | Tiempo del eco |
| 10 | Echo Feedback | 0-1.5 | 0.0 | Realimentación del eco (>1 = auto-oscilación) |
| 11 | Master Level | 0-1 | 0.5 | Volumen de salida |

## Controles Norns

### Encoders
| Encoder | Sin knob grid activo | Con knob grid activo |
|---|---|---|
| **E1** | Feedback Gain | Controla el knob del grid |
| **E2** | Cambia foco de parámetro | Controla el knob del grid |
| **E3** | Ajusta parámetro enfocado | Controla el knob del grid |

### Keys
| Key | Acción |
|---|---|
| **K1** | Normal (K1+K3 guarda snapshot) |
| **K2** | Página anterior |
| **K3** | Página siguiente (o load/save snapshot en página SNAPSHOTS) |
| **K1 + K3** | Guarda snapshot en slot actual |

## Grid 16x8

### Fila 1: (vacía)
### Filas 2-6: Knobs Audrey-II
### Fila 7: (vacía)

### Fila 8, Col 1: SHIFT (momentáneo, solo grid)
### Fila 8, Cols 3-6: LFO 1-4
### Fila 8, Cols 9-16: Snapshots (8 slots)

```
         Col1   Col2   Col3   Col4   Col5   Col6   Col7   Col8   Col9   Col10  Col11  Col12  Col13  Col14   Col15  Col16
Row 1:  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]   [---]  [---]
Row 2:  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [DW]   [---]  [---]  [---]  [---]  [---]  [OUT]   [---]  [---]
Row 3:  [---]  [---]  [---]  [FBGN] [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]   [---]  [---]
Row 4:  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [VDEC] [---]  [---]  [---]  [---]  [---]  [ESND]  [---]  [---]
Row 5:  [---]  [FREQ] [---]  [---]  [---]  [HPF]  [---]  [---]  [---]  [LPF]  [---]  [EFB]  [---]  [---]   [---]  [---]
Row 6:  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [BODY] [---]  [---]  [---]  [---]  [---]  [ETIM]  [---]  [---]
Row 7:  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]   [---]  [---]
Row 8:  [SH]   [---]  [LF1]  [LF2]  [LF3]  [LF4]  [---]  [---]  [S1]  [S2]  [S3]  [S4]  [S5]  [S6]  [S7]  [S8]
```

**Leyenda:**
- FREQ: Frequency (2, 5)
- FBGN: Feedback Gain (4, 3)
- BODY: Feedback Body (8, 6)
- HPF: Highpass Cutoff (6, 5)
- LPF: Lowpass Cutoff (10, 5)
- DW: Reverb Mix / Dry-Wet (8, 2)
- VDEC: Reverb Decay (8, 4)
- ESND: Echo Send (14, 4)
- ETIM: Echo Time (14, 6)
- EFB: Echo Feedback (12, 5)
- OUT: Master Level (14, 2)

**Interacción:**
- Brillo normal: 5
- Pulsar: overlay con nombre y valor (brillo 14/15 mientras pulsado)
- Mantener pulsado + girar K2/K3: ajusta el parámetro
- Soltar: overlay se limpia tras 0.5s

### Snapshots (8 slots, Row 8 Cols 9-16)

| Gesto | Slot ocupado | Slot vacío |
|---|---|---|
| **Tap** | Carga snapshot | Guarda snapshot |
| **SHIFT + tap** | Sobrescribe snapshot | Guarda snapshot |
| **Hold >2s** | Borra snapshot (con parpadeo) | Nada |

**Brillos:**
- Vacío: 1
- Ocupado: 3
- Cargado (current): 11
- Parpadeo delete: alterna 11/0

**Por PSET:** Cada preset tiene sus propios 8 snapshots guardados en `dust/data/audrey/snapshots/pset_XX/snapshot_N.pset`. Al cambiar de PSET, los snapshots cambian automáticamente.
### SHIFT (Row 8, Col 1)

- Brillo normal: 1
- Brillo pulsado: 14
- Momentáneo: solo activo mientras se mantiene
- **Independiente de K1** (solo en grid)

## Snapshots (sistema de archivos)

Los snapshots se guardan en `dust/data/audrey/snapshot_N.pset` (formato PSET de norns, compatible con el sistema de presets).

## Audio Input

El audio de entrada (L+R sumados con -6dB) se inyecta en el bucle de realimentación junto con el ruido blanco. Cualquier fuente de audio externa (micrófono, guitarra, línea) excita el drone.

## Flujo de Señal

```
audio_in + noise(-90dB) + fb_return
  → Delay(body) → CombL(KS) → clip(±20) → LeakDC → overdrive(tanh)
  → LPF12(Q=0.9) → HPF12(Q=0.9) → Reverb(8comb+4allpass)
  → mix * verbMix → *fbGain → [fb_write, echo_send]
  → BPF(800)+tanh → Delay(echo) → 0.5*(dry+echo)
  → Limiter(0.7) → OUT
```

## Aceleración de Encoders

Los parámetros usan dos estrategias de aceleración, aplicadas según la velocidad de giro del encoder:

### Parámetros de frecuencia (Freq, LPF, HPF) — cents logarítmicos
| Giro | Cents | Efecto | HPF a 10 Hz | LPF a 100 Hz |
|------|-------|--------|-------------|--------------|
| **Lento** (δ=1) | 1.5¢ | Imperceptible | 10.009 Hz | 100.09 Hz |
| **Medio** (δ=3) | 70¢ | ~¾ semitono | 10.41 Hz | 104.1 Hz |
| **Rápido** (δ=6) | 1035¢ | ~10 semitonos | 18.2 Hz | 182 Hz |

### Parámetros lineales (Gain, Body, Mix, Decay, Send, Time, Level) — step × aceleración
| Giro | Steps | Ejemplo: fb_gain (step=0.01) |
|------|-------|------------------------------|
| **Lento** (δ=1) | 1 | 0.01 dB |
| **Medio** (δ=3) | 15.6 | 0.16 dB |
| **Rápido** (δ=6) | 88 | 0.88 dB |

La aceleración permite precisión quirúrgica girando lento y barridos veloces girando rápido. Se usa `params:set()` directamente en vez de `params:delta()` para evitar el comportamiento errático de norns que interpreta delta como porcentaje del rango.

## LFOs (4 moduladores)

Audrey incluye 4 LFOs asignables a cualquier parámetro. Cada LFO puede tener **múltiples destinos** simultáneos con profundidad, polaridad (±) y modo (unipolar/bipolar) independientes.

### Formas de onda
| Onda | Descripción |
|------|-------------|
| **Triángulo** | Onda triangular suave, sin escalones |
| **SLEW** | LFNoise con slew (ruido aleatorio suave, no cíclico) |

### Modos de modulación
| Modo | Display | Comportamiento |
|------|---------|----------------|
| Unipolar + | `uni+` | 0 → +depth desde el valor actual |
| Unipolar − | `uni-` | 0 → −depth desde el valor actual |
| Bipolar + | `bi+` | −depth → +depth centrado en el valor actual |
| Bipolar − | `bi-` | +depth → −depth centrado en el valor actual |

Los LFOs usan **offset auto-correctivo**: si mueves un parámetro manualmente mientras está siendo modulado, el LFO se adapta automáticamente al nuevo valor sin saltos.

### Grid: LFO buttons (Row 8, Cols 3-6)
| Gesto | Efecto |
|-------|--------|
| **Pulsar LFO** | Navega a página LFO + entra en modo patching |
| **Hold LFO + tap knob** | Conectar (o mostrar overlay si ya conectado) |
| **Hold knob + tap LFO** | Mismo patching (bidireccional) |
| **SHIFT + LFO + knob** | Eliminar esa asignación (cualquier orden) |
| **SHIFT + pulsar LFO** | Eliminar TODAS las asignaciones |
| **Soltar LFO** | Sale de patch mode, overlay desaparece, vuelve a página anterior |

**Brillo LFO buttons:** 2-12 oscilante. Brillo 14 en patch mode. Brillo 15 si knob held + conectado.

### Knob highlight
Al pulsar un knob, si tiene LFOs asignados → brillo **15** (en vez de 14).

### Páginas UI (2-5): LFO 1-4
Cada página muestra: forma de onda, frecuencia, estado ON/OFF, y scope de voltage real.

| Control | Acción |
|---------|--------|
| **E1** | Ajusta frecuencia (cents logarítmicos) |
| **E2** | Mueve cursor de asignación |
| **E3** | Ajusta profundidad de la asignación enfocada |
| **K2** | Cambia forma de onda (TRIA / SLEW) |
| **K3** | Activa/desactiva LFO |

### Popup de modulación (al conectar o ajustar)
```
┌─────────────────────────────────┐
│  LFO 2 → Reverb Mix             │
│  ████████████░░░░░░  uni+ 0.350 │
│  E2/E3:dpt  K2:±  K3:UNI/BI    │
└─────────────────────────────────┘
```

## Versión

v7.3.0 — Basado en Audrey-II original C++ por infrasonic/synthi

## Historial de Versiones

| Versión | Cambios |
|---------|---------|
| v7.3.0 | Snapshots 8 slots en Row 8, per-PSET, knobs rows 2-6, HPF↔LPF, SHIFT momentáneo |
| v7.2.0 | 4 LFOs con offset auto-correctivo, LFNoise con slew, page indicators, 60 Hz |
| v7.1.0 | Aceleración de encoders con `params:set()`, todo "lin", steps finos |
| v7.0.0 | Grid redesign, engine fiel al C++ original |
