# Audrey — Manual de Usuario

## Descripción

Audrey es un sintetizador drone feedback-driven, puerto fiel del Audrey-II original (Daisy Seed) para norns. Está basado en el código C++ original de infrasonic/synthi.

El sonido se genera mediante un **bucle de realimentación** auto-oscilante: un generador de ruido blanco a -90dBFS excita un resonador Karplus-Strong, cuya salida pasa por un overdrive, filtros, y reverb, y luego se realimenta a la entrada. Cuando la ganancia de realimentación supera ~0 dB, el sistema se auto-excita y genera drones infinitos.

## Parámetros (11)

| # | Parámetro | Rango | Default | Descripción |
|---|---|---|---|---|
| 1 | Frequency | 16-72 nn | 40 nn | Frecuencia en notas MIDI. Control continuo con magnetismo a notas exactas |
| 2 | Feedback Gain | -60 a 12 dB | 0.8 dB | Ganancia del bucle de realimentación. >0 dB = auto-oscilación |
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
| **K1** | Shift (momentáneo, igual que SHIFT del grid) |
| **K2** | Página anterior |
| **K3** | Página siguiente (o load/save snapshot en página SNAPSHOTS) |
| **K1 + K3** | Guarda snapshot en slot actual |

## Grid 16x8

### Fila 1: Snapshots (16 slots)

| Gesto | Slot ocupado | Slot vacío |
|---|---|---|
| **Tap** | Carga snapshot | Guarda snapshot |
| **SHIFT + tap** | Sobrescribe snapshot | Guarda snapshot |
| **Hold >2s** | Borra snapshot (con parpadeo) | Nada |

**Brillos:**
- Vacío: 1
- Ocupado: 3
- Cargado (current): 11
- Parpadeo delete: alterna 11/0 cada 250ms

### Filas 2-7: Knobs Audrey-II

```
         Col1   Col2   Col3   Col4   Col5   Col6   Col7   Col8   Col9   Col10  Col11  Col12  Col13  Col14   Col15  Col16
Row 2:  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]   [---]  [---]
Row 3:  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [DW]   [---]  [---]  [---]  [---]  [---]  [OUT]   [---]  [---]
Row 4:  [---]  [---]  [---]  [FBGN] [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]   [---]  [---]
Row 5:  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [VDEC] [---]  [---]  [---]  [---]  [---]  [ESND]  [---]  [---]
Row 6:  [---]  [FREQ] [---]  [---]  [---]  [LPF]  [---]  [---]  [---]  [HPF]  [---]  [EFB]  [---]  [---]   [---]  [---]
Row 7:  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [BODY] [---]  [---]  [---]  [---]  [---]  [ETIM]  [---]  [---]
Row 8:  [SH]   [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]  [---]   [---]  [---]
```

**Leyenda:**
- FREQ: Frequency (2, 6)
- FBGN: Feedback Gain (4, 4)
- BODY: Feedback Body (8, 7)
- LPF: Lowpass Cutoff (6, 6)
- HPF: Highpass Cutoff (10, 6)
- DW: Reverb Mix / Dry-Wet (8, 3)
- VDEC: Reverb Decay (8, 5)
- ESND: Echo Send (14, 5)
- ETIM: Echo Time (14, 7)
- EFB: Echo Feedback (12, 6)
- OUT: Master Level (14, 3)

**Interacción:**
- Brillo normal: 5
- Pulsar: overlay con nombre y valor (brillo 14 mientras pulsado)
- Mantener pulsado + girar K2/K3: ajusta el parámetro
- Soltar: overlay se limpia tras 0.5s

### Fila 8, Col 1: SHIFT

- Brillo normal: 1 (apenas visible)
- Brillo pulsado: 14
- Momentáneo: solo activo mientras se mantiene
- Funcionalmente idéntico a K1

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

Todos los parámetros usan mapeo **lineal** con alta resolución. La aceleración se aplica en función de la velocidad de giro del encoder:

| Giro | Frecuencia (cents) | Resto de parámetros |
|------|-------------------|---------------------|
| **Lento** (delta=1) | 1 cent (imperceptible) | 1 step |
| **Medio** (delta=3) | 27 cents (~¼ semitono) | 9 steps |
| **Rápido** (delta=6) | 216 cents (~2 semitonos) | 36 steps |

Esto permite precisión quirúrgica girando lento y barridos veloces girando rápido, sin necesidad de mapeo exponencial (que es errático con encoders).

## Versión

v7.1.0 — Basado en Audrey-II original C++ por infrasonic/synthi
