# PowerShell-Skript zur Fehlerprüfung mit FFmpeg für MKV-Dateien
# Dieses Skript überprüft alle MKV-Dateien in einem ausgewählten Ordner auf Fehler.
# Es wird eine Logdatei erstellt, die alle Ergebnisse enthält.
# Autor: [Dein Name]
# Datum: [4/8/2025]
# Version: 1.0
# Hinweis: Dieses Skript ist für den persönlichen Gebrauch gedacht und sollte nicht ohne Erlaubnis weitergegeben werden.
# Verwendung: Führen Sie das Skript in PowerShell aus. Es öffnet sich ein Dialog zur Ordnerauswahl.
# Die MKV-Dateien werden dann auf Fehler überprüft und die Ergebnisse in einer Logdatei gespeichert.


# Importiere die benötigten Assemblies für Windows Forms
# Diese Zeile ist notwendig, um die Windows Forms-Funktionalität zu nutzen
# und den Ordnerauswahldialog anzuzeigen.


Add-Type -AssemblyName System.Windows.Forms

$ffmpeg = "F:\media-autobuild_suite-master\local64\bin-video\ffmpeg.exe"

$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = "Wähle den Ordner mit den MKV-Dateien"
$dialog.ShowNewFolderButton = $false

if ($dialog.ShowDialog() -eq "OK") {
    $verzeichnis = $dialog.SelectedPath
    $mkvDateien = Get-ChildItem -Path $verzeichnis -Filter *.mkv -Recurse

    if ($mkvDateien.Count -eq 0) {
        Write-Output "Keine MKV-Dateien gefunden."
        return
    }

    $logDatei = Join-Path -Path $verzeichnis -ChildPath "MKV_Überprüfung.log"
    "`n==== Überprüfung gestartet am $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" | Add-Content $logDatei

    foreach ($datei in $mkvDateien) {
        Write-Output "Überprüfe Datei: $($datei.FullName)"

        $tempFehlerDatei = [System.IO.Path]::GetTempFileName()

        # Argumente als Array korrekt übergeben
        $ffmpegArgs = @(
            "-v", "error",
            "-i", $datei.FullName,
            "-f", "null",
            "-"
        )

        # FFmpeg ausführen, Fehlerausgabe umleiten
        & $ffmpeg @ffmpegArgs 2> $tempFehlerDatei
        $exitCode = $LASTEXITCODE

        $fehlerText = Get-Content $tempFehlerDatei -Raw

        if ($exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($fehlerText)) {
            Write-Output "OK: $($datei.Name)"
            Add-Content $logDatei "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($datei.FullName) - OK"
        } else {
            Write-Output "FEHLER in Datei: $($datei.Name)"
            Add-Content $logDatei "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($datei.FullName) - FEHLER:"
            Add-Content $logDatei $fehlerText
            Add-Content $logDatei "----------------------------------------"
        }

        Remove-Item $tempFehlerDatei -Force
    }

    "`n==== Überprüfung beendet am $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====" | Add-Content $logDatei
    Write-Output "Überprüfung abgeschlossen. Ergebnisse in: $logDatei"
} else {
    Write-Output "Abgebrochen – kein Ordner ausgewählt."
}