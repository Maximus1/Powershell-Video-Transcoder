[![CodeFactor](https://www.codefactor.io/repository/github/maximus1/powershell-video-transcoder/badge/main)](https://www.codefactor.io/repository/github/maximus1/powershell-video-transcoder/overview/main)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/0ec11745ed0c4e268fa6fd2316f53b57)](https://app.codacy.com/gh/Maximus1/Powershell-Video-Transcoder/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![Donate via PayPal](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=NLQMQSQB7Y79N)

~~# Powershell-Video-Transcoder~~
Auto Video Transcode

Transcode your MKV Videos (Movies and Episodes)  with AAC and HEVC

INFO: your FFMPEG needs to support libfdk_aac. Compile it by yourself (<https://github.com/m-ab-s/media-autobuild_suite>)

This Script lets you choose a Folder and scanns recursive for MKV files.

- It then counts the files corresponding to the filter.
- Codecs, file size, dimensions, number of audio streams and more are measured for each file.
- It is decided how many instances are allowed to run based on the load and the process distribution (Handbrake and FFmpeg).
- Files that are already in the desired format are skipped.
- The files to be processed are pre-sorted into 4 categories.
  1. is AAC and is HEVC
  2. no AAC but HEVC - FFMPEG
    #Surround
    #stereo or mono
    handbrake
  3. no AAC and no HEVC - ~~handbrake~~ FFMPEG
    #Surround
    #stereo or mono
  4. With ACC but no HEVC - ~~handbrake~~ FFMPEG
- A path filter is used to check whether it is a series and then scaled down to 720p if necessary.
- Films remain at their original resolution



Output to the console:

```text
5329 MKV-Dateien verbleibend.
Verarbeite Datei: Y:\Serie\Staffel 03\Serie - S03E02 - Tolle Folge.mkv
Datei erkannt als Serientitel. Prüfe auf 720p anpassung.
Aktuelle Auflösung: 1280x720. Keine Größenanpassung notwendig.
Starte FFmpeg zur Lautstärkeanalyse...
Passe Lautstärke an um 4.9 dB
Starte FFmpeg zur Lautstärkeanpassung...Video copy...Audio transcode Stereo...Lautstärke anpassung und Metadaten...
FFmpeg-Argumente: -hide_banner -loglevel error -stats -y -i "Y:\Serie - S03E02 - Tolle Folge.mkv" -c:v copy -b:a 192k -af volume=4.9dB -c:s copy -metadata LUFS=-18 -metadata gained=4.9 -metadata normalized=true "Y:\Serie - S03E02 - Tolle Folge_normalized.mkv"
  5    31,56       2,86       0,02   14288   1 ffmpeg
frame=33418 fps=1450 q=-1.0 Lsize=  639952KiB time=00:22:16.72 bitrate=3921.9kbits/s speed=  58x    
Lautstärkeanpassung abgeschlossen für: Y:\Serie - S03E02 - Tolle Folge.mkv
Überprüfe die Ausgabedatei: Y:\Serie - S03E02 - Tolle Folge_normalized.mkv
Extrahierte Dauer: 00:22:16.74
Audioformat ist stereo (2 Kanäle)
  Quelldatei-Dauer: 00:22:16.73 | Audiokanäle: 2
  Ausgabedatei-Dauer: 00:22:16.74 | Audiokanäle: 2
  OK: Die Laufzeiten stimmen überein.
  OK: Die Anzahl der Audiokanäle ist gleich geblieben.
True
  Erfolg: Quelldatei gelöscht und normalisierte Datei umbenannt zu Serie - S03E02 - Tolle Folge.mkv
Verarbeitung abgeschlossen für: Y:\Serie - S03E02 - Tolle Folge.mkv
```

My Powershell skills aren't that good, but with your help the script might be really good.
