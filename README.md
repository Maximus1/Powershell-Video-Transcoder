# 🚀 Der ultimative PowerShell Video-Transcoder & Normalizer – Mit Helligkeitsanalyse und CRF-Optimierung! 🚀

**Skript:** [Auto Video Transcode noch schneller mit helligkeitsmessung.ps1](./Auto%20Video%20Transcode%20noch%20schneller%20mit%20helligkeitsmessung.ps1)

Haben Sie es satt, Ihre Videos manuell zu konvertieren und die Lautstärke anzupassen? Verabschieden Sie sich von inkonsistenten Dateigrößen und schwankenden Audiopegeln! Dieses Skript ist Ihr persönlicher, vollautomatischer Medien-Butler, der Ihre gesamte Videosammlung in eine moderne, optimierte und qualitativ hochwertige Bibliothek verwandelt.

**Starten Sie das Skript, wählen Sie einen Ordner aus, und lehnen Sie sich zurück. Den Rest erledigt die Magie der Automatisierung!**

---

## ✨ Was ist neu? 🆕

### ⭐ Helligkeitsanalyse mit automatischer CRF-Anpassung
Das Skript analysiert jedes Video auf seine durchschnittliche Helligkeit mittels **9 repräsentativer Segmente** (YAVG-Werte), die gleichmäßig über den eigentlichen Filminhalt verteilt sind:

- **Vorspann-Versorgung:** Die ersten ~90 Sekunden werden übergangen, um Studiologos und Vorspann sicher zu überspringen
- **Abspann-Ausschluss:** Die letzten ~18% der Dauer werden ignoriert, um schwarzen Abspann nicht als dunkles Video zu interpretieren
- **Robuste Mehrheitsentscheidung:** Nur wenn die Mehrheit der Segmente (mindestens 6 von 9) dunkel ist (unter 60 YAVG), gilt das Video als überwiegend dunkel
- **Automatische CRF-Anpassung:** Bei überwiegend dunklem SDR-Material wird der CRF automatisch um 2 Punkte gesenkt, damit der Encoder mehr Bits für Schwarzbereiche und Rauschen aufwenden kann
- **Untergrenze CRF 14:** Verhindert Überkomprimierung auch bei sehr dunklen Videos
- **HDR-Schutz:** Bei HDR-Material wird die Helligkeitsanalyse automatisch übersprungen – SDR-Helligkeitswerte wären bei HDR-Content irreführend!

Diese Innovation sorgt dafür, dass dunkle Filme (Noir, Sci-Fi-Nächte, Horror) nicht unnötig komprimiert werden und stattdessen ihre Schwarzwerte und Bildatmosphäre optimal dargestellt bekommen.

---

## ✨ Hauptfunktionen – Was dieses Skript so besonders macht

Dieses Skript ist mehr als nur ein einfacher Konverter. Es ist ein intelligentes System, das für jede einzelne Datei die beste Entscheidung trifft.

### 🚀 Blitzschnelle parallele Verarbeitung
- **Multi-Core-Optimierung:** Das Skript nutzt **parallele Verarbeitung** mit bis zu 8 Threads gleichzeitig, um mehrere Videos gleichzeitig zu prüfen und zu entscheiden, welche Dateien konvertiert werden müssen.
- **Intelligente Normalisierungs-Vorab-Prüfung:** Alle Dateien werden zunächst parallel überprüft, um bereits normalisierte Dateien zu identifizieren und zu überspringen – keine Zeit mit unnötigen Konvertierungen verschwenden!

### 🎮 GPU-Beschleunigung für rasante Konvertierung
- **Automatische Encoder-Erkennung:** Das Skript erkennt Ihre Hardware automatisch und nutzt die beste verfügbare GPU:
  - **NVIDIA:** `hevc_nvenc` für blitzschnelle HEVC-Kodierung auf GeForce und RTX
  - **AMD:** `hevc_amf` für optimale Performance auf Radeon-Grafikkarten
  - **Fallback:** Nutzt `libx265` (CPU) wenn keine GPU verfügbar ist
- **Intelligentes Decoding:** Aktiviert auch beim Dekodieren Hardware-Beschleunigung, außer bei AV1-Material (das oft Probleme verursacht).

### 🧠 Intelligente & adaptive Transkodierung
- **Automatische Codec-Modernisierung:** Konvertiert veraltete Formate (wie XviD, DivX, H.264) automatisch in das hocheffiziente **HEVC (H.265)** Format.
- **Serien-Erkennung:** Erkennt automatisch Serien (`SxxExx`-Muster) und wendet optimierte CRF-Werte an. Filme bekommen CRF 18, Serien CRF 20.
- **Effizienz-Analyse:** Das Skript analysiert, ob eine Datei im Verhältnis zu ihrer Laufzeit zu groß ist. Nur wenn eine Neukodierung wirklich sinnvoll ist, wird sie durchgeführt.
- **Schutz vor Aufblähen:** Verhindert aktiv, dass eine neu kodierte Datei größer wird als das Original.

### 🌑 Adaptive Helligkeitsanalyse mit automatischer CRF-Anpassung ⭐ [NEU!]
Das Skript analysiert jedes Video auf seine durchschnittliche Helligkeit mittels **9 repräsentativer Segmente** (YAVG-Werte):

- **Vorspann-Versorgung:** Die ersten ~90 Sekunden werden übergangen, um Studiologos und Vorspann sicher zu überspringen
- **Abspann-Ausschluss:** Die letzten ~18% der Dauer werden ignoriert, um schwarzen Abspann nicht als dunkles Video zu interpretieren
- **Robuste Mehrheitsentscheidung:** Nur wenn die Mehrheit der Segmente (mindestens 6 von 9) dunkel ist (unter 60 YAVG), gilt das Video als überwiegend dunkel
- **Automatische CRF-Anpassung:** Bei überwiegend dunklem SDR-Material wird der CRF automatisch um 2 Punkte gesenkt, damit der Encoder mehr Bits für Schwarzbereiche und Rauschen aufwenden kann
- **HDR-Schutz:** Bei HDR-Material wird die Helligkeitsanalyse automatisch übersprungen – SDR-Helligkeitswerte wären bei HDR-Content irreführend!

Diese Innovation sorgt dafür, dass dunkle Filme (Noir, Sci-Fi-Nächte, Horror) nicht unnötig komprimiert werden und stattdessen ihre Schwarzwerte und Bildatmosphäre optimal dargestellt bekommen.

### 🎯 VMAF-Qualitätskontrolle mit automatischem Re-Recode
- **Professionelle Qualitätsmessung:** Nach jedem Recode wird der **VMAF-Score** (Video Multi-Method Assessment Fusion) gemessen – das Industriestandard-Verfahren von Netflix, das menschliche Wahrnehmung modelliert.
- **Konfigurierbare Zeitspanne:** Analyse-Start und -Dauer sind frei einstellbar (`$vmafStartSec`, `$vmafDurationSec`). Standard: ab 90s für 5 Minuten.
- **Automatischer Re-Recode:** Liegt der Score unter dem konfigurierten Mindestwert (`$vmafMinScore`, Standard: 93), wird automatisch ein neuer Encode mit CRF-2 gestartet – bis zu `$vmafMaxRetries` Mal.
- **Toleranzzone:** Scores knapp unter dem Schwellenwert (innerhalb `$vmafTolerance`, Standard: 1.5 Punkte) werden akzeptiert, da der Unterschied visuell nicht wahrnehmbar ist. Ein Score von z.B. 92.8 löst bei Schwelle 93 und Toleranz 1.5 keinen Retry aus.
- **Sicherheitsnetz:** Vor jedem Retry wird die aktuelle Ausgabedatei gesichert. Wird die neue Datei durch die Größenprüfung abgelehnt, wird das Backup automatisch wiederhergestellt.
- **Abschaltbar:** Die automatische Retry-Logik kann mit `$vmafAutoRetry = $false` deaktiviert werden – VMAF wird dann nur gemessen und angezeigt.

### 🎥 Proaktive Interlace & HDR-Erkennung
- **Automatische Interlace-Erkennung:** Das Skript prüft jedes Video auf veraltetes Interlaced-Material und wendet Deinterlacing (`bwdif`) an, falls nötig.
- **HDR-Format-Erkennung:** Erkennt automatisch HDR10, Dolby Vision, HLG und andere HDR-Formate.
- **Bittiefe-Analyse:** Identifiziert 8-Bit, 10-Bit und 12-Bit-Material für optimale Kodierungsentscheidungen.

### 🎬 Restaurierung für alte Schätze
- **AVI-Spezialbehandlung:** Alte AVI-Dateien erhalten eine VIP-Behandlung mit einer hochwertigen Filterkette:
  1. **Deinterlacing** (`bwdif`): Entfernt Kammartefakte
  2. **Rauschunterdrückung** (`hqdn3d`): Reduziert Bildrauschen
  3. **Upscaling auf 1080p**: Bringt altes Material auf Full-HD-Auflösung
  4. **Nachschärfen** (`cas`): Verleiht dem hochskalierten Bild Klarheit und Detailreichtum

### 🔊 Professionelle Audionormalisierung
- **Professionelle LUFS-Messung:** Nutzt FFmpeg's `ebur128`-Filter für genaue Lautstärke-Analyse.
- **Konsistente Lautstärke:** Alle Audiospuren werden auf **-18 LUFS** normalisiert (EBU R128 Standard).
- **Optimierter Codec:** Audio wird in **AAC** (via `libfdk_aac`) transkodiert, mit optimierten VBR-Bitraten für Surround (448 kbit/s), Stereo (320 kbit/s) und Mono (256 kbit/s).

### ⏱️ FPS-Stabilisierung
- **Automatisches FPS-Capping:** Bei Videos mit über 25 FPS wird das Video automatisch auf 25 fps heruntergekodet. Dies verhindert Playback-Probleme und sorgt für konsistente Wiedergabegeschwindigkeit (wichtig für PAL-Norm!).

### 🛑 Hang-Detection – Verhindert ewig hängende Prozesse! ⭐
- **Intelligenter Timeout-Mechanismus:** Wenn der FFmpeg-Prozess länger als 300 Sekunden (5 Minuten) keine Ausgabe produziert, wird er automatisch beendet.
- **Automatische Fehlermeldung:** Statt ewig warten zu müssen, erhalten Sie eine klare Fehlermeldung mit Farbkodierung (ROT!).
- **Prozess-Sicherheit:** Verhindert, dass Ihr System durch hängende FFmpeg-Prozesse blockiert wird.

### 📊 Detaillierte farbkodierte Statistik
Am Ende der Verarbeitung gibt das Skript eine vollständige Auswertung aller verarbeiteten Dateien aus:

```
Datei                  Aktion        Quelle (MB)   Ziel (MB)  Ersparnis (MB)  Ersparnis (%)    VMAF
──────────────────────────────────────────────────────────────────────────────────────────────
Film.mkv               V-recodiert      3241.44    2429.32          812.12        25.06%   96.24
Serie S01E01.mkv       VA-recodiert      876.33     621.18          255.15        29.11%   91.33
Doku.mkv               Kopiert          1024.00    1024.00            0.00         0.00%      -
──────────────────────────────────────────────────────────────────────────────────────────────
GESAMT (3 Dateien)                      5141.77    4074.50         1067.27        20.76%   93.79
  → Gesamtersparnis: 1067.27 MB (1.04 GB)
```

- **Aktionstypen:** `Kopiert` / `V-recodiert` / `A-recodiert` / `VA-recodiert`
- **Farbkodierung Größe:** Grün = Datei kleiner geworden, Rot = Datei größer geworden
- **Farbkodierung VMAF:** Grün ≥ 93, Gelb 88–92, Rot < 88

### 🛡️ Sicher & Zuverlässig
- **Integritätsprüfung:** Jede neu erstellte Datei wird mit FFmpeg auf Stream-Fehler überprüft.
- **Keine Duplikate:** Bereits normalisierte Dateien werden anhand von Metadaten-Tags erkannt und übersprungen.
- **Emby/Jellyfin-Integration:** Automatische `.embyignore`-Verwaltung verhindert, dass Mediaserver unfertige Dateien einlesen.
- **Detailliertes Logging:** Für jede verarbeitete Datei wird eine eigene Log-Datei erstellt.

---

## 🌟 Ihre Vorteile auf einen Blick
- **"Feuer und Vergessen"-Prinzip:** Starten Sie den Prozess für Ihre gesamte Mediathek und lassen Sie das Skript die Arbeit machen – auch über Nacht.
- **Massive Platzersparnis:** Modernisieren Sie Ihre Sammlung und gewinnen Sie wertvollen Speicherplatz zurück.
- **Einheitliche Qualität:** Konsistente visuelle und akustische Erfahrung über alle Ihre Filme und Serien.
- **Messbare Qualität:** VMAF-Score belegt objektiv, dass die Qualität erhalten geblieben ist.
- **Zukunftssicher:** HEVC und AAC, die Codecs der Zukunft.
- **Rasante GPU-Verarbeitung:** Nutzen Sie Ihre NVIDIA oder AMD GPU für bis zu 20x schnellere Konvertierungen.
- **Intelligente Helligkeitsoptimierung:** Dunkle Inhalte erhalten automatisch mehr Bitrate – perfekte Schwarzwerte!

---

## 🛠️ Anforderungen
1. **PowerShell 7.0+** – Empfohlen für parallele Verarbeitung. [Kostenlos downloadbar](https://github.com/PowerShell/PowerShell)
2. **FFmpeg** – Mit `libx265`, `libvmaf`, `hevc_nvenc` / `hevc_amf` (optional für GPU) und `libfdk_aac`. Pfad über `$ffmpegPath` konfigurieren.
3. **MKVToolNix** – `mkvextract.exe` wird für die Normalisierungs-Tag-Prüfung benötigt. Pfad über `$mkvextractPath` konfigurieren.
4. **GPU (optional)** – NVIDIA (RTX/GeForce) oder AMD Radeon für Hardware-beschleunigte Kodierung.

---

## ⚙️ Konfiguration

Alle Einstellungen befinden sich im `#region Konfiguration`-Block am Anfang der Skriptdatei:

| Variable | Standard | Beschreibung |
|---|---|---|
| `$ffmpegPath` | – | Vollständiger Pfad zu `ffmpeg.exe` |
| `$mkvextractPath` | – | Vollständiger Pfad zu `mkvextract.exe` |
| `$useHardwareAccel` | `$true` | GPU-Beschleunigung aktivieren |
| `$targetLoudness` | `-18` | Ziel-Lautheit in LUFS |
| `$crfTargetFilm` | `18` | CRF-Wert für Filme (SDR-Helligkeit) |
| `$crfTargetSerie` | `20` | CRF-Wert für Serien (SDR-Helligkeit) |
| `$vmafStartSec` | `90` | Startpunkt der VMAF-Analyse in Sekunden |
| `$vmafDurationSec` | `300` | Dauer der VMAF-Analyse in Sekunden |
| `$vmafAutoRetry` | `$true` | Automatischer Re-Recode bei schlechtem VMAF-Score |
| `$vmafMinScore` | `93` | Mindest-VMAF-Score (0–100) |
| `$vmafTolerance` | `1.5` | Akzeptierte Unterschreitung ohne Retry |
| `$vmafMaxRetries` | `2` | Maximale Anzahl Re-Recode-Versuche |
| `$hangTimeoutSeconds` | `300` | Hang-Detection Timeout in Sekunden (5 Min) |
| `$targetVideoCodec` | `'HEVC'` | Ziel-Video-Codec für die Transkodierung |
| `$targetExtension` | `'.mkv'` | Zieldateiendung für alle verarbeiteten Dateien |

---

## 🚀 Anwendung

### PowerShell 7+ als Standard einrichten (empfohlen)

```powershell
# Als Administrator ausführen
$regPath = "HKCU:\Software\Classes\.ps1\Shell\Open\command"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "(Default)" -Value 'C:\Program Files\PowerShell\7\pwsh.exe -File "%1"' -Force
```

### Skript ausführen
1. Öffnen Sie PowerShell 7+ oder Windows PowerShell.
2. Führen Sie das Skript aus: `.'Auto Video Transcode noch schneller mit helligkeitsmessung.ps1'`
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
| Hang-Detection | ✅ Fertig | 300 Sek Timeout, verhindert hängende Prozesse ⭐ |
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
