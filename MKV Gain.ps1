# PowerShell-Skript zur Lautstärkeanalyse und Anpassung der Lautstärke von MKV-Dateien mit FFmpeg
# Setze das Verzeichnis, in dem nach MKV-Dateien gesucht werden soll
#$directory = "X:\MythBusters"
# Stelle sicher, dass ffmpeg im Systempfad verfügbar ist oder gebe den kompletten Pfad an
$ffmpegPath = "F:\media-autobuild_suite-master\local64\bin-video\ffmpeg.exe"
# Ziel-Lautheit in LUFS (z. B. -14 LUFS für YouTube, -23 LUFS für Rundfunk)
$targetLoudness = -18

Add-Type -AssemblyName System.Windows.Forms

# Funktion zur Lautstärkeanalyse mit FFmpeg
function Get-LoudnessInfo {
    param (
        [string]$filePath
    )
        
    try {
        # Für Windows: Nutze NUL statt /dev/null
        # Führe ffmpeg mit der Lautstärkeanalyse über ebur128 aus - Ausgabe in Variable erfassen
        $tempOutputFile = [System.IO.Path]::GetTempFileName()
        $ffmpegProcess = Start-Process -FilePath $ffmpegPath -ArgumentList "-i", "`"$($filePath)`"", "-hide_banner", "-filter_complex", "ebur128=metadata=1", "-f", "null", "NUL" -NoNewWindow -PassThru -RedirectStandardError $tempOutputFile
        $ffmpegProcess.WaitForExit()
         Write-Host "Analysieren fertig" -ForegroundColor Green

        # Lese die Ausgabe aus der temporären Datei
        $ffmpegOutput = Get-Content -Path $tempOutputFile -Raw
           
        # Lösche die temporäre Datei
        Remove-Item -Path $tempOutputFile -Force -ErrorAction SilentlyContinue
        if ($ffmpegOutput -match "I:\s*([-\d\.]+)\s*LUFS") {
            Write-Host "Integrierte Lautheit für $($file.Name): $integratedLoudness LUFS" -ForegroundColor yellow
        } else {
            if ($ffmpegOutput -match "Error|Invalid") {
                Write-Host "Fehler beim Verarbeiten von $($file.Name):" -ForegroundColor Red
                Write-Host $ffmpegOutput -ForegroundColor Red #Ausgabe der Fehlermeldung
            }
        }
        return $ffmpegOutput
    }
    catch {
        Write-Host "Fehler beim Ausführen von FFmpeg: $_" -ForegroundColor Red
        # Überprüfe, ob FFmpeg Fehler ausgibt
    
        return $null
    }
}

# Funktion zur Anpassung der Lautstärke mit FFmpeg
function Set-VolumeGain {
    param (
        [string]$filePath, # Pfad zur Eingabedatei
        [double]$gain, # Der anzuwendende Gain-Wert in dB
        [string]$outputFile, # Pfad für die Ausgabedatei
        [int]$audioChannels # Anzahl der Audiokanäle in der Eingabedatei
    )

    Write-Host "Wende die Lautstärkeanpassung mit ffmpeg an"
    # Wende die Lautstärkeanpassung mit ffmpeg an und warte auf den Abschluss
    try {
        # Überprüfe die Anzahl der Audiokanäle, um den richtigen FFmpeg-Befehl auszuwählen
        if ($audioChannels -igt 2) {
            # Für Dateien mit mehr als 2 Audiokanälen (z.B. 5.1)
            $process = Start-Process -FilePath $ffmpegPath -ArgumentList "-y", "-i", "`"$($filePath)`"", "-hide_banner", "-af", "volume=${gain}dB", "-c:v", "copy", "-c:a", "libfdk_aac", "-profile:a", "aac_he", "-ac", "6", "-channel_layout", "5.1", "-c:s", "copy", "-metadata", "LUFS=18", "-metadata", "gained=${gain}", "-metadata", "normalized=true", "`"$($outputFile)`"" -NoNewWindow -PassThru -Wait -ErrorAction Stop
        } else {
            # Für Dateien mit 2 oder weniger Audiokanälen (z.B. Stereo oder Mono)
            $process = Start-Process -FilePath $ffmpegPath -ArgumentList "-y", "-i", "`"$($filePath)`"", "-hide_banner", "-af", "volume=${gain}dB", "-c:v", "copy", "-c:a", "libfdk_aac",  "-profile:a", "aac_he", "-b:a", "192k", "-c:s", "copy", "-metadata", "LUFS=18", "-metadata", "gained=${gain}", "-metadata", "normalized=true", "`"$($outputFile)`"" -NoNewWindow -PassThru -Wait -ErrorAction Stop
        }
        # Warte auf den Abschluss dieses Prozesses

        $process.WaitForExit()
        Write-Host "Lautstärkeanpassung fertig" -ForegroundColor Green
    }
    catch {
        Write-Host "Fehler bei der Lautstärkeanpassung: $_" -ForegroundColor Red
        # Alternativer Befehl, falls die Standardanpassung fehlschlägt
        Write-Host "Alternativer Befehl wird ausgeführt..." -ForegroundColor Yellow
        $process = Start-Process -FilePath $ffmpegPath -ArgumentList "-fflags", "+genpts", "-i", "`"$($filePath)`"", "-c:v", "copy", "-c:a", "copy", "-avoid_negative_ts", "make_zero", "`"$($outputFile)`"" -NoNewWindow -PassThru -Wait -ErrorAction Stop
        Write-Host "Repariere $($filePath) - Bitte warten..." -ForegroundColor Yellow
        $process.WaitForExit()
        Write-Host "Reparatur abgeschlossen" -ForegroundColor Green
    }
}

# Funktion zum Extrahieren der Mediendaten mittels FFmpeg
function Get-MediaInfo {
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
<#     if ($infoOutput -match "REPAIR" ) {
        Write-Host "Überspringe defekte Datei: $($file.Name) (Tag)" -ForegroundColor green
        continue
    } #>
        
        # Extrahiere die Dauer mit einem verbesserten Regex-Pattern
        if ($infoOutput -match "Duration:\s*(\d+):(\d+):(\d+)\.(\d+)") {
            $hours = [int]$matches[1]
            $minutes = [int]$matches[2]
            $seconds = [int]$matches[3]
            $milliseconds = [int]$matches[4]
            
            $totalSeconds = $hours * 3600 + $minutes * 60 + $seconds + ($milliseconds / 100)
            $mediaInfo.Duration = $totalSeconds
            $mediaInfo.DurationFormatted = "{0:D2}:{1:D2}:{2:D2}.{3:D2}" -f $hours, $minutes, $seconds, $milliseconds
            
            #Write-Host "Extrahierte Dauer: $($mediaInfo.DurationFormatted)" -ForegroundColor DarkCyan
        }
        else {
            Write-Host "WARNUNG: Konnte Dauer nicht aus der FFmpeg-Ausgabe extrahieren" -ForegroundColor Yellow
            $mediaInfo.Duration = 0
            $mediaInfo.DurationFormatted = "00:00:00.00"
        }
        
        # Extrahiere die Anzahl der Audiokanäle mit verbessertem Regex
        if ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:.*?,\s+\d+\s+Hz,\s+([\d.]+)") {
            $mediaInfo.AudioChannels = $matches[1]
            #Write-Host "Extrahierte Audiokanäle: $($mediaInfo.AudioChannels)" -ForegroundColor DarkCyan
        }
        elseif ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:.+?stereo") {
            $mediaInfo.AudioChannels = 2
            #Write-Host "Audioformat ist stereo (2 Kanäle)" -ForegroundColor DarkCyan
        }
        elseif ($infoOutput -match "Stream\s+#\d+:\d+(?:\([\w-]+\))?:\s+Audio:.+?mono") {
            $mediaInfo.AudioChannels = 1
            #Write-Host "Audioformat ist mono (1 Kanal)" -ForegroundColor DarkCyan
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

# Finde alle MKV-Dateien im angegebenen Verzeichnis
Clear-Host
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
  if($result -eq [Windows.Forms.DialogResult]::OK)  {
    $destFolder = Split-Path -Path $PickFolder.FileName
    Write-Host -Object "Selected Location: $destFolder" -ForegroundColor Green
    Write-Host -Object 'Please Wait. Generating Filelist.' -ForegroundColor Green

    $mkvFiles1 = Get-ChildItem -Path $destFolder -Filter "*.mkv" -Recurse
    $mkvFileCount = ($mkvFiles1 | Measure-Object).Count
    Write-Host "$mkvFileCount MKV-Dateien gefunden." -ForegroundColor Green
  
foreach ($file in $mkvFiles1) {    
    Write-Host "$mkvFileCount MKV-Dateien verbleibend." -ForegroundColor Green
    $mkvFileCount --
# Überspringe bereits normalisierte Dateien
    Write-Host "Analysiere: $($file.FullName)" -ForegroundColor Cyan
        
# Hole Quelldatei-Informationen
    $sourceInfo = Get-MediaInfo -filePath $file.FullName # Ruft die Funktion Get-MediaInfo auf, um die Mediendaten der Datei zu extrahieren.

# Überprüfe, ob die Mediendaten korrekt extrahiert wurden
    if ($sourceInfo.Duration -eq 0 -or $sourceInfo.AudioChannels -eq 0) {
        Write-Host "FEHLER: Konnte Mediendaten für $($file.Name) nicht korrekt extrahieren. Überspringe Datei." -ForegroundColor Red
        
        # Erstelle eine Textdatei mit dem Log bei Analyse-Fehlern
        $logFile = [System.IO.Path]::Combine($file.DirectoryName, "$($file.BaseName)_mediainfo_error.log")
        @(
            "Fehler bei der Medieninfo-Extraktion von $($file.Name) am $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "Konnte Dauer oder Audiokanäle nicht ermitteln.",
            "Dauer: $($sourceInfo.DurationFormatted)",
            "Audiokanäle: $($sourceInfo.AudioChannels)"
        ) | Out-File -FilePath $logFile -Encoding UTF8
        Write-Host "Konnte Dauer oder Audiokanäle nicht ermitteln." -ForegroundColor Red
        Write-Host "Fehlerprotokoll erstellt: $logFile" -ForegroundColor Red
        Write-Host "Überspringe Datei." -ForegroundColor Red
        continue
    }
    
    Write-Host "Quelldatei-Informationen:" -ForegroundColor Blue
    Write-Host "  Dauer: $($sourceInfo.DurationFormatted)" -ForegroundColor Blue
    Write-Host "  Audiokanäle: $($sourceInfo.AudioChannels)" -ForegroundColor Blue
    
    # Führe ffmpeg mit der Lautstärkeanalyse über ebur128 aus - Ausgabe in Variable erfassen
    Write-Host "Analysiere Lautstärke von $($file.Name)" -ForegroundColor cyan
    $ffmpegOutput = Get-LoudnessInfo -filePath $file.FullName # Ruft die Funktion Get-LoudnessInfo auf, um die Lautstärkeinformationen der Datei zu analysieren.
    
        
    # Extrahiere die integrierte Lautheit (LUFS) mit verbessertem Regex-Pattern
    if ($ffmpegOutput -match "I:\s*([-\d\.]+)\s*LUFS") {
        $gain = $targetLoudness - $integratedLoudness # Berechne den notwendigen Gain-Wert
        
        if ([math]::Abs($gain) -gt 0.1) {
            Write-Host "Passe Lautstärke um $gain dB an für: $($file.Name)" -ForegroundColor Yellow
            
# Erstelle den Namen für die angepasste Datei
            $outputFile = [System.IO.Path]::Combine($file.DirectoryName, "$($file.BaseName)_normalized.mkv")
            Set-VolumeGain -filePath $file.FullName -gain $gain -outputFile $outputFile -audioChannels $sourceInfo.AudioChannels

            # Variable für das Protokoll
            $logContent = @()
            $logContent += "Verarbeitung von $($file.Name) am $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            $logContent += "Quelldatei: $($file.FullName)"
            $logContent += "Ausgabedatei: $outputFile"
            $logContent += "Integrierte Lautheit: $integratedLoudness LUFS"
            $logContent += "Ziel-Lautheit: $targetLoudness LUFS"
            $logContent += "Angewendeter Gain: $gain dB"
            
            # Überprüfe die Ausgabedatei, sobald der Prozess abgeschlossen ist
            $verificationsOk = $true
            
            if (Test-Path $outputFile) {
                Write-Host "Überprüfe die Ausgabedatei: $outputFile" -ForegroundColor Cyan
                
                # Warte kurz, um sicherzustellen, dass die Datei vollständig geschrieben wurde
                Start-Sleep -Seconds 2
                
                $outputInfo = Get-MediaInfo2 -filePath $outputFile
                
                # Überprüfe, ob die Ausgabedatei korrekt erfasst wurde
                if ($outputInfo.Duration -eq 0 -or $outputInfo.AudioChannels -eq 0) {
                    $verificationsOk = $false
                    $logContent += "FEHLER: Konnte Mediendaten für die Ausgabedatei nicht korrekt extrahieren."
                    Write-Host "  FEHLER: Konnte Mediendaten für die Ausgabedatei nicht korrekt extrahieren." -ForegroundColor Red
                } else {
                    $logContent += "Quelldatei-Dauer: $($sourceInfo.DurationFormatted) | Audiokanäle: $($sourceInfo.AudioChannels)"
                    $logContent += "Ausgabedatei-Dauer: $($outputInfo.DurationFormatted) | Audiokanäle: $($outputInfo.AudioChannels)"
                    
                    Write-Host "  Quelldatei-Dauer: $($sourceInfo.DurationFormatted) | Audiokanäle: $($sourceInfo.AudioChannels)" -ForegroundColor Blue
                    Write-Host "  Ausgabedatei-Dauer: $($outputInfo.DurationFormatted) | Audiokanäle: $($outputInfo.AudioChannels)" -ForegroundColor Blue
                    
                    # Überprüfe die Laufzeit (mit einer kleinen Toleranz von 1 Sekunde)
                    $durationDiff = [Math]::Abs($sourceInfo.Duration - $outputInfo.Duration)
                    if ($durationDiff -gt 1) {
                        $verificationsOk = $false
                        $logContent += "FEHLER: Die Laufzeiten unterscheiden sich um $durationDiff Sekunden!"
                        Write-Host "  WARNUNG: Die Laufzeiten unterscheiden sich um $durationDiff Sekunden!" -ForegroundColor Red
                    } else {
                        $logContent += "OK: Die Laufzeiten stimmen überein."
                        Write-Host "  OK: Die Laufzeiten stimmen überein." -ForegroundColor Green
                    }
                    
                    # Überprüfe die Anzahl der Audiokanäle
                    if ($sourceInfo.AudioChannels -ne $outputInfo.AudioChannels) {
                        $verificationsOk = $false
                        $logContent += "FEHLER: Die Anzahl der Audiokanäle hat sich geändert! (Quelle: $($sourceInfo.AudioChannels), Ausgabe: $($outputInfo.AudioChannels))"
                        Write-Host "  WARNUNG: Die Anzahl der Audiokanäle hat sich geändert! (Quelle: $($sourceInfo.AudioChannels), Ausgabe: $($outputInfo.AudioChannels))" -ForegroundColor Red
                    } else {
                        $logContent += "OK: Die Anzahl der Audiokanäle ist gleich geblieben."
                        Write-Host "  OK: Die Anzahl der Audiokanäle ist gleich geblieben." -ForegroundColor Green
                    }
                }
                
                # Überprüfe, ob die Verifikationen erfolgreich waren
                if ($verificationsOk) {
                    # Alles gut, lösche die Quelldatei und benenne die normalisierte Datei um
                    try {
                        # Temporäre Datei für Umbenennung
                        $tempFile = [System.IO.Path]::Combine($file.DirectoryName, "$($file.BaseName)_temp.mkv")
                        
                        # Datei umbenennen mit Zwischenschritt um Namenskollisionen zu vermeiden
                        Rename-Item -Path $outputFile -NewName $tempFile -Force
                        Remove-Item -Path $file.FullName -Force
                        Rename-Item -Path $tempFile -NewName $file.Name -Force
                        
                        $logContent += "ERFOLG: Quelldatei gelöscht und normalisierte Datei umbenannt zu $($file.Name)"
                        Write-Host "  Erfolg: Quelldatei gelöscht und normalisierte Datei umbenannt zu $($file.Name)" -ForegroundColor Green
                    }
                    catch {
                        $logContent += "FEHLER bei Umbenennung/Löschen: $_"
                        Write-Host "  FEHLER bei Umbenennung/Löschen: $_" -ForegroundColor Red
                    }
                } else {
                    # Fehler aufgetreten, lösche die Ausgabedatei
                    try {
                        Remove-Item -Path $outputFile -Force
                        
                        # Erstelle eine Textdatei mit dem Log
                        $logFile = [System.IO.Path]::Combine($file.DirectoryName, "$($file.BaseName)_error.log")
                        $logContent += "FEHLER: Überprüfung fehlgeschlagen. Ausgabedatei wurde gelöscht."
                        $logContent | Out-File -FilePath $logFile -Encoding UTF8
                        
                        Write-Host "  Ausgabedatei gelöscht. Fehlerprotokoll erstellt: $logFile" -ForegroundColor Red
                    }
                    catch {
                        Write-Host "  FEHLER beim Löschen der fehlerhaften Ausgabedatei: $_" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "FEHLER: Ausgabedatei $outputFile wurde nicht erstellt!" -ForegroundColor Red
                
                # Erstelle eine Textdatei mit dem Log
                $logFile = [System.IO.Path]::Combine($file.DirectoryName, "$($file.BaseName)_error.log")
                $logContent += "FEHLER: Ausgabedatei wurde nicht erstellt."
                $logContent | Out-File -FilePath $logFile -Encoding UTF8
            }
        } else {
            Write-Host "Lautstärke für $($file.Name) ist bereits nahe am Zielwert, keine Anpassung notwendig." -ForegroundColor Blue
            $process = Start-Process -FilePath $ffmpegPath -ArgumentList "-i", "`"$($file.FullName)`"", "-c:v", "copy", "-c:a", "copy", "-c:s", "copy", "-metadata", "normalized=true", "`"$outputFile`"" -NoNewWindow -PassThru
        }
    } else {
        Write-Host "Warnung: Keine Lautstärkeinformationen für $($file.Name) gefunden." -ForegroundColor Yellow
        Write-Host "FFmpeg-Ausgabe:" -ForegroundColor Yellow
        Write-Host $ffmpegOutput
        
        # Erstelle eine Textdatei mit dem Log bei Analyse-Fehlern
        $logFile = [System.IO.Path]::Combine($file.DirectoryName, "$($file.BaseName)_analysis_error.log")
        @(
            "Fehler bei der Lautstärkeanalyse von $($file.Name) am $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "Keine LUFS-Werte gefunden.",
            "FFmpeg-Ausgabe:",
            $ffmpegOutput
        ) | Out-File -FilePath $logFile -Encoding UTF8
        Write-Host "Fehlerprotokoll erstellt: $logFile" -ForegroundColor Red
    }
    
    Write-Host "Verarbeitung von $($file.Name) abgeschlossen." -ForegroundColor Green
    Write-Host "-------------------------------------------" -ForegroundColor DarkGray
}

Write-Host "Alle Dateien wurden verarbeitet." -ForegroundColor Green
}
else
{
  Write-Host -Object 'File Save Dialog Canceled' -ForegroundColor Yellow
}