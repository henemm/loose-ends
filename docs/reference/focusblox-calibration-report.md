# FocusBlox-Kalibrierung (Issue #23)

Stichprobe: 60 von 287 Aufgaben, `FoundationModelsEnricher` gegen die tatsächlich in FocusBlox bestätigten Werte. Aktuelle Schreib-Schwelle: 0.6. Modellfehler (z. B. Guardrail-Fehlalarm), übersprungen: 1.

### importance (59 Aufgaben mit bekanntem Wert)

| Schwelle | Geschrieben | Precision | Recall |
|---|---|---|---|
| 0.3 | 56 | 38% | 36% |
| 0.4 | 56 | 38% | 36% |
| 0.5 | 56 | 38% | 36% |
| 0.6 | 54 | 35% | 32% |
| 0.7 | 54 | 35% | 32% |
| 0.8 | 51 | 33% | 29% |
| 0.9 | 50 | 34% | 29% |

### urgency (59 Aufgaben mit bekanntem Wert)

| Schwelle | Geschrieben | Precision | Recall |
|---|---|---|---|
| 0.3 | 55 | 29% | 27% |
| 0.4 | 55 | 29% | 27% |
| 0.5 | 54 | 28% | 25% |
| 0.6 | 52 | 25% | 22% |
| 0.7 | 52 | 25% | 22% |
| 0.8 | 49 | 27% | 22% |
| 0.9 | 47 | 28% | 22% |

### duration (58 Aufgaben mit bekanntem Wert)

| Schwelle | Geschrieben | Precision | Recall |
|---|---|---|---|
| 0.3 | 57 | 51% | 50% |
| 0.4 | 57 | 51% | 50% |
| 0.5 | 57 | 51% | 50% |
| 0.6 | 57 | 51% | 50% |
| 0.7 | 57 | 51% | 50% |
| 0.8 | 56 | 52% | 50% |
| 0.9 | 53 | 53% | 48% |

### energy (51 Aufgaben mit bekanntem Wert)

| Schwelle | Geschrieben | Precision | Recall |
|---|---|---|---|
| 0.3 | 48 | 25% | 24% |
| 0.4 | 48 | 25% | 24% |
| 0.5 | 48 | 25% | 24% |
| 0.6 | 47 | 23% | 22% |
| 0.7 | 47 | 23% | 22% |
| 0.8 | 45 | 24% | 22% |
| 0.9 | 41 | 27% | 22% |