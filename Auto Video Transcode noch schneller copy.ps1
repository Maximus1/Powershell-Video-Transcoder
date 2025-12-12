#region Konfiguration
# Pfad zur FFmpeg-Anwendung. Dieser muss korrekt gesetzt sein, damit das Skript funktioniert.
$ffmpegPath = "F:\media-autobuild_suite-master1\local64\bin-video\ffmpeg.exe"
# Pfad zur mkvextract-Anwendung aus dem MKVToolNix-Paket.
$mkvextractPath = "C:\Program Files\MKVToolNix\mkvextract.exe"

# Ziel-Lautheit in LUFS fuer die Audionormalisierung (z.B. -18 fuer eine konsistente Lautstaerke).
$targetLoudness = -18
$filePath = ''
# Liste der zu verarbeitenden Dateiendungen.
$extensions = @('.mkv', '.mp4', '.avi', '.m2ts')

#Nutze Hardwarebeschleunigung (encoding) wenn moeglich
#$useHardwareAccel = $true # Setze auf $true, um Hardwarebeschleunigung zu verwenden, wenn verfuegbar.
$useHardwareAccel = $false

# Qualitaetsvorgaben fuer die Encoder.
$amd_quality = "quality" # AMD Preset fuer hohe Qualitaet.
$Nvidia_quality = "hq" # NVIDIA Preset fuer hohe Qualitaet.
$encoderPreset = 'medium' # Standard-Preset fuer libx265.
# CRF-Wert (Constant Rate Factor) fuer Filme. Niedrigere Werte bedeuten hoehere Qualitaet.
$crfTargetm = 18 # CRF fuer Filme
# CRF-Wert fuer Serien.
$crfTargets = 20 # Etwas hoeherer CRF fuer Serien zur besseren Kompression.
# Encoder-Preset beeinflusst die Kodierungsgeschwindigkeit vs. Kompression (z.B. 'medium', 'slow').
# Der Ziel-Videocodec fuer die Transkodierung.
$targetVideoCodec = 'HEVC' # Alle Videos werden in HEVC (H.265) kodiert.

# Zieldateiendung fuer alle verarbeiteten Dateien.
$targetExtension = '.mkv' # Alle Ausgabedateien werden im MKV-Container gespeichert.
# Array zum Sammeln von Dateien, die noch nicht normalisiert wurden und verarbeitet werden muessen.
$script:filesnotnorm = @()
# Array zum Sammeln von Dateien, die bereits normalisiert sind und uebersprungen werden.
$script:filesnorm = @()

# Qualitaetsstufen fuer die Berechnung der erwarteten Dateigroeße, um unnoetig große Dateien zu erkennen.
$qualitaetFilm = "hoch" # Qualitaetsstufe fuer Filme
$qualitaetSerie = "hoch" # Qualitaetsstufe fuer Serien


#endregion

#region Hilfsfunktionen

function Get-SystemGpuVendor { # Ermittelt den GPU-Hersteller (NVIDIA oder AMD) im System.
    <#
    .SYNOPSIS
        Ermittelt den Hersteller der primaeren dedizierten GPU im System.
    .DESCRIPTION
        Fragt ueber WMI/CIM die installierten Grafikkarten ab und gibt "NVIDIA" oder "AMD" zurueck.
        Priorisiert dedizierte Karten gegenueber integrierten Grafikeinheiten.
    .RETURNS
        [string] "NVIDIA", "AMD" oder "Unknown".
    #>
    try {
        # Hole alle Video-Controller im System
        $videoControllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop

        # Suche gezielt nach NVIDIA oder AMD, um dedizierte GPUs zu priorisieren
        $nvidiaGpu = $videoControllers | Where-Object { $_.Name -like "*NVIDIA*" }
        $amdGpu = $videoControllers | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Advanced Micro Devices*" }

        if ($nvidiaGpu) {
            Write-Host "System-Check: NVIDIA GPU gefunden ($($nvidiaGpu[0].Name))." -ForegroundColor DarkGray
            return "NVIDIA"
        }
        if ($amdGpu) {
            Write-Host "System-Check: AMD GPU gefunden ($($amdGpu[0].Name))." -ForegroundColor DarkGray
            return "AMD"
        }

        Write-Host "System-Check: Keine dedizierte NVIDIA oder AMD GPU gefunden." -ForegroundColor DarkGray
        return "Unknown"
    }
    catch {
        Write-Warning "Fehler bei der Abfrage der System-GPU via WMI/CIM: $($_.Exception.Message)"
        return "Unknown"
    }
}
function Get-HardwareEncoder { # Bestimmt den verfuegbaren Hardware-Encoder basierend auf System-GPU und FFmpeg-Unterstuetzung.
    param(
        [string]$ffmpegPath
    )

    # Prueft die verfuegbaren Encoder in FFmpeg
    $encodersOutput = & $ffmpegPath -encoders 2>$null
    $hasNvidia = $encodersOutput -match "hevc_nvenc"
    $hasAmd = $encodersOutput -match "hevc_amf"

    # 1. Echte Hardware im System pruefen
    $gpuVendor = Get-SystemGpuVendor

    # 2. Logik basierend auf Hardware UND FFmpeg-Support (NVIDIA priorisiert)
    if ($gpuVendor -eq "NVIDIA" -and $hasNvidia) {
        Write-Host "Bestaetigt: NVIDIA GPU und FFmpeg-Encoder (hevc_nvenc) sind verfuegbar." -ForegroundColor Green
        return "hevc_nvenc"
    }
    elseif ($gpuVendor -eq "AMD" -and $hasAmd) {
        Write-Host "Bestaetigt: AMD GPU und FFmpeg-Encoder (hevc_amf) sind verfuegbar." -ForegroundColor Green
        return "hevc_amf"
    }
    else {
        if ($gpuVendor -ne "Unknown") {
            Write-Host "Warnung: $gpuVendor GPU gefunden, aber der passende FFmpeg HEVC-Encoder ist nicht verfuegbar." -ForegroundColor Yellow
        }
        Write-Host "Keine kompatible Hardware-Beschleunigung gefunden. Fallback auf CPU-Encoder (libx265)." -ForegroundColor Yellow
        return "libx265"
    }
}

function Test-IsNormalized { # Überprueft, ob eine MKV-Datei bereits ein "NORMALIZED=true"-Tag in ihren Metadaten enthaelt.
# Überprueft, ob eine MKV-Datei bereits ein "NORMALIZED=true"-Tag in ihren Metadaten enthaelt.
    param (
        [string]$file
    )

    if (!(Test-Path $mkvextractPath)) {
        Write-Error "mkvextract.exe nicht gefunden unter $mkvextractPath"
        "`n==== mkvextract.exe nicht gefunden unter $mkvextractPath ====" | Add-Content -LiteralPath (Join-Path $destFolder "Normalization_Check.log")
        return $false
    }

# Erstellt eine temporaere XML-Datei, um die Tag-Ausgabe von mkvextract zu speichern.
    $tempXml = [System.IO.Path]::GetTempFileName()

    try {
# Extrahiert die Metadaten-Tags der Videodatei und leitet sie in die temporaere XML-Datei um.
        & $mkvextractPath tags "$file" > $tempXml 2>$null

# Liest den gesamten Inhalt der XML-Datei.
        $xmlText = Get-Content -Path $tempXml -Raw -Encoding UTF8

        if ([string]::IsNullOrWhiteSpace($xmlText)) {
            throw "Extrahierter XML-Inhalt ist leer oder ungueltig."
        }
# Versucht, den Text als XML zu parsen. Schlaegt dies fehl, ist es wahrscheinlich keine gueltige MKV-Datei.
        try {
            [xml]$xml = $xmlText
        } catch {
            $script:filesnotnorm += $file # Datei zur Verarbeitung hinzufuegen
            Write-Warning "Konnte XML nicht parsen (vermutlich keine MKV): $file"
            "`n==== Konnte XML nicht parsen (vermutlich keine MKV): $file ====" | Add-Content -LiteralPath (Join-Path $destFolder "Normalization_Check.log")
            return $false
        }

# Durchsucht das XML-Dokument nach einem 'NORMALIZED'-Tag mit dem spezifischen Wert 'true'.
        $normalized = $xml.SelectNodes('//Simple[Name="NORMALIZED"]/String') |
                      Where-Object { $_.InnerText -eq 'true' }

        if ($null -eq $normalized -or $normalized.Count -eq 0) {
            $script:filesnotnorm += $file
            return $false
        } else {
            $script:filesnorm += $file
            return $true
        }
    }
    catch {
        $script:filesnotnorm += $file
# Faengt alle Fehler waehrend der Verarbeitung ab (z.B. bei beschaedigten Dateien) und stuft die Datei sicherheitshalber als "nicht normalisiert" ein.
        Write-Warning "Fehler beim Verarbeiten von $file`nGrund: $_"
        "`n==== Fehler beim Verarbeiten von $file`nGrund: $_ ====" | Add-Content -LiteralPath (Join-Path $destFolder "Normalization_Check.log")
        return $false
    }
    finally {
# Stellt sicher, dass die temporaere XML-Datei nach der Verarbeitung immer geloescht wird.
        if (Test-Path $tempXml) {
            Remove-Item $tempXml -Force
        }
    }
}
function Get-MediaInfo { # Sammelt umfassende Metadaten einer Videodatei.
    param ([string]$filePath, [string]$logDatei)
    # Sammelt umfassende Metadaten einer Videodatei durch die Kombination mehrerer Analysefunktionen.

    if (!(Test-Path -LiteralPath $filePath)) {
        Write-Host "FEHLER: Datei nicht gefunden: $filePath" -ForegroundColor Red
        return $null
    }

    $ffmpegOutput = Get-FFmpegOutput -FilePath $filePath
    $mediaInfo = @{}

    # Ruft grundlegende Videoinformationen wie Dauer, Codec und Aufloesung ab.
    $mediaInfo += Get-BasicVideoInfo -Output $ffmpegOutput -FilePath $filePath
    # Ermittelt Farbinformationen wie Bittiefe und HDR-Status.
    $mediaInfo += Get-ColorAndHDRInfo -Output $ffmpegOutput
    # Extrahiert Audioinformationen wie Kanalanzahl und Codec.
    $mediaInfo += Get-AudioInfo -Output $ffmpegOutput
    # Prueft, ob das Video Interlaced-Material enthaelt.
    $mediaInfo += Get-InterlaceInfo -FilePath $filePath
    # Prueft, ob der Dateiname einem Serienmuster (SxxExx) entspricht.
    $mediaInfo += Test-IsSeries -filename $filePath -logDatei $logDatei -sourceInfo $mediaInfo


    # Analysiert, ob eine Neukodierung basierend auf der Dateigroeße im Verhaeltnis zur Laufzeit empfohlen wird.
    $mediaInfo += Get-RecodeAnalysis -MediaInfo $mediaInfo -logDatei $logDatei

    # Speichert die urspruenglichen Dauer-Werte, da sie in spaeteren Analysen ueberschrieben werden koennten.
    if ($mediaInfo.Duration -and -not $mediaInfo.ContainsKey("Duration1")) {
        $mediaInfo.Duration1 = $mediaInfo.Duration
    }
    if ($mediaInfo.DurationFormatted -and -not $mediaInfo.ContainsKey("DurationFormatted1")) {
        $mediaInfo.DurationFormatted1 = $mediaInfo.DurationFormatted
    }
    # Gibt eine Zusammenfassung der ermittelten Medieninformationen auf der Konsole aus.
    Write-Host "Video: $($mediaInfo.DurationFormatted1) | $($mediaInfo.VideoCodec) | $($mediaInfo.Resolution) | Interlaced: $($mediaInfo.Interlaced) | FPS: $($mediaInfo.FPS)" -ForegroundColor DarkCyan
    Write-Host "Audio: $($mediaInfo.AudioChannels) Kanaele | $($mediaInfo.AudioCodec)" -ForegroundColor DarkCyan
    return $mediaInfo
}
#region Hilfsfunktionen zu Get-MediaInfo
function Get-FFmpegOutput { # Ruft die FFmpeg-Ausgabe fuer eine Datei ab.
    param ([string]$FilePath)
    # Fuehrt 'ffmpeg -i' fuer eine Datei aus und faengt die Standardfehlerausgabe (stderr) ab, die die Metadaten enthaelt.

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $ffmpegPath
    $startInfo.Arguments = "-i `"$FilePath`""
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $process.Start() | Out-Null
    $output = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return $output
}
function Get-BasicVideoInfo { # Extrahiert grundlegende Video-Metadaten (Groeße, FPS, Dauer, Codec, Aufloesung) aus der FFmpeg-Ausgabe.
    param (
        [string]$Output,
        [string]$FilePath
    )
    # Extrahiert grundlegende Video-Metadaten (Groeße, FPS, Dauer, Codec, Aufloesung) aus der FFmpeg-Ausgabe.
    $info = @{}
    $size = (Get-Item $FilePath).Length
    $info.FileSizeBytes = $size

    if ($Output -match "fps,\s*(\d+(\.\d+)?)") {
        $info.FPS = [double]$matches[1]
    }

    if ($Output -match "Duration:\s*(\d+):(\d+):(\d+)\.(\d+)") {
        $h = [int]$matches[1]; $m = [int]$matches[2]; $s = [int]$matches[3]; $ms = [int]$matches[4]
        $info.Duration = $h * 3600 + $m * 60 + $s + ($ms / 100)
        $info.DurationFormatted1 = "{0:D2}:{1:D2}:{2:D2}.{3:D2}" -f $h, $m, $s, $ms
    }

    if ($Output -match "Video:\s*([^\s,]+)") {
        $info.VideoCodecSource = $matches[1]
        $info.VideoCodec = $matches[1]
# Prueft, ob der Quellcodec NICHT AV1 ist, um die Hardwarebeschleunigung zu aktivieren.
        if ($info.VideoCodecSource -ne "AV1" -and $info.VideoCodecSource -ne "av1") {
            Write-Host "  -> Hardwarebeschleunigung (Decoding) aktiviert fuer Nicht-AV1-Codecs." -ForegroundColor Cyan
            "`n====  -> Hardwarebeschleunigung (Decoding) aktiviert fuer Nicht-AV1-Codecs. ===" | Add-Content -LiteralPath $logDatei
        }
# Wenn der Quellcodec AV1 ist, wird die Hardwarebeschleunigung deaktiviert, da sie oft Probleme verursacht.
        if ($info.VideoCodecSource -eq "AV1") {
            $info.NoAccel = $true
            Write-Host "  -> Hardwarebeschleunigung (Decoding) deaktiviert fuer AV1-Codecs." -ForegroundColor Cyan
            "`n====  -> Hardwarebeschleunigung (Decoding) deaktiviert fuer AV1-Codecs. ===" | Add-Content -LiteralPath $logDatei
        }
    }

    if ($Output -match "Video:.*?,\s+(\d+)x(\d+)") {
        $info.Resolution = "$($matches[1])x$($matches[2])"
    }
    return $info
}
function Get-ColorAndHDRInfo { # Extrahiert Farbinformationen und HDR-Status aus der FFmpeg-Ausgabe.
    param ([string]$Output)
    $info = @{}
# Analysiert die FFmpeg-Ausgabe, um Farbinformationen wie Bittiefe, Farbraum und HDR-Formate zu ermitteln.

# Sucht nach dem Pixelformat (z.B. yuv420p10le) und extrahiert die Bittiefe (z.B. 10) sowie Farbinformationen in Klammern.
    if ($Output -match "yuv\d{3}p(\d{2})\w*\(([^)]*)\)") {
        $info.BitDepth = [int]$matches[1]
        $info.Is12BitOrMore = $info.BitDepth -ge 12
        $colorParts = $matches[2].Split("/")
        foreach ($part in $colorParts) {
            switch ($part.Trim()) {
                { $_ -match "^(tv|pc)$" }     { $info.ColorRange = $_ }
                { $_ -match "^bt\d+" }        { $info.ColorPrimaries = $_ }
                { $_ -match "smpte|hlg|pq" }  { $info.TransferCharacteristics = $_ }
            }
        }
    } elseif ($Output -match "yuv\d{3}p(\d{2})") {
# Fallback, falls die Bittiefe ohne zusaetzliche Farbinformationen in Klammern angegeben ist.
        $info.BitDepth = [int]$matches[1]
        $info.Is12BitOrMore = $info.BitDepth -ge 12
    } else {
# Standardannahme ist 8 Bit, wenn keine spezifische Bittiefe erkannt wird.
        $info.BitDepth = 8
        $info.Is12BitOrMore = $false
    }

    if ($Output -match "(HDR10\+?|Dolby\s+Vision|HLG|PQ|BT\.2020|smpte2084|arib-std-b67)") { # Prueft auf Schluesselwoerter, die auf HDR-Material hinweisen.
        $info.HDR = $true
        $info.HDR_Format = $matches[1]
    } else {
        $info.HDR = $false
        $info.HDR_Format = "Kein HDR"
    }

    return $info
}
function Get-AudioInfo { # Extrahiert Audio-Metadaten (Kanalanzahl und Codec) aus der FFmpeg-Ausgabe.
    param ([string]$Output)
    $info = @{}
# Extrahiert Audio-Metadaten (Kanalanzahl und Codec) aus der FFmpeg-Ausgabe.

# Sucht nach der Kanalanzahl in der Form "X channels".
    if ($Output -match "Audio:.*?,\s*\d+\s*Hz,\s*([0-9\.]+)\s*channels?") {
        $info.AudioChannels = [int]$matches[1]
    } elseif ($Output -match "Audio:.*?,\s*\d+\s*Hz,\s*([^\s,]+),") {
# Sucht nach textuellen Kanalbeschreibungen wie "mono", "stereo", "5.1" etc.
        switch -Regex ($matches[1]) {
            "mono"   { $info.AudioChannels = 1 }
            "stereo" { $info.AudioChannels = 2 }
            "5\.1"   { $info.AudioChannels = 6 }
            "7\.1"   { $info.AudioChannels = 8 }
            default  { $info.AudioChannels = 0 }
        }
    }

# Extrahiert den Audio-Codec (z.B. aac, ac3, dts).
    if ($Output -match "Audio:\s*([\w\-\d]+)") {
        $info.AudioCodec = $matches[1]
    }

    return $info
}
function Get-InterlaceInfo { # Bestimmt, ob ein Video Interlaced-Material enthaelt, mittels FFmpeg's 'idet'-Filter.
    param ([string]$FilePath)
    $info = @{}
# Verwendet den 'idet'-Filter von FFmpeg, um festzustellen, ob ein Video Interlaced-Material ist.
# Der idet-Filter analysiert eine Anzahl von Frames (hier 1500) und zaehlt, wie viele progressiv, TFF oder BFF sind.
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $ffmpegPath
        $startInfo.Arguments = "-i `"$FilePath`" -filter:v idet -frames:v 1500 -an -f null NUL"
        $startInfo.RedirectStandardError = $true
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $startInfo
        $proc.Start() | Out-Null
        $output = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

# Extrahiert die finale Zusammenfassung des idet-Filters.
        $match = [regex]::Matches($output, "Multi frame detection:\s*TFF:\s*(\d+)\s*BFF:\s*(\d+)\s*Progressive:\s*(\d+)")
        if ($match.Count -gt 0) {
            $last = $match[$match.Count - 1]
            $tff = [int]$last.Groups[1].Value
            $bff = [int]$last.Groups[2].Value
            $prog = [int]$last.Groups[3].Value
            $info.Interlaced = ($tff + $bff) -gt $prog
# Wenn die Summe der Interlaced-Frames (TFF + BFF) groeßer ist als die der progressiven Frames, wird das Video als Interlaced eingestuft.
        }
    } catch {
        $info.Interlaced = $false
# Bei einem Fehler wird sicherheitshalber von progressivem Material ausgegangen.
    }

    return $info
}
function Test-IsSeries { # Erkennt anhand des Dateinamens (SxxExx-Muster), ob es sich um eine Serie handelt, und prueft, ob eine Skalierung auf 720p noetig ist.
    param(
# Erkennt anhand des Dateinamens (SxxExx-Muster), ob es sich um eine Serie handelt, und prueft, ob eine Skalierung auf 720p noetig ist.
        [string]$filename,
        [hashtable]$sourceInfo,
        [string]$logDatei
    )
    $info = @{}
# Prueft, ob der Dateiname dem typischen Serienmuster "SxxExx" entspricht.
    if ($filename -match "S\d+E\d+") {
        $info.IsSeries = $true
        if ($sourceInfo.Resolution -match "^(\d+)x(\d+)$") {
            $width = [int]$matches[1]
            $height = [int]$matches[2]
# Wenn die Aufloesung groeßer als 720p ist, wird eine Skalierung erzwungen.
            if ($width -gt 1280 -or $height -gt 720) {
                $info.resize = $true
                $info.Force720p = $true
                Write-Host "Aufloesung > 1280x720 erkannt: Resize und Force720p aktiviert." -ForegroundColor Yellow
                "`n==== Aufloesung > 1280x720 erkannt: Resize und Force720p aktiviert. ====" | Add-Content -LiteralPath $logDatei
            } else {
                $info.resize = $false
                $info.Force720p = $false
            }
        }
        Write-Host "Datei als Serie erkannt: $filename" -ForegroundColor Green
        "`n==== Datei als Serie erkannt: $filename ====" | Add-Content -LiteralPath $logDatei
    }
    else {
# Wenn das Muster nicht zutrifft, wird die Datei als Film behandelt.
        $info.IsSeries = $false
        $info.Force720p = $false
        Write-Host "Datei nicht als Serie erkannt: $filename"
        "`n==== Datei nicht als Serie erkannt: $filename ====" | Add-Content -LiteralPath $logDatei
    }
    return $info
}
function Get-RecodeAnalysis { # Analysiert, ob eine Neukodierung basierend auf der Dateigroeße im Verhaeltnis zur Laufzeit empfohlen wird.
    param (
# Vergleicht die tatsaechliche Dateigroeße mit einer erwarteten Groeße, um zu entscheiden, ob eine Neukodierung zur Platzersparnis sinnvoll ist.
        [hashtable]$MediaInfo,
        [string]$logDatei
    )
    $info = @{}
# Prueft zuerst, ob der Codec bereits dem Zielcodec entspricht.
    if ($mediaInfo.VideoCodecSource -ne $targetVideoCodec) {
        $info = @{ RecodeRecommended = $true }
        Write-Host "Recode erforderlich: Video-Codec ist '$($mediaInfo.VideoCodecSource)' und nicht '$targetVideoCodec'." -ForegroundColor Yellow
        "`n==== Recode erforderlich: Video-Codec ist '$($mediaInfo.VideoCodecSource)' und nicht '$targetVideoCodec'. ====" | Add-Content -LiteralPath $logDatei
    }
    else {
# Wenn der Codec bereits korrekt ist, wird die Dateigroeße geprueft.
        $fileSizeBytes = $mediaInfo.FileSizeBytes
        $fileSizeMB = $fileSizeBytes / 1MB
        $duration = $mediaInfo.Duration
# Berechnet die erwartete Dateigroeße basierend auf der Laufzeit und vordefinierten Qualitaetsraten.
        $expectedSizeMB = Measure-ExpectedSizeMB -durationSeconds $duration -isSeries $mediaInfo.IsSeries -logDatei $logDatei
# Empfiehlt eine Neukodierung, wenn die Datei signifikant (hier >50%) groeßer als erwartet ist.
        if ($fileSizeMB -gt ($expectedSizeMB * 1.5)) {
            $info = @{ RecodeRecommended = $true }
            Write-Host "Recode empfohlen: Datei ist deutlich groeßer als erwartet ($([math]::Round($fileSizeMB,2)) MB > $expectedSizeMB MB)" -ForegroundColor Yellow
            "`n==== Recode empfohlen: Datei ist deutlich groeßer als erwartet ($([math]::Round($fileSizeMB,2)) MB > $expectedSizeMB MB) ====" | Add-Content -LiteralPath $logDatei
        }
        else {
            $info = @{ RecodeRecommended = $false }
            Write-Host "Kein Recode noetig: Dateigroeße ist im erwarteten Bereich ($([math]::Round($fileSizeMB,2)) MB ≤ $expectedSizeMB MB)" -ForegroundColor Green
            "`n==== Kein Recode noetig: Dateigroeße ist im erwarteten Bereich ($([math]::Round($fileSizeMB,2)) MB ≤ $expectedSizeMB MB) ====" | Add-Content -LiteralPath $logDatei
        }
    }

    return $info
}
function Measure-ExpectedSizeMB { # Berechnet eine erwartete Zieldateigroeße in MB basierend auf der Videolaenge und unterschiedlichen Raten fuer Filme und Serien.
    param (
# Berechnet eine erwartete Zieldateigroeße in MB basierend auf der Videolaenge und unterschiedlichen Raten fuer Filme und Serien.
        [double]$durationSeconds,
        [bool]$isSeries,
        [string]$logDatei
    )

# Vordefinierte Bitraten (in MB pro Sekunde) fuer verschiedene Qualitaetsstufen bei Filmen.
    $filmRates = @{
        "niedrig" = 0.25
        "mittel"  = 0.4
        "hoch"    = 0.7
        "sehrhoch"= 1.0
    }
# Vordefinierte Bitraten (in MB pro Sekunde) fuer verschiedene Qualitaetsstufen bei Serien.
    $serieRates = @{
        "niedrig" = 0.1
        "mittel"  = 0.14
        "hoch"    = 0.3
        "sehrhoch"= 0.5
    }

# Waehlt die passende Raten-Tabelle und Qualitaetsstufe basierend auf dem Medientyp.
    if ($isSeries -eq $true) {
        $quality = $qualitaetSerie.ToLower()
        $rates = $serieRates
    }
    else {
        $quality = $qualitaetFilm.ToLower()
        $rates = $filmRates
    }

# Fallback auf 'mittel', falls eine ungueltige Qualitaetsstufe konfiguriert wurde.
    if (-not $rates.ContainsKey($quality)) {
        Write-Warning "Qualitaet '$quality' nicht definiert. Nutze 'mittel'."
        "`n==== Qualitaet '$quality' nicht definiert. Nutze 'mittel'. ====" | Add-Content -LiteralPath $logDatei
        $quality = "mittel"
    }

    $mbPerSecond = $rates[$quality]
    $expectedSizeMB = [math]::Round($mbPerSecond * $durationSeconds, 2)
    return $expectedSizeMB
}
#endregion
function Get-MediaInfo2 { # Eine schlankere Medienanalyse fuer Ausgabedateien nach der Konvertierung.
    param (
        # Eine schlankere Version von Get-MediaInfo, die speziell fuer die Analyse von Ausgabedateien nach der Konvertierung gedacht ist.
        [string]$filePath,
        [string]$logDatei
    )

    $mediaInfoout = @{}

    try {
# FFmpeg-Analyse durchfuehren
        $infoOutput = Get-FFmpegOutput -FilePath $filePath

# Ruft Basis-Videoinformationen ab.
        $videoInfo = Get-BasicVideoInfo -Output $infoOutput -FilePath $filePath
        $mediaInfoout += $videoInfo

# Die von Get-BasicVideoInfo erstellte Eigenschaft 'DurationFormatted1' wird in 'DurationFormatted' umbenannt,
# um innerhalb dieser Funktion konsistent zu sein.
        if ($mediaInfoout.ContainsKey('DurationFormatted1')) {
            $mediaInfoout.DurationFormatted = $mediaInfoout.DurationFormatted1
            $mediaInfoout.Remove('DurationFormatted1')
        }

# Ruft Audioinformationen ab.
        $mediaInfoout += Get-AudioInfo -Output $infoOutput

# Gibt eine Zusammenfassung der erfassten Daten aus.
        Write-Host "Video: $($mediaInfoout.DurationFormatted) | $($mediaInfoout.VideoCodec) | $($mediaInfoout.Resolution)" -ForegroundColor DarkCyan
        Write-Host "Audio: $($mediaInfoout.AudioChannels) Kanaele | $($mediaInfoout.AudioCodec)" -ForegroundColor DarkCyan
    }
    catch { # Fehlerbehandlung
        Write-Host "FEHLER: Medienanalyse fehlgeschlagen: $_" -ForegroundColor Red
        $mediaInfoout.Duration = 0
        $mediaInfoout.DurationFormatted = "00:00:00.00"
        $mediaInfoout.AudioChannels = 0
        $mediaInfoout.VideoCodec = "Fehler"
        $mediaInfoout.AudioCodec = "Fehler"
        $mediaInfoout.Resolution = "Unbekannt"
    }
    return $mediaInfoout
}
function Get-LoudnessInfo { # Analysiert die Lautheit (LUFS) einer Audiospur mittels FFmpeg 'ebur128'-Filter.
    param (
        [string]$filePath # Der Pfad zur zu analysierenden Videodatei.
    )
# Analysiert die Audiospur einer Datei mit dem FFmpeg 'ebur128'-Filter, um die Lautheit (LUFS) zu bestimmen.
    try {
        Write-Host "Starte FFmpeg zur Lautstaerkeanalyse..." -ForegroundColor Cyan
        "`n==== Starte FFmpeg zur Lautstaerkeanalyse fuer $filePath ====" | Add-Content -LiteralPath $logDatei

# Stellt die Basis-Argumente fuer die Lautheitsanalyse zusammen.
        $baseArgs = @(
            "-i", "`"$filePath`"", "-vn", "-hide_banner", "-stats", "-threads", "12",
            "-filter_complex", "[0:a:0]ebur128=metadata=1", "-f", "null", "NUL"
        )

        $ffmpegArguments = @()
# Fuegt die Hardwarebeschleunigung hinzu, außer sie wurde explizit deaktiviert (z.B. fuer AV1).
        if ($sourceInfo.NoAccel -eq $true) {
            $ffmpegArguments = $baseArgs
        } else {
            $ffmpegArguments = @("-hwaccel", "d3d11va") + $baseArgs
        }

# Fuehrt FFmpeg aus und liest die Ausgabe live, um eine Fortschrittsanzeige zu ermoeglichen.
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $ffmpegPath
        $processInfo.Arguments = $ffmpegArguments -join ' '
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        $totalFrames = [math]::Round($sourceInfo.Duration1 * $sourceInfo.FPS)
        $outputBuilder = New-Object System.Text.StringBuilder

        while (-not $process.HasExited) { # Liest die FFmpeg-Ausgabe zeilenweise
            $line = $process.StandardError.ReadLine()
            if ($null -ne $line) {
                [void]$outputBuilder.AppendLine($line)
                if ($line -like "frame=*") {
                    $progressMatch = [regex]::Match($line, "frame=\s*(\d+)\s+fps=\s*([\d\.]+)")
                    if ($progressMatch.Success) {
                        $processedFrames = [int64]$progressMatch.Groups[1].Value
                        $currentFps = [double]$progressMatch.Groups[2].Value.Replace('.', ',')

                        if ($currentFps -gt 0 -and $totalFrames -gt 0 -and $processedFrames -le $totalFrames) {
                            $remainingFrames = $totalFrames - $processedFrames
                            $remainingExecutionSeconds = $remainingFrames / $currentFps
                            $remainingTimeSpan = [TimeSpan]::FromSeconds($remainingExecutionSeconds)
                            $percentComplete = ($processedFrames / $totalFrames) * 100
                            $progressText = "Analyse-Fortschritt: {0:N2}% | Verbleibend: {1:hh\h\:mm\m\:ss\s}" -f $percentComplete, $remainingTimeSpan
                            Write-Host "`r$progressText" -NoNewline -ForegroundColor Gray
                        }
                    }
                }
            }
        }
        Write-Host "" # Zeilenumbruch nach der Fortschrittsanzeige
        $process.WaitForExit()
        $ffmpegOutput = $outputBuilder.ToString()
        return $ffmpegOutput
    }
    catch {
        Write-Host "FEHLER: Fehler beim Ausfuehren von FFmpeg: $_" -ForegroundColor Red
        "`n==== Fehler beim Ausfuehren von FFmpeg: $_ ====" | Add-Content -LiteralPath $logDatei
        return $null
    }
}
function Set-VolumeGain {# Funktion zur Anpassung der Lautstaerke mit FFmpeg
    param (
        [string]$filePath, # Pfad zur Eingabedatei
        [double]$gain, # Der anzuwendende Gain-Wert in dB
        [string]$outputFile, # Pfad fuer die Ausgabedatei
        [int]$audioChannels, # Anzahl der Audiokanaele in der Eingabedatei
        [string]$videoCodec, # Video Codec der Eingabedatei
        [bool]$interlaced, # Gibt an, ob das Video interlaced ist
        [int]$bitDepth # Bittiefe des Videos
        )
    try {
        Write-Host "Starte FFmpeg zur Lautstaerkeanpassung..." -ForegroundColor Cyan

        # Encoder bestimmen basierend auf Hardwarebeschleunigung
        $videoEncoder = "libx265" # Standard ist CPU libx265
        if ($useHardwareAccel -eq $true) {
            $videoEncoder = Get-HardwareEncoder -ffmpegPath $ffmpegPath
        }
        Write-Host "Verwende Video-Encoder: $videoEncoder" -ForegroundColor Magenta

        $ffmpegArguments = @()

# Basis-Argumente fuer FFmpeg, die fuer fast alle Operationen gelten.
        $ffmpegArguments += @(
            "-hide_banner", # Versteckt das FFmpeg-Banner fuer eine sauberere Ausgabe
            "-loglevel", "info", # 'info' wird fuer '-stats' benoetigt, um die Fortschrittsanzeige zu erhalten
            "-stats", # Erzwingt die periodische Ausgabe von Kodierungsstatistiken
            "-y", # Überschreibt vorhandene Ausgabedateien ohne Nachfrage
            "-threads", "12" # Nutzt 12 CPU-Threads fuer die Kodierung.
        )
# Hardwarebeschleunigung deaktivieren, wenn NoAccel gesetzt ist
        if ($sourceInfo.NoAccel -eq $true) {
            Write-Host "  -> Hardwarebeschleunigung (Decoding) wegen AV1 Codec deaktiviert." -ForegroundColor Cyan
            "`n====  -> Hardwarebeschleunigung (Decoding) wegen AV1 Codec deaktiviert. ===" | Add-Content -LiteralPath $logDatei
        }else {
            $ffmpegArguments += @("-hwaccel", "d3d11va")
        }
        $ffmpegArguments += @(
# Eingabedatei angeben
            "-i", "`"$($filePath)`""
        )

# Pruefen ob BitDepth != 8 → immer reencode zu HEVC 8bit
        $needsReencodeDueToBitDepth = $false
        if ($bitDepth -ne 8) {
            Write-Host "WARNUNG: BitDepth ist $bitDepth, Reencode zu HEVC 8bit erforderlich" -ForegroundColor Yellow
            "`n==== BitDepth ist $bitDepth, Reencode zu HEVC 8bit erforderlich ====" | Add-Content -LiteralPath $logDatei
        $needsReencodeDueToBitDepth = $true
        }

# Pruefen, ob es sich um eine alte AVI-Datei handelt, die eine Sonderbehandlung benoetigt
        $isAviFile = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant() -eq '.avi'

        if ($isAviFile) {
            Write-Host "AVI-Spezialbehandlung: Visuelle Verbesserung und Transkodierung zu HEVC 1080p..." -ForegroundColor Magenta
            "`n==== AVI-Spezialbehandlung: Visuelle Verbesserung und Transkodierung zu HEVC 1080p... ====" | Add-Content -LiteralPath $logDatei

# Stellt die Filterkette dynamisch zusammen, basierend darauf, ob das Material interlaced ist.
            $baseFilter = "hqdn3d=1.0:1.5:3.0:4.5,scale=1920:-2,cas=strength=0.15"
            if ($interlaced) {
                Write-Host "  -> AVI ist interlaced, wende Deinterlacing an." -ForegroundColor Cyan
                $videoFilter = "bwdif=0:-1:0," + $baseFilter
            } else {
                Write-Host "  -> AVI ist progressiv, kein Deinterlacing noetig." -ForegroundColor Cyan
                $videoFilter = $baseFilter
            }

            $baseCrfAvi = 20
            $cqpValueAvi = [math]::Round($baseCrfAvi * 1.2)
            $cqValueAvi = [math]::Round($baseCrfAvi * 1.2)

            if ($videoEncoder -eq "hevc_amf") { # AMD HEVC
                $ffmpegArguments += @(
                    "-c:v", $videoEncoder, "-quality", "quality", "-rc", "cqp",
                    "-qp_i", $cqpValueAvi, "-qp_p", $cqpValueAvi, "-qp_b", $cqpValueAvi, "-vf", $videoFilter
                )
            } elseif ($videoEncoder -eq "hevc_nvenc") { # NVIDIA HEVC
                $ffmpegArguments += @(
                    "-c:v", $videoEncoder, "-preset", "p6", "-rc", "vbr",
                    "-cq", $cqValueAvi, "-b:v", "0", "-vf", $videoFilter
                )
            } else { # CPU libx265
                $ffmpegArguments += @(
                    "-c:v", "libx265", "-pix_fmt", "yuv420p", "-preset", "medium", "-crf", $baseCrfAvi,
                    "-vf", $videoFilter,
                    "-x265-params", "log-level=warning:aq-mode=4:psy-rd=1.5:psy-rdoq=0.7:rd=3:bframes=8:ref=4:deblock=-1,-1:me=umh:subme=5:rdoq-level=1"
                )
            }
        }
# Prueft verschiedene Bedingungen, um zu entscheiden, ob eine Video-Neukodierung erforderlich ist.
        if ($sourceInfo.Force720p -or $sourceInfo.RecodeRecommended -or $needsReencodeDueToBitDepth -or ($videoCodec -ne $targetVideoCodec)) {
            Write-Host "Transcode aktiv..." -ForegroundColor Cyan

# Videofilter-Kette initialisieren
            $videoFilterChain = @()

# Framerate-Begrenzung fuer Serien
            if ($sourceInfo.IsSeries -eq $true -and $sourceInfo.FPS -gt 25) {
                Write-Host "Framerate > 25 FPS erkannt. Begrenze auf 25 FPS." -ForegroundColor Magenta
                $ffmpegArguments += @("-r", "25")
            }

# Deinterlacing falls erforderlich
            if ($sourceInfo.Interlaced) { $videoFilterChain += "bwdif=0:-1:0" }

# Skalierung auf 720p fuer Serien
            if ($sourceInfo.Force720p) { $videoFilterChain += "scale=1280:-2" }

# Filterkette an FFmpeg uebergeben, wenn Filter vorhanden sind
            if ($videoFilterChain.Count -gt 0) {
                $ffmpegArguments += @("-vf", ($videoFilterChain -join ','))
            }

# Encoder-spezifische Qualitaetseinstellungen
            $qualityValue = if ($sourceInfo.IsSeries) { $crfTargets } else { $crfTargetm }
            $cqpValue = [math]::Round($qualityValue * 1.2)
            $cqValue = [math]::Round($qualityValue * 1.2)

            if ($videoEncoder -eq "hevc_amf") {
                Write-Host "Qualitaets-Ziel (AMD CQP): $cqpValue" -ForegroundColor Cyan
            } elseif ($videoEncoder -eq "hevc_nvenc") {
                Write-Host "Qualitaets-Ziel (NVIDIA CQ): $cqValue" -ForegroundColor Cyan
            } else {
                Write-Host "Qualitaets-Ziel (CPU CRF): $qualityValue" -ForegroundColor Cyan
            }

            if ($videoEncoder -eq "hevc_amf") { # AMD
                $ffmpegArguments += @(
                    "-c:v", $videoEncoder,
                    "-quality", $amd_quality,
                    "-rc", "cqp",
                    "-qp_i", $cqpValue, "-qp_p", $cqpValue, "-qp_b", $cqpValue
                )
            } elseif ($videoEncoder -eq "hevc_nvenc") { # NVIDIA
                $ffmpegArguments += @(
                    "-c:v", $videoEncoder,
                    "-preset", $Nvidia_quality,
                    "-rc", "constqp ",
                    "-cqi", $cqValue,
                    "-qpp", "$cqValue",
                    "-qp_cb", "$cqValue",
                    "-qp_cr", "$cqValue",
                    "-b:v", "0"
                )
            } else { # CPU
                $ffmpegArguments += @(
                    "-c:v", "libx265",
                    "-pix_fmt", "yuv420p",
                    "-preset", $encoderPreset,
                    "-crf", $qualityValue,
                    "-x265-params", "log-level=warning:nr=0:aq-mode=1:frame-threads=12:qcomp=0.7",
                    "-max_muxing_queue_size", "1024"
                )
            }
        } else {
# Kopiert den Videostream 1:1, wenn keine Neukodierung erforderlich ist.
            Write-Host " Video wird kopiert (HEVC, 8 Bit und Groeße OK)" -ForegroundColor Green
            "`n==== Video wird kopiert (HEVC, 8 Bit und Groesse OK) ====" | Add-Content -LiteralPath $logDatei
            $ffmpegArguments += @("-c:v", "copy")
        }

# Entscheidet ueber die Audiokodierung basierend auf der Lautstaerkeabweichung und der Kanalanzahl.
# Nur wenn eine Lautstaerkeanpassung stattfindet, wird auch das Audio neu kodiert.
        if ([math]::Abs($gain) -gt 0.2) {
            switch ($audioChannels) {
                { $_ -gt 2 } {
                    Write-Host "[SURROUND] Audio: Surround - Transcode VBR 5 fuer hohe Surround-Qualitaet" -ForegroundColor Cyan
                    "`n==== Audio: Surround - Transcode VBR 5 fuer hohe Surround-Qualitaet ====" | Add-Content -LiteralPath $logDatei
                    $ffmpegArguments += @(
                        "-c:a", "libfdk_aac",
                        "-vbr", "5"
                    )
                }
                { $_ -eq 2 } {
                    Write-Host "[STEREO] Audio: Stereo - Transcode VBR 4 fuer exzellente Stereo-Qualitaet" -ForegroundColor Cyan
                    "`n==== Audio: Stereo - Transcode VBR 4 fuer exzellente Stereo-Qualitaet ====" | Add-Content -LiteralPath $logDatei
                    $ffmpegArguments += @(
                        "-c:a", "libfdk_aac",
                        "-vbr", "4"
                    )
                }
                default {
                    Write-Host "[MONO] Audio: Mono - Transcode High-Efficiency Profil fuer niedrige Bitraten" -ForegroundColor Cyan
                    "`n==== Audio: Mono - Transcode High-Efficiency Profil fuer niedrige Bitraten ====" | Add-Content -LiteralPath $logDatei
                    $ffmpegArguments += @(
                        "-c:a", "libfdk_aac",
                        "-profile:a", "aac_he_v2"
                    )
                }
            }
        }
        else {
            Write-Host "Audio-Gain vernachlassigbar (pm 0.2 dB) - Audio wird kopiert" -ForegroundColor Green
            "`n==== Audio-Gain vernachlassigbar (pm 0.2 dB) - Audio wird kopiert ====" | Add-Content -LiteralPath $logDatei
            $ffmpegArguments += @(
                "-c:a", "copy" # Copy audio stream if gain is negligible (±0.2 dB)
            )
        }
# Fuegt die finalen Argumente hinzu: Lautstaerkeanpassung, Untertitel kopieren und Metadaten setzen.
# Der -af Filter wird immer angewendet, auch bei Gain 0, um die Metadaten konsistent zu halten.
        $ffmpegArguments += @(
            "-af", "volume=${gain}dB",
            "-c:s", "copy", # Kopiere alle zugeordneten Untertitel
            "-metadata", "LUFS=$targetLoudness",
            "-metadata", "gained=$gain",
            "-metadata", "normalized=true",
            "-disposition:a:0", "default", # Markiere die erste ausgewaehlte Audiospur als Standard
            "`"$($outputFile)`""
        )

        Write-Host "FFmpeg-Argumente: $($ffmpegArguments -join ' ')" -ForegroundColor DarkCyan
        "`n==== FFmpeg-Argumente: $($ffmpegArguments -join ' ') ====" | Add-Content -LiteralPath $logDatei


        $firstAttemptFailed = $false
# Startet den FFmpeg-Prozess und implementiert eine Fortschrittsanzeige.
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $ffmpegPath
        $processInfo.Arguments = $ffmpegArguments -join ' '
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $errorOutputBuilder = New-Object System.Text.StringBuilder

        $process.Start() | Out-Null

# Berechnet die Gesamtzahl der Frames fuer eine robustere Fortschrittsanzeige.
        $totalFrames = [math]::Round($sourceInfo.Duration1 * $sourceInfo.FPS)

# Echtzeit-Verarbeitung der FFmpeg-Ausgabe zur Restzeitberechnung
        while (-not $process.HasExited) { # Schleife laeuft, solange der FFmpeg-Prozess aktiv ist.
            $line = $process.StandardError.ReadLine()
            if ($null -ne $line) { [void]$errorOutputBuilder.AppendLine($line) }
            if ($line -like "frame=*") {
# Extrahiere verarbeitete Frames und aktuelle Kodier-FPS
                $progressMatch = [regex]::Match($line, "frame=\s*(\d+)\s+fps=\s*([\d\.]+)")
                if ($progressMatch.Success) {
                    $processedFrames = [int64]$progressMatch.Groups[1].Value
                    $currentFps = [double]$progressMatch.Groups[2].Value.Replace('.', ',')

                    if ($currentFps -gt 0 -and $totalFrames -gt 0 -and $processedFrames -le $totalFrames) {
                        $remainingFrames = $totalFrames - $processedFrames
                        $remainingExecutionSeconds = $remainingFrames / $currentFps
                        $remainingTimeSpan = [TimeSpan]::FromSeconds($remainingExecutionSeconds)
                        $percentComplete = ($processedFrames / $totalFrames) * 100

# Stelle sicher, dass der Prozentsatz nicht ueber 100 geht
                        if ($percentComplete -gt 100) { $percentComplete = 100.0 }
                        $progressText = "Fortschritt: {0:N2}% | Verbleibend: {1:hh\h\:mm\m\:ss\s} | FPS: {2:N0}" -f $percentComplete, $remainingTimeSpan, $currentFps
                        Write-Host "`r$progressText" -NoNewline -ForegroundColor Gray
                    }
                }
            }
        }

# Sorgt fuer einen sauberen Zeilenumbruch nach der einzeiligen Fortschrittsanzeige.
        Write-Host ""

        $process.WaitForExit()
        $exitCode = $process.ExitCode

# Prueft den Exit-Code von FFmpeg, um Erfolg oder Misserfolg festzustellen.
        if ($exitCode -eq 0) {
            Write-Host "Lautstaerkeanpassung abgeschlossen fuer: $($filePath)" -ForegroundColor Green
            "`n==== Lautstaerkeanpassung abgeschlossen fuer: $($filePath) ====" | Add-Content -LiteralPath $logDatei
            return $true
        }
        else {
            # Wenn der erste Versuch fehlschlaegt und ein Hardware-Encoder verwendet wurde
            if ($videoEncoder -ne "libx265") {
                $firstAttemptFailed = $true
                Write-Host "`nFEHLER: Hardware-Encoding ($videoEncoder) fehlgeschlagen. Exit-Code: $exitCode" -ForegroundColor Red
                Write-Host "FFmpeg-Fehlerausgabe:" -ForegroundColor Red
                Write-Host ($errorOutputBuilder.ToString()) -ForegroundColor DarkRed
                "`n==== FEHLER: Hardware-Encoding ($videoEncoder) fehlgeschlagen. Exit-Code: $exitCode ====" | Add-Content -LiteralPath $logDatei
                "`n==== FFmpeg-Fehlerausgabe: $($errorOutputBuilder.ToString()) ====" | Add-Content -LiteralPath $logDatei

                Write-Host "Fehler - Versuche CPU encoding" -ForegroundColor Yellow
                "`n==== Fehler - Versuche CPU encoding ====" | Add-Content -LiteralPath $logDatei

                # Entferne die Hardware-Encoder-Argumente
                $ffmpegArguments = $ffmpegArguments | Where-Object { $_ -ne "-c:v" -and $_ -ne $videoEncoder -and $_ -ne "-quality" -and $_ -ne $amd_quality -and $_ -ne "-rc" -and $_ -ne "cqp" -and $_ -ne "-qp_i" -and $_ -ne $cqpValue -and $_ -ne "-qp_p" -and $_ -ne "-qp_b" -and $_ -ne "-preset" -and $_ -ne $Nvidia_quality -and $_ -ne "constqp " -and $_ -ne "-cqi" -and $_ -ne "-qpp" -and $_ -ne "-qp_cb" -and $_ -ne "-qp_cr" -and $_ -ne "-b:v" -and $_ -ne "0" }

                # Fuege die CPU-Encoder-Argumente an der richtigen Stelle ein (nach der Eingabedatei)
                $inputIndex = [array]::IndexOf($ffmpegArguments, "`"$($filePath)`"")
                $cpuArgs = @(
                    "-c:v", "libx265",
                    "-pix_fmt", "yuv420p",
                    "-preset", $encoderPreset,
                    "-crf", $qualityValue,
                    "-x265-params", "log-level=warning:nr=0:aq-mode=1:frame-threads=12:qcomp=0.7",
                    "-max_muxing_queue_size", "1024"
                )
                $ffmpegArguments = $ffmpegArguments[0..$inputIndex] + $cpuArgs + $ffmpegArguments[($inputIndex + 1)..$($ffmpegArguments.Length - 1)]

                # Starte den zweiten Versuch mit CPU-Encoding
                $processInfo.Arguments = $ffmpegArguments -join ' '
                $process.StartInfo = $processInfo
                $errorOutputBuilder.Clear() | Out-Null
                $process.Start() | Out-Null

                while (-not $process.HasExited) {
                    $line = $process.StandardError.ReadLine()
                    if ($null -ne $line) { [void]$errorOutputBuilder.AppendLine($line) }
                    if ($line -like "frame=*") {
                        $progressMatch = [regex]::Match($line, "frame=\s*(\d+)\s+fps=\s*([\d\.]+)")
                        if ($progressMatch.Success) {
                            $processedFrames = [int64]$progressMatch.Groups[1].Value
                            $currentFps = [double]$progressMatch.Groups[2].Value.Replace('.', ',')
                            if ($currentFps -gt 0 -and $totalFrames -gt 0 -and $processedFrames -le $totalFrames) {
                                $remainingFrames = $totalFrames - $processedFrames
                                $remainingExecutionSeconds = $remainingFrames / $currentFps
                                $remainingTimeSpan = [TimeSpan]::FromSeconds($remainingExecutionSeconds)
                                $percentComplete = ($processedFrames / $totalFrames) * 100
                                if ($percentComplete -gt 100) { $percentComplete = 100.0 }
                                $progressText = "Fortschritt (CPU): {0:N2}% | Verbleibend: {1:hh\h\:mm\m\:ss\s} | FPS: {2:N0}" -f $percentComplete, $remainingTimeSpan, $currentFps
                                Write-Host "`r$progressText" -NoNewline -ForegroundColor Gray
                            }
                        }
                    }
                }
                Write-Host ""
                $process.WaitForExit()
                $exitCode = $process.ExitCode
            }

            if ($exitCode -eq 0) {
                Write-Host "Lautstaerkeanpassung (CPU-Fallback) abgeschlossen fuer: $($filePath)" -ForegroundColor Green
                "`n==== Lautstaerkeanpassung (CPU-Fallback) abgeschlossen fuer: $($filePath) ====" | Add-Content -LiteralPath $logDatei
                return $true
            }
            else {
                Write-Host "FEHLER: FFmpeg-Prozess mit Exit-Code $exitCode beendet (auch nach CPU-Fallback)" -ForegroundColor Red
                "`n==== FEHLER: FFmpeg-Prozess mit Exit-Code $exitCode beendet (auch nach CPU-Fallback) ====" | Add-Content -LiteralPath $logDatei
                Write-Host "FFmpeg-Fehlerausgabe: $($errorOutputBuilder.ToString())" -ForegroundColor DarkRed
                "`n==== FFmpeg-Fehlerausgabe: $($errorOutputBuilder.ToString()) ====" | Add-Content -LiteralPath $logDatei
                return $false
            }
        }

    }
    catch {Write-Host "FEHLER: Fehler bei der Lautstaerkeanpassung: $_" -ForegroundColor Red "`n==== FEHLER bei der Lautstaerkeanpassung: $_ ====" | Add-Content -LiteralPath $logDatei}
    return $false
}
function Test-OutputFile {# Überpruefe die Ausgabedatei, sobald der Prozess abgeschlossen ist
    param ( # Vergleicht die erstellte Ausgabedatei mit der Quelldatei, um die erfolgreiche Konvertierung zu validieren.

        [string]$outputFile,
        [string]$sourceFile,
        [string]$logDatei,
        [object]$sourceInfo,
        [string]$targetExtension
        )
    Write-Host "Überpruefe Ausgabedatei und ggf. Quelldatei" -ForegroundColor Cyan
    "`n==== Überpruefe Ausgabedatei und ggf. Quelldatei ====" | Add-Content -LiteralPath $logDatei

# Eine kurze Pause, um sicherzustellen, dass das Betriebssystem den Dateihandle vollstaendig freigegeben hat.
    Start-Sleep -Seconds 2

    $integrityResult = Test-FileIntegrity -Outputfile $outputFile -ffmpegPath $ffmpegPath -destFolder $destFolder -file $sourceFile -logDatei $logDatei -sourceInfo $sourceInfo

    $outputInfo = Get-MediaInfo2 -filePath $outputFile -logDatei $logDatei
# Prueft, ob die Metadaten der Ausgabedatei erfolgreich gelesen werden konnten.
    if ($outputInfo.Duration -eq 0 -or $outputInfo.AudioChannels -eq 0) {
        Write-Host "  FEHLER: Konnte Mediendaten fuer die Ausgabedatei nicht korrekt extrahieren." -ForegroundColor Red
        "`n==== FEHLER: Konnte Mediendaten fuer die Ausgabedatei nicht korrekt extrahieren. ====" | Add-Content -LiteralPath $logDatei
        return $false
    }else {
        Write-Host "  Die Ausgabedatei wurde erfolgreich erfasst." -ForegroundColor Green
        "`n==== Die Ausgabedatei wurde erfolgreich erfasst. ====" | Add-Content -LiteralPath $logDatei
        Write-Host "  Quelldatei-Dauer: $($sourceInfo.DurationFormatted1) | Audiokanaele: $($sourceInfo.AudioChannels)" -ForegroundColor Blue
        Write-Host "  Ausgabedatei-Dauer: $($outputInfo.DurationFormatted) | Audiokanaele: $($outputInfo.AudioChannels)" -ForegroundColor Blue

# Ruft die Dateigroeßen in Bytes fuer einen exakten numerischen Vergleich ab.
        $sizeSourceBytes = (Get-Item -LiteralPath $sourceFile).Length
        $sizeOutputBytes = (Get-Item -LiteralPath $outputFile).Length

# Formatiert die Dateigroeßen in ein lesbares MB-Format nur fuer die Konsolenausgabe.
        $fileSizeSourceFormatted = "{0:N2} MB" -f ($sizeSourceBytes / 1MB)
        $fileSizeOutputFormatted = "{0:N2} MB" -f ($sizeOutputBytes / 1MB)

        Write-Host "  Quelldatei-Groeße: $($fileSizeSourceFormatted)" -ForegroundColor DarkCyan
        Write-Host "  Ausgabedatei-Groeße: $($fileSizeOutputFormatted)" -ForegroundColor DarkCyan

# Prueft, ob die Ausgabedatei mehr als 3 MB groeßer ist als die Quelldatei.
        if ($sizeOutputBytes -gt ($sizeSourceBytes + 3MB)) {
            $diffMB = [math]::Round(($sizeOutputBytes - $sizeSourceBytes) / 1MB, 2)
            Write-Host "  WARNUNG: Die Ausgabedatei ist $diffMB MB groeßer als die Quelldatei!" -ForegroundColor Red
            "`n==== WARNUNG: Die Ausgabedatei ist $diffMB MB groeßer als die Quelldatei! ====" | Add-Content -LiteralPath $logDatei
            return $false # Eine groeßere Datei ist normalerweise unerwuenscht.
        }
        else {
            $diffMB = [math]::Round(($sizeSourceBytes - $sizeOutputBytes) / 1MB, 2)
            Write-Host "  Die Ausgabedatei ist $diffMB MB kleiner als die Quelldatei." -ForegroundColor Green
            $diffPercent = if ($sizeSourceBytes -gt 0) { [math]::Round((($sizeSourceBytes - $sizeOutputBytes) / $sizeSourceBytes) * 100, 2) } else { 0 } # Berechnet die prozentuale Ersparnis.
            "`n==== Die Ausgabedatei ist $diffMB MB kleiner als die Quelldatei. ====" | Add-Content -LiteralPath $logDatei


            Write-Host "  Das entspricht einer Reduzierung um $diffPercent %." -ForegroundColor Green
            "`n==== Das entspricht einer Reduzierung um $diffPercent %. ====" | Add-Content -LiteralPath $logDatei
        }
    }

# Überpruefe die Laufzeit beider Dateien (mit einer kleinen Toleranz von 1 Sekunde)
    $durationDiff = [Math]::Abs($sourceInfo.Duration1 - $outputInfo.Duration)
    if ($durationDiff -gt 1) {
        Write-Host "  WARNUNG: Die Laufzeiten unterscheiden sich um $durationDiff Sekunden!" -ForegroundColor Red
        "`n==== WARNUNG: Die Laufzeiten unterscheiden sich um $durationDiff Sekunden! ====" | Add-Content -LiteralPath $logDatei
        return $false
    }else {
        Write-Host "  Die Laufzeiten stimmen ueberein." -ForegroundColor Green
        "`n==== Die Laufzeiten stimmen ueberein. ====" | Add-Content -LiteralPath $logDatei
    }
# Überpruefe die Anzahl der Audiokanaele beider Dateien
    if ($sourceInfo.AudioChannels -ne $outputInfo.AudioChannels) {
        Write-Host "  WARNUNG: Die Anzahl der Audiokanaele hat sich geaendert! (Quelle: $($sourceInfo.AudioChannels), Ausgabe: $($outputInfo.AudioChannels))" -ForegroundColor Red
        "`n==== WARNUNG: Die Anzahl der Audiokanaele hat sich geaendert! (Quelle: $($sourceInfo.AudioChannels), Ausgabe: $($outputInfo.AudioChannels)) ====" | Add-Content -LiteralPath $logDatei
        return $false
    }else {
        Write-Host "  Die Anzahl der Audiokanaele ist gleich geblieben." -ForegroundColor Green
        "`n==== Die Anzahl der Audiokanaele ist gleich geblieben. ====" | Add-Content -LiteralPath $logDatei
    }
    return $integrityResult # Gibt das Ergebnis der Integritaetspruefung zurueck.
}

function Invoke-IntegrityCheck { # Fuehrt eine FFmpeg-Integritaetspruefung fuer eine einzelne Datei durch und zeigt den Fortschritt an.
# Fuehrt eine FFmpeg-Integritaetspruefung fuer eine einzelne Datei durch und zeigt den Fortschritt an.
    param(
        [string]$FilePath,
        [string]$CheckType, # "Quelle" oder "Ausgabe" fuer die Anzeige
        [hashtable]$SourceInfo
    )

    Write-Host "Starte Integritaetspruefung fuer $CheckType-Datei: $([System.IO.Path]::GetFileName($FilePath))"

    $arguments = @(
        "-v", "error", # Nur kritische Fehler anzeigen
        "-stats",      # Aber Fortschrittsstatistiken erzwingen
        "-i", "`"$FilePath`"",
        "-f", "null",
        "-"
    )
# Hardwarebeschleunigung nur hinzufuegen, wenn sie nicht explizit fuer die Quelle deaktiviert wurde.
    if (-not $SourceInfo.NoAccel) {
        $arguments = @("-hwaccel", "d3d11va") + $arguments
    }

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $ffmpegPath
    $processInfo.Arguments = $arguments -join ' '
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null

    $totalFrames = [math]::Round($SourceInfo.Duration1 * $SourceInfo.FPS)
    $outputBuilder = New-Object System.Text.StringBuilder

    while (-not $process.HasExited) {
        $line = $process.StandardError.ReadLine()
        if ($null -ne $line) {
            [void]$outputBuilder.AppendLine($line)
            if ($line -like "frame=*") {
                $progressMatch = [regex]::Match($line, "frame=\s*(\d+)\s+fps=\s*([\d\.]+)")
                if ($progressMatch.Success) {
                    $processedFrames = [int64]$progressMatch.Groups[1].Value
                    $currentFps = [double]$progressMatch.Groups[2].Value.Replace('.', ',')

                    if ($currentFps -gt 0 -and $totalFrames -gt 0 -and $processedFrames -le $totalFrames) {
                        $percentComplete = ($processedFrames / $totalFrames) * 100
                        $progressText = "Pruefung ($CheckType): {0:N2}%" -f $percentComplete
                        Write-Host "`r$progressText" -NoNewline -ForegroundColor Gray
                    }
                }
            }
        }
    }
    Write-Host "" # Zeilenumbruch nach der Fortschrittsanzeige
    $process.WaitForExit()

    return [PSCustomObject]@{
        ExitCode    = $process.ExitCode
        ErrorOutput = $outputBuilder.ToString()
    }
}

function Test-FileIntegrity { # Überprueft die Integritaet einer Mediendatei, indem FFmpeg versucht, sie zu dekodieren. Fehler werden protokolliert.
# Überprueft die Integritaet einer Mediendatei, indem FFmpeg versucht, sie zu dekodieren. Fehler werden protokolliert.
    param (
        [Parameter(Mandatory = $true)]
        [string]$outputFile,

        [Parameter(Mandatory = $true)]
        [string]$ffmpegPath,

        [Parameter(Mandatory = $true)]
        [string]$destFolder,

        [Parameter(Mandatory = $true)]
        [string]$logDatei,
        [string]$file,
        [hashtable]$sourceInfo
    )

# Pruefung der Ausgabedatei
    $outputResult = Invoke-IntegrityCheck -FilePath $outputFile -CheckType "Ausgabe" -SourceInfo $sourceInfo
# Bereinige die Fehlerausgabe von reinen Fortschrittsanzeigen, bevor sie geprueft wird.
    $filteredErrorOutput = $outputResult.ErrorOutput -split [System.Environment]::NewLine | Where-Object { $_ -notlike "frame=*" } | Out-String
    $isOutputOk = ($outputResult.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($filteredErrorOutput)) -or ($outputResult.ErrorOutput -match "Application provided invalid, non monotonically increasing dts to muxer in stream 0")

    if ($isOutputOk) {
        Write-Host "OK: $outputFile" -ForegroundColor Green
        "`n==== OK: $outputFile ====" | Add-Content -LiteralPath $logDatei
        return $true # Wenn die Ausgabedatei OK ist, ist die Funktion erfolgreich.
    } else {
# Wenn die Ausgabedatei fehlerhaft ist, protokolliere den Fehler und pruefe die Quelldatei.
        Write-Host "FEHLER in Datei: $outputFile" -ForegroundColor Red
        Add-Content -LiteralPath $logDatei -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $outputFile - FEHLER:"
        Add-Content -LiteralPath $logDatei -Value $outputResult.ErrorOutput
        Add-Content -LiteralPath $logDatei -Value "$file wird auf fehler in der Quelle geprueft."
        Add-Content -LiteralPath $logDatei -Value "----------------------------------------"

# Pruefung der Quelldatei
        $sourceResult = Invoke-IntegrityCheck -FilePath $file -CheckType "Quelle" -SourceInfo $sourceInfo
# Bereinige auch hier die Fehlerausgabe.
        $filteredSourceErrorOutput = $sourceResult.ErrorOutput -split [System.Environment]::NewLine | Where-Object { $_ -notlike "frame=*" } | Out-String
        $isSourceOk = ($sourceResult.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($filteredSourceErrorOutput)) -or ($sourceResult.ErrorOutput -match "Application provided invalid, non monotonically increasing dts to muxer in stream 0")

        if ($isSourceOk) {
# Quelle ist OK, aber Ausgabe fehlerhaft -> Fehler im Transcoding. Ausgabedatei wird geloescht.
            Write-Host "OK: $file" -ForegroundColor Green
            "`n==== OK: $file ====" | Add-Content -LiteralPath $logDatei
            return $false # Signalisiert, dass die Ausgabedatei verworfen werden soll.
        } else {
# Quelle und Ausgabe sind fehlerhaft. Die neue Datei wird trotzdem behalten, da sie moeglicherweise besser ist.
            Write-Host "FEHLER in Datei: $file" -ForegroundColor Red
            Write-Host "$file und $outputFile haben beide fehler." -ForegroundColor Red
            Write-Host "Ersetze Quelldatei mit Ausgabedatei." -ForegroundColor green
            Add-Content -LiteralPath $logDatei -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $file - FEHLER:"
            Add-Content -LiteralPath $logDatei -Value $sourceResult.ErrorOutput
            Add-Content -LiteralPath $logDatei -Value "$file und $outputFile haben beide fehler."
            Add-Content -LiteralPath $logDatei -Value "Ersetze Quelldatei mit Ausgabedatei."
            Add-Content -LiteralPath $logDatei -Value "----------------------------------------"
            return $true # Signalisiert, dass die (fehlerhafte) Ausgabedatei die (fehlerhafte) Quelldatei ersetzen soll.
        }
    }
}
function Remove-Files { # Entfernt oder benennt Dateien basierend auf dem Integritaetstest-Ergebnis um.
    param ( # Benennt Dateien nach erfolgreicher Verarbeitung um und loescht die Quelldatei oder verwirft die fehlerhafte Ausgabedatei.
        [string]$outputFile,
        [string]$sourceFile,
        [string]$targetExtension,
        [bool]$isOutputOk
    )
    try {
        # Wenn die Ausgabedatei die Validierung bestanden hat, wird die Quelldatei ersetzt.
        if ($isOutputOk) {
            try {
                # 1. Finalen Zieldateinamen bestimmen. -LiteralPath ist wichtig fuer Sonderzeichen.
                $finalFile = [System.IO.Path]::Combine((Split-Path -LiteralPath $sourceFile), "$([System.IO.Path]::GetFileNameWithoutExtension($sourceFile))$targetExtension")

                # 2. Quelldatei explizit loeschen. -ErrorAction Stop stellt sicher, dass das Skript bei einem Fehler hier abbricht.
                Remove-Item -LiteralPath $sourceFile -Force -ErrorAction Stop

                # 3. Neue Datei an den finalen Ort verschieben/umbenennen. Move-Item ist hierfuer robuster als Rename-Item.
                Move-Item -LiteralPath $outputFile -Destination $finalFile -Force -ErrorAction Stop

                Write-Host "  Erfolg: Quelldatei geloescht und normalisierte Datei umbenannt zu $([System.IO.Path]::GetFileName($sourceFile))" -ForegroundColor Green
                "`n==== Erfolg: Quelldatei geloescht und normalisierte Datei umbenannt zu $([System.IO.Path]::GetFileName($sourceFile)) ====" | Add-Content -LiteralPath $logDatei
            }
            catch {
                Write-Host "FEHLER beim Loeschen von Dateien: $_" -ForegroundColor Red
                "`n==== FEHLER: Konnte Mediendaten fuer die Quelldatei nicht korrekt extrahieren. ====" | Add-Content -LiteralPath $logDatei
                Write-Host "  Datei: $($_.Exception.ItemName)" -ForegroundColor Red
                "`n==== Datei: $($_.Exception.ItemName) ====" | Add-Content -LiteralPath $logDatei
                Write-Host "  Fehlercode: $($_.Exception.HResult)" -ForegroundColor Red
                "`n==== Fehlercode: $($_.Exception.HResult) ====" | Add-Content -LiteralPath $logDatei
                Write-Host "  Fehlertyp: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                "`n==== Fehlertyp: $($_.Exception.GetType().FullName) ====" | Add-Content -LiteralPath $logDatei

            }
        } else {
            # Wenn die Ausgabedatei fehlerhaft ist, wird sie geloescht und die Quelldatei bleibt erhalten.
            Write-Host "  FEHLER: Test-OutputFile ist fehlgeschlagen. Test-OutputFile wird geloescht." -ForegroundColor Red
            "`n==== FEHLER: Test-OutputFile ist fehlgeschlagen. Test-OutputFile wird geloescht. ====" | Add-Content -LiteralPath $logDatei
            try {
                # Pruefen, ob die Quelldatei eine AVI ist. In diesem Fall soll die fehlerhafte Ausgabedatei nicht geloescht werden.
                $isAviFile = [System.IO.Path]::GetExtension($sourceFile).ToLowerInvariant() -eq '.avi'
                if (-not $isAviFile) {
                    Remove-Item -Path $outputFile -Force
                } else {
                    Write-Host "  INFO: Die Quelldatei ist eine AVI. Die fehlerhafte Ausgabedatei '$outputFile' wird zur Analyse beibehalten." -ForegroundColor Cyan
                    "`n==== INFO: Die Quelldatei ist eine AVI. Die fehlerhafte Ausgabedatei '$outputFile' wird zur Analyse beibehalten. ====" | Add-Content -LiteralPath $logDatei
                }
            }
            catch {
                Write-Host "FEHLER beim Loeschen von Dateien: $_" -ForegroundColor Red
                "`n==== FEHLER beim Loeschen von Dateien: $_ ====" | Add-Content -LiteralPath $logDatei
                Write-Host "  Datei: $($_.Exception.ItemName)" -ForegroundColor Red
                Write-Host "  Fehlercode: $($_.Exception.HResult)" -ForegroundColor Red
                Write-Host "  Fehlertyp: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                "`n==== FEHLERDETAILS: Datei: $($_.Exception.ItemName), Code: $($_.Exception.HResult), Typ: $($_.Exception.GetType().FullName) ====" | Add-Content -LiteralPath $logDatei
            }
        }
    }
    catch {
        Write-Host "  FEHLER bei Umbenennung/Loeschen: $_" -ForegroundColor Red
        "`n==== FEHLER bei Umbenennung/Loeschen: $_ ====" | Add-Content -LiteralPath $logDatei
    }
}

function Show-MainGui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    #region 1. Fenster-Initialisierung
    $mainForm = New-Object System.Windows.Forms.Form
    $mainForm.Text = "PowerShell Video Transcoder"
    $mainForm.Size = New-Object System.Drawing.Size(800, 600)
    $mainForm.StartPosition = 'CenterScreen'
    $mainForm.MinimumSize = New-Object System.Drawing.Size(640, 480)
    #endregion

    #region 2. Haupt-Layout-Container
    $mainTableLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainTableLayout.Dock = 'Fill'
    $mainTableLayout.ColumnCount = 1
    $mainTableLayout.RowCount = 3
    $mainTableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    $mainTableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null
    $mainTableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
    $mainForm.Controls.Add($mainTableLayout)
    #endregion

    # Zeigt das Fenster an
    [void]$mainForm.ShowDialog()
}

#endregion

#region Hauptskript
# Zeigt einen Dialog zur Auswahl des zu verarbeitenden Ordners an.
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

# Initialisiert das Array, das die Statistiken fuer die spaetere Auswertung sammelt.
$script:statistics = @()

$result = $PickFolder.ShowDialog()

if ($result -eq [Windows.Forms.DialogResult]::OK) { # Wenn der Benutzer einen Ordner ausgewaehlt hat
    $destFolder = Split-Path -Path $PickFolder.FileName
    Write-Host -Object "Ausgewaehlter Ordner: $destFolder" -ForegroundColor Green

# Sucht rekursiv nach allen relevanten Videodateien im ausgewaehlten Ordner. Die .NET-Methode ist schneller als Get-ChildItem.
    $startTime = Get-Date
    $mkvFiles = [System.IO.Directory]::EnumerateFiles($destFolder, '*.*', [System.IO.SearchOption]::AllDirectories) | Where-Object { ($extensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant()) -and ((Get-Item (Split-Path -Path $_ -Parent)).Name -ne "Fertig") } | Sort-Object
    $mkvFileCount = ($mkvFiles | Measure-Object).Count
    $endTime = Get-Date
    $duration = $endTime - $startTime
    Write-Host "Dateiscan-Zeit: $($duration.TotalSeconds) Sekunden" -ForegroundColor Yellow

# Erste Schleife: Prueft alle gefundenen Dateien, ob sie bereits normalisiert sind.
    foreach ($file in $mkvFiles) {
        Write-Host "$mkvFileCount Dateien zur Tag-Pruefung verbleibend." -ForegroundColor Green
        $mkvFileCount --
        Write-Host "Verarbeite Datei: $file" -ForegroundColor Cyan

# Überspringt Dateien, die bereits das "NORMALIZED"-Tag enthalten.
        if (Test-IsNormalized -file $file) {
            Write-Host "Datei ist bereits normalisiert. Überspringe: $($file)" -ForegroundColor DarkGray
        }
    }
# Zweite Schleife: Verarbeitet nur die Dateien, die in der ersten Schleife als "nicht normalisiert" identifiziert wurden.
    $mkvFileCount = ($script:filesnotnorm | Measure-Object).Count
    foreach ($file in $script:filesnotnorm) {
        $logBaseName = [System.IO.Path]::GetFileName($file)
        $logDatei = Join-Path -Path $destFolder -ChildPath "$($logBaseName).log"
        Write-Host "`nStarte Verarbeitung der *nicht normalisierten* Datei: $file" -ForegroundColor Cyan
        Write-Host "$mkvFileCount Dateien zur Verarbeitung verbleibend." -ForegroundColor Green
        $mkvFileCount --

# --- Start der Verarbeitung fuer nicht normalisierte Dateien ---
        try {
# Extrahiert die Metadaten der Quelldatei.
            $sourceInfo = Get-MediaInfo -filePath $file -logDatei $logDatei -ffmpegPath $ffmpegPath
            if (-not $sourceInfo) {
                throw "Konnte Mediendaten nicht extrahieren."
            }

# Fuehrt die Lautheitsanalyse durch.
            $ffmpegOutput = Get-LoudnessInfo -filePath $file
            if (!$ffmpegOutput) {
                throw "Konnte Lautstaerkeinformationen nicht extrahieren."
            }

# Extrahiert den integrierten Lautheitswert (I) aus der Analyse.
            if ($ffmpegOutput -match "I:\s*([-\d\.]+)\s*LUFS") {
                $integratedLoudness = [double]$matches[1]
                $gain = $targetLoudness - $integratedLoudness # Berechnet die notwendige Verstaerkung (Gain).

# Definiert den Pfad fuer die temporaere Ausgabedatei.
                $outputFile = [System.IO.Path]::Combine((Get-Item -LiteralPath $file).DirectoryName, "$([System.IO.Path]::GetFileNameWithoutExtension($file))_normalized$($targetExtension)")

# Fuehrt die Normalisierung nur durch, wenn die Abweichung einen Schwellenwert (hier 0.2 dB) ueberschreitet.
                if ([math]::Abs($gain) -gt 0.2) {
                    Write-Host "Passe Lautstaerke an um $gain dB" -ForegroundColor Yellow
                    "`n==== Passe Lautstaerke an um $gain dB ====" | Add-Content -LiteralPath $logDatei
                    Set-VolumeGain -filePath $file -gain $gain -outputFile $outputFile -audioChannels $sourceInfo.AudioChannels -videoCodec $sourceInfo.VideoCodec -interlaced $sourceInfo.Interlaced -bitDepth $sourceInfo.BitDepth
                }
                else {
# Wenn keine Lautstaerkeanpassung noetig ist, wird nur das Metadaten-Tag gesetzt.
                    Write-Host "Lautstaerke bereits im Zielbereich. Setze nur Metadaten." -ForegroundColor Green
                    "`n==== Lautstaerke bereits im Zielbereich. Setze nur Metadaten. ====" | Add-Content -LiteralPath $logDatei

                    $outputFile = [System.IO.Path]::Combine((Get-Item -LiteralPath $file).DirectoryName, "$([System.IO.Path]::GetFileNameWithoutExtension($file))_normalized$($targetExtension)")
# Argumente fuer einen schnellen Kopiervorgang ohne Neukodierung.
                    $ffmpegArgumentscopy = @(
                        "-hide_banner", "-loglevel", "error", "-stats", "-y", "-i", "`"$($file)`""
                    )
                    $ffmpegArgumentscopy += @(
                        "-c", "copy",
                        "-metadata", "LUFS=$targetLoudness", "-metadata", "gained=0", "-metadata", "normalized=true",
                        "`"$($outputFile)`""
                    )
                    Write-Host "FFmpeg-Argumente: $($ffmpegArgumentscopy -join ' ')" -ForegroundColor DarkCyan
                    "`n==== FFmpeg-Argumente: $($ffmpegArgumentscopy -join ' ') ====" | Add-Content -LiteralPath $logDatei
                    $copyProcess = Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegArgumentscopy -NoNewWindow -Wait -PassThru -ErrorAction Stop
# Prueft, ob der Kopiervorgang erfolgreich war.
                    if ($copyProcess.ExitCode -ne 0) {
                        throw "FFmpeg-Kopiervorgang ist mit Exit-Code $($copyProcess.ExitCode) fehlgeschlagen."
                    }
                }

# Validiert die erstellte Ausgabedatei und raeumt auf.
                $isOutputOk = Test-OutputFile -outputFile $outputFile -sourceFile $file -sourceInfo $sourceInfo -targetExtension $targetExtension -logDatei $logDatei
                Remove-Files -outputFile $outputFile -sourceFile $file -targetExtension $targetExtension -isOutputOk $isOutputOk

            }
            else {
                Write-Warning "Keine LUFS-Informationen gefunden. Überspringe Lautstaerkeanpassung."
                "`n==== WARNUNG: Keine LUFS-Informationen gefunden. Überspringe Lautstaerkeanpassung. ====" | Add-Content -LiteralPath $logDatei
            }
        }
        catch {
            Write-Error "Ein Fehler ist bei der Verarbeitung von '$file' aufgetreten: $_"
            "`n==== FEHLER bei der Verarbeitung von '$file': $_ ====" | Add-Content -LiteralPath $logDatei
        }
        finally {
            Write-Host "Verarbeitung fuer '$file' abgeschlossen." -ForegroundColor Green
            "`n==== Verarbeitung fuer '$file' abgeschlossen. ====" | Add-Content -LiteralPath $logDatei
            Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
        }
    }
# Nachbereitung: Sucht und loescht alle temporaeren "_normalized"- und ".log"-Dateien.
    Write-Host "Starte Nachbereitung: Suche und loesche temporaere Dateien..." -ForegroundColor Cyan
    $normalizedFiles = [System.IO.Directory]::EnumerateFiles($destFolder, "*_normalized*", [System.IO.SearchOption]::AllDirectories)
    foreach ($normalizedFile in $normalizedFiles) {
        try {
            Remove-Item -Path $normalizedFile -Force
            Write-Host "  Geloescht (temporaer): $normalizedFile" -ForegroundColor Green
        }
        catch {
            Write-Host "  FEHLER: Konnte temporaere Datei nicht loeschen $normalizedFile : $_" -ForegroundColor Red
        }
    }

# Gibt am Ende der gesamten Verarbeitung eine formatierte Tabelle mit den gesammelten Statistiken aus.
    Write-Host "`n--- Statistische Auswertung der Dateigroeßen ---" -ForegroundColor Yellow
    $script:statistics | Format-Table -AutoSize
# --- Ende der statistischen Auswertung ---

    $logFiles = [System.IO.Directory]::EnumerateFiles($destFolder, "*.log", [System.IO.SearchOption]::AllDirectories)
    foreach ($logFile in $logFiles) {
        try {
            Remove-Item -Path $logFile -Force
            Write-Host "  Geloescht (Log): $logFile" -ForegroundColor Green
        }
        catch {
            Write-Host "  FEHLER: Konnte Log-Datei nicht loeschen $logFile : $_" -ForegroundColor Red
        }
    }
    Write-Host "Alle Dateien verarbeitet." -ForegroundColor Green
}
else {
    Write-Host "Ordnerauswahl abgebrochen." -ForegroundColor Yellow
}

# Show-MainGui

#endregion
