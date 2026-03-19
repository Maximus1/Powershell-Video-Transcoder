# 🚀 Der ultimative PowerShell Video-Transcoder & Normalizer 🚀

Haben Sie es satt, Ihre Videos manuell zu konvertieren und die Lautstärke anzupassen? Verabschieden Sie sich von inkonsistenten Dateigrößen und schwankenden Audiopegeln! Dieses Skript ist Ihr persönlicher, vollautomatischer Medien-Butler, der Ihre gesamte Videosammlung in eine moderne, optimierte und qualitativ hochwertige Bibliothek verwandelt.

**Starten Sie das Skript, wählen Sie einen Ordner aus, und lehnen Sie sich zurück. Den Rest erledigt die Magie der Automatisierung!**
---

## ✨ Hauptfunktionen – Was dieses Skript so besonders macht
Dieses Skript ist mehr als nur ein einfacher Konverter. Es ist ein intelligentes System, das für jede einzelne Datei die beste Entscheidung trifft.

### 🚀 Blitzschnelle parallele Verarbeitung
- **Multi-Core-Optimierung:** Das Skript nutzt **parallele Verarbeitung** mit bis zu 8 Threads gleichzeitig, um mehrere Videos gleichzeitig zu prüfen und zu entscheiden, welche Dateien konvertiert werden müssen.
Perfekt für moderne Systeme mit mehreren CPU-Kernen!
- **Intelligente Normalisierungs-Vorab-Prüfung:** Alle Dateien werden zunächst parallel überprüft, um bereits normalisierte Dateien zu identifizieren und zu überspringen – keine Zeit mit unnötigen Konvertierungen verschwenden!

### 🎮 GPU-Beschleunigung für rasante Konvertierung
- **Automatische Encoder-Erkennung:** Das Skript erkennt Ihre Hardware automatisch und nutzt die beste verfügbare GPU:
    - **NVIDIA:** `hevc_nvenc` für blitzschnelle HEVC-Kodierung auf GeForce und RTX
    - **AMD:** `hevc_amf` für optimale Performance auf Radeon-Grafikkarten
    - **Fallback:** Nutzt `libx265` (CPU) wenn keine GPU verfügbar ist
- **Intelligentes Decoding:** Aktiviert auch beim Dekodieren Hardware-Beschleunigung, außer bei AV1-Material (das oft Probleme verursacht).

### 🧠 Intelligente & adaptive Transkodierung
- **Automatische Codec-Modernisierung:** Konvertiert veraltete Formate (wie XviD, DivX, H.264) automatisch in das hocheffiziente **HEVC (H.265)** Format, um massiv Speicherplatz zu sparen.
- **Serien-Erkennung:** Erkennt automatisch Serien (`SxxExx`-Muster) und wendet optimierte CRF-Werte an. Filme bekommen CRF 18, Serien CRF 20 für bessere Kompression, ohne Qualität zu opfern!
- **Effizienz-Analyse:** Das Skript analysiert, ob eine Datei im Verhältnis zu ihrer Laufzeit zu groß ist. Nur wenn eine Neukodierung wirklich sinnvoll ist, wird sie durchgeführt. Effiziente Dateien werden unangetastet gelassen!
- **Schutz vor Aufblähen:** Verhindert aktiv, dass eine neu kodierte Datei größer wird als das Original.

### 🎥 Proaktive Interlace & HDR-Erkennung
- **Automatische Interlace-Erkennung:** Das Skript prüft jedes Video auf veraltetes Interlaced-Material und wendet Deinterlacing (`bwdif`) an, falls nötig – für sauberes, modernes Video!
- **HDR-Format-Erkennung:** Erkennt automatisch HDR10, Dolby Vision, HLG und andere HDR-Formate, um sicherzustellen, dass hochwertige Inhalte richtig verarbeitet werden.
- **Bittiefe-Analyse:** Identifiziert 10-Bit und 12-Bit-Material für optimale Kodierungsentscheidungen.

### 🎬 Restaurierung für alte Schätze
- **AVI-Spezialbehandlung:** Alte AVI-Dateien erhalten eine VIP-Behandlung! Sie werden nicht nur konvertiert, sondern durch eine hochwertige Filterkette visuell restauriert:
    1.  **Deinterlacing** (`yadif`): Entfernt unschöne Kammartefakte.
    2.  **Rauschunterdrückung** (`nlmeans`): Reduziert Bildrauschen für ein sauberes Bild.
    3.  **Upscaling auf 1080p**: Bringt altes Material auf Full-HD-Auflösung.
    4.  **Nachschärfen** (`unsharp`): Verleiht dem hochskalierten Bild wieder Klarheit und Detailreichtum.

### 🔊 Professionelle Audionormalisierung mit präziser Lautstärke-Messung
- **Professionelle LUFS-Messung:** Nutzt FFmpeg's `ebur128`-Filter für genaue **Lautstärke-Analyse** jeder Audiospur.
- **Konsistente Lautstärke:** Alle Audiodateien werden auf einen professionellen Standard von **-18 LUFS** normalisiert – nie wieder zur Fernbedienung greifen!
- **Perfekter Codec:** Audio wird immer in das universell kompatible **AAC-Format** transkodiert, mit optimierten Bitraten für Surround, Stereo und Mono.
- **Adaptive Normalisierung:** Das Skript berechnet den exakten Gain-Boost für jede Datei und normalisiert ohne störende Kompression oder Verzerrung.

### 🛡️ Sicher & Zuverlässig
- **Integritätsprüfung:** Jede neu erstellte Datei wird mit `ffmpeg` auf Stream-Fehler überprüft, um sicherzustellen, dass das Ergebnis perfekt ist.
- **Keine Duplikate:** Das Skript erkennt bereits normalisierte Dateien anhand von Metadaten-Tags und überspringt sie, um doppelte Arbeit zu vermeiden.
- **Emby-Integration (.embyignore):** Während der Verarbeitung wird automatisch eine `.embyignore`-Datei im aktuellen Ordner erstellt. Dies verhindert, dass Mediaserver wie **Emby** oder **Jellyfin** unfertige oder temporäre Dateien während des Transcodierens in die Bibliothek aufnehmen. Nach Abschluss wird die Datei sauber entfernt.
- **Detailliertes Logging:** Für jede verarbeitete Datei wird eine eigene Log-Datei erstellt, die jeden einzelnen Schritt und jede Entscheidung dokumentiert. Perfekt für die Fehlersuche und Nachverfolgung!

---

## 🌟 Ihre Vorteile auf einen Blick
- **"Feuer und Vergessen"-Prinzip:** Starten Sie den Prozess für Ihre gesamte Mediathek und lassen Sie das Skript die Arbeit machen – auch über Nacht.
- **Massive Platzersparnis:** Modernisieren Sie Ihre Sammlung und gewinnen Sie wertvollen Speicherplatz zurück.
- **Einheitliche Qualität:** Genießen Sie eine konsistente visuelle und akustische Erfahrung über alle Ihre Filme und Serien hinweg.
- **Zukunftssicher:** Bringen Sie Ihre Videos auf den neuesten Stand mit HEVC und AAC, den Codecs der Zukunft.
- **Rasante GPU-Verarbeitung:** Nutzen Sie Ihre NVIDIA oder AMD GPU für bis zu 10x schnellere Konvertierungen!
---

## 🛠️ Anforderungen
1.  **PowerShell 7.0+:** (Empfohlen für parallele Verarbeitung. [Kostenlos downloadbar](https://github.com/PowerShell/PowerShell))
2.  **FFmpeg:** Stellen Sie sicher, dass `ffmpeg.exe` verfügbar ist und der Pfad (`$ffmpegPath`) im Skript korrekt gesetzt ist. Die FFmpeg-Version sollte `libx265` (für HEVC), `hevc_nvenc` / `hevc_amf` (optional für GPU) und `aac` unterstützen.
3.  **MKVToolNix:** Das Werkzeug `mkvextract.exe` wird benötigt, um Normalisierungs-Tags zu prüfen. Der Pfad (`$mkvextractPath`) muss im Skript gesetzt sein.
4.  **GPU (optional):** NVIDIA (RTX/GeForce) oder AMD Radeon für Hardware-beschleunigte Kodierung.
---

## ⚙️ Konfiguration
Passen Sie die Variablen am Anfang der Datei `Auto Video Transcode noch schneller.ps1` an Ihre Bedürfnisse an:

- `$ffmpegPath`: Der vollständige Pfad zu Ihrer `ffmpeg.exe`.
- `$mkvextractPath`: Der vollständige Pfad zu Ihrer `mkvextract.exe`.
- `$useHardwareAccel`: `$true` für GPU-Beschleunigung, `$false` zum Deaktivieren.
- `$targetLoudness`: Die Ziel-Lautheit in LUFS (Standard: -18).
- `$crfTargetm` / `$crfTargets`: Die CRF-Werte für Filme (18) und Serien (20) – niedriger = bessere Qualität.
- `$qualitätFilm` / `$qualitätSerie`: Die Qualitätsstufen für die Effizienz-Analyse.
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
1.  Öffnen Sie PowerShell 7+ oder Windows PowerShell.
2.  Führen Sie das Skript aus: `.\'Auto Video Transcode noch schneller.ps1'`
3.  Es öffnet sich ein Dialogfenster. Wählen Sie den Ordner aus, der Ihre Videosammlung enthält.
4.  Bestätigen Sie mit "OK".
5.  **Das war's!** Beobachten Sie, wie Ihr Computer Ihre Mediathek auf das nächste Level hebt.
---

## ⚠️ Haftungsausschluss
Dieses Skript löscht die Originaldateien nach einer erfolgreichen Konvertierung. Es wird dringend empfohlen, **vor der ersten Anwendung ein Backup Ihrer Daten zu erstellen** oder das Skript zunächst mit Kopien Ihrer Dateien in einem Testordner auszuführen. 
**Die Nutzung erfolgt auf eigene Gefahr.**

---

## 📊 Feature-Status

| Feature | Status | Hinweise |
|---------|--------|----------|
| GPU-Beschleunigung (NVIDIA/AMD) | ✅ Complete | hevc_nvenc, hevc_amf, libx265 Fallback |
| Metadaten-Analyse | ✅ Complete | Codec, Auflösung, Audio, Interlace, HDR, Bittiefe |
| Serien-Erkennung | ✅ Complete | SxxExx Pattern-Matching |
| Normalisierungs-Checking | ✅ Complete | Parallele Überprüfung mit Fortschritts-Tracking |
| Emby-Integration | ✅ Complete | Automatische .embyignore Erstellung & Bereinigung |
| Video-Transkodierung | 🔄 In Development | HEVC-Encoding mit CRF-Optimierung |
| Audio-Normalisierung | ✅ Complete | EBUR128-Messung, AAC-Kodierung (Session 3 validiert) |
| AVI-Spezialbehandlung | ✅ Complete | Deinterlace, Denoise, Upscale, Sharpen |
| Error Handling & Logging | 🔄 In Development | Detaillierte Logs pro Datei |
| **Code-Qualität** | **✅ Improved** | **Session 5: .embyignore logic fixed** |

---