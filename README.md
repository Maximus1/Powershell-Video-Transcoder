[![Codacy Badge](https://app.codacy.com/project/badge/Grade/0ec11745ed0c4e268fa6fd2316f53b57)](https://app.codacy.com/gh/Maximus1/Powershell-Video-Transcoder/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

# 🚀 Der ultimative PowerShell Video-Transcoder & Normalizer – Mit Helligkeitsanalyse und CRF-Optimierung! 🚀

**Skript:** [Auto Video Transcode noch schneller mit helligkeitsmessung.ps1](./Auto%20Video%20Transcode%20noch%20schneller%20mit%20helligkeitsmessung.ps1)

Haben Sie es satt, Ihre Videos manuell zu konvertieren und die Lautstärke anzupassen? Verabschieden Sie sich von inkonsistenten Dateigrößen und schwankenden Audiopegeln! Dieses Skript ist Ihr persönlicher, vollautomatischer Medien-Butler, der Ihre gesamte Videosammlung in eine moderne, optimierte und qualitativ hochwertige Bibliothek verwandelt.

**Starten Sie das Skript, wählen Sie einen Ordner aus, und lehnen Sie sich zurück. Den Rest erledigt die Magie der Automatisierung!**

---

## ✨ Was ist neu? 🆕

### ⭐ Adaptive Helligkeitsanalyse mit automatischer CRF-Anpassung
Das Skript analysiert jedes Video vor dem Encoding auf seine durchschnittliche Helligkeit mittels **9 repräsentativer Segmente** (Luma-YAVG-Werte von 0-255) über ein 15-sekündiges Analysefenster pro Segment:

- **Vorspann-Schutz:** Die ersten 90 Sekunden werden übersprungen, um Studiologos und Intros zu ignorieren.
- **Abspann-Ausschluss:** Die letzten ~18% der Dauer werden ignoriert (Analyse endet bei 82% der Gesamtlaufzeit), um einen schwarzen Abspann nicht fälschlicherweise als dunkles Video zu interpretieren.
- **Präziser Doppel-Seek:** Nutzt einen kombinierten Fast-Seek und Accurate-Seek (`-ss [Zeit-2] -i ... -ss 2`), um Keyframe-Versatze ohne nennenswerten Dekodier-Overhead präzise auszugleichen.
- **Robuste Mehrheitsentscheidung:** Nur wenn eine klare Mehrheit der Segmente (**mindestens 6 von 9**) dunkel ist (unter 60 YAVG), gilt das Video als überwiegend dunkel.
- **Automatische CRF-Anpassung:** Bei überwiegend dunklem SDR-Material wird der CRF automatisch um 2 Punkte gesenkt, damit der Encoder mehr Bits für Schattenbereiche und Rauschen aufwendet (Untergrenze von CRF 14 ist fest codiert).
- **HDR-Schutz:** Bei HDR-Material wird die Helligkeitsanalyse automatisch übersprungen – SDR-Luma-Messungen wären bei HDR-Content irreführend!

Diese Innovation sorgt dafür, dass dunkle Filme (Noir, Sci-Fi-Nächte, Horror) ihre Schwarzwerte und Bildatmosphäre optimal beibehalten.

---

## ✨ Hauptfunktionen – Was dieses Skript so besonders macht

### 🚀 Blitzschnelle parallele Verarbeitung der Tag-Prüfung
- **Multi-Core-Optimierung:** Das Skript nutzt **parallele Verarbeitung mit bis zu 8 Threads gleichzeitig** (`ForEach-Object -Parallel`), um den Normalisierungs-Status aller Dateien im Ordner vorab zu ermitteln.
- **Intelligente Vorab-Prüfung:** Bereits normalisierte MKV-Dateien (erkannt am Metadaten-Tag `NORMALIZED=true` via `mkvextract`) werden sofort identifiziert und übersprungen. Das spart massiv Zeit!

### 🎮 GPU-Beschleunigung für rasante Konvertierung
- **Automatische Hardware-Erkennung:** Das Skript analysiert Ihre Grafikkarten via WMI/CIM und gleicht diese mit den verfügbaren FFmpeg-Encodern ab:
  - **NVIDIA:** `hevc_nvenc` (mit dem zugewiesenen Qualitäts-Preset `hq`) und hardwarebeschleunigtem Decoding via `d3d11va`.
  - **AMD:** `hevc_amf` (mit dem zugewiesenen Qualitäts-Preset `quality`) und hardwarebeschleunigtem Decoding via `d3d11va`.
  - **Fallback:** Automatische Umschaltung auf den CPU-Encoder `libx265`, falls keine kompatible GPU oder kein passender FFmpeg-Support gefunden wird.
- **AV1-Sicherheitsnetz:** Bei AV1-Quellmaterial wird die Hardware-Dekodierung (`-hwaccel d3d11va`) automatisch deaktiviert, da sie häufig zu Instabilitäten führt.

### 🧠 Intelligente & adaptive Transkodierung
- **Automatische Codec-Modernisierung:** Konvertiert veraltete Formate (wie XviD, DivX, H.264) automatisch in das hocheffiziente **HEVC (H.265)** Format.
- **Serien-Erkennung & Parameter-Wechsel:** Erkennt Serien automatisch anhand des `SxxExx`-Musters im Dateinamen:
  - **Filme:** Erhalten den Standard-Zielwert `$crfTargetm = 18` (bzw. CQ/CQP-Äquivalente bei GPU-Nutzung).
  - **Serien:** Erhalten den Standard-Zielwert `$crfTargets = 20`. Falls eine Serie eine Auflösung von über 720p besitzt, wird automatisch eine Skalierung auf 720p (`scale=1280:-2`) erzwungen, um Speicherplatz zu sparen.
- **Effizienz-Analyse (Größen-Check):** Vergleicht die tatsächliche Dateigröße mit einer mathematisch erwarteten Zielgröße (basierend auf konfigurierten Bitraten-Profilen). Ein Recode wird nur durchgeführt, wenn die Datei signifikant zu groß für ihre Laufzeit ist (> 50% über dem Erwartungswert) oder der Codec nicht übereinstimmt.
- **Schutz vor Aufblähen:** Sollte die neu kodierte Ausgabedatei trotz Video-Rekodierung um mehr als 3 MB größer werden als das Original, bricht die Validierung ab und die Datei wird verworfen.

### 🎯 VMAF-Qualitätskontrolle mit automatischem Re-Recode
- **Professionelle Qualitätsmessung:** Misst den **VMAF-Score** (Video Multi-Method Assessment Fusion) im Direktvergleich zwischen Quelle und Ausgabe mittels `n_subsample=5` (jeder 5. Frame wird gewertet – spart ~80% Analysezeit).
- **Automatische CRF-Kompensation:** Fällt der VMAF-Score unter die konfigurierte Mindestgrenze abzüglich der Toleranz (`$vmafMinScore - $vmafTolerance`), startet das Skript automatisch einen neuen Encoding-Versuch.
- **Iterative Qualitätssteigerung:** Bei jedem der maximal `$vmafMaxRetries` Versuche wird der CRF-Wert um weitere 2 Punkte gesenkt (bis maximal CRF 14), um die Bitrate gezielt anzuheben.
- **Dateisicherungs-Netz:** Vor jedem erneuten Recode wird die bisherige Ausgabedatei als `.backup` gesichert. Schlägt der neue Versuch fehl oder reißt die Dateigrößengrenze, wird das Backup vollautomatisch wiederhergestellt.

### 🎥 Proaktive Interlace & FPS-Stabilisierung
- **Dynamische Interlace-Erkennung:** Analysiert die ersten 1500 Frames via `idet`-Filter. Überwiegen TFF/BFF-Frames gegenüber progressiven Frames, wird echtes Deinterlacing mittels `bwdif=0:-1:0` hinzugeschaltet.
- **FPS-Capping (PAL-Kompatibilität):** Videos mit einer Framerate von mehr als 25.1 FPS werden beim Encoding rigoros auf **25 FPS** begrenzt (`-r 25`), um Abspielprobleme auf klassischen Mediaplayern zu verhindern.
- **Bit-Depth-Sanierung:** Videos mit einer Farbtiefe ungleich 8-Bit werden automatisch zu standardisiertem HEVC 8-Bit re-kodiert.

### 🎬 Restaurierung für alte Schätze (AVI-VIP-Behandlung)
Alte `.avi`-Dateien durchlaufen automatisch eine fest definierte, hochwertige Restaurierungs-Filterkette auf Basis von CPU/GPU-spezifischen Profilen (Standard-Basiswert: CRF 20):
1. **Deinterlacing** (`bwdif=0:-1:0`) – falls die `idet`-Analyse Interlaced-Material meldet.
2. **Rauschunterdrückung** (`hqdn3d=1.0:1.5:3.0:4.5`) zur Bereinigung des analogen Rauschens.
3. **Upscaling auf 1080p** via intelligentem `scale=1920:-2`.
4. **Nachschärfen** mittels Contrast Adaptive Sharpening (`cas=strength=0.15`) für klare Kantenzeichnungen.

### 🔊 Professionelle Audionormalisierung (EBU R128)
- **Präzise LUFS-Messung:** Analysiert die erste Audiospur via FFmpeg-Filter `ebur128`.
- **Exakte Pegelanpassung:** Berechnet die Abweichung zum konfigurierten Zielwert `$targetLoudness = -18` LUFS. Liegt die Abweichung über 0.2 dB, wird das Audio angepasst.
- **High-End Audio-Encoding:** Nutzt den hochwertigen `libfdk_aac`-Codec im Variable-Bitrate-Verfahren (VBR):
  - **Surround-Audio (> 2 Kanäle):** `VBR 3` für exzellente Raumklang-Kompression.
  - **Stereo-Audio (= 2 Kanäle):** `VBR 2` für kristallklaren Stereoklang.
  - **Mono-Audio:** `VBR 1` unter expliziter Downmix-Erzwingung auf einen Kanal (`-ac 1`).
- **Bitstream-Kopie:** Liegt der Pegel bereits im Toleranzbereich (±0.2 dB), wird die Audiospur verlustfrei kopiert (`-c:a copy`).

### 🛑 Hang-Detection & Asynchrone Prozessüberwachung
Das Skript duldet keine blockierten Prozesse. Über die Hintergrund-Überwachung `Watch-FFmpegProcess` werden alle kritischen Instanzen im **10-Sekunden-Takt** validiert:

| Modus | Abgedeckte Funktionen | Überwachungskriterien | Timeout | Aktion bei Fehler |
|---|---|---|---|---|
| **1B** | `Get-FFmpegOutput`<br>`Get-InterlaceInfo`<br>`Get-VideoBrightnessInfo`<br>`Get-LoudnessInfo` | CPU-Aktivität (Delta < 0.5s Stagnation) | **120 Sek.** | Beendet exakt die betroffene Prozess-PID via `.Kill()` |
| **2 / 3** | `Set-VolumeGain` (CPU-Fallback)<br>`Get-VmafScore` | Globaler Frame-Fortschritt (`$global:CurrentFFmpegFrame`) & CPU-Aktivität | **120 Sek.** | Beendet exakt die betroffene Prozess-PID via `.Kill()` |

*Hinweis zur Haupt-GPU-Konvertierung:* Die Haupt-Konvertierung in `Set-VolumeGain` besitzt eine zusätzliche, integrierte asynchrone Schleife (`ReadLineAsync`) mit einem dedizierten **300-Sekunden-Timeout** (5 Minuten), die bei vollständigem Stillstand der FFmpeg-Standardfehlerausgabe greift und den Prozess terminiert.

### 📊 Detaillierte farbkodierte Statistik
Nach Abschluss aller Aufgaben wird eine strukturierte Tabelle mit dynamisch berechneten Spaltenbreiten und einer finalen Summenzeile ausgegeben:
- **Aktionen:** `Kopiert`, `V-recodiert`, `A-recodiert`, `VA-recodiert`.
- **Farbmetriken (Größe):** **Grün** = Speicherplatz erfolgreich eingespart / **Rot** = Datei vergrößert.
- **Farbmetriken (VMAF):** **Grün** = Exzellent (≥ 93) / **Gelb** = Akzeptabel (88-92) / **Rot** = Qualitätsverlust (< 88).

### 🛡️ Mediaserver-Schutz & Sicherheit
- **Jellyfin/Emby-Integration:** Während der Verarbeitung einer Videodatei wird im entsprechenden Verzeichnis temporär eine `.embyignore`-Datei erstellt. Das verhindert, dass Mediaserver die unvollständige Datei mitten im Konvertierungsprozess einlesen. Nach Abschluss wird die Datei sauber bereinigt.
- **Fehler-Validierung:** Bei Fehlern im Transcoding wird die fehlerhafte Ausgabedatei sofort gelöscht (Ausnahme: Beschädigte `.avi`-Dateien werden zu Analysezwecken einbehalten).
- **Verlustfreier Metadaten-Schluss:** Jede Datei erhält die finalen Tags `LUFS`, `gained` und `normalized=true`.

---

## 🛠️ Anforderungen

1. **PowerShell 7.0+** – Zwingend erforderlich für die parallele Verarbeitung (`ForEach-Object -Parallel`).
2. **FFmpeg** – Kompiliert mit `libx265`, `libvmaf`, `hevc_nvenc`, `hevc_amf` und `libfdk_aac`. Der Pfad muss in `$ffmpegPath` hinterlegt werden.
3. **MKVToolNix** – `mkvextract.exe` wird zwingend für die Tag-Prüfung benötigt. Der Pfad muss in `$mkvextractPath` hinterlegt werden.
4. **Hardware (Optional):** NVIDIA- oder AMD-Grafikkarte für die Nutzung der schnellen Hardware-Encoder.

---

## ⚙️ Konfiguration

Alle wichtigen Parameter lassen sich im `#region Konfiguration`-Block am Anfang des Skripts feintunen:

| Variable | Standardwert | Beschreibung |
|---|---|---|
| `$ffmpegPath` | `"F:\media-autobuild_suite-master\local64\bin-video\ffmpeg.exe"` | Vollständiger Pfad zur `ffmpeg.exe`. |
| `$mkvextractPath` | `"C:\Program Files\MKVToolNix\mkvextract.exe"` | Vollständiger Pfad zur `mkvextract.exe`. |
| `$targetLoudness` | `-18` | Ziel-Lautheit in LUFS für die Normalisierung. |
| `$extensions` | `@('.mkv', '.mp4', '.avi', '.m2ts')` | Array der im Ordnerscan berücksichtigen Video-Formate. |
| `$useHardwareAccel` | `$true` | Aktiviert die GPU-Encoder-Suche (`$false` erzwingt CPU `libx265`). |
| `$encoderPreset` | `'medium'` | x265-Geschwindigkeits-Preset für den CPU-Fallback. |
| `$crfTargetm` | `18` | Standard-CRF-Wert für Filme (SDR). |
| `$crfTargets` | `20` | Standard-CRF-Wert für Serien (SDR). |
| `$qualitaetFilm` | `"hoch"` | Qualitätsprofil für den Größen-Check bei Filmen (`niedrig`, `mittel`, `hoch`, `sehrhoch`). |
| `$qualitaetSerie` | `"hoch"` | Qualitätsprofil für den Größen-Check bei Serien (`niedrig`, `mittel`, `hoch`, `sehrhoch`). |
| `$vmafStartSec` | `90` | Startzeitpunkt des VMAF-Vergleichs (überspringt Intros). |
| `$vmafDurationSec` | `300` | Dauer des VMAF-Vergleichsfensters (5 Minuten). |
| `$vmafAutoRetry` | `$true` | Aktiviert den automatischen Re-Recode bei ungenügendem VMAF. |
| `$vmafMinScore` | `93` | Angestrebter Mindest-VMAF-Score. |
| `$vmafTolerance` | `1.5` | Erlaubte Abweichung. Ein Score bis `91.5` löst hier noch keinen Retry aus. |
| `$vmafMaxRetries` | `2` | Maximale Anzahl an Re-Recode-Versuchen pro Datei. |

---

## 🚀 Anwendung

### Skript ausführen
1. Öffnen Sie PowerShell 7+ oder Windows PowerShell.
2. Führen Sie das Skript aus: `'C:\Pfad\Auto Video Transcode noch schneller mit helligkeitsmessung.ps1'`
3. Es öffnet sich ein Dialogfenster. Wählen Sie den Ordner mit Ihrer Videosammlung aus.
4. Bestätigen Sie mit "OK".
5. **Das war's!** Beobachten Sie, wie Ihr Computer Ihre Mediathek auf das nächste Level hebt.

---

## ⚠️ Haftungsausschluss

Dieses Skript löscht die Originaldateien nach einer erfolgreichen Konvertierung. Es wird dringend empfohlen, **vor der ersten Anwendung ein Backup Ihrer Daten zu erstellen** oder das Skript zunächst mit Kopien Ihrer Dateien in einem Testordner auszuführen.

**Die Nutzung erfolgt auf eigene Gefahr.**

---

## 📊 Feature-Status

| Feature | Status | Hinweise |
|---|---|---|
| GPU-Beschleunigung (NVIDIA/AMD) | ✅ Fertig | hevc_nvenc, hevc_amf, libx265 Fallback |
| Metadaten-Analyse | ✅ Fertig | Codec, Auflösung, Audio, Interlace, HDR, Bittiefe, FPS |
| Serien-Erkennung | ✅ Fertig | SxxExx Pattern-Matching, automatisches 720p-Downscaling |
| Normalisierungs-Checking | ✅ Fertig | Parallele Überprüfung mit Fortschritts-Tracking |
| Emby/Jellyfin-Integration | ✅ Fertig | Automatische .embyignore Erstellung & Bereinigung |
| Video-Transkodierung | ✅ Fertig | HEVC-Encoding mit CRF-Optimierung |
| Audio-Normalisierung | ✅ Fertig | EBUR128-Messung, AAC-Kodierung (libfdk_aac), VBR-Optimierung |
| AVI-Spezialbehandlung | ✅ Fertig | Deinterlace, Denoise, Upscale auf 1080p, Sharpen |
| **Helligkeitsanalyse** | ✅ Fertig | **9 Segmente-YAVG, Mehrheitsentscheid, automatische CRF-Anpassung ⭐** |
| FPS-Stabilisierung | ✅ Fertig | Auto-Cap >25 → 25 fps für PAL-Kompatibilität |
| **Hang-Detection** | ✅ Fertig | **300 Sek Timeout, verhindert hängende Prozesse ⭐**|
| VMAF-Qualitätsmessung | ✅ Fertig | n_subsample=5, konfigurierbare Zeitspanne |
| VMAF Auto-Retry | ✅ Fertig | Bis zu 2 Re-Recode-Versuche, Backup/Restore-Sicherung, Toleranzzone |
| Farbkodierte Statistik | ✅ Fertig | Aktion, Größen, Ersparnis, VMAF pro Datei + Summenzeile |
| Error Handling & Logging | ✅ Fertig | Integritätsprüfung, detaillierte Logs pro Datei |
| Dialogfenster im Vordergrund | ✅ Fertig | Zuverlässig auch bei Start aus VSCode |

---

## 🎯 Optimiert für:

- **4K Blu-rays** → HEVC 8-Bit/10-Bit + AAC, VMAF ≥93
- **Serien (Netflix/Amazon/HBO)** → HEVC, CRF20 + Serien-Namensnormalisierung  
- **Filme** → HEVC CRF18 bei hohem Bitbudget, HDR10 + Dolby Vision
- **Streaming-Sets** (Jellyfin) → HEVC 4:2:0 C500 für optimale Kompatibilität

---

## 📱 Unterstützung & Feedback

Dieses Skript ist Teil der [Powershell-Video-Transcoder](https://github.com/Maximus1/Powershell-Video-Transcoder)-Sammlung auf GitHub. Für Fragen, Features oder Issues, öffnen Sie bitte ein [Issue im Repository](https://github.com/Maximus1/Powershell-Video-Transcoder/issues).
