# 🚀 Powershell Video-Transcoder & Serien-Umbenenner

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/0ec11745ed0c4e268fa6fd2316f53b57)](https://app.codacy.com/gh/Maximus1/Powershell-Video-Transcoder/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

> Vollautomatische Video-Transkodierung mit KI-inspirierter Qualitätsanalyse, adaptiver Helligkeitsmessung, VMAF-Qualitätskontrolle und einem intelligenten Serien-Umbenenner.

**Haben Sie es satt, Ihre Videos manuell zu konvertieren, die Lautstärke anzupassen und Serien-Dateinamen zu korrigieren?**

Dieses Repository enthält zwei leistungsstarke PowerShell-Werkzeuge:

| Tool | Beschreibung |
|---|---|
| 🎬 **Auto Video Transcoder** | Wandelt Ihre komplette Videosammlung automatisch in hochoptimiertes HEVC (H.265) um – mit Helligkeitsanalyse, LUFS-Audionormalisierung, VMAF-Qualitätssicherung und GPU-Beschleunigung. |
| 📺 **Serien-Umbenenner** | Benennt Serien-Dateien automatisch anhand der Episodenführer von fernsehserien.de um – inklusive grafischer Auswahloberfläche und Scene-Tag-Bereinigung. |

**Starten Sie das Skript, wählen Sie einen Ordner, und lehnen Sie sich zurück – den Rest erledigt die Automatisierung.**

---

## ✨ NEU: Die Highlights der aktuellen Version

### 🎯 Adaptive Helligkeitsmessung mit automatischer CRF-Optimierung
Das Herzstück der neuesten Version ist die intelligente Helligkeitsanalyse (nur SDR, per FFmpeg `signalstats`-Filter – keine externen Tools nötig):

- **9 repräsentative Segmente** à 15 Sekunden werden gleichmäßig über die Filmlänge verteilt (YAVG-Werte, Skala 0–255).
- **Vorspann-Schutz:** Die ersten 90 Sekunden werden übersprungen – Studiologos und Intros verfälschen das Ergebnis nicht.
- **Abspann-Ausschluss:** Die Analyse endet bei 82 % der Gesamtlaufzeit, damit ein schwarzer Abspann nicht fälschlich als dunkles Video gewertet wird.
- **Präziser Doppel-Seek:** Kombinierter Fast-Seek + Accurate-Seek (`-ss [Zeit-2] -i ... -ss 2`) gleicht Keyframe-Versätze aus – ohne Dekodier-Overhead.
- **Klare Mehrheitsentscheidung:** Nur wenn **mindestens 6 von 9 Segmenten** dunkel sind (< 60 YAVG), gilt das Video als überwiegend dunkel.
- **Automatische CRF-Anpassung:** Bei dunklen SDR-Videos wird der CRF um **2 Punkte gesenkt** (Untergrenze CRF 14), damit der Encoder mehr Bits für Schattenbereiche und Rauschen aufwendet.
- **HDR-Schutz:** Bei HDR-Material wird die Helligkeitsanalyse automatisch übersprungen (SDR-Luma wäre bei HDR irreführend).

### 🛠️ Kalibrierungs-Logging (CalibrationData.json)
Neu hinzugekommen ist ein optionales **Kalibrierungs-Logging** (`$enableCalibrationLogging`):

- Speichert nach jedem erfolgreichen Transcode Größe, Auflösung und VMAF-Score in einer kumulativ wachsenden **JSON-Datei**.
- Berechnet automatisch die Werte **MB/s** und **MB/s pro Megapixel** – ideal, um die Qualitätsprofile der Größenanalyse anhand realer eigener Werte nachzukalibrieren.
- Vorhandene Einträge für dieselbe Datei werden ersetzt statt dupliziert.

### ⚡ Dynamische Hardware-Beschleunigungs-Auswahl (Get-OptimalHwaccel)
Statt fest verdrahtet nur `d3d11va` zu nutzen, fragt das Skript jetzt **alle von FFmpeg unterstützten HW-Beschleuniger** dynamisch ab (`ffmpeg -hwaccels`) und wählt herstellerspezifisch die beste Methode:

| GPU | Prioritätenliste |
|---|---|
| NVIDIA (`hevc_nvenc`) | `cuda` → `nvdec` → `d3d12va` → `d3d11va` → `vulkan` → `dxva2` |
| AMD (`hevc_amf`) | `d3d11va` → `d3d12va` → `vulkan` → `dxva2` → `opencl` |
| Intel (`hevc_qsv`) | `qsv` → `d3d12va` → `d3d11va` → `dxva2` → `vaapi` |

### 🔊 Intelligentes AAC-Bitrate-Management (Get-AacAudioEncodingArgs)
Neue Funktion für die Audio-Encoding-Parameter:

- Wählt das Profil **`aac_low`** (konservativster, kompatibelster AAC-Profileintrag).
- **Dynamische Bitratenberechnung:** Basis 96 k (Mono), 128 k (Stereo), 160 k+ (Surround) – bei bekannter Quellbitrate wird der Wert adaptiv abgeleitet (75 % bei ≤ 2 Kanälen, 50 % bei > 2 Kanälen, begrenzt auf sinnvolle Bereiche).
- Verhindert das unnötige Aufblähen der Audiospur bei Surround-Material.

### 🚀 VMAF-Qualitätskontrolle v2
- **JSON-Log-Auswertung:** Der VMAF-Score wird primär aus einer temporären JSON-Log-Datei gelesen – deutlich zuverlässiger als stderr-Textparsing (Windows-spezifische Lösung).
- **Toleranzzone:** Scores zwischen `$vmafMinScore` und `$vmafMinScore - $vmafTolerance` werden still akzeptiert – nur eine deutliche Unterschreitung löst einen Retry aus.
- **Backup/Restore-Sicherheitsnetz:** Vor jedem Retry wird die aktuelle Ausgabedatei als `.backup` gesichert. Schlägt der neue Encode die Größenvalidierung, wird das Backup automatisch wiederhergestellt.
- **Iteratives CRF-Stepping:** Jeder Retry senkt den CRF um 2 (bis auf Untergrenze 14).

### 🔄 AVI-Restaurierung optimiert (720p)
Die AVI-Spezialbehandlung wurde verbessert:

- **Ziel 1280 px statt 1920 px:** AVI-Quellen sind fast immer SD-Material – das Hochskalieren auf 1080p kostete nur Rechenzeit ohne echten Qualitätsgewinn.
- Filterkette: Deinterlacing (falls nötig) → `hqdn3d` Rauschunterdrückung → `scale=1280:-2` → `cas` (Contrast Adaptive Sharpening).
- **Helligkeitskorrektur auch für AVI:** Überwiegend dunkle AVI-Dateien erhalten ebenfalls eine CRF-Senkung.

### 💾 NVIDIA & AMD Encoder-Verbesserungen
- **NVIDIA:** `-tune hq`, VBR mit `-cq`-Qualitätsziel und `-multipass fullres` für genauere Bitratenverteilung (Turing+).
- **AMD:** `-vbaq` (Variable Block-Adaptive Quantization) und `-high_motion_quality_boost_enable` für bessere Qualität in schnellen Szenen. QVBR-Level wird automatisch gespiegelt (51 = beste Qualität).

---

## 🎬 Werkzeug 1: Auto Video Transcoder

**Skript:** [`Auto Video Transcode noch schneller mit helligkeitsmessung.ps1`](./Auto%20Video%20Transcode%20noch%20schneller%20mit%20helligkeitsmessung.ps1)

### Hauptfunktionen im Überblick

#### ⚡ Parallele Tag-Prüfung
- **Bis zu 8 Threads gleichzeitig** (`ForEach-Object -Parallel`) zur Vorab-Prüfung des Normalisierungs-Status.
- Bereits normalisierte MKV-Dateien (erkennbar am Metadaten-Tag `NORMALIZED=true` via `mkvextract`) werden sofort übersprungen.

#### 🎮 GPU-Beschleunigung
- **Automatische GPU-Erkennung** via WMI/CIM + FFmpeg-Encoder-Abgleich.
- **NVIDIA:** `hevc_nvenc` mit `hq`-Preset · **AMD:** `hevc_amf` mit `quality`-Preset.
- **Fallback** auf CPU-Encoder `libx265`, falls keine kompatible GPU vorhanden.
- **AV1-Sicherheitsnetz:** Hardware-Dekodierung wird bei AV1-Quellen deaktiviert (Stabilität).

#### 🧠 Adaptive Transkodierung
- Automatische Modernisierung veralteter Formate (XviD, DivX, H.264) → **HEVC (H.265)**.
- **Serien-Erkennung** (`SxxExx`): CRF 20 für Serien, automatisches Downscaling auf 720p bei Auflösungen > 720p.
- **Filme:** CRF 18 als Standard.
- **Größen-Check:** Recode nur wenn die Datei > 150 % der erwarteten Größe für ihre Laufzeit ist (MB/s pro Megapixel, kalibriert für Film & Serie).

#### 🎯 VMAF-Qualitätsmessung & Auto-Retry
- VMAF-Direktvergleich zwischen Quelle und Ausgabe (`n_subsample=5` – jeder 5. Frame, ~80 % schneller).
- Automatischer Re-Recode bei Score < Schwelle minus Toleranz (Standard: 93 - 1.5).
- Sicherung der bisherigen Ausgabe als `.backup` vor jedem Retry.

#### 🎥 Proaktive Interlace- & FPS-Stabilisierung
- `idet`-Analyse (1500 Frames) → echtes Deinterlacing via `bwdif` bei Bedarf.
- FPS-Capping auf **25 FPS** (PAL-Kompatibilität) bei Videos > 25.1 FPS.
- **Bit-Depth-Sanierung:** Nicht-8-Bit → standardisiertes HEVC 8-Bit.

#### 🔊 Professionelle Audionormalisierung (EBU R128)
- LUFS-Messung per `ebur128`, Zielwert konfigurierbar (Standard: **-18 LUFS**).
- Audio-Recode nur bei Abweichung > ±0.2 dB – sonst verlustfreie Kopie.
- AAC-Encoding mit dynamischer Bitrate (`libfdk_aac`-Kompatibilität / nativer AAC).

#### 🛑 Hang-Detection & Prozessüberwachung
- Asynchrone Überwachung aller FFmpeg-Prozesse im 10-Sekunden-Takt.
- **120-Sekunden-Timeout** für Analyse-Funktionen, **300-Sekunden-Timeout** für Encode/VMAF.
- Beendet blockierte Prozesse gezielt per PID (via `taskkill` statt `.Kill()`, robuster bei GPU-Deadlocks).

#### 🛡️ Mediaserver-Schutz
- Automatische `.embyignore`-Erstellung während der Verarbeitung (Jellyfin/Emby).
- Fehlerhafte Ausgabedateien werden verworfen (AVI-Analyse-Ausnahme).
- Finale Metadaten: `LUFS`, `gained`, `normalized=true`.

#### 📊 Farbkodierte Statistiktabelle
- Spalten: Datei, Aktion, Quelle/Ziel (MB), Ersparnis (MB/%), VMAF.
- Grün = eingespart, Rot = vergrößert · VMAF: Grün ≥ 93, Gelb 88–92, Rot < 88.
- Gesamtsummenzeile mit durchschnittlichem VMAF und Gesamtersparnis (MB + GB).

---

## 📺 Werkzeug 2: Serien-Umbenenner

**Skript:** [`Serien umbenenner.ps1`](./Serien%20umbenner.ps1)

Dieses Werkzeug automatisiert das Umbenennen von Serien-Dateien durch **Online-Abgleich mit fernsehserien.de**:

### Hauptfunktionen

| Funktion | Beschreibung |
|---|---|
| 🔍 **Online-Suche** | Automatische Suche auf fernsehserien.de, inkl. Umlaut-Normalisierung (Ä→AE) und Fallback-Suche bei Null-Treffern. |
| 🖼️ **Grafische Auswahl-GUI** | Bei mehreren Treffern öffnet sich ein Fenster mit Serienposter-Vorschau. |
| 📋 **Episodenführer-Abgleich** | Parst den Episodenführer und erkennt Episoden über Staffel-/Episodennummer (`SxxExx`), absolute Nummer oder Titelähnlichkeit (Levenshtein-Distanz). |
| 🏷️ **Scene-Tag-Bereinigung** | Entfernt automatisch Scene-Tags (PROPER, REPACK, 1080p, BluRay, x265, German, DL, ...) aus Dateinamen. |
| 🧠 **Lernender Tag-Filter** | GUI zur Auswahl zusätzlicher Tags, die dauerhaft in `CustomSceneTags.txt` gespeichert und zukünftig entfernt werden. |
| 💾 **Lokaler Serien-Cache** | Speichert Serieninformationen in `Serieninfo.txt` – erneute Läufe nutzen den lokalen Cache statt erneuter Online-Abfragen. |
| ↩️ **Automatischer Nachlauf** | Fehlgeschlagene Dateien werden im 2. Durchlauf mit erweiterter Suche (alle Treffer) erneut verarbeitet. |
| 🔢 **Intelligente Sortierung** | Sortierbare ListView mit benutzerdefiniertem Comparer (Text + Zahlen) in der Episoden-Auswahl. |
| 📁 **Massenumbenennung** | Verarbeitet komplette Ordnerstrukturen rekursiv (.mkv + .mp4). |

### Namensschema
```
Neue Datei:    Serie - S01E01 - Episodentitel.mkv
```

---

## 🛠️ Anforderungen

| Komponente | Version / Hinweis |
|---|---|
| **PowerShell** | Version **7.0+** (zwingend für `ForEach-Object -Parallel`) |
| **FFmpeg** | Mit `libx265`, `libvmaf`, `hevc_nvenc`, `hevc_amf`, `libfdk_aac` (Pfad in `$ffmpegPath` konfigurieren) |
| **MKVToolNix** | `mkvextract.exe` für die Tag-Prüfung (Pfad in `$mkvextractPath` konfigurieren) |
| **GPU (optional)** | NVIDIA- oder AMD-Grafikkarte für Hardware-Encoding |

**Serien-Umbenenner:** Benötigt Internetzugang zu `fernsehserien.de` und PowerShell 5.1+ (Windows Forms GUI).

---

## ⚙️ Konfiguration (Transcoder)

Alle wichtigen Parameter befinden sich im `#region Konfiguration`-Block:

| Variable | Standardwert | Beschreibung |
|---|---|---|
| `$ffmpegPath` | `"F:\media-autobuild_suite\local64\bin-video\ffmpeg.exe"` | Pfad zur `ffmpeg.exe` |
| `$mkvextractPath` | `"C:\Program Files\MKVToolNix\mkvextract.exe"` | Pfad zur `mkvextract.exe` |
| `$targetLoudness` | `-18` | Ziel-Lautheit in LUFS |
| `$extensions` | `@('.mkv', '.mp4', '.avi', '.m2ts')` | Verarbeitete Video-Formate |
| `$enableCalibrationLogging` | `$false` | Aktiviert das JSON-Kalibrierungs-Logging (⭐ NEU) |
| `$useHardwareAccel` | `$true` | GPU-Encoder-Suche aktiv (`$false` = CPU `libx265`) |
| `$encoderPreset` | `'medium'` | CPU-Preset für den Fallback |
| `$crfTargetm` | `18` | CRF-Zielwert für Filme |
| `$crfTargets` | `20` | CRF-Zielwert für Serien |
| `$qualitaetFilm` / `$qualitaetSerie` | `"hoch"` | Qualitätsprofil für den Größen-Check (`niedrig`, `mittel`, `hoch`, `sehrhoch`) |
| `$vmafStartSec` | `90` | Startpunkt des VMAF-Vergleichs |
| `$vmafDurationSec` | `300` | VMAF-Analysedauer (5 Minuten) |
| `$vmafAutoRetry` | `$true` | Auto-Retry bei zu niedrigem VMAF aktiv |
| `$vmafMinScore` | `93` | Mindest-VMAF-Score |
| `$vmafTolerance` | `1.5` | Erlaubte Abweichung vor Retry-Auslösung |
| `$vmafMaxRetries` | `2` | Maximale Re-Recode-Versuche |

---

## 🚀 Anwendung

### Auto Video Transcoder
1. Öffnen Sie PowerShell 7+.
2. Führen Sie das Skript aus:
   ```powershell
   & 'C:\Pfad\Auto Video Transcode noch schneller mit helligkeitsmessung.ps1'
   ```
3. Wählen Sie den Ordner mit Ihrer Videosammlung.
4. **Fertig.** Das Skript analysiert, konvertiert, normalisiert und validiert Ihre gesamte Sammlung.

### Serien-Umbenenner
1. Öffnen Sie PowerShell.
2. Führen Sie das Skript aus:
   ```powershell
   & 'C:\Pfad\Serien umbenenner.ps1'
   ```
3. Wählen Sie den Ordner mit Ihren Serien-Dateien.
4. Das Skript sucht jede Serie online, gleicht die Episoden ab und benennt die Dateien um.

---

## ⚠️ Haftungsausschluss

Der Transcoder löscht die Originaldateien nach erfolgreicher Konvertierung:
- Erstellen Sie **unbedingt ein Backup** Ihrer Sammlung.
- Testen Sie das Skript zunächst mit Kopien Ihrer Dateien.

**Die Nutzung erfolgt auf eigene Gefahr.**

---

## 📊 Feature-Status

| Feature | Status | Hinweise |
|---|---|---|
| **Helligkeitsanalyse + CRF-Anpassung** | ✅ Fertig | 9 Segmente, Mehrheitsentscheidung, HDR-Schutz (⭐ NEU) |
| **Kalibrierungs-Logging (JSON)** | ✅ Fertig | MB/s & MB/s pro Megapixel (⭐ NEU) |
| **Dynamische HWACCEL-Auswahl** | ✅ Fertig | Herstellerspezifische Prioritäten (⭐ NEU) |
| **Adaptives AAC-Bitrate-Management** | ✅ Fertig | Profil + Bitrate abhängig von Quelle & Kanälen (⭐ NEU) |
| **AVI-Restaurierung 720p** | ✅ Fertig | Denoise, Scale, Sharpen + Helligkeitskorrektur (⭐ NEU) |
| VMAF-Qualitätsmessung | ✅ Fertig | JSON-Log-Auswertung, n_subsample=5 |
| VMAF Auto-Retry | ✅ Fertig | Backup/Restore, Toleranzzone, CRF-Stepping |
| GPU-Beschleunigung | ✅ Fertig | NVIDIA (vbr+cq+multipass), AMD (qvbr+vbaq), CPU-Fallback |
| Parallele Tag-Prüfung | ✅ Fertig | 8 Threads, `NORMALIZED=true`-Erkennung |
| Serien-Erkennung | ✅ Fertig | SxxExx, 720p-Downscale, CRF-Unterschiede |
| Audio-Normalisierung (EBU R128) | ✅ Fertig | Ziel-LUFS -18, ±0.2 dB Toleranz |
| Interlace- & FPS-Stabilisierung | ✅ Fertig | bwdif, 25-FPS-Cap, 8-Bit-Sanierung |
| Hang-Detection | ✅ Fertig | 120s / 300s Timeouts, taskkill |
| Mediaserver-Schutz | ✅ Fertig | .embyignore, Fehler-Validierung, Metadaten |
| Farbkodierte Statistik | ✅ Fertig | Summenzeile, VMAF-Farbcodierung |
| **Serien-Umbenenner (eigenständig)** | ✅ Fertig | Online-Abgleich, GUI, Scene-Tags, Cache (⭐ NEU) |

---

## 🎯 Optimiert für

- **4K-Blu-rays** → HEVC 8-Bit/10-Bit + AAC, VMAF ≥ 93
- **Serien** → HEVC CRF 20, 720p-Downscale, saubere Dateinamen
- **Filme** → HEVC CRF 18, HDR-Schutz bei der Helligkeitsanalyse
- **Alte AVI-Schätze** → Deinterlace, Denoise, Upscale, Sharpen
- **Jellyfin/Emby-Setups** → Mediaserver-kompatibel, automatische Ignore-Dateien

---

## 📱 Unterstützung & Feedback

Für Fragen, Feature-Wünsche oder Issues öffnen Sie bitte ein [Issue im Repository](https://github.com/Maximus1/Powershell-Video-Transcoder/issues).

---

## 📄 Lizenz

Dieses Projekt ist unter der **MIT-Lizenz** veröffentlicht. Weitere Informationen finden Sie in der [LICENSE](./LICENSE)-Datei. Mitwirkende werden gebeten, den [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) zu respektieren.