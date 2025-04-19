[![CodeFactor](https://www.codefactor.io/repository/github/maximus1/powershell-video-transcoder/badge/main)](https://www.codefactor.io/repository/github/maximus1/powershell-video-transcoder/overview/main)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/0ec11745ed0c4e268fa6fd2316f53b57)](https://app.codacy.com/gh/Maximus1/Powershell-Video-Transcoder/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![Donate via PayPal](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=NLQMQSQB7Y79N)

~~# Powershell-Video-Transcoder~~
Auto Video Transcoder

This script automates quality control and adjustment for large video collections, ensuring all files have consistent loudness and modern codecs, while avoiding reprocessing of files that have already been handled.

The script is a PowerShell tool for automated analysis, volume normalization, and, if necessary, transcoding of MKV video files in a selected folder. Its workflow is as follows:

INFO: your FFMPEG needs to support libfdk_aac. Compile it by yourself (<https://github.com/m-ab-s/media-autobuild_suite>)


1. **Folder Selection:** At startup, a dialog opens allowing the user to select a folder containing video files.

2. **File Search and Filtering:** The script recursively searches for all MKV files in the chosen folder. It filters out any files already marked as "GAINED" or "NORMALIZED" in their metadata tags to avoid duplicate processing.

3. **Media Analysis:** For each remaining file, FFmpeg is used to extract information such as duration, audio and video codecs, resolution, and audio channels.

4. **Loudness Analysis:** The integrated loudness (LUFS) of the audio track is measured using FFmpeg.

5. **Volume Adjustment:** If the loudness is outside the target range, the file is reprocessed with FFmpeg to adjust the volume and set new metadata ("gained", "normalized").

6. **Transcoding:** If necessary, the video is transcoded to the HEVC codec (H.265) and/or downscaled to 720p resolution. Audio streams are also adjusted according to the number of channels.

7. **Integrity Check:** After processing, the output file is checked with FFmpeg to ensure it was created correctly and that key properties (duration, channels) match the original file.

8. **Cleanup:** The original file is replaced by the new, normalized file. Temporary files and already normalized files are deleted.


Output to the console:

```text
55 MKV-Dateien verbleibend.
Verarbeite Datei: Z:\TV\The Series S02E08.mkv
Video: 01:07:26.34 | h264 | 1248x520 | Interlaced: False
Audio: 6 Kanäle: | eac3
Datei erkannt als Serientitel. Prüfe auf 720p anpassung.
Aktuelle Auflösung: 1248x520. Keine Größenanpassung notwendig.
Starte FFmpeg zur Lautstärkeanalyse...
Passe Lautstärke an um 4.3 dB
Starte FFmpeg zur Lautstärkeanpassung...Video Transode...Audio transcode Surround...Lautstärke anpassung und Metadaten...
FFmpeg-Argumente: -hide_banner -loglevel error -stats -y -i "Z:\TV\The Series S02E08.mkv" -c:v libx265 -preset medium -crf 23 -c:a libfdk_aac -profile:a aac_he -ac 6 -channel_layout 5.1 -af volume=4.3dB -c:s copy -metadata LUFS=-18 -metadata gained=4.3 -metadata normalized=true "Z:\TV\The Series S02E08_normalized.mkv"
      6    31,78       3,14       0,00   20652   1 ffmpeg
x265 [info]: HEVC encoder version 4.1+126-b354c00
x265 [info]: build info [Windows][GCC 14.2.0][64 bit] 8bit+10bit+12bit
x265 [info]: using cpu capabilities: MMX2 SSE2Fast LZCNT SSSE3 SSE4.2 AVX FMA3 BMI2 AVX2
x265 [info]: Main profile, Level-3.1 (Main tier)
x265 [info]: Thread pool created using 12 threads
x265 [info]: Slices                              : 1
x265 [info]: frame threads / pool features       : 3 / wpp(9 rows)
x265 [warning]: Source height < 720p; disabling lookahead-slices
x265 [info]: Coding QT: max CU size, min CU size : 64 / 8
x265 [info]: Residual QT: max TU size, max depth : 32 / 1 inter / 1 intra
x265 [info]: ME / range / subpel / merge         : hex / 57 / 2 / 3
x265 [info]: Keyframe min / max / scenecut / bias  : 23 / 250 / 40 / 5.00
x265 [info]: Lookahead / bframes / badapt        : 20 / 4 / 2
x265 [info]: b-pyramid / weightp / weightb       : 1 / 1 / 0
x265 [info]: References / ref-limit  cu / depth  : 3 / off / on
x265 [info]: AQ: mode / str / qg-size / cu-tree  : 2 / 1.0 / 32 / 1
x265 [info]: Rate Control / qCompress            : CRF-23.0 / 0.60
x265 [info]: tools: rd=3 psy-rd=2.00 early-skip rskip mode=1 signhide tmvp
x265 [info]: tools: b-intra strong-intra-smoothing deblock sao dhdr10-info
frame=97014 fps= 98 q=29.2 Lsize=  470878KiB time=01:02:12.43 bitrate=1033.5kbits/s speed=3.78x
x265 [info]: frame I:   1265, Avg QP:20.82  kb/s: 6372.97
x265 [info]: frame P:  26942, Avg QP:22.90  kb/s: 1573.33
x265 [info]: frame B:  68807, Avg QP:28.96  kb/s: 261.38
x265 [info]: Weighted P-Frames: Y:1.5% UV:1.0%

encoded 97014 frames in 987.67s (98.22 fps), 705.42 kb/s, Avg QP:27.17
Lautstärkeanpassung abgeschlossen für: Z:\TV\The Series S02E08.mkv
Überprüfe die Ausgabedatei: Z:\TV\The Series S02E08_normalized.mkv
Überprüfe Datei: Z:\TV\The Series S02E08_normalized.mkv
OK: Z:\TV\The Series S02E08_normalized.mkv
Überprüfung abgeschlossen. Ergebnis in: Z:\TV\MKV_Überprüfung.log
Extrahierte Dauer: 01:07:26.44
Video: 01:07:26.44 | hevc | 1248x520
Audio: 6 Kanäle: | aac
  Quelldatei-Dauer: 01:07:26.34 | Audiokanäle: 6
  Ausgabedatei-Dauer: 01:07:26.44 | Audiokanäle: 6
  OK: Die Laufzeiten stimmen überein.
  OK: Die Anzahl der Audiokanäle ist gleich geblieben.
True
  Erfolg: Quelldatei gelöscht und normalisierte Datei umbenannt zu The Series S02E08.mkv
Verarbeitung abgeschlossen für: Z:\TV\The Series S02E08.mkv
```

My Powershell skills aren't that good, but with your help the script might be really good.
