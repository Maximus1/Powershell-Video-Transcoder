# ---------------------------------------------------------------------------------
# Serien Umbenenner Tool
# ---------------------------------------------------------------------------------
# Dieses Skript automatisiert das Umbenennen von Serien-Dateien durch Online-Abgleich.
#
# Hauptfunktionen:
# - Sucht automatisch nach Serieninformationen auf fernsehserien.de
# - Erkennt Episoden-Nummern und Titel aus Dateinamen
# - Bietet eine grafische Benutzeroberfläche zur Auswahl bei mehreren Treffern
# - Unterstützt Scene-Tags und bereinigt Dateinamen von unnötigem Ballast
# - Ermöglicht Massenumbenennung ganzer Ordnerstrukturen
# ---------------------------------------------------------------------------------

#region Skript-Initialisierung
# ---------------------------------------------------------------------------------
# Skript-Initialisierung
# ---------------------------------------------------------------------------------
#
# Leert die im Skript verwendeten Variablen, um einen sauberen und vorhersagbaren Start bei jeder Ausführung zu gewährleisten.
# Das '-ErrorAction SilentlyContinue' unterdrückt Fehler, falls eine Variable beim ersten Start noch nicht existiert.
Clear-Variable -Name 'regex', 'selectedPath', 'cachedSeries', 'files', 'file', 'searchResults', 'selectedSeriesUrl', 'guideUrl', 'episodeInfo', 'baseName', 'seriesNameFromFile', 'absoluteEpisodeNumber', 'episodeTitleFromFile', 'newName', 'retryFiles', 'approvedHiddenCodePattern' -ErrorAction SilentlyContinue
#
# Fügt die .NET-Assembly 'System.Windows.Forms' hinzu. Diese wird benötigt, um grafische Benutzeroberflächen (GUIs) wie den Ordnerauswahldialog und das Auswahlfenster für Suchergebnisse zu erstellen.
Add-Type -AssemblyName System.Windows.Forms
# Fügt die .NET-Assembly 'System.Web' hinzu. Diese stellt Hilfsprogramme für Web-Anwendungen bereit, insbesondere 'HttpUtility.UrlEncode', um Sonderzeichen und Leerzeichen in Suchbegriffen für eine URL korrekt zu kodieren.
Add-Type -AssemblyName System.Web

# Fügt eine C#-Klasse hinzu, um die Sortierung der ListView-Spalten zu ermöglichen (Text und Zahlen).
$code = @"
using System;
using System.Collections;
using System.Windows.Forms;

public class EpisodeSorterComparerV2 : IComparer
{
    public int Column { get; set; }
    public SortOrder Order { get; set; }

    public EpisodeSorterComparerV2()
    {
        Column = 0;
        Order = SortOrder.Ascending;
    }

    public int Compare(object x, object y)
    {
        ListViewItem itemX = x as ListViewItem;
        ListViewItem itemY = y as ListViewItem;

        // Hauptvergleich auf der gewählten Spalte
        int result = CompareItems(itemX, itemY, Column);

        // Sekundäre Sortierung: Wenn gleich, dann sortiere nach Code (Spalte 0)
        if (result == 0 && Column != 0)
        {
            result = CompareItems(itemX, itemY, 0);
        }

        if (Order == SortOrder.Descending)
        {
            result = -result;
        }

        return result;
    }

    private int CompareItems(ListViewItem itemX, ListViewItem itemY, int colIndex)
    {
        string textX = itemX.SubItems.Count > colIndex ? itemX.SubItems[colIndex].Text : "";
        string textY = itemY.SubItems.Count > colIndex ? itemY.SubItems[colIndex].Text : "";

        double numX, numY;
        if (double.TryParse(textX, out numX) && double.TryParse(textY, out numY))
        {
            return numX.CompareTo(numY);
        }
        else
        {
            return String.Compare(textX, textY);
        }
    }
}
"@
# Verhindert Fehler, falls der Typ in der aktuellen Session bereits existiert
try { Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms -ErrorAction Stop } catch {}


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
    $searchUrl = "https://www.fernsehserien.de/suche/$($($encodedName))"
#
    try {
        # Führt die Web-Anfrage aus. '-UseBasicParsing' ist schneller und vermeidet Abhängigkeiten vom Internet Explorer.
        $response = Invoke-WebRequest -Uri $searchUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

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
            $regexMatches = [regex]::Matches($response.Content, $regex, "Singleline") # Sucht alle Suchergebnisse im HTML-Inhalt.
            $results = @() # Initialisiert ein leeres Array für die Ergebnisse.
            foreach ($match in $regexMatches) {
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
    $listBox.add_SelectedIndexChanged({
        # Dieses Ereignis wird ausgelöst, wenn der Benutzer einen Eintrag in der Liste auswählt.
        if ($listBox.SelectedIndex -ge 0) { # Prüft, ob ein gültiger Eintrag ausgewählt wurde.
            $selectedItem = $SearchResults[$listBox.SelectedIndex] # Holt das ausgewählte Ergebnisobjekt.
            $imageUrl = $selectedItem.ImageUrl # Holt die Bild-URL des ausgewählten Eintrags.
            if (-not [string]::IsNullOrEmpty($imageUrl)) { # Prüft, ob eine Bild-URL vorhanden ist.
                try {
                    # Bild herunterladen und anzeigen
                    $webClient = New-Object System.Net.WebClient # Erstellt einen neuen WebClient zum Herunterladen.
                    $imageBytes = $webClient.DownloadData($imageUrl) # Lädt das Bild als Byte-Array herunter.
                    if ($imageBytes -and $imageBytes.Length -gt 0) {
                        # Das Byte-Array explizit als einzelnes Argument übergeben, um das "Entpacken" durch PowerShell zu verhindern.
                        $memoryStream = New-Object System.IO.MemoryStream(,$imageBytes) # Erstellt einen Speicherstrom aus den Bild-Bytes.
                        $pictureBox.Image = [System.Drawing.Image]::FromStream($memoryStream) # Lädt das Bild aus dem Speicherstrom in die PictureBox.
                    }
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
        $response = Invoke-WebRequest -Uri $SeriesUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop # Lädt den HTML-Inhalt der Serienseite.
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
    
    # --- NEU: Sortierung aktivieren ---
    $sorter = New-Object EpisodeSorterComparerV2 # Erstellt den benutzerdefinierten Sorter
    $listView.ListViewItemSorter = $sorter # Weist ihn der ListView zu
    
    # Event-Handler für Spaltenklick
    $listView.add_ColumnClick({
        param($sender, $e)
        
        # Prüfen, ob die gleiche Spalte erneut geklickt wurde
        if ($sender.ListViewItemSorter.Column -eq $e.Column) {
            # Sortierreihenfolge umkehren
            if ($sender.ListViewItemSorter.Order -eq [System.Windows.Forms.SortOrder]::Ascending) {
                $sender.ListViewItemSorter.Order = [System.Windows.Forms.SortOrder]::Descending
            } else {
                $sender.ListViewItemSorter.Order = [System.Windows.Forms.SortOrder]::Ascending
            }
        } else {
            # Neue Spalte: Standardmäßig aufsteigend sortieren
            $sender.ListViewItemSorter.Column = $e.Column
            $sender.ListViewItemSorter.Order = [System.Windows.Forms.SortOrder]::Ascending
        }
        $sender.Sort() # Sortierung ausführen
    })
    # ----------------------------------

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
        $item.Tag = $_ # Speichert das Episoden-Objekt direkt im Item (WICHTIG für Sortierung!)
        [void]$listView.Items.Add($item) # Fügt den kompletten Eintrag zur ListView hinzu.
    }

    # Initiale Sortierung nach Distanz (Spalte 3)
    $sorter.Column = 3
    $sorter.Order = [System.Windows.Forms.SortOrder]::Ascending
    $listView.Sort()

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
            return $listView.SelectedItems[0].Tag # Gibt das im Tag gespeicherte Objekt zurück (korrekt auch nach Sortierung).
        }
    }
    return $null # Gibt null zurück, wenn abgebrochen wurde.
}
#
# Extrahiert alle Episoden aus dem HTML-Inhalt und gibt sie als strukturierte Liste zurück.
function Parse-EpisodeGuide {
    param (
        [string]$GuideContent
    )
    # Sucht alle HTML-Blöcke, die eine Episode repräsentieren (eingeschlossen in '<a>'-Tags mit 'role="row"').
    $episodePattern = '<a role="row".*?</a>' # Definiert das Regex-Muster für einen Episodenblock.
    $episodes = [regex]::Matches($GuideContent, $episodePattern, 'Singleline') # Findet alle Episodenblöcke im HTML.
    
    $parsedList = @()
    
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
        $parsedList += [PSCustomObject]@{ 
            Absolute = $epAbs # Speichert die absolute Nummer.
            Staffel  = $st # Speichert die Staffelnummer.
            Episode  = $epNum # Speichert die Episodennummer.
            Code     = $epCode # Speichert den SxxExx-Code.
            Titel    = $epTitle # Speichert den Titel.
        }
    }
    return $parsedList
}

# Extrahiert die Informationen zu einer bestimmten Episode aus der vorab geparsten Episodenliste.
function Get-EpisodeInfo {
    param(
        [Parameter(Mandatory)]
        [array]$EpisodeList,

        [Parameter(Mandatory=$false)]
        [int]$AbsoluteEpisodeNumber = -1,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$EpisodeTitleFromFile,

        [Parameter(Mandatory=$false)]
        [string]$SeasonEpisodeCode,

        [switch]$ShowAllMatches # NEU: Wenn gesetzt, werden alle Treffer angezeigt, nicht nur die besten 8.
    )
#
    # Wenn eine negative Episodennummer übergeben wird und kein Code vorhanden ist, bedeutet das, dass wir nur nach dem Titel suchen sollen.
    $searchByTitleOnly = ($AbsoluteEpisodeNumber -lt 0 -and [string]::IsNullOrEmpty($SeasonEpisodeCode))
    
    $potentialMatches = @()
    
    if ($searchByTitleOnly) {
        $potentialMatches = $EpisodeList
    } else {
        if ($AbsoluteEpisodeNumber -ge 0) {
            $potentialMatches = $EpisodeList | Where-Object { $_.Absolute -eq $AbsoluteEpisodeNumber }
        } elseif (-not [string]::IsNullOrEmpty($SeasonEpisodeCode)) {
            $potentialMatches = $EpisodeList | Where-Object { $_.Code -eq $SeasonEpisodeCode }
        }
    }

    if ($potentialMatches.Count -eq 0) { # Wenn keine Treffer für die Nummer gefunden wurden...
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
    $matchesWithDistance = @() # Temporäre Liste für Ergebnisse inkl. berechneter Distanz.
#
    foreach ($match in $potentialMatches) { # Schleife durch alle potenziellen Treffer.
        # Überspringe leere Titel, um unnötige Berechnungen zu vermeiden.
        if ([string]::IsNullOrWhiteSpace($match.Titel)) {
            continue
        }

        $distance = Get-LevenshteinDistance -s $EpisodeTitleFromFile -t $match.Titel # Berechnet die Titelähnlichkeit.
        # Write-Host "    - Vergleiche mit: '$($match.Titel)' (Distanz: $distance)" # Entfernt für Performance.
        
        # Speichert das Match und die Distanz, um späteres Neuberechnen beim Sortieren zu vermeiden.
        $matchesWithDistance += [PSCustomObject]@{ 
            Match    = $match
            Distance = $distance
        }

        if ($distance -lt $lowestDistance) { # Wenn die aktuelle Distanz geringer ist als die bisher geringste...
            $lowestDistance = $distance # ...wird sie als neue geringste Distanz gespeichert.
            $bestMatch = $match # ...und der aktuelle Treffer als bester Treffer gespeichert.
        }
    }
    
    if ($bestMatch) {
         Write-Host "    -> Bester Kandidat bisher: '$($bestMatch.Titel)' (Distanz: $lowestDistance)" -ForegroundColor Gray
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
        # Wenn nur nach Titel gesucht wurde, die Liste auf die 8 besten Treffer reduzieren.
        # Dies geschieht NICHT, wenn -ShowAllMatches gesetzt ist.
        if ($searchByTitleOnly -and -not $ShowAllMatches) { # NEU: Prüfung auf ShowAllMatches
            Write-Host "  -> Reduziere die Liste auf die 8 besten Treffer."
            # Sortiert basierend auf der bereits berechneten Distanz (viel schneller).
            $sortedMatches = $matchesWithDistance | Sort-Object Distance 
            # Extrahiere die originalen Match-Objekte und nimmt die besten 8.
            $potentialMatches = $sortedMatches | Select-Object -First 8 | ForEach-Object { $_.Match }
        }
        elseif ($ShowAllMatches) {
            Write-Host "  -> Zeige ALLE Treffer an (erweiterte Suche)." -ForegroundColor Cyan
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

# Speichert die Serieninformationen und Episodenliste in einer lokalen Textdatei.
function Save-LocalSeriesInfo {
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$SeriesName,
        [string]$GuideUrl,
        [array]$Episodes
    )

    try {
        $content = @()
        $content += "SeriesName=$SeriesName"
        $content += "GuideUrl=$GuideUrl"
        $content += "[EPISODES]"
        
        foreach ($ep in $Episodes) {
            # Format: Code|Absolute|Staffel|Episode|Titel
            # Wir verwenden | als Trennzeichen, da es in Dateinamen/Titeln selten vorkommt (und dort bereinigt wird).
            $line = "{0}|{1}|{2}|{3}|{4}" -f $ep.Code, $ep.Absolute, $ep.Staffel, $ep.Episode, $ep.Titel
            $content += $line
        }
        
        $content | Out-File -FilePath $Path -Encoding utf8 -Force
        Write-Host "Serieninformationen wurden in '$Path' gespeichert." -ForegroundColor Green
    }
    catch {
        Write-Warning "Konnte Serieninformationen nicht speichern: $($_.Exception.Message)"
    }
}

# Liest die lokalen Serieninformationen aus der Textdatei.
function Get-LocalSeriesInfo {
    param (
        [string]$Path,
        [switch]$IncludeUsed
    )
    
    if (-not (Test-Path $Path)) { 
        Write-Host "Keine lokale Serieninfo-Datei gefunden." -ForegroundColor DarkGray
        return $null 
    }
    
    Write-Host "Lese lokale Serieninformationen aus '$Path'..." -ForegroundColor Cyan
    $content = Get-Content $Path -Encoding utf8
    $seriesName = ""
    $guideUrl = ""
    $episodes = @()
    $inEpisodesSection = $false
    
    foreach ($line in $content) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        if ($line -match "^SeriesName=(.*)") { $seriesName = $matches[1].Trim(); continue }
        if ($line -match "^GuideUrl=(.*)") { $guideUrl = $matches[1].Trim(); continue }
        if ($line -eq "[EPISODES]") { $inEpisodesSection = $true; continue }
        
        if ($inEpisodesSection) {
            $isUsed = $line.StartsWith("*")
            $cleanLine = $line.TrimStart("*")
            
            if ($isUsed -and -not $IncludeUsed) { continue }
            
            $parts = $cleanLine -split '\|'
            if ($parts.Count -ge 5) {
                $episodes += [PSCustomObject]@{
                    Code     = $parts[0]
                    Absolute = if ($parts[1] -ne "") { [int]$parts[1] } else { $null }
                    Staffel  = [int]$parts[2]
                    Episode  = [int]$parts[3]
                    Titel    = $parts[4]
                    IsUsed   = $isUsed
                }
            }
        }
    }
    
    if ($seriesName -ne "") {
        return [PSCustomObject]@{
            SeriesName = $seriesName
            GuideUrl   = $guideUrl
            Episodes   = $episodes
        }
    }
    return $null
}

# Markiert eine Episode in der lokalen Datei als verwendet (fügt * hinzu).
function Update-LocalSeriesInfo {
    param (
        [string]$Path,
        [string]$Code,
        [string]$Title
    )
    
    if (-not (Test-Path $Path)) { return }
    
    $content = Get-Content $Path -Encoding utf8
    $newContent = @()
    $inEpisodesSection = $false
    
    foreach ($line in $content) {
        if ($line -eq "[EPISODES]") { 
            $inEpisodesSection = $true
            $newContent += $line
            continue 
        }
        
        if ($inEpisodesSection -and -not [string]::IsNullOrWhiteSpace($line)) {
            # Zeile prüfen: [*]Code|Absolute|Staffel|Episode|Titel
            $cleanLine = $line.TrimStart("*")
            $parts = $cleanLine -split '\|'
            
            # Wir vergleichen Code und Titel, um sicherzugehen
            if ($parts.Count -ge 5 -and $parts[0] -eq $Code -and $parts[4] -eq $Title) {
                if (-not $line.StartsWith("*")) {
                    $newContent += "*" + $line
                } else {
                    $newContent += $line
                }
            } else {
                $newContent += $line
            }
        } else {
            $newContent += $line
        }
    }
    
    $newContent | Out-File -FilePath $Path -Encoding utf8 -Force
    Write-Host "Lokaler Status für '$Code' aktualisiert (als verwendet markiert)." -ForegroundColor DarkGray
}

# --- NEU: Gekapselte Funktion für die Verarbeitung einer einzelnen Datei ---
function Process-File {
    param(
        [Parameter(Mandatory)]
        $file,
        
        [switch]$ShowAllMatches
    )

    $detectedCode = $null # Variable für zusätzlich gefundenen Code initialisieren
    # Prüfen, ob die Datei bereits das Zielformat 'Serie - SxxExx - Titel.mkv' hat.
    # Eine Datei wird übersprungen, wenn sie das SxxExx-Format hat UND der Titel danach nicht nur aus Zahlen besteht.
    # Das stellt sicher, dass Dateien wie 'Serie - S01E01 - 123.mkv' trotzdem verarbeitet werden.
    if ($file.Name -match '^.+ - S\d{2}E\d{2} - (.+)\.(mkv|mp4)$') { # Prüft, ob der Dateiname bereits dem Zielformat entspricht.
        $titlePart = $matches[1] # Extrahiert den Titelteil des Dateinamens.
        # Wenn der Titelteil NICHT nur aus Zahlen besteht, ist die Datei fertig.
        if ($titlePart -notmatch '^\d+$') { # Prüft, ob der Titel nicht nur aus Zahlen besteht.
            Write-Host "Datei '$($file.Name)' hat bereits das korrekte Format." -ForegroundColor DarkGray
            $msgResult = [System.Windows.Forms.MessageBox]::Show("Datei '$($file.Name)' scheint bereits korrekt zu sein. Trotzdem bereinigen?", "Datei überspringen?", "YesNo", "Question")
            if ($msgResult -eq "No") {
                return $true # Erfolg, da absichtlich übersprungen
            }
        }
    }
#
    Write-Host "------------------------------------------------------------" # Trennlinie für die Übersichtlichkeit.
    Write-Host "Verarbeite Datei: $($file.Name)" # Gibt den Namen der aktuell verarbeiteten Datei aus.
#
    $baseName = $file.BaseName # Holt den Dateinamen ohne die Dateiendung.
    # 4. Entfernt gängige Szene-Tags. Die Suche ist case-insensitive.
    # Zugriff auf $global:sceneTags oder $script:sceneTags erforderlich (hier durch Variablen-Scope oft automatisch verfügbar, zur Sicherheit direkt verwendet)
    $baseNameOhneTags = $baseName -replace "\b($script:sceneTags)\b", '' # Entfernt alle definierten Tags aus dem Dateinamen.
#
    # 5. Entfernt den Gruppennamen (Punkt 6), der oft mit einem Bindestrich am Ende steht.
    $baseNameOhneGruppe = $baseNameOhneTags -replace '-\w+$', '' # Entfernt den Gruppennamen am Ende.
#
    # --- Start: Block zur Normalisierung von Dateinamen ---
    # 1. Normalisiert die Trennzeichen um das SxxExx-Muster herum, um eine saubere Struktur zu schaffen.
    # Dies behandelt Fälle wie "SerieS01E01Titel" oder "Serie-S01E01-Titel".
    $baseNameMitTrenner = $baseNameOhneGruppe -replace '(\S)(S\d{2}E\d{2})', '$1 - $2' -replace '(S\d{2}E\d{2})(\S)', '$1 - $2' # Fügt Trennzeichen um SxxExx ein.
    
    # Fix für Seriennamen wie "PUR+", wo das Plus direkt am Bindestrich kleben kann ("PUR+-Titel").
    # Wir fügen ein Leerzeichen ein, damit der Trenner als " - " erkannt wird oder zumindest sauber getrennt ist.
    $baseNameMitTrenner = $baseNameMitTrenner -replace '\+-', '+ - ' 
#
    # 2. Ersetzt alle restlichen Punkte und Unterstriche durch Leerzeichen.
    $baseNameOhnePunkte = $baseNameMitTrenner -replace '[\._]', ' ' # Ersetzt Punkte und Unterstriche durch Leerzeichen.
#
    if ($baseNameOhnePunkte -match '\s*-\s*\d{8,12}$') { # Prüft, ob am Ende eine lange numerische ID steht (mit oder ohne Leerzeichen).
        $baseNameID = $baseNameOhnePunkte -replace '\s*-\s*\d{8,12}$', '' # Entfernt diese ID.
        Write-Host "Numerische ID am Ende des Dateinamens entfernt." -ForegroundColor Magenta # Gibt eine Meldung aus.
        $baseNameOhnePunkte = $baseNameID # Aktualisiert den Dateinamen.
    }
    $baseNameOhnePunkte = $baseNameOhnePunkte -replace '\s{2,}', ' ' # Entfernt doppelte Leerzeichen.
#
    # Teilt den normalisierten Namen am Trennzeichen ' - ' auf, um die einzelnen Teile zu erhalten.
    $fileNameParts = $baseNameOhnePunkte -split ' - ' # Teilt den Namen in seine Bestandteile auf.

    # Fallback: Wenn kein Standard-Trenner ' - ' gefunden wurde, versuchen wir am ersten Bindestrich zu trennen, 
    # falls der Name lang genug ist und keine SxxExx-Struktur hat.
    if ($fileNameParts.Count -lt 2 -and $baseNameOhnePunkte -match '^[^-]+-.+$' -and $baseNameOhnePunkte -notmatch 'S\d{2}E\d{2}') {
        $firstDashIndex = $baseNameOhnePunkte.IndexOf('-')
        $seriesPart = $baseNameOhnePunkte.Substring(0, $firstDashIndex).Trim()
        $restPart = $baseNameOhnePunkte.Substring($firstDashIndex + 1).Trim()
        $fileNameParts = @($seriesPart, $restPart)
        $baseNameOhnePunkte = "$seriesPart - $restPart"
        Write-Host "Kein Standard-Trenner gefunden. Trenne am ersten Bindestrich: '$seriesPart' - '$restPart'" -ForegroundColor Magenta
    }
#
    # 3. Ersetzt Bindestriche, die als Trennzeichen dienen (mit Leerzeichen drumherum), durch den Standard-Trenner " - ".
    # Bindestriche innerhalb von Wörtern (z.B. "Dreifach-Date") bleiben unberührt.
    $baseNameFinal = $fileNameParts -replace '\s+-\s+', ' - ' # Normalisiert die Trennzeichen.
#
    # 4. Bereinigt mehrfache Leerzeichen, die durch die vorherigen Ersetzungen entstanden sein könnten.
    $baseNameFinal = $baseNameFinal -replace '\s{2,}', ' ' # Entfernt doppelte Leerzeichen.
    $baseNameFinal = $baseNameFinal.Trim()  # Entfernt führende und nachfolgende Leerzeichen.
    $baseNameFinal = $baseNameFinal | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } # Entfernt leere Teile.
#
    
    # Ermittle den potenziellen Seriennamen vorab, um zu prüfen, ob ein Wechsel stattgefunden hat.
    # Dies ist wichtig, damit die Tag-GUI auch bei der allerersten Datei einer neuen Serie korrekt angezeigt wird.
    if ($fileNameParts.Count -ge 1) {
        $potentialSeriesName = $fileNameParts[0].Trim()
        # Wende die gleiche Korrekturlogik für "Serie - Serie" an wie später im Skript.
        $potParts = $potentialSeriesName -split '-'
        if ($potParts.Count -eq 2 -and $potParts[0].Trim() -eq $potParts[1].Trim()) {
             $potentialSeriesName = $potParts[0].Trim()
        }

        # Wenn sich der Serienname geändert hat, setzen wir den Tag-Check zurück.
        if ($script:cachedSeries.Name -ne $potentialSeriesName) {
            $script:cachedSeries.HasCheckedTags = $false
        }
    }


    # --- NEU: GUI zur Auswahl zusätzlicher Tags ---
    # Führe die Tag-Auswahl nur einmal pro Serie durch (oder beim ersten Start).
    if (-not $script:cachedSeries.HasCheckedTags) {
        $tagsToRemove = Show-TagSelectionGui -FileNameParts $baseNameFinal # Zeigt die GUI zur Tag-Auswahl an.
        $script:cachedSeries.HasCheckedTags = $true # Merken, dass die Prüfung erfolgt ist.
        
        if ($null -ne $tagsToRemove -and $tagsToRemove.Count -gt 0) {
            Write-Host "Folgende neue Tags werden entfernt und gespeichert: $($tagsToRemove -join ', ')" -ForegroundColor Magenta
            
            # Neue Tags zur Datei hinzufügen (ohne Duplikate)
            $existingCustomTags = if (Test-Path $script:customTagsFile) { Get-Content $script:customTagsFile } else { @() }
            $allCustomTags = ($existingCustomTags + $tagsToRemove) | Select-Object -Unique
            $allCustomTags | Out-File $script:customTagsFile -Encoding utf8

            # Neue Tags sofort zur aktuellen Session hinzufügen
            $script:sceneTags += '|' + ($tagsToRemove -join '|')

            # Dateinamen-Teile neu erstellen, ohne die ausgewählten Tags
            $fileNameParts = $fileNameParts | Where-Object { $_ -notin $tagsToRemove }

            # Den bereinigten Namen für die weitere Verarbeitung neu zusammensetzen
            $baseNameFinal = $fileNameParts -join ' - '
        }
    }
#
    if ($fileNameParts.Count -lt 2) { # Prüft, ob der Name mindestens zwei Teile hat.
        Write-Warning "Dateiname '$($file.Name)' (nach Normalisierung: '$baseNameFinal') entspricht nicht dem Format 'Serie - Folge - Titel' und wird übersprungen." # Gibt eine Warnung aus.
        return $true # Überspringen, aber nicht als Fehler werten (kein Retry)
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
        return $true
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

        # --- NEU: Erweiterte Analyse des Titels ---
        
        # 1. Prüfen auf versteckten Code wie "S04 E13" (entstanden aus S04_E13 durch Normalisierung)
        if ($episodeTitleFromFile -match 'S(\d+)\s*E(\d+)') {
            $tempCode = "S{0:00}E{1:00}" -f [int]$matches[1], [int]$matches[2]
            
            # Abfrage nur beim ersten Mal, wenn noch keine Entscheidung getroffen wurde
            if ($null -eq $script:approvedHiddenCodePattern) {
                $msgResult = [System.Windows.Forms.MessageBox]::Show("Im Titel wurde ein versteckter Episodencode '$tempCode' gefunden.`nSoll dieser für die Identifikation verwendet werden?`n`n(Diese Entscheidung wird für den aktuellen Durchlauf gespeichert)", "Versteckten Code gefunden", "YesNo", "Question")
                $script:approvedHiddenCodePattern = ($msgResult -eq "Yes")
            }

            if ($script:approvedHiddenCodePattern) {
                $detectedCode = $tempCode
                Write-Host "Versteckten Episodencode '$detectedCode' im Titel gefunden." -ForegroundColor Cyan
            }
        }

        # 2. Prüfen auf Bindestrich ohne Leerzeichen (z.B. "Untertitel-Episodentitel")
        # Wir splitten nur, wenn der Titel dadurch nicht extrem kurz wird (Schutz vor "X-Men")
        if ($episodeTitleFromFile -match '^.+-.+$') {
            $parts = $episodeTitleFromFile -split '-', 2
            $potentialTitle = $parts[1].Trim()
            Write-Host "Titel enthält Bindestrich. Trenne ab: '$($parts[0].Trim())' -> Verwende: '$potentialTitle'" -ForegroundColor Magenta
            $episodeTitleFromFile = $potentialTitle
        }
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
        Write-Host "Neue Serie erkannt: '$seriesNameFromFile'." -ForegroundColor Yellow
        
        # --- NEU: Zuerst lokal suchen ---
        $serienInfoPath = Join-Path $script:selectedPath "Serieninfo.txt"
        $localInfo = $null
        
        if (Test-Path $serienInfoPath) {
            # Prüfen, ob wir im 2. Durchlauf sind und Used includen sollen
            $includeUsed = $script:includeUsedEpisodes -eq $true
            $localInfo = Get-LocalSeriesInfo -Path $serienInfoPath -IncludeUsed:$includeUsed
        }

        if ($localInfo) {
            Write-Host "Verwende lokale Informationen aus Serieninfo.txt." -ForegroundColor Green
            $script:cachedSeries.Name = $seriesNameFromFile
            $script:cachedSeries.SelectedSeries = [pscustomobject]@{ Title = $localInfo.SeriesName; Url = $localInfo.GuideUrl }
            $script:cachedSeries.EpisodeGuideUrl = $localInfo.GuideUrl
            $script:cachedSeries.ParsedEpisodes = $localInfo.Episodes
            # Content brauchen wir nicht laden, da wir die Episoden schon haben
            $script:cachedSeries.EpisodeGuideContent = "LOADED_FROM_FILE" 
        } 
        else {
            Write-Host "Suche online nach Episodenführer..." -ForegroundColor Yellow
            # Zugriff auf globalen Regex
            $searchResults = Invoke-SeriesSearch -SeriesName $seriesNameFromFile # Führt die Online-Suche durch.
    #
            # --- Start: Angepasste Verarbeitung der Suchergebnisse ---
            if ($null -eq $searchResults -or $searchResults.Count -eq 0) { # Wenn keine Ergebnisse gefunden wurden...
                Write-Warning "Keine Suchergebnisse für '$seriesNameFromFile' gefunden."
                return $false # Retry? Wenn keine Serie gefunden wird, hilft Retry meist nicht, aber konsistent mit "failed".
            }
    #
            # Fall 1: Direkter Treffer wurde von Invoke-SeriesSearch zurückgegeben
            if ($searchResults.PSObject.Properties['IsDirectHit'] -and $searchResults.IsDirectHit) { # Prüft, ob es ein direkter Treffer war.
                Write-Host "Direkter Treffer wird verarbeitet." -ForegroundColor Cyan # Meldung für den Benutzer.
                $script:cachedSeries.Name = $seriesNameFromFile # Speichert den Seriennamen im Cache.
                $script:cachedSeries.SelectedSeries = $searchResults.SelectedSeries # Speichert das Serienobjekt im Cache.
                $script:cachedSeries.EpisodeGuideUrl = $searchResults.EpisodeGuideUrl # Speichert die Episodenführer-URL im Cache.
                $script:cachedSeries.EpisodeGuideContent = "" # Leert den Inhalts-Cache, da er neu geladen werden muss.
                $script:cachedSeries.ParsedEpisodes = $null
            }
            # Fall 2: Liste von Suchergebnissen wurde zurückgegeben
            else {
                if ($searchResults.Count -eq 1) { # Wenn es genau ein Suchergebnis gibt...
                    Write-Host "Genau ein Suchergebnis gefunden, wird automatisch verwendet."
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
                        $script:cachedSeries.ParsedEpisodes = $null
                    }
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
                return $false
            }
        }
        
        # Parsen des Inhalts, falls noch nicht geschehen
        if ($null -eq $script:cachedSeries.ParsedEpisodes) {
             Write-Host "Parse Episodenguide einmalig für den Cache..." -ForegroundColor Cyan
             $script:cachedSeries.ParsedEpisodes = Parse-EpisodeGuide -GuideContent $script:cachedSeries.EpisodeGuideContent
             
             # --- NEU: Nach dem Parsen in Datei speichern ---
             $serienInfoPath = Join-Path $script:selectedPath "Serieninfo.txt"
             Save-LocalSeriesInfo -Path $serienInfoPath -SeriesName $script:cachedSeries.SelectedSeries.Title -GuideUrl $script:cachedSeries.EpisodeGuideUrl -Episodes $script:cachedSeries.ParsedEpisodes
        }

        # Ruft die spezifischen Informationen für die aktuelle Episode ab.
        # NEU: Übergabe von ShowAllMatches
        $episodeInfo = Get-EpisodeInfo -EpisodeList $script:cachedSeries.ParsedEpisodes -AbsoluteEpisodeNumber $absoluteEpisodeNumber -EpisodeTitleFromFile $episodeTitleFromFile -SeasonEpisodeCode $detectedCode -ShowAllMatches:$ShowAllMatches 
    }
    else {
        Write-Host "Kein Episodenführer für diese Serie verfügbar. Datei wird übersprungen." -ForegroundColor Red # Gibt eine Warnung aus, wenn kein Episodenführer gefunden wurde.
        return $false
    }
#
    # Wenn Episodeninformationen gefunden wurden, wird der neue Dateiname erstellt.
    if ($null -ne $episodeInfo) { # Wenn Episodeninformationen gefunden wurden...
        # Prüfen, ob ein gültiger Episodencode (SxxExx) gefunden wurde.
        if ([string]::IsNullOrEmpty($episodeInfo.Code)) { # ...aber kein SxxExx-Code...
            Write-Warning "Konnte keinen SxxExx-Code für die gefundene Episode '$($episodeInfo.Titel)' erstellen. Datei wird übersprungen."
            return $false
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
        Write-Warning "Keine Episoden-Information für Folge '$absoluteEpisodeNumber' von '$seriesNameFromFile' gefunden (oder abgebrochen). Datei wird zur Nachbearbeitung vorgemerkt."
        return $false # Signalisiert: Nicht erfolgreich / Abbruch
    }
    # Versucht, die Datei umzubenennen.
    try {
        Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop # Benennt die Datei um.
        
        # --- NEU: Entferne die verwendete Episode aus der Liste, damit sie nicht doppelt vergeben wird ---
        if ($null -ne $episodeInfo -and $null -ne $script:cachedSeries.ParsedEpisodes) {
            $script:cachedSeries.ParsedEpisodes = $script:cachedSeries.ParsedEpisodes | Where-Object { 
                $_.Code -ne $episodeInfo.Code -or $_.Titel -ne $episodeInfo.Titel -or $_.Absolute -ne $episodeInfo.Absolute 
            }
            Write-Host "Episode '$($episodeInfo.Code) - $($episodeInfo.Titel)' aus der Liste der verfügbaren Episoden entfernt." -ForegroundColor Gray
            
            # --- NEU: In Datei als verwendet markieren ---
            $serienInfoPath = Join-Path $script:selectedPath "Serieninfo.txt"
            Update-LocalSeriesInfo -Path $serienInfoPath -Code $episodeInfo.Code -Title $episodeInfo.Titel
        }
        return $true # Erfolg
    }
    catch {
        Write-Error "Fehler beim Umbenennen der Datei: $($_.Exception.Message)" # Gibt einen Fehler aus, falls das Umbenennen fehlschlägt.
        return $false # Fehler beim Umbenennen -> Retry?
    }
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
    $script:selectedPath = $folderBrowser.SelectedPath # Speichert den ausgewählten Pfad.
    Write-Host "Ausgewählter Ordner: $script:selectedPath" # Gibt den ausgewählten Pfad auf der Konsole aus.
} else {
    Write-Host "Abbruch. Das Programm wird beendet."
    exit # Beendet das Skript.
}
#
# Initialisiert ein Hashtable als Cache, um wiederholte Suchen für dieselbe Serie zu vermeiden.
$script:cachedSeries = @{
    Name              = "" # Name der zuletzt gesuchten Serie.
    EpisodeGuideUrl   = "" # URL des Episodenführers.
    SelectedSeries    = $null # Das vom Benutzer ausgewählte Serienobjekt.
    EpisodeGuideContent = "" # Der heruntergeladene HTML-Inhalt des Episodenführers.
    ParsedEpisodes    = $null # Die bereits geparste Liste aller Episoden.
    HasCheckedTags    = $false # Gibt an, ob die Tag-Auswahl für diese Serie bereits durchgeführt wurde.
}
#
$script:includeUsedEpisodes = $false # Standardmäßig keine verwendeten Episoden laden
# Ruft alle .mkv-Dateien aus dem ausgewählten Ordner und seinen Unterordnern ab.
$files = Get-ChildItem -Path $script:selectedPath -Recurse -Include *.mkv, *.mp4 # Sucht nach allen .mkv- und .mp4-Dateien im ausgewählten Ordner.

$retryFiles = @()

#
# Beginnt die Schleife zur Verarbeitung jeder einzelnen Datei (1. Durchlauf).
Write-Host "=== Start 1. Durchlauf (Top 8 Treffer) ===" -ForegroundColor Cyan
foreach ($file in $files) { # Startet die Schleife für jede gefundene Datei.
    $success = Process-File -File $file -ShowAllMatches:$false
    
    if (-not $success) {
        $retryFiles += $file
    }
}

# 2. Durchlauf für abgebrochene/fehlgeschlagene Dateien mit erweiterter Suche
if ($retryFiles.Count -gt 0) {
    Write-Host "`n=== Start 2. Durchlauf (Alle Treffer anzeigen) ===" -ForegroundColor Cyan
    Write-Host "Es werden $($retryFiles.Count) Dateien erneut verarbeitet..." -ForegroundColor Yellow
    
    # --- NEU: Popup Abfrage ---
    $msgResult = [System.Windows.Forms.MessageBox]::Show("Sollen im zweiten Durchlauf auch bereits als 'gefunden' markierte Episoden (aus Serieninfo.txt) wiederverwendet werden?", "Erweiterte Suche", "YesNo", "Question")
    if ($msgResult -eq "Yes") {
        $script:includeUsedEpisodes = $true
        # Cache leeren, damit beim nächsten Process-File die Datei neu geladen wird (mit * Einträgen)
        $script:cachedSeries.Name = "" 
        $script:cachedSeries.ParsedEpisodes = $null
        Write-Host "Bereits verwendete Episoden werden nun einbezogen." -ForegroundColor Magenta
    }
    
    # Warte kurz, damit der Benutzer die Meldung sieht
    Start-Sleep -Seconds 2
    
    foreach ($file in $retryFiles) {
        # Prüfen, ob die Datei noch existiert (könnte manuell geändert worden sein)
        if (Test-Path $file.FullName) {
            # Erneuter Aufruf mit ShowAllMatches = $true
            # Refresh File-Objekt um sicherzustellen, dass Pfad etc. aktuell sind
            $currentFile = Get-Item $file.FullName
            Process-File -File $currentFile -ShowAllMatches:$true
        }
    }
}

Write-Host "`nVerarbeitung abgeschlossen." -ForegroundColor Green
#endregion
