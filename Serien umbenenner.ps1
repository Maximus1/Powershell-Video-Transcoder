#region Skript-Initialisierung
# ---------------------------------------------------------------------------------
# Skript-Initialisierung
# ---------------------------------------------------------------------------------
#
# Leert die im Skript verwendeten Variablen, um einen sauberen und vorhersagbaren Start bei jeder Ausführung zu gewährleisten.
# Das '-ErrorAction SilentlyContinue' unterdrückt Fehler, falls eine Variable beim ersten Start noch nicht existiert.
Clear-Variable -Name 'regex', 'selectedPath', 'cachedSeries', 'files', 'file', 'searchResults', 'selectedSeriesUrl', 'guideUrl', 'episodeInfo', 'baseName', 'seriesNameFromFile', 'absoluteEpisodeNumber', 'episodeTitleFromFile', 'newName' -ErrorAction SilentlyContinue
#
# Fügt die .NET-Assembly 'System.Windows.Forms' hinzu. Diese wird benötigt, um grafische Benutzeroberflächen (GUIs) wie den Ordnerauswahldialog und das Auswahlfenster für Suchergebnisse zu erstellen.
Add-Type -AssemblyName System.Windows.Forms
# Fügt die .NET-Assembly 'System.Web' hinzu. Diese stellt Hilfsprogramme für Web-Anwendungen bereit, insbesondere 'HttpUtility.UrlEncode', um Sonderzeichen und Leerzeichen in Suchbegriffen für eine URL korrekt zu kodieren.
Add-Type -AssemblyName System.Web

# Definiert den regulären Ausdruck (Regex) für die Suche nach Serien auf der Webseite 'fernsehserien.de'.
# Dieser Ausdruck sucht nach dem gesamten HTML-Block für ein einzelnes Suchergebnis.
# - '<li class="ep-hover suchergebnisse-sendung">' : Sucht den Start des Listenelements.
# - '.*?' : Passt auf beliebige Zeichen (nicht gierig), bis ...
# - '</li>' : ... das schließende Listenelement gefunden wird.
$regex = '<li class="ep-hover suchergebnisse-sendung">.*?</li>' # Definiert den regulären Ausdruck zum Finden von Suchergebnissen im HTML-Code.

# Definiert den Pfad für die benutzerdefinierten Scene-Tags.
$customTagsFile = Join-Path -Path $PSScriptRoot -ChildPath "CustomSceneTags.txt"

# Definiert die Standard-Scene-Tags.
$sceneTags = 'PROPER|REPACK|iNTERNAL|LIMITED|READ\.NFO|UNCUT|UNRATED|REMASTERED|COMPLETE|SUBBED|DUBBED' # Allgemeine Tags
$sceneTags += '|German|Ger|English|Eng|DL|ML|Multi' # Sprache
$sceneTags += '|2160p|1080p|720p|4K|UHD' # Auflösung
$sceneTags += '|BluRay|BDRip|WEB-DL|WEBRip|HDTV|DVDRip|DVD|WEB' # Quelle
$sceneTags += '|x265|h265|HEVC|x264|h264|AVC' # Video-Codec
$sceneTags += '|AAC|AC3|EAC3|DD\+|DTS|DTS-HD|TrueHD|Atmos|MP3|DolbyAtmos' # Audio-Codec
$sceneTags += '|HFR|HDR|DolbyVision|IMAX|3D|FHD|HD|SD' # Weitere Qualitäts-Tags

# Lädt benutzerdefinierte Tags aus der Datei und fügt sie hinzu.
if (Test-Path $customTagsFile) {
    $customTags = Get-Content $customTagsFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($customTags) {
        $sceneTags += '|' + ($customTags -join '|')
    }
}
#endregion

#region Helfer-Funktionen
# ---------------------------------------------------------------------------------
# Helfer-Funktionen für Suche und Auswahl
# ---------------------------------------------------------------------------------
#
# Extrahiert die URL des Vorschaubildes aus einem HTML-Block eines Suchergebnisses.
function Get-SeriesImageUrl {
    # Parameter: Der HTML-Code-Block eines einzelnen Suchergebnisses.
    param(
        [Parameter(Mandatory)]
        [string]$HtmlContent
    )
#
    # Alternative zu Regex: String-Manipulation, um die URL zu finden.
    # Dies entspricht einer "stringbetween"-Logik.
    $startMarker = 'src="'  # Der Text, der direkt vor der URL steht.
    $endMarker = '" data'   # Der Text, der direkt nach der URL steht.
#
    # 1. Finde die Startposition des 'div'-Tags, um die Suche einzugrenzen.
    $imgTagIndex = $HtmlContent.IndexOf('<div') # Sucht die Position des 'div'-Tags.
    if ($imgTagIndex -lt 0) { # Prüft, ob das 'div'-Tag gefunden wurde.
        return $null # Kein '<img'-Tag im HTML-Block gefunden.
    }
#
    # 2. Finde die Startposition von 'src="' nach dem 'img'-Tag.
    $startIndex = $HtmlContent.IndexOf($startMarker, $imgTagIndex) # Sucht die Startposition des 'src'-Attributs.
    if ($startIndex -lt 0) { # Prüft, ob 'src="' gefunden wurde.
        return $null # Kein 'src'-Attribut gefunden.
    }
#
    # Die eigentliche URL beginnt nach dem Start-Marker.
    $urlStartIndex = $startIndex + $startMarker.Length # Berechnet den Startpunkt der eigentlichen URL.
#
    # 3. Finde die Position des nächsten Anführungszeichens, das die URL beendet.
    $endIndex = $HtmlContent.IndexOf($endMarker, $urlStartIndex) # Sucht die Endposition der URL.
    if ($endIndex -lt 0) { # Prüft, ob das Ende gefunden wurde.
        return $null # Kein schließendes Anführungszeichen gefunden.
    }
#
    # 4. Extrahiere den Text zwischen den Markierungen.
    $urlLength = $endIndex - $urlStartIndex # Berechnet die Länge der URL.
    $imageUrl = $HtmlContent.Substring($urlStartIndex, $urlLength) # Extrahiert die URL aus dem String.
#
    # Gibt die bereinigte URL zurück.
    return $imageUrl.Trim() # Gibt die gefundene URL zurück und entfernt führende/nachfolgende Leerzeichen.
}
#
# Führt eine Online-Suche auf fernsehserien.de durch und gibt die Ergebnisse zurück.
function Invoke-SeriesSearch {
    param (
        [string]$SeriesName
    )
#
    # Normalisiert den Suchbegriff für die URL: Umlaute werden ersetzt (z.B. Ä -> AE) und Leerzeichen durch Bindestriche.
    $normalizedSearchName = $SeriesName -replace 'Ä', 'AE' -replace 'ä', 'ae' -replace 'Ö', 'OE' -replace 'ö', 'oe' -replace 'Ü', 'UE' -replace 'ü', 'ue' -replace 'ß', 'ss'
    $urlReadyName = $normalizedSearchName -replace ' ', '-'
#
    # Informiert den Benutzer über die Normalisierung, falls eine stattgefunden hat.
    if ($urlReadyName -ne $SeriesName) {
        Write-Host "Führe Online-Suche für '$SeriesName' (normalisiert als '$urlReadyName') durch..."
        $encodedName = $urlReadyName
    } else {
        Write-Host "Führe Online-Suche für '$SeriesName' durch..."
        $encodedName = $SeriesName
    }
#
    # Kodiert den normalisierten Namen für die Verwendung in einer URL.
    $searchUrl = "https://www.fernsehserien.de/suche/$(($encodedName))"
#
    try {
        # Führt die Web-Anfrage aus. '-UseBasicParsing' ist schneller und vermeidet Abhängigkeiten vom Internet Explorer.
        $response = Invoke-WebRequest -Uri $searchUrl -UseBasicParsing -ErrorAction Stop

        # Die finale URL nach einer möglichen Weiterleitung.
        # Dies ist die robusteste Methode, da sie direkt die finale URI aus dem Antwortobjekt liest,
        # was in allen PowerShell-Versionen konsistent funktioniert.
        $finalUrl = $response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
#
        # Fall 1: Direkter Treffer, Weiterleitung auf eine Serienseite.
        if ($finalUrl -notlike "*/suche/*") {
            Write-Host "Eindeutiger Treffer! Direkt zur Serienseite weitergeleitet: $finalUrl" -ForegroundColor Cyan
            # Da wir auf der Serienseite sind, rufen wir direkt Get-EpisodeGuideUrl auf.
            # Diese Funktion gibt die URL des Episodenführers zurück.
            $guideUrl = Get-EpisodeGuideUrl -SeriesUrl $finalUrl # Ruft die Funktion auf, um die URL des Episodenführers zu erhalten.
            if ($guideUrl) {
                # Wir geben ein spezielles Objekt zurück, das die URL des Episodenführers enthält.
                # Die aufrufende Logik kann dies erkennen und direkt verwenden.
                return [pscustomobject]@{
                    IsDirectHit     = $true
                    EpisodeGuideUrl = $guideUrl
                    SelectedSeries  = [pscustomobject]@{ Title = $SeriesName; Url = $finalUrl }
                }
            } else {
                Write-Warning "Direkter Treffer, aber kein Episodenführer-Link gefunden auf $finalUrl"
                return $null
            }
        }
        # Fall 2: Mehrere Treffer, wir sind auf einer Suchergebnisseite.
        else {
            $matches = [regex]::Matches($response.Content, $regex, "Singleline") # Sucht alle Suchergebnisse im HTML-Inhalt.
            $results = @() # Initialisiert ein leeres Array für die Ergebnisse.
            foreach ($match in $matches) {
                $block = $match.Value # Der HTML-Block eines einzelnen Treffers.
                $titleMatch = [regex]::Match($block, 'title="([^"]+)"') # Extrahiert den Titel der Serie.
                $urlMatch = [regex]::Match($block, 'href="([^"]+)"') # Extrahiert die relative URL der Serie.
                $results += [pscustomobject]@{
                    Title    = $titleMatch.Groups[1].Value # Speichert den Titel im Ergebnisobjekt.
                    Url      = "https://www.fernsehserien.de" + $urlMatch.Groups[1].Value # Baut die absolute URL zusammen.
                    ImageUrl = Get-SeriesImageUrl -HtmlContent $block # Ruft die Funktion auf, um die Bild-URL zu extrahieren.
                }
            }
#
            # --- Start: Angepasste Fallback-Logik ---
            # Wenn keine Ergebnisse gefunden wurden und der Serienname Leerzeichen enthält,
            # wird der Name schrittweise vom Ende her gekürzt und erneut gesucht.
            if ($results.Count -eq 0 -and $SeriesName -like '* *') {
                $nameParts = $SeriesName.Split(' ')
                # Beginne mit dem Namen ohne das letzte Wort und gehe rückwärts, bis nur noch das erste Wort übrig ist.
                for ($i = $nameParts.Length - 1; $i -ge 1; $i--) {
                    $shortSeriesName = $nameParts[0..($i-1)] -join ' '
                    Write-Host "Keine Treffer. Versuche Fallback-Suche mit '$shortSeriesName'..." -ForegroundColor Yellow
#                    
                    # Rufe die Funktion rekursiv mit dem kürzeren Namen auf.
                    $fallbackResult = Invoke-SeriesSearch -SeriesName $shortSeriesName
                    # Wenn die Fallback-Suche erfolgreich war (Ergebnisse gefunden), gib das Ergebnis zurück und beende die Schleife.
                    if ($null -ne $fallbackResult -and $fallbackResult.Count -gt 0) { # Prüft, ob die Fallback-Suche erfolgreich war.
                        return $fallbackResult
                    }
                }
            }

            Write-Host "Suche ergab $($results.Count) Treffer."
            return $results # Gibt die Liste der Ergebnisse für die GUI zurück.
        }
    }
    catch {
        Write-Error "Fehler bei der Web-Suche: $($_.Exception.Message)"
        return $null
    }
}
# Zeigt eine grafische Benutzeroberfläche (GUI) an, um aus mehreren Suchergebnissen die richtige Serie auszuwählen.
function Show-SeriesSelectionGui {
    param (
        [array]$SearchResults,
        [string]$SeriesName
    )
#
    $form = New-Object System.Windows.Forms.Form # Erstellt ein neues Fenster (Formular).
    $form.Text = "Suchergebnisse für '$SeriesName'" # Setzt den Titel des Fensters.
    $form.Size = New-Object System.Drawing.Size(800, 450) # Legt die Größe des Fensters fest.
    $form.StartPosition = "CenterScreen" # Positioniert das Fenster in der Mitte des Bildschirms.
#
    # Erstellt ein Label mit Anweisungen für den Benutzer.
    $label = New-Object System.Windows.Forms.Label # Erstellt ein neues Textfeld (Label).
    $label.Location = New-Object System.Drawing.Point(10, 10) # Setzt die Position des Labels.
    $label.Size = New-Object System.Drawing.Size(760, 40) # Legt die Größe des Labels fest.
    $label.Text = "Mehrere Treffer für '$SeriesName' gefunden. Bitte wählen Sie den korrekten Eintrag aus der Liste aus:" # Setzt den Anzeigetext.
    $form.Controls.Add($label) # Fügt das Label zum Formular hinzu.
#
    $listBox = New-Object System.Windows.Forms.ListBox # Erstellt eine neue Auswahlliste (ListBox).
    # Füllt die ListBox mit den Titeln der Suchergebnisse.
    $listBox.Location = New-Object System.Drawing.Point(10, 50) # Setzt die Position der ListBox.
    $listBox.Size = New-Object System.Drawing.Size(450, 300) # Legt die Größe der ListBox fest.
    $listBox.Font = New-Object System.Drawing.Font("Segoe UI", 12) # Legt die Schriftart und -größe fest.
    $SearchResults | ForEach-Object { [void]$listBox.Items.Add($_.Title) } # Fügt die Titel der Suchergebnisse zur ListBox hinzu.
    $form.Controls.Add($listBox) # Fügt die ListBox zum Formular hinzu.
#
    $pictureBox = New-Object System.Windows.Forms.PictureBox # Erstellt ein neues Bildanzeigefeld (PictureBox).
    # Konfiguriert die PictureBox, um das Vorschaubild anzuzeigen.
    $pictureBox.Location = New-Object System.Drawing.Point(470, 50) # Setzt die Position der PictureBox.
    $pictureBox.Size = New-Object System.Drawing.Size(300, 300) # Legt die Größe der PictureBox fest.
    $pictureBox.SizeMode = 'Zoom' # Stellt sicher, dass das Bild passend skaliert wird.
    $pictureBox.BorderStyle = 'FixedSingle' # Fügt einen Rahmen um die PictureBox hinzu.
    $form.Controls.Add($pictureBox) # Fügt die PictureBox zum Formular hinzu.
#
    $listBox.add_SelectedIndexChanged({ # Fügt einen Event-Handler hinzu, der bei Auswahl eines Eintrags ausgelöst wird.
        # Dieses Ereignis wird ausgelöst, wenn der Benutzer einen Eintrag in der Liste auswählt.
        if ($listBox.SelectedIndex -ge 0) { # Prüft, ob ein gültiger Eintrag ausgewählt wurde.
            $selectedItem = $SearchResults[$listBox.SelectedIndex] # Holt das ausgewählte Ergebnisobjekt.
            $imageUrl = $selectedItem.ImageUrl # Holt die Bild-URL des ausgewählten Eintrags.
            if (-not [string]::IsNullOrEmpty($imageUrl)) { # Prüft, ob eine Bild-URL vorhanden ist.
                try {
                    # Bild herunterladen und anzeigen
                    $webClient = New-Object System.Net.WebClient # Erstellt einen neuen WebClient zum Herunterladen.
                    $imageBytes = $webClient.DownloadData($imageUrl) # Lädt das Bild als Byte-Array herunter.
                    # Das Byte-Array explizit als einzelnes Argument übergeben, um das "Entpacken" durch PowerShell zu verhindern.
                    $memoryStream = New-Object System.IO.MemoryStream(,$imageBytes) # Erstellt einen Speicherstrom aus den Bild-Bytes.
                    $pictureBox.Image = [System.Drawing.Image]::FromStream($memoryStream) # Lädt das Bild aus dem Speicherstrom in die PictureBox.
                }
                catch {
                    # Bei Fehler Platzhalter oder nichts anzeigen
                    $pictureBox.Image = $null
                    Write-Warning "Konnte Bild nicht laden: $($_.Exception.Message)"
                    # Write-Warning kann hier zu einem Absturz führen. MessageBox ist sicher.
                    [System.Windows.Forms.MessageBox]::Show("Bild konnte nicht geladen werden:`n$($_.Exception.Message)", "Fehler beim Laden des Bildes", "OK", "Warning") | Out-Null
                }
            } else {
                $pictureBox.Image = $null # Wenn keine Bild-URL vorhanden ist, wird die PictureBox geleert.
            }
        }
    })
#
    # Erstellt die "OK"- und "Abbrechen"-Schaltflächen.
    $okButton = New-Object System.Windows.Forms.Button # Erstellt eine neue Schaltfläche.
    $okButton.Location = New-Object System.Drawing.Point(285, 360) # Setzt die Position der Schaltfläche.
    $okButton.Size = New-Object System.Drawing.Size(100, 30) # Legt die Größe der Schaltfläche fest.
    $okButton.Text = "OK" # Setzt den Text der Schaltfläche.
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK # Legt fest, dass diese Schaltfläche das "OK"-Ergebnis zurückgibt.
    $form.AcceptButton = $okButton # Macht diese Schaltfläche zur Standard-Schaltfläche (wird bei Enter ausgelöst).
    $form.Controls.Add($okButton) # Fügt die Schaltfläche zum Formular hinzu.
#
    $cancelButton = New-Object System.Windows.Forms.Button # Erstellt eine "Abbrechen"-Schaltfläche.
    $cancelButton.Location = New-Object System.Drawing.Point(395, 360) # Setzt die Position.
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30) # Legt die Größe fest.
    $cancelButton.Text = "Abbrechen" # Setzt den Text.
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel # Legt das "Cancel"-Ergebnis fest.
    $form.CancelButton = $cancelButton # Macht diese Schaltfläche zur Abbrechen-Schaltfläche (wird bei Escape ausgelöst).
    $form.Controls.Add($cancelButton) # Fügt die Schaltfläche zum Formular hinzu.
#
    # Zeigt das Formular als modalen Dialog an (blockiert die weitere Skriptausführung, bis das Fenster geschlossen wird).
    $result = $form.ShowDialog() # Zeigt das Fenster an und wartet auf eine Benutzereingabe.
#
    # Gibt das ausgewählte Suchergebnis zurück, wenn der Benutzer auf "OK" klickt.
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { # Prüft, ob der Benutzer "OK" geklickt hat.
        $selectedIndex = $listBox.SelectedIndex # Holt den Index des ausgewählten Eintrags.
        if ($selectedIndex -ge 0) { # Prüft, ob ein Eintrag ausgewählt wurde.
            return $SearchResults[$selectedIndex] # Gibt das entsprechende Objekt aus dem Suchergebnis-Array zurück.
        }
    }
    return $null # Gibt null zurück, wenn der Benutzer abbricht oder nichts auswählt.
}
#
# Ermittelt die URL des Episodenführers basierend auf der Haupt-URL der Serie.
function Get-EpisodeGuideUrl {
    param (
        [string]$SeriesUrl
    )

    Write-Host "Suche nach Episodenführer-Link auf Seite: $SeriesUrl"
    # Prüft, ob die übergebene URL bereits die Episodenführer-Seite ist.
    try {
        if ($SeriesUrl -like "*/episodenguide*") {
            Write-Host "Die angegebene URL ist bereits der Episodenführer." -ForegroundColor Green # Bestätigungsmeldung.
            return $SeriesUrl # Gibt die URL direkt zurück.
        }
        # Wenn es keine Episodenführer-URL ist, muss der Inhalt der Seite geladen werden,
        # um den Link zum Episodenführer zu finden.
        $response = Invoke-WebRequest -Uri $SeriesUrl -UseBasicParsing -ErrorAction Stop # Lädt den HTML-Inhalt der Serienseite.
        $guideMatch = [regex]::Match($response.Content, 'data-menu-item="episodenguide"[^>]*>.*?<a[^>]*href="([^"]+/episodenguide)"') # Sucht den Link zum Episodenführer.
        return "https://www.fernsehserien.de" + $guideMatch.Groups[1].Value # Baut die absolute URL zusammen und gibt sie zurück.
    }
    catch {
        Write-Error "Fehler beim Abrufen der Serienseite: $($_.Exception.Message)"
        return $null
    }
}

# Berechnet die Levenshtein-Distanz zwischen zwei Zeichenketten.
# Dies ist ein Maß für die Ähnlichkeit zweier Zeichenketten. Eine kleinere Zahl bedeutet eine größere Ähnlichkeit.
function Get-LevenshteinDistance {
    param(
        [string]$s,
        [string]$t
    )
    $n = $s.Length # Länge der ersten Zeichenkette.
    $m = $t.Length # Länge der zweiten Zeichenkette.
    $d = New-Object 'int[,]' ($n + 1), ($m + 1) # Erstellt eine 2D-Matrix zur Berechnung.
#
    if ($n -eq 0) { return $m } # Wenn die erste Zeichenkette leer ist, ist die Distanz die Länge der zweiten.
    if ($m -eq 0) { return $n } # Wenn die zweite Zeichenkette leer ist, ist die Distanz die Länge der ersten.
#
    for ($i = 0; $i -le $n; $i++) { $d.SetValue($i, $i, 0) } # Initialisiert die erste Spalte der Matrix.
    for ($j = 0; $j -le $m; $j++) { $d.SetValue($j, 0, $j) } # Initialisiert die erste Zeile der Matrix.
#
    for ($i = 1; $i -le $n; $i++) { # Iteriert durch die Zeichen der ersten Zeichenkette.
        for ($j = 1; $j -le $m; $j++) { # Iteriert durch die Zeichen der zweiten Zeichenkette.
            $cost = if ($t[$j - 1] -eq $s[$i - 1]) { 0 } else { 1 } # Kosten sind 0, wenn die Zeichen gleich sind, sonst 1.
            # Die [Math]::Min-Aufrufe werden getrennt, um Typenprobleme in PowerShell zu vermeiden.
            $val1 = $d.GetValue($i - 1, $j) + 1 # Kosten für das Löschen.
            $val2 = $d.GetValue($i, $j - 1) + 1 # Kosten für das Einfügen.
            $val3 = $d.GetValue($i - 1, $j - 1) + $cost # Kosten für die Ersetzung.
            $d.SetValue([Math]::Min([Math]::Min($val1, $val2), $val3), $i, $j) # Setzt den minimalen Kostenwert in die Matrix.
        }
    }
    return $d.GetValue($n, $m) # Gibt den finalen Wert in der unteren rechten Ecke der Matrix zurück.
}

# Zeigt eine GUI an, um aus mehrdeutigen Episodentreffern den korrekten auszuwählen.
function Show-EpisodeSelectionGui {
    param (
        [array]$PotentialMatches,
        [string]$FileNameTitle
    )
#
    $form = New-Object System.Windows.Forms.Form # Erstellt ein neues Fenster.
    $form.Text = "Mehrdeutige Episoden gefunden" # Setzt den Fenstertitel.
    $form.Size = New-Object System.Drawing.Size(700, 400) # Legt die Größe fest.
    $form.StartPosition = "CenterScreen" # Zentriert das Fenster.
#
    $label = New-Object System.Windows.Forms.Label # Erstellt ein Textfeld.
    $label.Location = New-Object System.Drawing.Point(10, 10) # Setzt die Position.
    $label.Size = New-Object System.Drawing.Size(660, 40) # Legt die Größe fest.
    $label.Text = "Für den Titel '$FileNameTitle' wurden mehrere mögliche Episoden gefunden. Bitte wählen Sie die korrekte aus:" # Setzt den Anzeigetext.
    $form.Controls.Add($label) # Fügt das Label zum Formular hinzu.
#
    # Erstellt eine ListView anstelle einer ListBox, um Spalten zu ermöglichen.
    $listView = New-Object System.Windows.Forms.ListView # Erstellt eine neue Listenansicht.
    $listView.Location = New-Object System.Drawing.Point(10, 50) # Setzt die Position.
    $listView.Size = New-Object System.Drawing.Size(660, 250) # Legt die Größe fest.
    $listView.Font = New-Object System.Drawing.Font("Segoe UI", 10) # Legt die Schriftart fest.
    $listView.View = [System.Windows.Forms.View]::Details # Stellt die Ansicht auf "Details" (mit Spalten).
    $listView.FullRowSelect = $true # Sorgt dafür, dass die ganze Zeile markiert wird.
    $listView.MultiSelect = $false # Erlaubt nur die Auswahl eines Eintrags.
#
    # Definiert die Spalten für die ListView.
    [void]$listView.Columns.Add("Code", 80) # Fügt die Spalte "Code" hinzu.
    [void]$listView.Columns.Add("Titel (Online)", 250) # Fügt die Spalte "Titel (Online)" hinzu.
    [void]$listView.Columns.Add("Titel (Datei)", 250) # Fügt die Spalte "Titel (Datei)" hinzu.
    [void]$listView.Columns.Add("Distanz", 60) # Fügt die Spalte "Distanz" hinzu.
#
    # Füllt die ListView mit den potenziellen Treffern.
    $PotentialMatches | ForEach-Object { # Iteriert durch jeden potenziellen Treffer.
        $distance = Get-LevenshteinDistance -s $FileNameTitle -t $_.Titel # Berechnet die Levenshtein-Distanz.
        $item = New-Object System.Windows.Forms.ListViewItem($_.Code) # Erstellt einen neuen Listeneintrag mit dem Episodencode.
        [void]$item.SubItems.Add($_.Titel) # Fügt den Online-Titel als Untereintrag hinzu.
        [void]$item.SubItems.Add($FileNameTitle) # Zeigt den Dateinamen-Titel zum direkten Vergleich an.
        [void]$item.SubItems.Add($distance) # Fügt die berechnete Distanz hinzu.
        [void]$listView.Items.Add($item) # Fügt den kompletten Eintrag zur ListView hinzu.
    }
    # Wählt den ersten Eintrag in der Liste standardmäßig aus, um die Bedienung zu beschleunigen.
    if ($listView.Items.Count -gt 0) { # Prüft, ob Einträge vorhanden sind.
        $listView.Items[0].Selected = $true # Markiert den ersten Eintrag.
        $listView.Focus() # Setzt den Fokus auf die Liste, damit man mit den Pfeiltasten navigieren kann.
    }
#
    $form.Controls.Add($listView) # Fügt die ListView zum Formular hinzu.
#
    $okButton = New-Object System.Windows.Forms.Button # Erstellt die "OK"-Schaltfläche.
    $okButton.Location = New-Object System.Drawing.Point(230, 310) # Setzt die Position.
    $okButton.Size = New-Object System.Drawing.Size(100, 30) # Legt die Größe fest.
    $okButton.Text = "OK" # Setzt den Text.
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK # Legt das "OK"-Ergebnis fest.
    $form.AcceptButton = $okButton # Macht sie zur Standard-Schaltfläche.
    $form.Controls.Add($okButton) # Fügt sie zum Formular hinzu.
#
    $cancelButton = New-Object System.Windows.Forms.Button # Erstellt die "Abbrechen"-Schaltfläche.
    $cancelButton.Location = New-Object System.Drawing.Point(340, 310) # Setzt die Position.
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30) # Legt die Größe fest.
    $cancelButton.Text = "Abbrechen" # Setzt den Text.
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel # Legt das "Cancel"-Ergebnis fest.
    $form.CancelButton = $cancelButton # Macht sie zur Abbrechen-Schaltfläche.
    $form.Controls.Add($cancelButton) # Fügt sie zum Formular hinzu.
#
    $result = $form.ShowDialog() # Zeigt das Fenster an und wartet.
#
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { # Prüft, ob "OK" geklickt wurde.
        if ($listView.SelectedItems.Count -gt 0) { # Prüft, ob ein Eintrag ausgewählt ist.
            $selectedIndex = $listView.SelectedIndices[0] # Holt den Index des ausgewählten Eintrags.
            return $PotentialMatches[$selectedIndex] # Gibt das ausgewählte Objekt zurück.
        }
    }
    return $null # Gibt null zurück, wenn abgebrochen wurde.
}
#
# Extrahiert die Informationen zu einer bestimmten Episode aus dem HTML-Inhalt des Episodenführers.
function Get-EpisodeInfo {
    param(
        [Parameter(Mandatory)]
        [string]$GuideContent,

        [Parameter(Mandatory)]
        [int]$AbsoluteEpisodeNumber,

        [Parameter(Mandatory)]
        [string]$EpisodeTitleFromFile
    )
#
    # Wenn eine negative Episodennummer übergeben wird, bedeutet das, dass wir nur nach dem Titel suchen sollen.
    $searchByTitleOnly = ($AbsoluteEpisodeNumber -lt 0) # Legt fest, ob nur nach Titel gesucht werden soll.
#
    # Sucht alle HTML-Blöcke, die eine Episode repräsentieren (eingeschlossen in '<a>'-Tags mit 'role="row"').
    $episodePattern = '<a role="row".*?</a>' # Definiert das Regex-Muster für einen Episodenblock.
    $episodes = [regex]::Matches($GuideContent, $episodePattern, 'Singleline') # Findet alle Episodenblöcke im HTML.
#
    $potentialMatches = @() # Initialisiert ein Array für passende Episoden basierend auf der Nummer.
    $allEpisodesForTitleSearch = @() # Initialisiert ein Array für alle Episoden, falls nur nach Titel gesucht wird.
#
    # Durchläuft jeden gefundenen Episodenblock.
    foreach ($ep in $episodes) { # Schleife über jeden gefundenen Episodenblock.
        $block = $ep.Value # Der HTML-Inhalt des aktuellen Blocks.
#
        # Titel
        $epTitle = $null # Initialisiert die Titel-Variable.
        if ($block -match '<span itemprop="name">([^<]+)</span>') { # Sucht nach dem Episodentitel im HTML.
            $epTitle = $matches[1].Trim() # Extrahiert und bereinigt den Titel.
        }
#
        # Staffel und Episode (z.B. 1.01 → S01E01)
        $epCode = $null # Initialisiert die Code-Variable (SxxExx).
        $st = $null # Initialisiert die Staffelnummer.
        $epNum = $null # Initialisiert die Episodennummer.
        if ($block -match '<b>(\d+)\.(\d+)</b>') { # Sucht nach dem Staffel.Episode-Code (z.B. 1.01).
            $st     = [int]$matches[1] # Extrahiert die Staffelnummer.
            $epNum  = [int]$matches[2] # Extrahiert die Episodennummer.
            $epCode = "S{0:00}E{1:00}" -f $st, $epNum # Formatiert den Code zu SxxExx.
        }
        # Fallback für Specials, bei denen die Nummer im 'title'-Attribut steht (z.B. title="0.01 ...")
        elseif ($block -match 'title="(\d+)\.(\d+)') { # Fallback-Suche für Specials.
            $st     = [int]$matches[1] # Extrahiert Staffelnummer.
            $epNum  = [int]$matches[2] # Extrahiert Episodennummer.
            $epCode = "S{0:00}E{1:00}" -f $st, $epNum # Formatiert den Code.
        }
#
        # Absolute Nummer
        $epAbs = $null # Initialisiert die absolute Episodennummer.
        # Der Regex wurde angepasst, um sowohl reguläre Folgen (...<span) als auch Specials (...</div>) zu erkennen.
        if ($block -match '<div role="cell">(\d+)(?:<span|</div>)') { # Sucht nach der absoluten Nummer.
            $epAbs = [int]$matches[1] # Extrahiert die absolute Nummer.
        }
#
        # Wenn die absolute Nummer übereinstimmt, wird der Treffer zur Liste der potenziellen Übereinstimmungen hinzugefügt.
        if (-not $searchByTitleOnly -and $epAbs -eq $AbsoluteEpisodeNumber) { # Prüft auf Übereinstimmung der absoluten Nummer.
            $potentialMatches += [PSCustomObject]@{
                Absolute = $epAbs # Speichert die absolute Nummer.
                Staffel  = $st # Speichert die Staffelnummer.
                Episode  = $epNum # Speichert die Episodennummer.
                Code     = $epCode # Speichert den SxxExx-Code.
                Titel    = $epTitle # Speichert den Titel.
            }
        }
        # Wenn nur nach Titel gesucht wird, sammeln wir alle Episoden.
        elseif ($searchByTitleOnly) { # Wenn nur nach Titel gesucht wird...
            $allEpisodesForTitleSearch += [PSCustomObject]@{
                Absolute = $epAbs # ...wird die Episode zur Liste aller Episoden hinzugefügt.
                Staffel  = $st
                Episode  = $epNum
                Code     = $epCode
                Titel    = $epTitle
            }
        }
    }
#
    # Wenn nur nach Titel gesucht wird, werden alle Episoden als potenzielle Treffer verwendet.
    if ($searchByTitleOnly) { # Wenn die Titelsuche aktiv ist...
        $potentialMatches = $allEpisodesForTitleSearch # ...werden alle Episoden als potenzielle Treffer gesetzt.
    } elseif ($potentialMatches.Count -eq 0) { # Wenn keine Treffer für die Nummer gefunden wurden...
        return $null # Kein Treffer für die Episodennummer.
    }
#
    if ($potentialMatches.Count -eq 1) { # Wenn es genau einen Treffer gibt...
        Write-Host "  -> Eindeutiger Treffer für Folge '$AbsoluteEpisodeNumber' gefunden." -ForegroundColor DarkGreen # ...wird eine Erfolgsmeldung ausgegeben.
        return $potentialMatches[0] # Nur ein Treffer, dieser wird verwendet.
    }
#
    # Wenn es mehrere Treffer gibt (z.B. reguläre Folge + Special), wird der Titel verglichen.
    if ($searchByTitleOnly) { # Wenn nur nach Titel gesucht wird...
        Write-Host "  -> Suche Episode nur anhand des Titels '$EpisodeTitleFromFile'..." -ForegroundColor Yellow # ...wird eine entsprechende Meldung ausgegeben.
    } else {
        Write-Host "  -> Mehrdeutige Treffer für Folge '$AbsoluteEpisodeNumber' gefunden. Vergleiche Titel..." -ForegroundColor Yellow # ...wird eine Meldung über die Mehrdeutigkeit ausgegeben.
    }
    $bestMatch = $null # Initialisiert die Variable für den besten Treffer.
    $lowestDistance = [int]::MaxValue # Initialisiert die geringste Distanz mit einem sehr hohen Wert.
#
    foreach ($match in $potentialMatches) { # Schleife durch alle potenziellen Treffer.
        $distance = Get-LevenshteinDistance -s $EpisodeTitleFromFile -t $match.Titel # Berechnet die Titelähnlichkeit.
        Write-Host "    - Vergleiche mit: '$($match.Titel)' (Distanz: $distance)" # Gibt den Vergleich aus.
        if ($distance -lt $lowestDistance) { # Wenn die aktuelle Distanz geringer ist als die bisher geringste...
            $lowestDistance = $distance # ...wird sie als neue geringste Distanz gespeichert.
            $bestMatch = $match # ...und der aktuelle Treffer als bester Treffer gespeichert.
        }
    }
#
    # Wenn die geringste Distanz 0 ist, haben wir einen perfekten Treffer.
    if ($lowestDistance -eq 0) { # Prüft auf einen perfekten Titel-Match.
        Write-Host "  -> Perfekter Treffer basierend auf Titelähnlichkeit gefunden: '$($bestMatch.Titel)'" -ForegroundColor DarkGreen # Erfolgsmeldung.
        return $bestMatch # Gibt den perfekten Treffer zurück.
    }
    else {
        # Wenn kein perfekter Treffer gefunden wurde, den Benutzer auswählen lassen.
        Write-Host "  -> Kein exakter Treffer. Bereite Auswahl für den Benutzer vor." -ForegroundColor Yellow # Meldung für den Benutzer.
#
        # Wenn nur nach Titel gesucht wurde, die Liste auf die 6 besten Treffer reduzieren.
        if ($searchByTitleOnly) { # Wenn nur nach Titel gesucht wurde...
            Write-Host "  -> Reduziere die Liste auf die 8 besten Treffer." # ...wird die Liste gekürzt.
            $sortedMatches = $potentialMatches | Sort-Object @{Expression={Get-LevenshteinDistance -s $_.Titel -t $EpisodeTitleFromFile}} # Sortiert die Treffer nach Titelähnlichkeit.
            $potentialMatches = $sortedMatches | Select-Object -First 8 # Wählt die besten 8 Treffer aus.
        }
#
        return Show-EpisodeSelectionGui -PotentialMatches $potentialMatches -FileNameTitle $EpisodeTitleFromFile # Zeigt die GUI zur manuellen Auswahl an.
    }
}

# Zeigt eine GUI an, um zusätzliche Scene-Tags aus den Dateinamen-Segmenten auszuwählen.
function Show-TagSelectionGui {
    param (
        [array]$FileNameParts
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Zusätzliche Tags auswählen"
    $form.Size = New-Object System.Drawing.Size(500, 400)
    $form.StartPosition = "CenterScreen"

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(460, 40)
    $label.Text = "Wähle die Segmente aus, die als neue Scene-Tags behandelt und zukünftig entfernt werden sollen:"
    $form.Controls.Add($label)

    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Location = New-Object System.Drawing.Point(10, 50)
    $checkedListBox.Size = New-Object System.Drawing.Size(460, 250)
    $checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $FileNameParts | ForEach-Object { [void]$checkedListBox.Items.Add($_, $false) }
    $form.Controls.Add($checkedListBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(130, 310)
    $okButton.Size = New-Object System.Drawing.Size(100, 30)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(240, 310)
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Text = "Abbrechen"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Gibt die ausgewählten (angekreuzten) Elemente zurück.
        return $checkedListBox.CheckedItems
    }

    return $null
}
#endregion

#region Hauptlogik
# ---------------------------------------------------------------------------------
# Hauptlogik des Skripts
# ---------------------------------------------------------------------------------
#
# Zeigt einen Dialog an, in dem der Benutzer den zu verarbeitenden Ordner auswählen kann.
#$selectedPath = "Z:\TV\Das Dschungelbuch\" # Beispiel für eine feste Pfadangabe zum Testen.
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog # Erstellt einen neuen Ordnerauswahldialog.
if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { # Zeigt den Dialog an und prüft, ob der Benutzer "OK" geklickt hat.
    $selectedPath = $folderBrowser.SelectedPath # Speichert den ausgewählten Pfad.
    Write-Host "Ausgewählter Ordner: $selectedPath" # Gibt den ausgewählten Pfad auf der Konsole aus.
} else {
    Write-Host "Abbruch. Das Programm wird beendet." # Gibt eine Abbruchmeldung aus.
    exit # Beendet das Skript.
}
#
# Initialisiert ein Hashtable als Cache, um wiederholte Suchen für dieselbe Serie zu vermeiden.
$script:cachedSeries = @{
    Name              = "" # Name der zuletzt gesuchten Serie.
    EpisodeGuideUrl   = "" # URL des Episodenführers.
    SelectedSeries    = $null # Das vom Benutzer ausgewählte Serienobjekt.
    EpisodeGuideContent = "" # Der heruntergeladene HTML-Inhalt des Episodenführers.
}
#
# Ruft alle .mkv-Dateien aus dem ausgewählten Ordner und seinen Unterordnern ab.
$files = Get-ChildItem -Path $selectedPath -Recurse -Include *.mkv, *.mp4 # Sucht nach allen .mkv- und .mp4-Dateien im ausgewählten Ordner.
#
# Beginnt die Schleife zur Verarbeitung jeder einzelnen Datei.
foreach ($file in $files) { # Startet die Schleife für jede gefundene Datei.
    # Prüfen, ob die Datei bereits das Zielformat 'Serie - SxxExx - Titel.mkv' hat.
    # Eine Datei wird übersprungen, wenn sie das SxxExx-Format hat UND der Titel danach nicht nur aus Zahlen besteht.
    # Das stellt sicher, dass Dateien wie 'Serie - S01E01 - 123.mkv' trotzdem verarbeitet werden.
    if ($file.Name -match '^.+ - S\d{2}E\d{2} - (.+)\.(mkv|mp4)$') { # Prüft, ob der Dateiname bereits dem Zielformat entspricht.
        $titlePart = $matches[1] # Extrahiert den Titelteil des Dateinamens.
        # Wenn der Titelteil NICHT nur aus Zahlen besteht, ist die Datei fertig.
        if ($titlePart -notmatch '^\d+$') { # Prüft, ob der Titel nicht nur aus Zahlen besteht.
        Write-Host "Datei '$($file.Name)' hat bereits das korrekte Format und wird übersprungen." -ForegroundColor DarkGray # Gibt eine Meldung aus.
        continue # Springt zur nächsten Datei in der Schleife.
    }
    }
#
    Write-Host "------------------------------------------------------------" # Trennlinie für die Übersichtlichkeit.
    Write-Host "Verarbeite Datei: $($file.Name)" # Gibt den Namen der aktuell verarbeiteten Datei aus.
#
    $baseName = $file.BaseName # Holt den Dateinamen ohne die Dateiendung.
    # 4. Entfernt gängige Szene-Tags. Die Suche ist case-insensitive.
    $baseNameOhneTags = $baseName -replace "\b($sceneTags)\b", '' # Entfernt alle definierten Tags aus dem Dateinamen.
#
    # 5. Entfernt den Gruppennamen (Punkt 6), der oft mit einem Bindestrich am Ende steht.
    $baseNameOhneGruppe = $baseNameOhneTags -replace '-\w+$', '' # Entfernt den Gruppennamen am Ende.
#
    # --- Start: Block zur Normalisierung von Dateinamen ---
    # 1. Normalisiert die Trennzeichen um das SxxExx-Muster herum, um eine saubere Struktur zu schaffen.
    # Dies behandelt Fälle wie "SerieS01E01Titel" oder "Serie-S01E01-Titel".
    $baseNameMitTrenner = $baseNameOhneGruppe -replace '(\S)(S\d{2}E\d{2})', '$1 - $2' -replace '(S\d{2}E\d{2})(\S)', '$1 - $2' # Fügt Trennzeichen um SxxExx ein.
#
    # 2. Ersetzt alle restlichen Punkte und Unterstriche durch Leerzeichen.
    $baseNameOhnePunkte = $baseNameMitTrenner -replace '[\._]', ' ' # Ersetzt Punkte und Unterstriche durch Leerzeichen.
#
    if ($baseNameOhnePunkte -match ' - \d{8,12}$') { # Prüft, ob am Ende eine lange numerische ID steht.
        $baseNameID = $baseNameOhnePunkte -replace ' - \d{8,12}$', '' # Entfernt diese ID.
        Write-Host "Numerische ID am Ende des Dateinamens entfernt." -ForegroundColor Magenta # Gibt eine Meldung aus.
        $baseNameOhnePunkte = $baseNameID # Aktualisiert den Dateinamen.
    }
    $baseNameOhnePunkte = $baseNameOhnePunkte -replace '\s{2,}', ' ' # Entfernt doppelte Leerzeichen.
#
    # Teilt den normalisierten Namen am Trennzeichen ' - ' auf, um die einzelnen Teile zu erhalten.
    $fileNameParts = $baseNameOhnePunkte -split ' - ' # Teilt den Namen in seine Bestandteile auf.

    # 3. Ersetzt Bindestriche, die als Trennzeichen dienen (mit Leerzeichen drumherum), durch den Standard-Trenner " - ".
    # Bindestriche innerhalb von Wörtern (z.B. "Dreifach-Date") bleiben unberührt.
    $baseNameFinal = $fileNameParts -replace '\s+-\s+', ' - ' # Normalisiert die Trennzeichen.
#
    # 4. Bereinigt mehrfache Leerzeichen, die durch die vorherigen Ersetzungen entstanden sein könnten.
    $baseNameFinal = $baseNameFinal -replace '\s{2,}', ' ' # Entfernt doppelte Leerzeichen.
    $baseNameFinal = $baseNameFinal.Trim()  # Entfernt führende und nachfolgende Leerzeichen.
    $baseNameFinal = $baseNameFinal | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } # Entfernt leere Teile.
#


    # --- NEU: GUI zur Auswahl zusätzlicher Tags ---
    $tagsToRemove = Show-TagSelectionGui -FileNameParts $baseNameFinal # Zeigt die GUI zur Tag-Auswahl an.
    if ($null -ne $tagsToRemove -and $tagsToRemove.Count -gt 0) {
        Write-Host "Folgende neue Tags werden entfernt und gespeichert: $($tagsToRemove -join ', ')" -ForegroundColor Magenta
        
        # Neue Tags zur Datei hinzufügen (ohne Duplikate)
        $existingCustomTags = if (Test-Path $customTagsFile) { Get-Content $customTagsFile } else { @() }
        $allCustomTags = ($existingCustomTags + $tagsToRemove) | Select-Object -Unique
        $allCustomTags | Out-File $customTagsFile -Encoding utf8

        # Neue Tags sofort zur aktuellen Session hinzufügen
        $global:sceneTags += '|' + ($tagsToRemove -join '|')

        # Dateinamen-Teile neu erstellen, ohne die ausgewählten Tags
        $fileNameParts = $fileNameParts | Where-Object { $_ -notin $tagsToRemove }

        # Den bereinigten Namen für die weitere Verarbeitung neu zusammensetzen
        $baseNameFinal = $fileNameParts -join ' - '
    }
#
    if ($fileNameParts.Count -lt 2) { # Prüft, ob der Name mindestens zwei Teile hat.
        Write-Warning "Dateiname '$($file.Name)' (nach Normalisierung: '$baseNameFinal') entspricht nicht dem Format 'Serie - Folge - Titel' und wird übersprungen." # Gibt eine Warnung aus.
        continue # Springt zur nächsten Datei.
    }
#
    # Extrahiert den Seriennamen und korrigiert ihn, falls er durch die Aufteilung verdoppelt wurde (z.B. "Serie - Serie").
    $seriesNameFromFile = $fileNameParts[0].Trim() # Der erste Teil ist der Serienname.
    $seriesNameParts = $seriesNameFromFile -split '-' # Teilt den Seriennamen am Bindestrich.
    if ($seriesNameParts.Count -eq 2 -and $seriesNameParts[0].Trim() -eq $seriesNameParts[1].Trim()) { # Prüft auf Verdopplung.
        $seriesNameFromFile = $seriesNameParts[0].Trim() # Korrigiert den Namen.
        Write-Host "Korrigierter Serienname: '$seriesNameFromFile'" -ForegroundColor Magenta # Gibt eine Meldung aus.
    }
#
    # Extrahiert die absolute Episodennummer und den Titel aus den restlichen Teilen des Dateinamens.
    $absoluteEpisodeNumber = $fileNameParts[1].Trim() # Der zweite Teil ist potenziell die Episodennummer.
#
    # Prüfen, ob der zweite Teil das SxxExx-Format hat.
    if ($absoluteEpisodeNumber -match '^S\d+E\d+' -and $baseNameFinal.Count -gt 2) { # Wenn der zweite Teil SxxExx ist...
        # Wenn ja, wird die absolute Folgennummer aus dem dritten Teil extrahiert.
        $absoluteEpisodeNumber = $baseNameFinal[1].Trim() # ...bleibt er die Episodennummer (obwohl es ein Code ist, wird es hier so behandelt).
        $episodeTitleFromFile  = $baseNameFinal[2..($baseNameFinal.Count - 1)] -join ' - ' # Der Rest ist der Titel.
    } elseif ($absoluteEpisodeNumber -match '^S\d+E\d+') { # Wenn der zweite Teil SxxExx ist, aber nichts mehr folgt...
        # Wenn es das SxxExx-Format hat, aber keine weitere Nummer folgt, überspringen.
        Write-Host "Datei '$($file.Name)' scheint bereits im korrekten SxxExx-Format zu sein und wird übersprungen." -ForegroundColor Green # ...wird die Datei übersprungen.
        try {
            Rename-Item -Path $file.FullName -NewName "$baseNameFinal.$($file.Extension)" -ErrorAction Stop # Benennt die Datei um.
            }
        catch {
            Write-Error "Fehler beim Umbenennen der Datei: $($_.Exception.Message)" # Gibt einen Fehler aus, falls das Umbenennen fehlschlägt.
        }
        continue # Nächste Datei.
    } else {
        # Der Rest des Namens ist der Titel.
        $episodeTitleFromFile  = $fileNameParts[2..($fileNameParts.Count - 1)] -join ' - ' # Ansonsten ist der Rest der Titel.
    }
#
    # Prüft, ob der extrahierte Teil eine Zahl ist.
    if ($absoluteEpisodeNumber -notmatch '^\d+$') { # Wenn die extrahierte "Nummer" keine Zahl ist...
        # Wenn keine Zahl gefunden wurde, wird der Teil als Titel interpretiert.
        # Die Episodennummer wird auf -1 gesetzt, um eine reine Titelsuche auszulösen.
        Write-Host "Keine Folgennummer im Namen gefunden. Suche wird nur nach Titel durchgeführt." -ForegroundColor Magenta # ...wird eine Meldung ausgegeben.
        $episodeTitleFromFile = ($fileNameParts[1..($fileNameParts.Count - 1)] -join ' - ').Trim() # Der gesamte Rest wird zum Titel.
        $absoluteEpisodeNumber = -1 # Setzt die Nummer auf -1, um die Titelsuche zu signalisieren.
    }
#
    # Bereinigt den Titel, um sicherzustellen, dass keine SxxExx-Muster oder führende Trennzeichen mehr enthalten sind, bevor die Distanz berechnet wird.
    $episodeTitleFromFile = ($episodeTitleFromFile -replace 'S\d{2}E\d{2}', '' -replace '^\s*-\s*', '').Trim() # Bereinigt den extrahierten Titel.
#
    Write-Host "Gefunden: Serie '$seriesNameFromFile', Folge '$absoluteEpisodeNumber', Titel '$episodeTitleFromFile'" # Gibt die extrahierten Informationen aus.
#
    # Prüft, ob die aktuell verarbeitete Serie eine andere ist als die zuvor verarbeitete.
    if ($script:cachedSeries.Name -ne $seriesNameFromFile) { # Wenn sich der Serienname geändert hat...
        # Cache für die neue Serie zurücksetzen
        # Wenn es eine neue Serie ist, wird eine neue Online-Suche gestartet.
        Write-Host "Neue Serie erkannt: '$seriesNameFromFile'. Suche nach Episodenführer..." -ForegroundColor Yellow # ...wird eine neue Suche gestartet.
#
        $searchResults = Invoke-SeriesSearch -SeriesName $seriesNameFromFile -regex $regex # Führt die Online-Suche durch.
#
        # --- Start: Angepasste Verarbeitung der Suchergebnisse ---
        if ($null -eq $searchResults -or $searchResults.Count -eq 0) { # Wenn keine Ergebnisse gefunden wurden...
            Write-Warning "Keine Suchergebnisse für '$seriesNameFromFile' gefunden." # ...wird eine Warnung ausgegeben.
            continue # ...und die nächste Datei verarbeitet.
        }
#
        # Fall 1: Direkter Treffer wurde von Invoke-SeriesSearch zurückgegeben
        if ($searchResults.PSObject.Properties['IsDirectHit'] -and $searchResults.IsDirectHit) { # Prüft, ob es ein direkter Treffer war.
            Write-Host "Direkter Treffer wird verarbeitet." -ForegroundColor Cyan # Meldung für den Benutzer.
            $script:cachedSeries.Name = $seriesNameFromFile # Speichert den Seriennamen im Cache.
            $script:cachedSeries.SelectedSeries = $searchResults.SelectedSeries # Speichert das Serienobjekt im Cache.
            $script:cachedSeries.EpisodeGuideUrl = $searchResults.EpisodeGuideUrl # Speichert die Episodenführer-URL im Cache.
            $script:cachedSeries.EpisodeGuideContent = "" # Leert den Inhalts-Cache, da er neu geladen werden muss.
        }
        # Fall 2: Liste von Suchergebnissen wurde zurückgegeben
        else {
            if ($searchResults.Count -eq 1) { # Wenn es genau ein Suchergebnis gibt...
                Write-Host "Genau ein Suchergebnis gefunden, wird automatisch verwendet." # ...wird dieses automatisch verwendet.
                $script:cachedSeries.SelectedSeries = $searchResults[0] # Speichert das Ergebnis im Cache.
            } else {
                # Bei mehreren Ergebnissen wird die GUI zur Auswahl angezeigt.
                $script:cachedSeries.SelectedSeries = Show-SeriesSelectionGui -SearchResults $searchResults -SeriesName $seriesNameFromFile # Zeigt die Auswahl-GUI an.
            }
#
            if ($null -ne $script:cachedSeries.SelectedSeries) { # Wenn eine Serie ausgewählt wurde...
                $guideUrl = Get-EpisodeGuideUrl -SeriesUrl $script:cachedSeries.SelectedSeries.Url # ...wird die Episodenführer-URL gesucht.
                if ($guideUrl) { # Wenn eine URL gefunden wurde...
                    $script:cachedSeries.Name = $seriesNameFromFile # ...wird der Cache mit den neuen Informationen aktualisiert.
                    $script:cachedSeries.EpisodeGuideUrl = $guideUrl
                    $script:cachedSeries.EpisodeGuideContent = ""
                }
            }
        }
    }
    # Wenn die Serie bereits bekannt ist, werden die Informationen aus dem Cache verwendet.
    else {
        Write-Host "Serie '$seriesNameFromFile' ist bereits bekannt. Verwende gespeicherte Informationen." -ForegroundColor Cyan # Meldung, dass Cache verwendet wird.
    }
#
    # Prüft, ob eine gültige Episodenführer-URL vorhanden ist.
    if (-not [string]::IsNullOrEmpty($script:cachedSeries.EpisodeGuideUrl)) { # Wenn eine Episodenführer-URL vorhanden ist...
        # Lädt den Inhalt des Episodenführers, falls er noch nicht im Cache ist.
        if ([string]::IsNullOrEmpty($script:cachedSeries.EpisodeGuideContent)) { # ...und der Inhalt noch nicht geladen wurde...
            try {
                Write-Host "Lade Inhalt von Episodenführer: $($script:cachedSeries.EpisodeGuideUrl)" # ...wird der Inhalt jetzt heruntergeladen.
                $script:cachedSeries.EpisodeGuideContent = (Invoke-WebRequest -Uri $script:cachedSeries.EpisodeGuideUrl -UseBasicParsing -ErrorAction Stop).Content # Führt den Download durch.
            }
            catch {
                Write-Error "Fehler beim Herunterladen des Episodenführers: $($_.Exception.Message)" # Gibt einen Fehler aus, falls der Download fehlschlägt.
                continue # Springt zur nächsten Datei.
            }
        }
        # Ruft die spezifischen Informationen für die aktuelle Episode ab.
        $episodeInfo = Get-EpisodeInfo -GuideContent $script:cachedSeries.EpisodeGuideContent -AbsoluteEpisodeNumber $absoluteEpisodeNumber -EpisodeTitleFromFile $episodeTitleFromFile # Sucht die Episodeninformationen.
    }
    else {
        Write-Warning "Kein Episodenführer für diese Serie verfügbar. Datei wird übersprungen." -ForegroundColor Red # Gibt eine Warnung aus, wenn kein Episodenführer gefunden wurde.
        continue # Springt zur nächsten Datei.
    }
#
    # Wenn Episodeninformationen gefunden wurden, wird der neue Dateiname erstellt.
    if ($null -ne $episodeInfo) { # Wenn Episodeninformationen gefunden wurden...
        # Prüfen, ob ein gültiger Episodencode (SxxExx) gefunden wurde.
        if ([string]::IsNullOrEmpty($episodeInfo.Code)) { # ...aber kein SxxExx-Code...
            Write-Warning "Konnte keinen SxxExx-Code für die gefundene Episode '$($episodeInfo.Titel)' erstellen. Datei wird übersprungen." # ...wird eine Warnung ausgegeben.
            continue # ...und die Datei übersprungen.
        }
#
        # Prüft, ob der online gefundene Serienname vom Namen in der Datei abweicht, und verwendet den präziseren Online-Namen.
        $finalSeriesName = $seriesNameFromFile # Verwendet standardmäßig den Namen aus der Datei.
        $onlineSeriesName = $script:cachedSeries.SelectedSeries.Title # Holt den Namen aus der Online-Suche.
        if (-not [string]::IsNullOrEmpty($onlineSeriesName) -and ($onlineSeriesName -ne $finalSeriesName)) { # Wenn der Online-Name existiert und abweicht...
            Write-Host "Passe Seriennamen an: '$finalSeriesName' -> '$onlineSeriesName'" -ForegroundColor Magenta # ...wird eine Anpassungsmeldung ausgegeben.
            $finalSeriesName = $onlineSeriesName # ...und der Online-Name verwendet.
        }
#
        $sanitizedTitle = $episodeInfo.Titel -replace '[\\/:*?"<>|]', '' # Entfernt ungültige Zeichen aus dem Episodentitel.
        # Setzt den neuen Namen nach dem Schema "Serie - SxxExx - Titel.ext" zusammen.
        $newName = "{0} - {1} - {2}{3}" -f $finalSeriesName, $episodeInfo.Code, $sanitizedTitle, $file.Extension # Baut den neuen Dateinamen zusammen.
        Write-Host "Neuer Dateiname: $newName" -ForegroundColor Green # Gibt den neuen Dateinamen aus.
    }
    else {
        Write-Warning "Keine Episoden-Information für Folge '$absoluteEpisodeNumber' von '$seriesNameFromFile' gefunden. Datei wird übersprungen." # Gibt eine Warnung aus, wenn keine Episode gefunden wurde.
        continue # Springt zur nächsten Datei.
    }
    # Versucht, die Datei umzubenennen.
    try {
        Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop # Benennt die Datei um.
    }
    catch {
        Write-Error "Fehler beim Umbenennen der Datei: $($_.Exception.Message)" # Gibt einen Fehler aus, falls das Umbenennen fehlschlägt.
    }
}
#endregion
