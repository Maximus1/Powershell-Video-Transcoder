# PowerShell-Skript zur kombinierten Medienanalyse, Lautstärkeanpassung und Transkodierung mit FFmpeg
# Datum: [Aktuelles Datum]
# Version: 1.0
# Hinweis: Dieses Skript ist für den persönlichen Gebrauch gedacht und sollte nicht ohne Erlaubnis weitergegeben werden.
# Verwendung: Führen Sie das Skript in PowerShell aus. Es öffnet sich ein Dialog zur Ordnerauswahl.
# Die MKV-Dateien werden dann überprüft, die Lautstärke angepasst und bei bedarf transkodiert.
# Die Ausgabedateien werden im gleichen Verzeichnis wie die Eingabedateien gespeichert.
# Bei Fehlern wird eine Logdatei erstellt und die Ergebnisse in der Logdatei gespeichert.


#region Konfiguration
# Pfad zu FFmpeg (muss korrekt sein)
$ffmpegPath = "F:\media-autobuild_suite-master\local64\bin-video\ffmpeg.exe"

# Ziel-Lautheit in LUFS (z. B. -14 für YouTube, -23 für Rundfunk)
$targetLoudness = -18
$filePath = ''

# Encoder-Voreinstellungen (können angepasst werden)
$crfTarget = 23
$encoderPreset = 'medium'
$audioCodecBitrate192 = '192k'
$audioCodecBitrate128 = '128k'
$videoCodecHEVC = 'HEVC'
$force720p = $false

# Standard-Dateierweiterung für die Ausgabe
$targetExtension = '.mkv'
#endregion

#region Hilfsfunktionen
function Get-MediaInfo {# Funktion zum Extrahieren von Mediendaten mit FFmpeg
    param (
        [string]$filePath # Pfad zur Eingabedatei
    )
    $mediaInfo = @{} # Hashtable zum Speichern der Mediendaten
    try {
        # Prüfen, ob die Datei existiert
        if (!(Test-Path $filePath)) {
            Write-Host "FEHLER: Datei nicht gefunden: $filePath" -ForegroundColor Red
            return $null
        }
        # FFmpeg-Prozess starten, um Mediendaten zu extrahieren
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $ffmpegPath
        $startInfo.Arguments = "-i `"$filePath`"" # FFmpeg-Argumente für die Eingabe
        $startInfo.RedirectStandardError = $true # StandardError umleiten, um die Ausgabe zu erfassen
        $startInfo.UseShellExecute = $false # ShellExecute deaktivieren, um die Umleitung zu ermöglichen
        $startInfo.CreateNoWindow = $true # Kein Konsolenfenster erstellen

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        $process.Start() | Out-Null # Prozess starten und Ausgabe verwerfen

        $infoOutput = $process.StandardError.ReadToEnd() # StandardError lesen
        $process.WaitForExit() # Warten, bis der Prozess beendet ist

        # Überspringe bereits normalisierte Dateien
        if ($file.Name -match "_normalized") {
            Write-Host "Überspringe bereits normalisierte Datei: $($file.Name) (Name)" -ForegroundColor green
            continue
        }
        if ($infoOutput -match "NORMALIZED" ) {
            Write-Host "Überspringe bereits normalisierte Datei: $($file.Name) (Tag)" -ForegroundColor green
            continue
        }
        if ($infoOutput -match "GAINED" ) {
            Write-Host "Überspringe bereits normalisierte Datei: $($file.Name) (Tag)" -ForegroundColor green
            continue
        }
        # Dauer extrahieren
        if ($infoOutput -match "Duration:\s*(\d+):(\d+):(\d+)\.(\d+)") {
            $hours = [int]$matches[1]
            $minutes = [int]$matches[2]
            $seconds = [int]$matches[3]
            $milliseconds = [int]$matches[4]

            $totalSeconds = $hours * 3600 + $minutes * 60 + $seconds + ($milliseconds / 100)
            $mediaInfo.Duration = $totalSeconds
            $mediaInfo.DurationFormatted1 = "{0:D2}:{1:D2}:{2:D2}.{3:D2}" -f $hours, $minutes, $seconds, $milliseconds
            #Write-Host "Extrahierte Dauer: $($mediaInfo.DurationFormatted1)" -ForegroundColor DarkCyan

        }
        else {
            Write-Host "WARNUNG: Konnte Dauer nicht aus der FFmpeg-Ausgabe extrahieren" -ForegroundColor Yellow
            $mediaInfo.Duration = 0
            $mediaInfo.DurationFormatted = "00:00:00.00"
        }
        # Audiokanäle extrahieren
        if ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:.*?,\s+\d+\s+Hz,\s+([\d.]+)") {
            $mediaInfo.AudioChannels = $matches[1]
        }
        elseif ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:.+?stereo") {
            $mediaInfo.AudioChannels = 2
        }
        elseif ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:.+?mono") {
            $mediaInfo.AudioChannels = 1
        }
        else {
            Write-Host "WARNUNG: Konnte Audiokanäle nicht aus der FFmpeg-Ausgabe extrahieren" -ForegroundColor Yellow
            $mediaInfo.AudioChannels = 0
        }
        Write-Host "Quelldatei-Dauer: $($mediaInfo.DurationFormatted1) | Audiokanäle: $($mediaInfo.AudioChannels)" -ForegroundColor DarkCyan
        # Audio Codec extrahieren
        if ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:\s*(\w+)") {
            $mediaInfo.AudioCodec = $matches[1]
        }
        else {
            Write-Host "WARNUNG: Konnte Audio Codec nicht aus der FFmpeg-Ausgabe extrahieren" -ForegroundColor Yellow
            $mediaInfo.AudioCodec = "Unbekannt"
        }
        # Video Codec extrahieren
        if ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Video:\s*(\w+)") {
            $mediaInfo.VideoCodec = $matches[1]
        }
        else {
            Write-Host "WARNUNG: Konnte Video Codec nicht aus der FFmpeg-Ausgabe extrahieren" -ForegroundColor Yellow
            $mediaInfo.VideoCodec = "Unbekannt"
        }
        # Auflösung extrahieren
        if ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Video:.*?,\s+(\d+)x(\d+)") {
            $mediaInfo.Resolution = "$($matches[1])x$($matches[2])"
        }
        else {
            Write-Host "WARNUNG: Konnte Auflösung nicht aus der FFmpeg-Ausgabe extrahieren" -ForegroundColor Yellow
            $mediaInfo.Resolution = "Unbekannt"
        }
    }
    catch {
        Write-Host "FEHLER: Fehler beim Abrufen der Mediendaten: $_" -ForegroundColor Red
        return $null
    }
    return $mediaInfo
}
function Get-MediaInfo2 { #keine file vorhanden prüfung
    param (
        [string]$filePath
    )
    $mediaInfo = @{}
    try {
        # Führe FFmpeg aus, um Informationen über die Datei zu erhalten
        # Führe expliziten Befehl statt Umleitung aus, um korrekte Fehlerausgabe zu erhalten
        #$tempOutputFile = [System.IO.Path]::GetTempFileName()
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $ffmpegPath
        $startInfo.Arguments = "-i `"$filePath`""
        $startInfo.RedirectStandardError = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        $process.Start() | Out-Null

        $infoOutput = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        # Extrahiere die Dauer mit einem verbesserten Regex-Pattern
        if ($infoOutput -match "Duration:\s*(\d+):(\d+):(\d+)\.(\d+)") {
            $hours = [int]$matches[1]
            $minutes = [int]$matches[2]
            $seconds = [int]$matches[3]
            $milliseconds = [int]$matches[4]
            $totalSeconds = $hours * 3600 + $minutes * 60 + $seconds + ($milliseconds / 100)
            $mediaInfo.Duration = $totalSeconds
            $mediaInfo.DurationFormatted = "{0:D2}:{1:D2}:{2:D2}.{3:D2}" -f $hours, $minutes, $seconds, $milliseconds
            Write-Host "Extrahierte Dauer: $($mediaInfo.DurationFormatted)" -ForegroundColor DarkCyan
        }
        else {
            Write-Host "WARNUNG: Konnte Dauer nicht aus der FFmpeg-Ausgabe extrahieren" -ForegroundColor Yellow
            $mediaInfo.Duration = 0
            $mediaInfo.DurationFormatted = "00:00:00.00"
        }
        # Extrahiere die Anzahl der Audiokanäle mit verbessertem Regex
        if ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:.*?,\s+\d+\s+Hz,\s+([\d.]+)") {
            $mediaInfo.AudioChannels = $matches[1]
            Write-Host "Extrahierte Audiokanäle: $($mediaInfo.AudioChannels)" -ForegroundColor DarkCyan
        }
        elseif ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:.+?stereo") {
            $mediaInfo.AudioChannels = 2
            Write-Host "Audioformat ist stereo (2 Kanäle)" -ForegroundColor DarkCyan
        }
        elseif ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:.+?mono") {
            $mediaInfo.AudioChannels = 1
            Write-Host "Audioformat ist mono (1 Kanal)" -ForegroundColor DarkCyan
        }
        else {
            Write-Host "WARNUNG: Konnte Audiokanäle nicht aus der FFmpeg-Ausgabe extrahieren" -ForegroundColor Yellow
            $mediaInfo.AudioChannels = 0
        }
    }
    catch {
        Write-Host "Fehler beim Abrufen der Mediendaten: $_" -ForegroundColor Red
        $mediaInfo.Duration = 0
        $mediaInfo.DurationFormatted = "00:00:00.00"
        $mediaInfo.AudioChannels = 0
    }
    return $mediaInfo
}
function Get-LoudnessInfo {# Funktion zur Lautstärkeanalyse mit FFmpeg
    param (
        [string]$filePath # Pfad zur Eingabedatei
    )
    try {
        # Temporäre Datei erstellen, um die FFmpeg-Ausgabe zu speichern
        $tempOutputFile = [System.IO.Path]::GetTempFileName()
        # FFmpeg-Prozess starten, um die Lautstärke zu analysieren
        Write-Host "Starte FFmpeg zur Lautstärkeanalyse..." -ForegroundColor Cyan
        $ffmpegProcess = Start-Process -FilePath $ffmpegPath -ArgumentList "-i", "`"$($filePath)`"", "-hide_banner", "-filter_complex", "ebur128=metadata=1", "-f", "null", "NUL" -NoNewWindow -PassThru -RedirectStandardError $tempOutputFile
        $ffmpegProcess.WaitForExit()
        # Ausgabe aus der temporären Datei lesen
        $ffmpegOutput = Get-Content -Path $tempOutputFile -Raw
        # Temporäre Datei löschen
        Remove-Item -Path $tempOutputFile -Force -ErrorAction SilentlyContinue
        return $ffmpegOutput
    }
    catch {
        Write-Host "FEHLER: Fehler beim Ausführen von FFmpeg: $_" -ForegroundColor Red
        return $null
    }
}
function Set-VolumeGain {# Funktion zur Anpassung der Lautstärke mit FFmpeg
    param (
        [string]$filePath, # Pfad zur Eingabedatei
        [double]$gain, # Der anzuwendende Gain-Wert in dB
        [string]$outputFile, # Pfad für die Ausgabedatei
        [int]$audioChannels, # Anzahl der Audiokanäle in der Eingabedatei
        [string]$videoCodec # Video Codec der Eingabedatei

    )
    try {
        # FFmpeg-Argumente basierend auf der Anzahl der Audiokanäle erstellen
        Write-Host "Starte FFmpeg zur Lautstärkeanpassung..." -NoNewline -ForegroundColor Cyan
        $ffmpegArguments = @(
            "-hide_banner", # FFmpeg-Banner ausblenden
            "-loglevel", "error",
            "-stats", # Statistiken anzeigen
            "-y", # Überschreibe Ausgabedateien ohne Nachfrage
            "-i", "`"$($filePath)`"" # Eingabedatei
        )

        # konvertieren, wenn der Video Codec nicht HEVC ist
        if ($videoCodec -ne $videoCodecHEVC -AND -not $force720p -match "true") {
            Write-Host "Video Transode..." -NoNewline -ForegroundColor Cyan
            $ffmpegArguments += @(
                "-c:v", "libx265", # Video-Codec auf HEVC setzen
                "-preset", $encoderPreset, # Encoder-Voreinstellung verwenden
                "-crf", $crfTarget  # CRF-Wert für die Qualität
            )
        }
        if ($force720p -match "true") {
            Write-Host "Video transcoe mit resize..." -NoNewline -ForegroundColor Cyan
            $ffmpegArguments += @(
                "-c:v", "libx265", # Video-Codec auf HEVC setzen
                "-preset", $encoderPreset, # Encoder-Voreinstellung verwenden
                "-crf", $crfTarget,  # CRF-Wert für die Qualität
                "-vf", "scale=1280:720" # Auflösung auf 720p skalieren
            )
        }
        # Überprüfen, ob der Video-Codec bereits HEVC ist
        if ($videoCodec -eq $videoCodecHEVC -AND -not $force720p) {
            Write-Host "Video copy..." -NoNewline -ForegroundColor Cyan
            # Video-Codec beibehalten, wenn er bereits HEVC ist
            $ffmpegArguments += @(
                "-c:v", "copy" # Video Codec kopieren
            ) 
        }
        if ($audioChannels -gt 2) {
            Write-Host "Audio transcode Surround..." -NoNewline -ForegroundColor Cyan
            $ffmpegArguments += @(
                "-c:a", "libfdk_aac", # Audio-Codec auf AAC setzen
                "-profile:a", "aac_he", # AAC-Profil setzen
                "-ac", $audioChannels, # Anzahl der Audiokanäle beibehalten
                "-channel_layout", "5.1" # Kanal-Layout setzen
            )
        }
        if ($audioChannels -eq 2) {
            Write-Host "Audio transcode Stereo..." -NoNewline -ForegroundColor Cyan
            $ffmpegArguments += @(
                "-c:a", "libfdk_aac", # Audio-Codec auf AAC setzen
                "-profile:a", "aac_he", # AAC-Profil setzen
                "-b:a", $audioCodecBitrate192 # Audio-Bitrate setzen
            )
        }
        if ($audioChannels -le 1) {
            Write-Host "Audio transcode Mono..." -NoNewline -ForegroundColor Cyan
            $ffmpegArguments += @(
                "-c:a", "libfdk_aac", # Audio-Codec auf AAC setzen
                "-profile:a", "aac_he", # AAC-Profil setzen
                "-b:a", $audioCodecBitrate128 # Audio-Bitrate setzen
            )        
        }
        $ffmpegArguments += @(
            Write-Host "Lautstärke anpassung und Metadaten..."  -ForegroundColor Cyan
            "-af", "volume=${gain}dB", # Lautstärke anpassen
            "-c:s", "copy", # Untertitel kopieren
            "-metadata", "LUFS=$targetLoudness", # LUFS-Metadaten setzen
            "-metadata", "gained=$gain", # Gain-Metadaten setzen
            "-metadata", "normalized=true", # Normalisierungs-Metadaten setzen
            "`"$($outputFile)`"" # Ausgabedatei
        )
        Write-Host "FFmpeg-Argumente: $($ffmpegArguments -join ' ')" -ForegroundColor DarkCyan
        # FFmpeg-Prozess starten
        Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArguments -NoNewWindow -Wait -PassThru -ErrorAction Stop
        Write-Host "Lautstärkeanpassung abgeschlossen für: $($filePath)" -ForegroundColor Green
    }
    catch {
        Write-Host "FEHLER: Fehler bei der Lautstärkeanpassung: $_" -ForegroundColor Red
    }
}
function Test-OutputFile {# Überprüfe die Ausgabedatei, sobald der Prozess abgeschlossen ist
    param (
        [string]$outputFile,
        [string]$sourceFile,
        [object]$sourceInfo,
        [string]$targetExtension
        )
    Write-Host "Überprüfe die Ausgabedatei: $outputFile" -ForegroundColor Cyan
    # Warte kurz, um sicherzustellen, dass die Datei vollständig geschrieben wurde
    Start-Sleep -Seconds 2

    Test_Fileintregity -Outputfile $outputFile -ffmpegPath $ffmpegPath -destFolder $destFolder

    $outputInfo = Get-MediaInfo2 -filePath $outputFile
    # Überprüfe, ob die Ausgabedatei korrekt erfasst wurde
    if ($outputInfo.Duration -eq 0 -or $outputInfo.AudioChannels -eq 0) {
        Write-Host "  FEHLER: Konnte Mediendaten für die Ausgabedatei nicht korrekt extrahieren." -ForegroundColor Red
        return $false
    }
    Write-Host "  Quelldatei-Dauer: $($sourceInfo.DurationFormatted) | Audiokanäle: $($sourceInfo.AudioChannels)" -ForegroundColor Blue
    Write-Host "  Ausgabedatei-Dauer: $($outputInfo.DurationFormatted) | Audiokanäle: $($outputInfo.AudioChannels)" -ForegroundColor Blue
    # Überprüfe die Laufzeit (mit einer kleinen Toleranz von 1 Sekunde)
    $durationDiff = [Math]::Abs($sourceInfo.Duration - $outputInfo.Duration)
    if ($durationDiff -gt 1) {
        Write-Host "  WARNUNG: Die Laufzeiten unterscheiden sich um $durationDiff Sekunden!" -ForegroundColor Red
        return $false
    }
    Write-Host "  OK: Die Laufzeiten stimmen überein." -ForegroundColor Green
    # Überprüfe die Anzahl der Audiokanäle
    if ($sourceInfo.AudioChannels -ne $outputInfo.AudioChannels) {
        Write-Host "  WARNUNG: Die Anzahl der Audiokanäle hat sich geändert! (Quelle: $($sourceInfo.AudioChannels), Ausgabe: $($outputInfo.AudioChannels))" -ForegroundColor Red
        return $false
    }
    Write-Host "  OK: Die Anzahl der Audiokanäle ist gleich geblieben." -ForegroundColor Green
    return $true
}
function Test_Fileintregity {
    param (
        [Parameter(Mandatory = $true)]
        [string]$outputFile,

        [Parameter(Mandatory = $true)]
        [string]$ffmpegPath,

        [Parameter(Mandatory = $true)]
        [string]$destFolder
    )

    $logDatei = Join-Path -Path $destFolder -ChildPath "MKV_Überprüfung.log"
    "`n==== Überprüfung gestartet am $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" | Add-Content $logDatei

    Write-Host "Überprüfe Datei: $outputFile"

    # Temporäre Datei für FFmpeg-Fehlerausgabe
    $tempFehlerDatei = [System.IO.Path]::GetTempFileName()

    # FFmpeg-Argumente vorbereiten
    $argumentso = @(
        "-v", "error",
        "-i", "`"$outputFile`"",
        "-f", "null",
        "-"
    ) -join ' '

    $argumentsi = @(
        "-v", "error",
        "-i", "`"$filePath`"",
        "-f", "null",
        "-"
    ) -join ' '

    # Prozess konfigurieren
    $processInfoo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfoo.FileName = $ffmpegPath
    $processInfoo.Arguments = $argumentso
    $processInfoo.Arguments = $argumentsi
    $processInfoo.RedirectStandardError = $true
    $processInfoo.RedirectStandardOutput = $true
    $processInfoo.UseShellExecute = $false
    $processInfoo.CreateNoWindow = $true

    # FFmpeg starten
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfoo
    $process.Start() | Out-Null

    # Fehler auslesen und warten
    [string]$ffmpegFehlero = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $exitCode = $process.ExitCode

    # Fehlerausgabe zwischenspeichern
    $ffmpegFehlero | Out-File -FilePath $tempFehlerDatei -Encoding UTF8

    # Auswertung
    if ($exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($ffmpegFehlero)) {
        Write-Host "OK: $outputFile" -ForegroundColor Green
        Add-Content $logDatei "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $outputFile - OK"
    } else {
        Write-Host "FEHLER in Datei: $outputFile" -ForegroundColor Red
        Add-Content $logDatei "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $outputFile - FEHLER:"
        Add-Content $logDatei $ffmpegFehlero
        Add-Content $logDatei "$filePath wird auf fehler in der Quelle geprüft."
        Add-Content $logDatei "----------------------------------------"

        # Prozess konfigurieren
        $processInfoi = New-Object System.Diagnostics.ProcessStartInfo
        $processInfoi.FileName = $ffmpegPath
        $processInfoi.Arguments = $argumentsi
        $processInfoi.RedirectStandardError = $true
        $processInfoi.RedirectStandardOutput = $true
        $processInfoi.UseShellExecute = $false
        $processInfoi.CreateNoWindow = $true

        # FFmpeg starten
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfoi
        $process.Start() | Out-Null

        # Fehler auslesen und warten
        [string]$ffmpegFehleri = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $exitCode = $process.ExitCode

        # Fehlerausgabe zwischenspeichern
        $ffmpegFehleri | Out-File -FilePath $tempFehlerDatei -Encoding UTF8

        # Auswertung
        if ($exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($ffmpegFehleri)) {
            Write-Host "OK: $filePath" -ForegroundColor Green
            Add-Content $logDatei "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $filePath - OK"
        } else {
            Write-Host "FEHLER in Datei: $filePath" -ForegroundColor Red
            Add-Content $logDatei "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $filePath - FEHLER:"
            Add-Content $logDatei $ffmpegFehleri
            Add-Content $logDatei "$filePath und $outputFile haben beide fehler."
            Add-Content $logDatei "----------------------------------------"
        }
    }

    Remove-Item $tempFehlerDatei -Force

    "`n==== Überprüfung beendet am $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" | Add-Content $logDatei
    Write-Host "Überprüfung abgeschlossen. Ergebnis in: $logDatei"
}

function Remove-Files {# Funktion zum Aufräumen und Umbenennen von Dateien
    param (
        [string]$outputFile,
        [string]$sourceFile,
        [string]$targetExtension
    )
    try {
        # Temporäre Datei für Umbenennung
        # Datei umbenennen, wenn Test-OutputFile $true zurückgibt
        if ($true) {
            $tempFile = [System.IO.Path]::Combine((Split-Path -Path $sourceFile), "$([System.IO.Path]::GetFileNameWithoutExtension($sourceFile))_temp$([System.IO.Path]::GetExtension($sourceFile))")
            # Datei umbenennen mit Zwischenschritt um Namenskollisionen zu vermeiden
            Rename-Item -Path $outputFile -NewName $tempFile -Force
            Remove-Item -Path $sourceFile -Force
            Rename-Item -Path $tempFile -NewName ([System.IO.Path]::GetFileName($sourceFile)) -Force
            Write-Host "  Erfolg: Quelldatei gelöscht und normalisierte Datei umbenannt zu $([System.IO.Path]::GetFileName($sourceFile))" -ForegroundColor Green
        } else {
            Write-Host "  FEHLER: Test-OutputFile ist fehlgeschlagen. Test-OutputFile wird gelöscht." -ForegroundColor Red
            Remove-Item -Path $outputFile -Force
        }
    }
    catch {
        Write-Host "  FEHLER bei Umbenennung/Löschen: $_" -ForegroundColor Red
    }
}
#endregion

#region Hauptskript
# Ordnerauswahldialog anzeigen
Add-Type -AssemblyName System.Windows.Forms
$PickFolder = New-Object -TypeName System.Windows.Forms.OpenFileDialog
$PickFolder.FileName = 'Mediafolder'
$PickFolder.Filter = 'Folder Selection|*.*'
$PickFolder.AddExtension = $false
$PickFolder.CheckFileExists = $false
$PickFolder.Multiselect = $false
$PickFolder.CheckPathExists = $true
$PickFolder.ShowReadOnly = $false
$PickFolder.ReadOnlyChecked = $true
$PickFolder.ValidateNames = $false

$result = $PickFolder.ShowDialog()

if ($result -eq [Windows.Forms.DialogResult]::OK) {
    $destFolder = Split-Path -Path $PickFolder.FileName
    Write-Host -Object "Ausgewählter Ordner: $destFolder" -ForegroundColor Green

    # Alle MKV-Dateien im ausgewählten Ordner rekursiv suchen
    $mkvFiles = Get-ChildItem -Path $destFolder -Filter "*.mkv" -Recurse
    $mkvFileCount = ($mkvFiles | Measure-Object).Count

    # Jede MKV-Datei verarbeiten
    foreach ($file in $mkvFiles) {
        Write-Host "$mkvFileCount MKV-Dateien verbleibend." -ForegroundColor Green
        $mkvFileCount --
        Write-Host "Verarbeite Datei: $($file.FullName)" -ForegroundColor Cyan

        # Mediendaten extrahieren
        $sourceInfo = Get-MediaInfo -filePath $file.FullName
        if (!$sourceInfo) {
            Write-Host "FEHLER: Konnte Mediendaten nicht extrahieren. Überspringe Datei." -ForegroundColor Red
            continue
        }

        # Überprüfen, ob der Dateiname dem Serienmuster entspricht (z. B. S01E01)
        if ($file.FullName -match "S\d+E\d+") {
            Write-Host "Datei erkannt als Serientitel. Prüfe auf 720p anpassung." -ForegroundColor Yellow
            # Setze Variable, um die 720p-Auflösung zu erzwingen
            if ($sourceInfo.Resolution -match "^(\d+)x(\d+)$") {
                $width = [int]$matches[1]
                $height = [int]$matches[2]
                if ($width -gt 1280 -or $height -gt 720) {
                    Write-Host "Aktuelle Auflösung: $($sourceInfo.Resolution). Größe wird auf 720p angepasst." -ForegroundColor Yellow
                    $force720p = $true
                } else {
                    Write-Host "Aktuelle Auflösung: $($sourceInfo.Resolution). Keine Größenanpassung notwendig." -ForegroundColor Yellow
                    $force720p = $false
                }
            } else {
                Write-Host "Aktuelle Auflösung: $($sourceInfo.Resolution). Keine Größenanpassung" -ForegroundColor Yellow
                $force720p = $false
            }
        } else {
            # Setze Variable, um die Standardauflösung beizubehalten
            $force720p = $false
        }

        # Lautstärkeinformationen extrahieren
        $ffmpegOutput = Get-LoudnessInfo -filePath $file.FullName
        if (!$ffmpegOutput) {
            Write-Host "FEHLER: Konnte Lautstärkeinformationen nicht extrahieren. Überspringe Datei." -ForegroundColor Red
            continue
        }

        # Integrierte Lautheit (LUFS) extrahieren
        if ($ffmpegOutput -match "I:\s*([-\d\.]+)\s*LUFS") {
            $integratedLoudness = [double]$matches[1]
            $gain = $targetLoudness - $integratedLoudness # Notwendigen Gain berechnen

            # Wenn der Gain größer als 0.1 dB ist, Lautstärke anpassen
            if ([math]::Abs($gain) -gt 0.2) {
                Write-Host "Passe Lautstärke an um $gain dB" -ForegroundColor Yellow
                # Ausgabedatei erstellen
                $outputFile = [System.IO.Path]::Combine($file.DirectoryName, "$($file.BaseName)_normalized$($targetExtension)")
                # Lautstärke anpassen
                Set-VolumeGain -filePath $file.FullName -gain $gain -outputFile $outputFile -audioChannels $sourceInfo.AudioChannels -videoCodec $sourceInfo.VideoCodec
                # Überprüfen der Ausgabedatei
                Test-OutputFile -outputFile $outputFile -sourceFile $file.FullName -sourceInfo $sourceInfo -targetExtension $targetExtension 
                # Aufräumen und Umbenennen der Ausgabedatei
                Remove-Files -outputFile $outputFile -sourceFile $file.FullName -targetExtension $targetExtension
            }
            else {
                Write-Host "Lautstärke bereits im Zielbereich. Keine Anpassung notwendig." -ForegroundColor Green
            }
        }
        else {
            Write-Host "WARNUNG: Keine LUFS-Informationen gefunden. Überspringe Lautstärkeanpassung." -ForegroundColor Yellow
        }
        Write-Host "Verarbeitung abgeschlossen für: $($file.FullName)" -ForegroundColor Green
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
    }
    # Nachbereitung: Lösche alle _normalized Dateien
    Write-Host "Starte Nachbereitung: Suche und lösche _normalized Dateien..." -ForegroundColor Cyan
    $normalizedFiles = Get-ChildItem -Path $destFolder -Filter "*_normalized*$targetExtension" -Recurse
    foreach ($normalizedFile in $normalizedFiles) {
        try {
            Remove-Item -Path $normalizedFile.FullName -Force
            Write-Host "  Gelöscht: $($normalizedFile.FullName)" -ForegroundColor Green
        }
        catch {
            Write-Host "  FEHLER: Konnte Datei nicht löschen $($normalizedFile.FullName): $_" -ForegroundColor Red
        }
    }
    Write-Host "Alle Dateien verarbeitet." -ForegroundColor Green
}
else {
    Write-Host "Ordnerauswahl abgebrochen." -ForegroundColor Yellow
}
#endregion