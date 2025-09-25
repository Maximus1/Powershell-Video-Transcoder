# 🚀 Der ultimative PowerShell Video-Transcoder & Normalizer 🚀

Haben Sie es satt, Ihre Videos manuell zu konvertieren und die Lautstärke anzupassen? Verabschieden Sie sich von inkonsistenten Dateigrößen und schwankenden Audiopegeln! Dieses Skript ist Ihr persönlicher, vollautomatischer Medien-Butler, der Ihre gesamte Videosammlung in eine moderne, optimierte und qualitativ hochwertige Bibliothek verwandelt.

**Starten Sie das Skript, wählen Sie einen Ordner aus, und lehnen Sie sich zurück. Den Rest erledigt die Magie der Automatisierung!**

---

## ✨ Hauptfunktionen – Was dieses Skript so besonders macht

Dieses Skript ist mehr als nur ein einfacher Konverter. Es ist ein intelligentes System, das für jede einzelne Datei die beste Entscheidung trifft.

### 🧠 Intelligente & adaptive Transkodierung
- **Automatische Codec-Modernisierung:** Konvertiert veraltete Formate (wie XviD, DivX, H.264) automatisch in das hocheffiziente **HEVC (H.265)** Format, um massiv Speicherplatz zu sparen.
- **Serien-Erkennung:** Erkennt automatisch Serien (`SxxExx`-Muster) und wendet optimierte CRF-Werte und eine optionale Skalierung auf 720p an, um eine perfekte Balance zwischen Qualität und Dateigröße zu gewährleisten.
- **Effizienz-Analyse:** Das Skript analysiert, ob eine Datei im Verhältnis zu ihrer Laufzeit zu groß ist. Nur wenn eine Neukodierung wirklich sinnvoll ist, wird sie durchgeführt. Effiziente Dateien werden unangetastet gelassen!
- **Schutz vor Aufblähen:** Verhindert aktiv, dass eine neu kodierte Datei größer wird als das Original.

### 🎬 Restaurierung für alte Schätze
- **AVI-Spezialbehandlung:** Alte AVI-Dateien erhalten eine VIP-Behandlung! Sie werden nicht nur konvertiert, sondern durch eine hochwertige Filterkette visuell restauriert:
    1.  **Deinterlacing** (`yadif`): Entfernt unschöne Kammartefakte.
    2.  **Rauschunterdrückung** (`nlmeans`): Reduziert Bildrauschen für ein sauberes Bild.
    3.  **Upscaling auf 1080p**: Bringt altes Material auf Full-HD-Auflösung.
    4.  **Nachschärfen** (`unsharp`): Verleiht dem hochskalierten Bild wieder Klarheit und Detailreichtum.

### 🔊 Professionelle Audionormalisierung
- **Konsistente Lautstärke:** Nie wieder zur Fernbedienung greifen! Alle Audiodateien werden auf einen professionellen Standard von **-18 LUFS** normalisiert.
- **Perfekter Codec:** Audio wird immer in das universell kompatible **AAC-Format** transkodiert, mit optimierten Bitraten für Surround, Stereo und Mono.

### 🛡️ Sicher & Zuverlässig
- **Integritätsprüfung:** Jede neu erstellte Datei wird mit `ffmpeg` auf Stream-Fehler überprüft, um sicherzustellen, dass das Ergebnis perfekt ist.
- **Keine Duplikate:** Das Skript erkennt bereits normalisierte Dateien anhand von Metadaten-Tags und überspringt sie, um doppelte Arbeit zu vermeiden.
- **Detailliertes Logging:** Für jede verarbeitete Datei wird eine eigene Log-Datei erstellt, die jeden einzelnen Schritt und jede Entscheidung dokumentiert. Perfekt für die Fehlersuche und Nachverfolgung!

---

## 🌟 Ihre Vorteile auf einen Blick

- **"Feuer und Vergessen"-Prinzip:** Starten Sie den Prozess für Ihre gesamte Mediathek und lassen Sie das Skript die Arbeit machen – auch über Nacht.
- **Massive Platzersparnis:** Modernisieren Sie Ihre Sammlung und gewinnen Sie wertvollen Speicherplatz zurück.
- **Einheitliche Qualität:** Genießen Sie eine konsistente visuelle und akustische Erfahrung über alle Ihre Filme und Serien hinweg.
- **Zukunftssicher:** Bringen Sie Ihre Videos auf den neuesten Stand mit HEVC und AAC, den Codecs der Zukunft.

---

## 🛠️ Anforderungen

1.  **PowerShell:** (Standardmäßig in Windows enthalten)
2.  **FFmpeg:** Stellen Sie sicher, dass `ffmpeg.exe` verfügbar ist und der Pfad (`$ffmpegPath`) im Skript korrekt gesetzt ist. Die FFmpeg-Version sollte `libx265` (für HEVC) und `aac` unterstützen.
3.  **MKVToolNix:** Das Werkzeug `mkvextract.exe` wird benötigt, um Normalisierungs-Tags zu prüfen. Der Pfad (`$mkvextractPath`) muss im Skript gesetzt sein.

---

## ⚙️ Konfiguration

Passen Sie die Variablen am Anfang der Datei `Auto Video Transcode noch schneller.ps1` an Ihre Bedürfnisse an:

- `$ffmpegPath`: Der vollständige Pfad zu Ihrer `ffmpeg.exe`.
- `$mkvextractPath`: Der vollständige Pfad zu Ihrer `mkvextract.exe`.
- `$targetLoudness`: Die Ziel-Lautheit in LUFS (Standard: -18).
- `$crfTargetm` / `$crfTargets`: Die CRF-Werte für Filme und Serien (niedriger = bessere Qualität).
- `$qualitätFilm` / `$qualitätSerie`: Die Qualitätsstufen für die Effizienz-Analyse.

---

## 🚀 Anwendung

1.  Öffnen Sie eine PowerShell-Konsole.
2.  Führen Sie das Skript aus: `.\'Auto Video Transcode noch schneller.ps1'`
3.  Es öffnet sich ein Dialogfenster. Wählen Sie den Ordner aus, der Ihre Videosammlung enthält.
4.  Bestätigen Sie mit "OK".
5.  **Das war's!** Beobachten Sie, wie Ihr Computer Ihre Mediathek auf das nächste Level hebt.

---

## ⚠️ Haftungsausschluss

Dieses Skript löscht die Originaldateien nach einer erfolgreichen Konvertierung. Es wird dringend empfohlen, **vor der ersten Anwendung ein Backup Ihrer Daten zu erstellen** oder das Skript zunächst mit Kopien Ihrer Dateien in einem Testordner auszuführen. 
**Die Nutzung erfolgt auf eigene Gefahr.**
