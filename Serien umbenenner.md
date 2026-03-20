# Serien Umbenenner Tool - Dokumentation

Dieses PowerShell-Skript automatisiert das Umbenennen von Videodateien (Serien), indem es Episodeninformationen von **fernsehserien.de** abruft und die lokalen Dateien entsprechend einem sauberen Schema (`Serie - SxxExx - Titel.ext`) umbenennt.

## Hauptfunktionen

*   **Online-Abgleich:** Sucht automatisch nach Serieninformationen und Episodenlisten.
*   **Intelligente Erkennung:** Nutzt Levenshtein-Distanz, um Dateinamen auch bei Schreibfehlern oder Abweichungen der korrekten Episode zuzuordnen.
*   **GUI-Unterstützung:**
    *   Auswahl der korrekten Serie bei mehrdeutigen Suchergebnissen (mit Bildvorschau).
    *   Auswahl der korrekten Episode, falls die automatische Zuordnung nicht eindeutig ist.
    *   Auswahl von zu entfernenden "Scene-Tags" (z.B. *GERMAN*, *DUBBED*).
*   **Lokaler Cache & Historie:** Speichert geladene Serieninfos in einer `Serieninfo.txt` im Zielordner, um wiederholte Web-Abfragen zu vermeiden und bereits zugeordnete Episoden zu markieren.
*   **Zwei-Phasen-Verarbeitung:**
    1.  **Durchlauf 1:** Versucht eine schnelle Zuordnung (Top 8 Treffer).
    2.  **Durchlauf 2 (Retry):** Versucht bei fehlgeschlagenen Dateien eine erweiterte Suche (alle Treffer) und fragt optional ab, ob bereits vergebene Episoden erneut genutzt werden dürfen.

## Voraussetzungen

*   Windows Betriebssystem.
*   PowerShell 5.1 oder höher.
*   Internetverbindung (für den Abgleich mit fernsehserien.de).

## Einrichtung

Es ist keine Installation notwendig. Das Skript kann direkt ausgeführt werden.

### Optionale Konfiguration: `CustomSceneTags.txt`
Wenn du permanent eigene Tags aus Dateinamen entfernen möchtest (z.B. spezielle Release-Gruppen-Namen), erstelle eine Datei namens `CustomSceneTags.txt` im selben Ordner wie das Skript.
*   Schreibe pro Zeile einen Tag hinein.
*   Diese Tags werden zusätzlich zu den Standard-Tags (1080p, x265, etc.) entfernt.

## Anwendung

1.  **Starten:** Führe das Skript `Serien umbenenner.ps1` aus (Rechtsklick -> "Mit PowerShell ausführen").
2.  **Ordnerwahl:** Ein Dialogfenster öffnet sich. Wähle den Ordner aus, in dem sich die Videodateien (`.mkv`, `.mp4`) befinden.
3.  **Tag-Bereinigung:** Beim ersten Start oder bei neuen Serien fragt das Skript via GUI, ob bestimmte Teile des Dateinamens als "Tags" erkannt und entfernt werden sollen. Wähle hier unerwünschte Namensbestandteile aus.
4.  **Verarbeitung:**
    *   Das Skript analysiert jede Datei.
    *   Bei Unsicherheiten (welche Serie? welche Episode?) öffnet sich ein Fenster, in dem du die richtige Auswahl treffen kannst.
    *   Die Dateien werden automatisch umbenannt.

## Funktionsweise im Detail

### 1. Dateibereinigung & Analyse
Das Skript bereinigt den Dateinamen zunächst von gängigen Szenen-Tags (z.B. "1080p", "WebRip") und versucht, Serie, Staffel und Episode aus dem Namen zu extrahieren.

### 2. Die Datei `Serieninfo.txt`
Im bearbeiteten Ordner wird eine Datei namens `Serieninfo.txt` erstellt.
*   **Zweck:** Sie speichert die Episodenliste der aktuellen Serie lokal.
*   **Vorteil:** Bei weiteren Dateien der gleichen Serie muss nicht erneut online gesucht werden (schneller & weniger Traffic).
*   **Verhinderung von Duplikaten:** Erfolgreich umbenannte Episoden werden in dieser Datei mit einem Sternchen (`*`) markiert. Das Skript versucht im ersten Durchlauf, diese Episoden nicht erneut an andere Dateien zu vergeben.

### 3. Der "Retry"-Modus (2. Durchlauf)
Dateien, die im ersten Durchlauf nicht eindeutig zugeordnet werden konnten, landen in einer Warteschlange.
*   Nach dem ersten Durchlauf startet automatisch der zweite Durchlauf für diese Problem-Dateien.
*   Die Suche wird "toleranter" (es werden mehr potenzielle Treffer angezeigt).
*   Das Skript fragt, ob auch bereits markierte ("verbrauchte") Episoden aus der `Serieninfo.txt` wieder zur Auswahl stehen sollen (nützlich, falls man z.B. eine bessere Version einer bereits vorhandenen Datei einsortiert).

## Häufige Fragen (FAQ)

**Was tun, wenn eine Serie falsch erkannt wurde?**
Lösche die `Serieninfo.txt` im Zielordner. Beim nächsten Start sucht das Skript wieder frisch online und fragt ggf. nach der richtigen Serie.

**Wie füge ich manuell Tags hinzu, die immer entfernt werden sollen?**
Nutze entweder die GUI-Abfrage beim Start oder trage sie in die `CustomSceneTags.txt` ein.

**Das Skript findet die Episode nicht, obwohl sie existiert.**
Das passiert oft bei Specials oder stark abweichenden Titeln.
*   Prüfe, ob die Folge auf *fernsehserien.de* gelistet ist.
*   Im zweiten Durchlauf (Retry) zeigt das Skript eine erweiterte Liste an; oft ist die Folge dort zu finden.

## Fehlerbehebung

*   **Skript schließt sich sofort:** Starte es über die PowerShell-Konsole (Rechtsklick im Ordner -> Terminal öffnen -> `.\Serien umbenenner.ps1`), um Fehlermeldungen zu sehen.
*   **Berechtigungsprobleme:** Stelle sicher, dass du Schreibrechte im Zielordner hast.
```