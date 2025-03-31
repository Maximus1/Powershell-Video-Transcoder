~~# Powershell-Video-Transcoder~~
Auto Video Transcode

Transcode your Videos (Movies and Episodes) from AVI, MP4, MKV to MKV with AAC and HEVC

This Script lets you choose a Folder and scanns recursive for AVI MP4 and MKV files.

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



-Filestats---------------------------------------------------------------------

MKV Batch Encoding File 333 of 4323 - 7.7%

Processing : W:\Awesome Series\Staffel 01\S01E13 Awesone Episode.mp4

Audiocount / Format / Channels : 1 / AAC / 2

Videoformat / Resolution : AVC / 1920 : 1080

VideoLaufzeit : 1266539 / 21

-Jobs--------------------------------------------------------------------------

FFMPEG Instanzen : 0 / 10

Handbrake Instanzen : 0 / 2

-Step--------------------------------------------------------------------------


Please feel free to contribute.
My Powershell skills aren't that good, but with your help the script might be really good.
