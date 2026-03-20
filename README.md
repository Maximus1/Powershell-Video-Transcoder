# 🚀 Der ultimative PowerShell Video-Transcoder & Normalizer 🚀

Haben Sie es satt, Ihre Videos manuell zu konvertieren und die Lautstärke anzupassen? Verabschieden Sie sich von inkonsistenten Dateigrößen und schwankenden Audiopegeln! Dieses Skript ist Ihr persönlicher, vollautomatischer Medien-Butler, der Ihre gesamte Videosammlung in eine moderne, optimierte und qualitativ hochwertige Bibliothek verwandelt.

**Starten Sie das Skript, wählen Sie einen Ordner aus, und lehnen Sie sich zurück. Den Rest erledigt die Magie der Automatisierung!**

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

### 🌑 Adaptive Helligkeitsanalyse mit automatischer CRF-Anpassung
- **Intelligente SDR-Helligkeitsmessung:** Das Skript analysiert die Helligkeit jedes Videos anhand von **9 repräsentativen Segmenten**, die gleichmäßig über den eigentlichen Filminhalt verteilt werden – Vorspann (erste 90 Sekunden) und Abspann (letzte 18%) werden automatisch ausgeschlossen.
- **Robuster Mehrheitsentscheid:** Nur wenn die **Mehrheit der Segmente** (mindestens 6 von 9) dunkel ist, gilt das Video als überwiegend dunkel. Einzelne dunkle Szenen lösen keine Anpassung aus.
- **Automatische CRF-Absenkung:** Bei überwiegend dunklem SDR-Material wird der CRF automatisch um 2 Punkte gesenkt, damit der Encoder mehr Bits für Schwarzbereiche und Rauschen aufwenden kann. Untergrenze: CRF 14.
- **HDR-Schutz:** Bei HDR-Material wird die Analyse automatisch übersprungen – SDR-Helligkeitswerte wären bei HDR-Content irreführend.
- **Technologie:** Nutzt FFmpegs `showinfo`-Filter mit doppeltem Seek-Verfahren (Fast-Seek + Accurate-Seek) für präzise und schnelle Ergebnisse ohne externe Tools.

### 🎯 VMAF-Qualitätskontrolle mit automatischem Re-Recode
- **Professionelle Qualitätsmessung:** Nach jedem Recode wird der **VMAF-Score** (Video Multi-Method Assessment Fusion) gemessen – das Industriestandard-Verfahren von Netflix, das menschliche Wahrnehmung modelliert.
- **Konfigurierbare Zeitspanne:** Analyse-Start und -Dauer sind frei einstellbar (`$vmafStartSec`, `$vmafDurationSec`). Standard: ab 90s für 5 Minuten.
- **Automatischer Re-Recode:** Liegt der Score unter dem konfigurierten Mindestwert (`$vmafMinScore`, Standard: 93), wird automatisch ein neuer Encode mit CRF-2 gestartet – bis zu `$vmafMaxRetries` Mal.
- **Toleranzzone:** Scores knapp unter dem Schwellenwert (innerhalb `$vmafTolerance`, Standard: 2.0 Punkte) werden akzeptiert, da der Unterschied visuell nicht wahrnehmbar ist. Ein Score von z.B. 92.1 löst bei Schwelle 93 und Toleranz 2.0 keinen Retry aus.
- **Sicherheitsnetz:** Vor jedem Retry wird die aktuelle Ausgabedatei gesichert. Wird die neue Datei durch die Größenprüfung abgelehnt, wird das Backup automatisch wiederhergestellt.
- **Abschaltbar:** Die automatische Retry-Logik kann mit `$vmafAutoRetry = $false` deaktiviert werden – VMAF wird dann nur gemessen und angezeigt.

### 🎥 Proaktive Interlace & HDR-Erkennung
- **Automatische Interlace-Erkennung:** Das Skript prüft jedes Video auf veraltetes Interlaced-Material und wendet Deinterlacing (`bwdif`) an, falls nötig.
- **HDR-Format-Erkennung:** Erkennt automatisch HDR10, Dolby Vision, HLG und andere HDR-Formate.
- **Bittiefe-Analyse:** Identifiziert 10-Bit und 12-Bit-Material für optimale Kodierungsentscheidungen.

### 🎬 Restaurierung für alte Schätze
- **AVI-Spezialbehandlung:** Alte AVI-Dateien erhalten eine VIP-Behandlung mit einer hochwertigen Filterkette:
  1. **Deinterlacing** (`bwdif`): Entfernt Kammartefakte
  2. **Rauschunterdrückung** (`hqdn3d`): Reduziert Bildrauschen
  3. **Upscaling auf 1080p**: Bringt altes Material auf Full-HD-Auflösung
  4. **Nachschärfen** (`cas`): Verleiht dem hochskalierten Bild Klarheit und Detailreichtum

### 🔊 Professionelle Audionormalisierung
- **Professionelle LUFS-Messung:** Nutzt FFmpegs `ebur128`-Filter für genaue Lautstärke-Analyse.
- **Konsistente Lautstärke:** Alle Audiospuren werden auf **-18 LUFS** normalisiert.
- **Optimierter Codec:** Audio wird in **AAC** (via `libfdk_aac`) transkodiert, mit optimierten VBR-Bitraten für Surround, Stereo und Mono.

### 📊 Detaillierte farbkodierte Statistik
Am Ende der Verarbeitung gibt das Skript eine vollständige Auswertung aller verarbeiteten Dateien aus:

```
Datei                  Aktion        Quelle (MB)   Ziel (MB)  Ersparnis (MB)  Ersparnis (%)    VMAF
────────────────────────────────────────────────────────────────────────────────────────────────────
Film.mkv               V-recodiert      3241.44    2429.32          812.12        25.06%   96.24
Serie S01E01.mkv       VA-recodiert      876.33     621.18          255.15        29.11%   91.33
Doku.mkv               Kopiert          1024.00    1024.00            0.00         0.00%      -
────────────────────────────────────────────────────────────────────────────────────────────────────
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
- **„Feuer und Vergessen"-Prinzip:** Starten Sie den Prozess für Ihre gesamte Mediathek und lassen Sie das Skript die Arbeit machen – auch über Nacht.
- **Massive Platzersparnis:** Modernisieren Sie Ihre Sammlung und gewinnen Sie wertvollen Speicherplatz zurück.
- **Einheitliche Qualität:** Konsistente visuelle und akustische Erfahrung über alle Ihre Filme und Serien.
- **Messbare Qualität:** VMAF-Score belegt objektiv, dass die Qualität erhalten geblieben ist.
- **Zukunftssicher:** HEVC und AAC, die Codecs der Zukunft.
- **Rasante GPU-Verarbeitung:** Nutzen Sie Ihre NVIDIA oder AMD GPU für bis zu 10x schnellere Konvertierungen.

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
| `$crfTargetm` | `18` | CRF-Wert für Filme |
| `$crfTargets` | `20` | CRF-Wert für Serien |
| `$qualitaetFilm` | `"hoch"` | Qualitätsstufe für die Effizienz-Analyse (Filme) |
| `$qualitaetSerie` | `"hoch"` | Qualitätsstufe für die Effizienz-Analyse (Serien) |
| `$vmafStartSec` | `90` | Startpunkt der VMAF-Analyse in Sekunden |
| `$vmafDurationSec` | `300` | Dauer der VMAF-Analyse in Sekunden |
| `$vmafAutoRetry` | `$true` | Automatischer Re-Recode bei schlechtem VMAF-Score |
| `$vmafMinScore` | `93` | Mindest-VMAF-Score (0–100) |
| `$vmafTolerance` | `2.0` | Akzeptierte Unterschreitung ohne Retry |
| `$vmafMaxRetries` | `2` | Maximale Anzahl Re-Recode-Versuche |

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
2. Führen Sie das Skript aus: `.'Auto Video Transcode noch schneller.ps1'`
3. Es öffnet sich ein Dialogfenster. Wählen Sie den Ordner mit Ihrer Videosammlung aus.
4. Bestätigen Sie mit „OK".
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
| Metadaten-Analyse | ✅ Fertig | Codec, Auflösung, Audio, Interlace, HDR, Bittiefe |
| Serien-Erkennung | ✅ Fertig | SxxExx Pattern-Matching, automatisches 720p-Downscaling |
| Normalisierungs-Checking | ✅ Fertig | Parallele Überprüfung mit Fortschritts-Tracking |
| Emby/Jellyfin-Integration | ✅ Fertig | Automatische .embyignore Erstellung & Bereinigung |
| Video-Transkodierung | ✅ Fertig | HEVC-Encoding mit CRF-Optimierung |
| Audio-Normalisierung | ✅ Fertig | EBUR128-Messung, AAC-Kodierung (libfdk_aac) |
| AVI-Spezialbehandlung | ✅ Fertig | Deinterlace, Denoise, Upscale auf 1080p, Sharpen |
| Helligkeitsanalyse | ✅ Fertig | 9 Segmente, Mehrheitsentscheid, automatische CRF-Anpassung |
| VMAF-Qualitätsmessung | ✅ Fertig | n_subsample=5, konfigurierbare Zeitspanne |
| VMAF Auto-Retry | ✅ Fertig | Bis zu 2 Re-Recode-Versuche, Backup/Restore-Sicherung, Toleranzzone |
| Farbkodierte Statistik | ✅ Fertig | Aktion, Größen, Ersparnis, VMAF pro Datei + Summenzeile |
| Error Handling & Logging | ✅ Fertig | Integritätsprüfung, detaillierte Logs pro Datei |
| Dialogfenster im Vordergrund | ✅ Fertig | Zuverlässig auch bei Start aus VSCode |