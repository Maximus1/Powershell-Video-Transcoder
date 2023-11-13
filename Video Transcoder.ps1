#requires -Version 3.0 -Modules Get-MediaInfo



${encoder-preset} = 'medium'
${audio-codec-bitrate-256} = '256k'
${audio-codec-bitrate-128} = '128k'
${hb-audiocodec} = 'av_aac'
${video-codec-hevc} = 'HEVC'
${audio-codec-aac} = 'AAC'
${akt-action-s} = 'Skipping'
${akt-action-p} = 'Processing'
${Languages-audio-video} = 'ger,deu,de,und,,'
$extensions = @('*.mkv', '*.mp4', '*.avi')
$seriessessonfolder = '*Staffel*'# Your naming for Seasons comes here. !!don´t remove the stars!!
$series720p = 0
$zahlffmpg = 0
$videoquality = 22
$HBHWDec = 'nvdec'
$subtitlelanglist = ${Languages-audio-video} #<---- Your Subtitle Languages to keep
$audiotitlelanglist = ${Languages-audio-video} #<---- Your Audio Languages to keep
$zahlffmpgmax = 5
$zahlhandb = 0
$zahlhandbmax = 2
$ffmpgexe = "$env:USERPROFILE\Documents\FFmpeg Batch AV Converter\ffmpeg.exe" #<---- Your path to FFmpeg 
$handbrakeexe = "$env:ProgramW6432\HandBrake\HandBrakeCLI.exe" #<---- Your path to Handbrakecli
$textoutput = "$env:USERPROFILE\Desktop\test.txt" #<---- Your path to Textfile
$waitprocess = 10
$i = 0

Add-Type -AssemblyName System.Windows.Forms
#region begin functions
#If Season in Path set encoded video to 720p else use movie Settings
function Check-Series
{
  if ($file.DirectoryName -like $seriessessonfolder) 
  {
    Write-Host -Object 'Ist Serie'
    if ($videoresH -ge 720)
    {
      Write-Host -Object 'auflösung ist größer als 720P'
      $script:series720p = [int]1
    }
    if($videoresH -le 720)
    {
      Write-Host -Object 'auflösung ist 720P oder kleiner'
      $script:series720p = 0
    }
  }
}
#Set maximum Procecces
Function Variable-Instanzen
{
  $zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
  $Auslastung = (Get-WmiObject -Class win32_processor | Measure-Object -Property LoadPercentage -Average).Average
  Write-Host -Object "Auslastung : $Auslastung"
  Write-Host -Object "Handbrakeinstanzen : $zahlhandb"
  if ($zahlhandb -lt $zahlhandbmax -and $Auslastung -lt 50)
  {
    $script:zahlffmpgmax = 10
    $script:zahlhandbmax = 2
  }
  if ($zahlhandb -eq 1 -and $Auslastung -ge 50)
  {
    $script:zahlffmpgmax = 5
    $script:zahlhandbmax = 1
  }
}

#Check if allready converted (...neu.EXT)
function Newfile-Vorhanden
{
  if([IO.File]::Exists($newfile))
  {
    Write-Host -Object 'File already converted' -ForegroundColor Green
    #Start-Sleep -Seconds 2
    continue
  }
}

#Check for existing .ignore file
function check-ignore
{
  if([IO.File]::Exists($ignorefile))
  {Write-Host -Object '.ignore file exists.'}
  else
  {
    Write-Host -Object 'writing .ignore file.'
    $null = New-Item -Path $ignorefilepath -Name '.ignore' -ItemType 'file' -Confirm:$false
  }
}

#Write actual $oldfile into a TXT file !!Just for your control!!
function Write-Oldfileitem 
{
  "$oldfile" | Out-File -FilePath $textoutput -Append -Confirm:$false
}

#Encode Audio only with FFmpg
function FFmpeg-Encode
{
  $zahlffmpg = (Get-Process -Name 'FFmpeg*').count
  if ($zahlffmpg -lt $zahlffmpgmax )
  {
    Start-Process  -FilePath $ffmpgexe -ArgumentList  "-i `"$oldfile`" -c:v copy -c:a aac -ab `"$aacbitrate`" -ar `"$aachz`" -filter:a loudnorm `"$newfile`""
    Write-Oldfileitem
  }
  else
  {
    while ($zahlffmpg -ge $zahlffmpgmax -or $Auslastung -ge 50)
    {
      Write-Host -Object "warte für $waitprocess sekunden"
      Start-Sleep -Seconds $waitprocess
      $zahlffmpg = (Get-Process -Name 'FFmpeg*').count
    }
    Start-Process  -FilePath $ffmpgexe -ArgumentList  "-i `"$oldfile`" -c:v copy -c:a aac -ab `"$aacbitrate`" -ar `"$aachz`" -filter:a loudnorm `"$newfile`""
    Write-Oldfileitem
  }
}

#Encode Audio and Video wit HandbrakeCli
function Handbrake-Encoderfull
{
  $zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
  if ($zahlhandb -lt $zahlhandbmax -and $Auslastung -lt 50)
  {
    Write-Host -Object "$zahlhandb / $zahlhandbmax"
    Check-Series
    if($series720p -eq 0)
    {
      Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset `"${encoder-preset}`" --vfr -A `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle --audio-lang-list `"$audiotitlelanglist`" --first-audio -E `"$handbrakeaudiocodec`" --mixdown `"$hbmixdown`" -B `"$handbrakeaudiobitrate`" --normalize-mix `"$handbrakenormalize`" -i `"$oldfile`" -o `"$newfile`""
      Write-Oldfileitem 
    }
    if($series720p -eq 1)
    {
      Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset `"${encoder-preset}`" -l 720 --loose-anamorphic --keep-display-aspect --vfr -A `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle --audio-lang-list `"$audiotitlelanglist`" --first-audio -E `"$handbrakeaudiocodec`" --mixdown `"$hbmixdown`" -B `"$handbrakeaudiobitrate`" --normalize-mix `"$handbrakenormalize`" -i `"$oldfile`" -o `"$newfile`""
      Write-Oldfileitem 
    }
  }
  else
  {
    while ($zahlhandb -ge $zahlhandbmax -or $Auslastung -ge 50)
    {
      Write-Host -Object "warte für $waitprocess sekunden"
      Start-Sleep -Seconds $waitprocess
      $zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
    }
    Check-Series
    if($series720p -eq 0)
    {
      Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset `"${encoder-preset}`" --vfr -A `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle --audio-lang-list `"$audiotitlelanglist`" --first-audio -E `"$handbrakeaudiocodec`" --mixdown `"$hbmixdown`" -B `"$handbrakeaudiobitrate`" --normalize-mix `"$handbrakenormalize`" -i `"$oldfile`" -o `"$newfile`""
      Write-Oldfileitem 
    }
    if($series720p -eq 1)
    {
      Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset `"${encoder-preset}`" -l 720 --loose-anamorphic --keep-display-aspect --vfr -A `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle --audio-lang-list `"$audiotitlelanglist`" --first-audio -E `"$handbrakeaudiocodec`" --mixdown `"$hbmixdown`" -B `"$handbrakeaudiobitrate`" --normalize-mix `"$handbrakenormalize`" -i `"$oldfile`" -o `"$newfile`""
      Write-Oldfileitem 
    }
  }
}

#Encode Video only with HandbrtakeCli
function Handbrake-Encoderaudiocopy
{
  $zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
  if ($zahlhandb -lt $zahlhandbmax -and $Auslastung -lt 50)
  {
    Write-Host -Object "$zahlhandb / $zahlhandbmax"
    Check-Series
    if($series720p -eq [int]0)
    {
      Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset medium --vfr -A `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle  -E `"$handbrakeaudiocodec`" -i `"$oldfile`" -o `"$newfile`""
      Write-Oldfileitem 
    }
    if($series720p -eq [int]1)
    {
      Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset medium -l 720 --loose-anamorphic --keep-display-aspect --vfr -A `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle  -E `"$handbrakeaudiocodec`" -i `"$oldfile`" -o `"$newfile`""
      Write-Oldfileitem
    }
  }
  else
  {
    while ($zahlhandb -ge $zahlhandbmax -or $Auslastung -ge 50)
    {
      Write-Host -Object "warte für $waitprocess sekunden"
      Start-Sleep -Seconds $waitprocess
      $zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
    }
    Check-Series
    if($series720p -eq 0)
    {
      Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset medium --vfr -A `"$HBHWDec`" --quality 22 --subtitle-lang-list `"$subtitlelanglist`"  --audio-lang-list `"$audiotitlelanglist`" --first-subtitle -E `"$handbrakeaudiocodec`" -i `"$oldfile`" -o `"$newfile`""
      Write-Oldfileitem
    }
    if($series720p -eq 1)
    {
      Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset medium -l 720 --loose-anamorphic --keep-display-aspect --vfr -A `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle  -E `"$handbrakeaudiocodec`" -i `"$oldfile`" -o `"$newfile`""
      Write-Oldfileitem
    }
  }
}
#endregion functions
Clear-Host
start-sleep -m 250
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
if($result -eq [Windows.Forms.DialogResult]::OK) 
{
  $destFolder = Split-Path -Path $PickFolder.FileName
  Write-Host -Object "Selected Location: $destFolder" -ForegroundColor Green
  Write-Host -Object 'Please Wait. Generating Filelist.'

  $filelist = Get-ChildItem -Path "$destFolder" -Include $extensions -Recurse
  $num = $filelist | Measure-Object
  $filecount = $num.count
}

else 
{
  Write-Host -Object 'File Save Dialog Canceled' -ForegroundColor Yellow
}


ForEach ($file in $filelist)
{
  $i++
  $processing = ${akt-action-p}
  #region begin Files
  $oldfile = $file.DirectoryName + '\' + $file.BaseName + $file.Extension
  $newfile = $file.DirectoryName + '\' + $file.BaseName + '.neu' + '.mkv' #$file.Extension #replace $file.Extension with '.mkv' to make every vo
  $ignorefilepath = $file.DirectoryName + '\'
  $ignorefile = $file.DirectoryName + '\' + '.ignore'
  $progress = ($i / $filecount) * 100
  $progress = [Math]::Round($progress,2)
  #endregion Files
  #region begin getting Mediainfo
  $audioformat = Get-MediaInfoValue -Path $oldfile -Kind Audio -Parameter 'Format'
  $videoformat = Get-MediaInfoValue -Path $oldfile -Kind Video -Parameter 'Format'
  if ($audioformat -eq ${audio-codec-aac} -AND $videoformat -eq ${video-codec-hevc})
  {$processing = ${akt-action-s}}
  [Int]$audiochanels = Get-MediaInfoValue -Path $oldfile -Kind Audio -Parameter 'Channel(s)'
  [Int]$audiocount = Get-MediaInfoValue -Path $oldfile -Kind General -Parameter 'AudioCount'
  $videodauer = Get-MediaInfoValue -Path $oldfile -Kind General -Parameter 'Duration'
  [Int]$videoresW = Get-MediaInfoValue -Path $oldfile -Kind 'Video' -Parameter 'Width'
  [Int]$videoresH = Get-MediaInfoValue -Path $oldfile -Kind 'Video' -Parameter 'Height'
  $videodauerminuten = [math]::Floor($videodauer/60000)
  #$outpufile_vorhanden = Test-Path -Path $newfile
  #endregion getting Mediainfo

    
  Variable-Instanzen
  #region begin Write host
  Clear-Host
  start-sleep -m 250
  Write-Host -Object -Filestats---------------------------------------------------------------------
  Write-Host -Object "MKV Batch Encoding File $i of $filecount - $progress%"
  Write-Host -Object "Processing : $oldfile" 
  Write-Host -Object "Audiocount / Format / Channels : $audiocount / $audioformat / $audiochanels"
  Write-Host -Object "Videoformat / Resolution : $videoformat / $videoresW : $videoresH"
  Write-Host -Object "VideoLaufzeit : $videodauer / $videodauerminuten"
  Write-Host -Object -Jobs--------------------------------------------------------------------------
  Write-Host -Object "FFMPEG Instanzen : $zahlffmpg / $zahlffmpgmax"
  Write-Host -Object "Handbrake Instanzen : $zahlhandb / $zahlhandbmax"
  Write-Host -Object -Step--------------------------------------------------------------------------
  If ($processing -eq ${akt-action-s})
  {
    Write-Host -Object "$processing" -ForegroundColor Red
  } 
  If ($processing -eq ${akt-action-p})
  {
    Write-Host -Object "$processing" -ForegroundColor Green
  }
  #endregion Write host
  Newfile-Vorhanden

  #ist AAC und ist HEVC
  if ($audioformat -eq ${audio-codec-aac} -AND $videoformat -eq ${video-codec-hevc})
  {continue}

  #kein AAC aber HEVC - FFMPEG
  if ($audioformat -NE ${audio-codec-aac} -AND $videoformat -eq ${video-codec-hevc})
  {
    #Suround
    if($audiochanels -gt '3')
    {
      $aacbitrate = ${audio-codec-bitrate-256}
      $aachz = '48000'
      Write-Host -Object 'FFMPEG Surround copy Video'
      check-ignore
      FFmpeg-Encode
    }
    #stereo oder mono
    if($audiochanels -lt '3')
    {
      $aacbitrate = ${audio-codec-bitrate-128}
      $aachz = '44100'
      Write-Host -Object 'FFMPEG Stereo copy Video'
      check-ignore
      FFmpeg-Encode
    }
  }

  #kein AAC und kein HEVC - Handbrake
  if ($audioformat -NE ${audio-codec-aac} -AND $videoformat -NE ${video-codec-hevc})
  {
    #Suround
    if($audiochanels -gt '3')
    {
      $handbrakeaudiocodec = ${hb-audiocodec}
      $handbrakeaudiobitrate = ${audio-codec-bitrate-256}
      $handbrakenormalize = '1'
      $hbmixdown = '5point1'
      Write-Host -Object 'Handbrake Surround full convert'
      check-ignore
      Handbrake-Encoderfull
    }
    #stereo oder mono
    if($audiochanels -lt '3')
    {
      $handbrakeaudiocodec = ${hb-audiocodec}
      $handbrakeaudiobitrate = ${audio-codec-bitrate-128}
      $handbrakenormalize = '1'
      $hbmixdown = 'stereo'
      Write-Host -Object 'Handbrake Stereo full convert'
      check-ignore
        Handbrake-Encoderfull
      }
    }

    #Mit ACC aber kein HEVC - Handbrake
    if ($audioformat -eq ${audio-codec-aac} -AND $videoformat -ne ${video-codec-hevc})
    {
      Write-Host -Object 'Handbrake copy audio'
      $handbrakeaudiocodec = 'copy'
      check-ignore
      Handbrake-Encoderaudiocopy
    }
  }
