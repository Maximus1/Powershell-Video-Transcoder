#requires -Version 3.0 -Modules Get-MediaInfo
$existingVariables = Get-Variable
try
{
  ${encoder-preset} = 'medium'
  ${audio-codec-bitrate-256} = '192k'
  ${audio-codec-bitrate-128} = '128k'
  ${hb-audiocodec} = 'av_aac'
  ${video-codec-hevc} = 'HEVC'
  ${audio-codec-aac} = 'AAC'
  $af = "acompressor=threshold=0.05:ratio=10:attack=200:release=1000"
  $HBDRC = 1.5
  ${Languages-audio-video} = 'ger,deu,de,und,,'
  $extensions = @('*.mkv', '*.mp4', '*.avi')
  $zielextension = '.mkv'
  $seriessessonfolder = '*Staffel 0*'# Your naming for Seasons comes here. !!don´t remove the stars!!
  $series720p = 0
  $zahlffmpg = 0
  $videoquality = 22
  $HBHWDec = 'nvdec'
  $subtitlelanglist = ${Languages-audio-video} #<---- Your Subtitle Languages to keep
  $audiotitlelanglist = ${Languages-audio-video} #<---- Your Audio Languages to keep
  $zahlffmpgmax = 5
  $zahlhandb = 0
  $zahlhandbmax = 2
  $ffmpgexe = "$env:ProgramFiles\EibolSoft\FFmpeg Batch AV Converter\ffmpeg.exe" #<---- Your path to FFmpeg 
  $handbrakeexe = "$env:ProgramW6432\HandBrake\HandBrakeCLI.exe" #<---- Your path to Handbrakecli
  $textoutput = "$env:USERPROFILE\Desktop\test.txt" #<---- Your path to Textfile
  $waitprocess = 10
  $warteffmpeg = 0
  $wartehb = 0
  $newfile = ''
  $i = 0
  $filelist =''


  Add-Type -AssemblyName System.Windows.Forms
  #region begin functions
  #If Season in Path set encoded video to 720p else use movie Settings
  function Check-Series
  {
    if ($file.DirectoryName -like $seriessessonfolder)
    {
      Write-Host -Object 'Ist Serie'
      if ($videoresH -gt 720)
      {
        Write-Host -Object 'auflösung ist größer als 720P'
        $script:series720p = [int]1
      }
      if($videoresH -le 720)
      {
        Write-Host -Object 'auflösung ist 720P oder kleiner'
        $script:series720p = [int]0
      }
    }
    elseif($file.DirectoryName -notlike $seriessessonfolder)
    {
      Write-Host -Object 'Ist keine Serie'
      $script:series720p = [int]0
    }
  }
  #Set maximum Procecces
  Function Variable-Instanzen
  {
    $script:zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
    $script:zahlffmpg = (Get-Process -Name 'FFmpeg*').count
    $script:Auslastung = (Get-WmiObject -Class win32_processor | Measure-Object -Property LoadPercentage -Average).Average
    Write-Host -Object "Auslastung : $Auslastung"
    Write-Host -Object "Handbrakeinstanzen : $zahlhandb"
    if ($zahlhandb -lt 2 -and $Auslastung -lt 75)
    {
      $script:zahlffmpgmax = 10
      $script:zahlhandbmax = 2
    }
    if ($zahlhandb -eq 2 -and $Auslastung -ge 75)
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
      if ($oldfile -like '*.mkv*' -or $oldfile -like '*.mp4*' -or $oldfile -like '*.avi*')
      {
        $sizeold = (Get-Item -Path $oldfile).length
        $sizeold = Format-FileSize -size $sizeold
        $sizenew = Format-FileSize -size ((Get-Item -Path $newfile).length)
        Write-Host 'Größe Alt':($sizeold)
        Write-Host 'Größe Neu':($sizenew)
      }
      Get-Audiocount
      Compare-videolength
      Get-newnfofile
      Remove-newmedia
      continue
    }
  }

  #Check for existing .ignore file
  function check-ignore
  {
    if([IO.File]::Exists($ignorefile))
    {
      Write-Host -Object '.ignore file exists.'
    }
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

  #Filesize conversion
  Function Format-FileSize()
  {
    Param ([Parameter(Mandatory)][long]$size)
    If ($size -gt 1TB)
    {
      [string]::Format('{0:0.00} TB', $size / 1TB)
    }
    ElseIf ($size -gt 1GB)
    {
      [string]::Format('{0:0.00} GB', $size / 1GB)
    }
    ElseIf ($size -gt 1MB)
    {
      [string]::Format('{0:0.00} MB', $size / 1MB)
    }
    ElseIf ($size -gt 1KB)
    {
      [string]::Format('{0:0.00} kB', $size / 1KB)
    }
    ElseIf ($size -gt 0)
    {
      [string]::Format('{0:0.00} B', $size)
    }
    Else
    {
      ''
    }
  }

  #Suche nach MKV Dateien
  Function Newfile-check
  {
    Try
    {
      if([IO.File]::Exists($oldfile) -AND [IO.File]::Exists($newfile))
      {
        Write-Host -Object 'beide da'
        Write-Host -Object "$oldfile"
        Write-Host -Object "$newfile"
      }
    }
    Catch
    {
      Write-Host -Object $newfile 'existiert nicht'
    }
  }

  function Get-Audiocount
  {
    $audiocountnew = (Get-MediaInfoValue -Path $newfile -Kind General -Parameter 'AudioCount')
    if ($audiocountnew -lt '1')
    {
      Write-Host -Object "Keine Audiospur gefunden in :($newfile)"
      Remove-Item -LiteralPath $newfile -Confirm:$false -Verbose
      continue
    }
  }
       
  function Compare-videolength
  {
    $videodaueralt = (Get-MediaInfoValue -Path $oldfile -Kind General -Parameter 'Duration')
    $videodaueraltminuten = [math]::Floor($videodaueralt/60000)
    Write-Host -Object "Dauer Alt : $videodaueralt / $videodaueraltminuten"
    [string]$videodauerneu = Get-MediaInfoValue -Path $newfile -Kind General -Parameter 'Duration'
    $videodauerneuminuten = [math]::Floor($videodauerneu/60000)
    Write-Host -Object "Dauer Neu : $videodauerneu / $videodauerneuminuten"
    if($videodaueraltminuten -eq $videodauerneuminuten)
    {
      Remove-Item -LiteralPath $oldfile -Confirm:$false -Verbose
      Rename-Item -LiteralPath $newfile -NewName $newfilerename -Confirm:$false -Verbose
    }
    else
    {
      Write-Host -Object "Länge unterschiedlich : $videodaueraltminuten / $videodauerneuminuten" -ForegroundColor Red
      Remove-Item -LiteralPath $newfile -Confirm:$false -Verbose
      Start-Sleep -Seconds 2
      continue
    }
  }

  function Get-newnfofile
  {
    if([IO.File]::Exists($oldfilenfo) -AND [IO.File]::Exists($newfilenfo))
    {
      Write-Host -Object 'beide da'
      Write-Host -Object "$oldfilenfo"
      Write-Host -Object "$newfilenfo"
    
      #Wenn .nfo im namen vorhanden
      if ($oldfilenfo -like '*.nfo*')
      {
        Write-Host -Object 'ist nfo'
        Remove-Item -LiteralPath $oldfilenfo -Confirm:$false -Verbose
        Rename-Item -LiteralPath $newfilenfo -NewName $oldfilenfo -Confirm:$false -Verbose
      }
    }
  }

  function Remove-newmedia
  {
    if([IO.File]::Exists($newfilebildneuclearlogopng))
    {
      Remove-Item -LiteralPath $newfilebildneuclearlogopng -Confirm:$false -Verbose
    }
    if([IO.File]::Exists($newfilebildneufanartjpg))
    {
      Remove-Item -LiteralPath $newfilebildneufanartjpg -Confirm:$false -Verbose
    }
    if([IO.File]::Exists($newfilebildneuposterjpg))
    {
      Remove-Item -LiteralPath $newfilebildneuposterjpg -Confirm:$false -Verbose
    }
    if([IO.File]::Exists($newfilebildneudiscartpng))
    {
      Remove-Item -LiteralPath $newfilebildneudiscartpng -Confirm:$false -Verbose
    }
    if([IO.File]::Exists($newfilebildneulandscapejpg))
    {
      Remove-Item -LiteralPath $newfilebildneulandscapejpg -Confirm:$false -Verbose
    }
    if([IO.File]::Exists($newfilebildneubannerjpg))
    {
      Remove-Item -LiteralPath $newfilebildneubannerjpg -Confirm:$false -Verbose
    }
    if([IO.File]::Exists($newfilebildneuclearartpng))
    {
      Remove-Item -LiteralPath $newfilebildneuclearartpng -Confirm:$false -Verbose
    }
    if([IO.File]::Exists($newfilebildneuthumbjpg))
    {
      Remove-Item -LiteralPath $newfilebildneuthumbjpg -Confirm:$false -Verbose
    }
    if([IO.File]::Exists($ignorefile))
    {
      Remove-Item -LiteralPath $ignorefile -Force -Confirm:$false -Verbose
    }
  }

  #Encode Audio only with FFmpg
  function FFmpeg-Encode
  {
    $zahlffmpg = (Get-Process -Name 'FFmpeg*').count
    if ($zahlffmpg -lt $zahlffmpgmax )
    {
      Start-Process  -FilePath $ffmpgexe -ArgumentList  "-i `"$oldfile`" -c:v copy -c:a aac -ab `"$aacbitrate`" -ar `"$aachz`" -filter:a loudnorm -af `"$af`" `"$newfile`""
      Write-Oldfileitem
    }
    else
    {
      while ($zahlffmpg -ge $zahlffmpgmax -or $Auslastung -ge 75)
      {
        if ($warteffmpeg -lt 1)
        {
          Write-Host -Object 'warte auf FFmpeg'
          $warteffmpeg = 1
        }
        Start-Sleep -Seconds $waitprocess
        $zahlffmpg = (Get-Process -Name 'FFmpeg*').count
        Variable-Instanzen
      }
      $warteffmpeg = 0
      Start-Process  -FilePath $ffmpgexe -ArgumentList  "-i `"$oldfile`" -c:v copy -c:a aac -ab `"$aacbitrate`" -ar `"$aachz`" -filter:a loudnorm -af `"$af`" `"$newfile`""
      Write-Oldfileitem
    }
  }

  #Encode Audio and Video wit HandbrakeCli
  function Handbrake-Encoderfull
  {
    $zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
    if ($zahlhandb -lt $zahlhandbmax -and $Auslastung -lt 75)
    {
      Write-Host -Object "$zahlhandb / $zahlhandbmax"
      if($series720p -eq [int]0)
      {
        Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset `"${encoder-preset}`" --vfr --enable-hw-decoding `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle --audio-lang-list `"$audiotitlelanglist`" --first-audio -E `"$handbrakeaudiocodec`" --mixdown `"$hbmixdown`" -B `"$handbrakeaudiobitrate`" -R `"$handbrakehz`" --normalize-mix `"$handbrakenormalize`" -D `"$HBDRC`" -i `"$oldfile`" -o `"$newfile`""
        Write-Oldfileitem
      }
      if($series720p -eq [int]1)
      {
        Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset `"${encoder-preset}`" -l 720 --loose-anamorphic --keep-display-aspect --vfr --enable-hw-decoding `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle --audio-lang-list `"$audiotitlelanglist`" --first-audio -E `"$handbrakeaudiocodec`" --mixdown `"$hbmixdown`" -B `"$handbrakeaudiobitrate`" -R `"$handbrakehz`" --normalize-mix `"$handbrakenormalize`" -D `"$HBDRC`" -i `"$oldfile`" -o `"$newfile`""
        Write-Oldfileitem
      }
    }
    else
    {
      while ($zahlhandb -ge $zahlhandbmax -or $Auslastung -ge 75)
      {
        if ($wartehb -lt 1)
        {
          Write-Host -Object 'warte auf Handbrake'
          $wartehb = 1
        }
        Start-Sleep -Seconds $waitprocess
        $zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
        Variable-Instanzen
      }
      $wartehb = 0
      if($series720p -eq 0)
      {
        Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset `"${encoder-preset}`" --vfr --enable-hw-decoding `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle --audio-lang-list `"$audiotitlelanglist`" --first-audio -E `"$handbrakeaudiocodec`" --mixdown `"$hbmixdown`" -B `"$handbrakeaudiobitrate`" -R `"$handbrakehz`" --normalize-mix `"$handbrakenormalize`" -D `"$HBDRC`" -i `"$oldfile`" -o `"$newfile`""
        Write-Oldfileitem
      }
      if($series720p -eq 1)
      {
        Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset `"${encoder-preset}`" -l 720 --loose-anamorphic --keep-display-aspect --vfr --enable-hw-decoding `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle --audio-lang-list `"$audiotitlelanglist`" --first-audio -E `"$handbrakeaudiocodec`" --mixdown `"$hbmixdown`" -B `"$handbrakeaudiobitrate`" -R `"$handbrakehz`" --normalize-mix `"$handbrakenormalize`" -D `"$HBDRC`" -i `"$oldfile`" -o `"$newfile`""
        Write-Oldfileitem
      }
    }
  }

  #Encode Video only with HandbrtakeCli
  function Handbrake-Encoderaudiocopy
  {
    $zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
    Variable-Instanzen
    if ($zahlhandb -lt $zahlhandbmax -and $Auslastung -lt 75)
    {
      Write-Host -Object "$zahlhandb / $zahlhandbmax"
      if($series720p -eq [int]0)
      {
        Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset medium --vfr --enable-hw-decoding `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle  -E `"$handbrakeaudiocodec`" -i `"$oldfile`" -o `"$newfile`""
        Write-Oldfileitem
      }
      if($series720p -eq [int]1)
      {
        Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset medium -l 720 --loose-anamorphic --keep-display-aspect --vfr --enable-hw-decoding `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle  -E `"$handbrakeaudiocodec`" -i `"$oldfile`" -o `"$newfile`""
        Write-Oldfileitem
      }
    }
    else
    {
      while ($zahlhandb -ge $zahlhandbmax -or $Auslastung -ge 75)
      {
        if ($wartehb -lt 1)
        {
          Write-Host -Object 'warte auf Handbrake'
          $wartehb = 1
        }
        Start-Sleep -Seconds $waitprocess
        $zahlhandb = (Get-Process -Name 'HandbrakeCLI*').count
        Variable-Instanzen
      }
      $wartehb = 0
      if($series720p -eq 0)
      {
        Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset medium --vfr --enable-hw-decoding `"$HBHWDec`" --quality 22 --subtitle-lang-list `"$subtitlelanglist`"  --audio-lang-list `"$audiotitlelanglist`" --first-subtitle -E `"$handbrakeaudiocodec`" -i `"$oldfile`" -o `"$newfile`""
        Write-Oldfileitem
      }
      if($series720p -eq 1)
      {
        Start-Process -FilePath $handbrakeexe -ArgumentList  "-e x265 --encoder-preset medium -l 720 --loose-anamorphic --keep-display-aspect --vfr --enable-hw-decoding `"$HBHWDec`" --quality `"$videoquality`" --subtitle-lang-list `"$subtitlelanglist`" --first-subtitle  -E `"$handbrakeaudiocodec`" -i `"$oldfile`" -o `"$newfile`""
        Write-Oldfileitem
      }
    }
  }

  #endregion functions
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
  if($result -eq [Windows.Forms.DialogResult]::OK)
  {
    $destFolder = Split-Path -Path $PickFolder.FileName
    Write-Host -Object "Selected Location: $destFolder" -ForegroundColor Green
    Write-Host -Object 'Please Wait. Generating Filelist.'

$filelist = ls -Path "$destFolder" -Include $extensions -Recurse

    $num = $filelist | Measure-Object
    $filecount = $num.count

    ForEach ($file in $filelist) #transcode
    {
      $i++
      #region begin Files
      $oldfile = $file.DirectoryName + '\' + $file.BaseName + $file.Extension
      if($oldfile -eq $newfile) #$newfile from loop before
      {
        continue
      }
      $newfile = $file.DirectoryName + '\' + $file.BaseName + '.neu' + $zielextension
      $newfilerename = $file.DirectoryName + '\' + $file.BaseName + $zielextension
      $ignorefilepath = $file.DirectoryName + '\'
      $ignorefile = $file.DirectoryName + '\' + '.ignore'
      $oldfilenfo = $file.DirectoryName + '\' + $file.BaseName + '.nfo'
      $newfilenfo = $file.DirectoryName + '\' + $file.BaseName + '.neu' + '.nfo'
      $newfilebildneuclearlogopng = $file.DirectoryName + '\' + $file.BaseName + '.neu-clearlogo.png'
      $newfilebildneufanartjpg = $file.DirectoryName + '\' + $file.BaseName + '.neu-fanart.jpg'
      $newfilebildneuposterjpg = $file.DirectoryName + '\' + $file.BaseName + '.neu-poster.jpg'
      $newfilebildneudiscartpng = $file.DirectoryName + '\' + $file.BaseName + '.neu-discart.png'
      $newfilebildneuthumbjpg = $file.DirectoryName + '\' + $file.BaseName + '.neu-thumb.jpg'
      $newfilebildneulandscapejpg = $file.DirectoryName + '\' + $file.BaseName + '.neu-landscape.jpg'
      $newfilebildneubannerjpg = $file.DirectoryName + '\' + $file.BaseName + '.neu-banner.jpg'
      $newfilebildneuclearartpng = $file.DirectoryName + '\' + $file.BaseName + '.neu-clearart.png'
      $progress = ($i / $filecount) * 100
      $progress = [Math]::Round($progress,2)
      #endregion Files
      #region begin getting Mediainfo
      #$Videofile = Get-MediaInfoSummary -Path $oldfile
      $audioformat = Get-MediaInfoValue -Path $oldfile -Kind Audio -Parameter 'Format'
      $videoformat = Get-MediaInfoValue -Path $oldfile -Kind Video -Parameter 'Format'
      [Int]$audiochanels = Get-MediaInfoValue -Path $oldfile -Kind Audio -Parameter 'Channel(s)'
      [Int]$audiocount = Get-MediaInfoValue -Path $oldfile -Kind General -Parameter 'AudioCount'
      $videodauer = Get-MediaInfoValue -Path $oldfile -Kind General -Parameter 'Duration'
      [Int]$videoresW = Get-MediaInfoValue -Path $oldfile -Kind 'Video' -Parameter 'Width'
      [Int]$videoresH = Get-MediaInfoValue -Path $oldfile -Kind 'Video' -Parameter 'Height'
      $videodauerminuten = [math]::Floor($videodauer/60000)
      #endregion getting Mediainfo
    
      Variable-Instanzen

      #region begin Write host
      Clear-Host
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
      #endregion Write host
      Newfile-Vorhanden
      Check-Series

      #ist AAC und ist HEVC
      if ($audioformat -eq ${audio-codec-aac} -AND $videoformat -eq ${video-codec-hevc})
      {
        if($series720p -eq 0)
        {
          continue
        }
        if($series720p -eq 1)
        {
          Write-Host -Object 'Handbrake copy audio - Scale to 720P'
          $handbrakeaudiocodec = 'copy'
          check-ignore
          Handbrake-Encoderaudiocopy
          continue
        }
      }
  
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

          continue
        }
        #stereo oder mono
        if($audiochanels -lt '3')
        {
          $aacbitrate = ${audio-codec-bitrate-128}
          $aachz = '44100'
          Write-Host -Object 'FFMPEG Stereo copy Video'
          check-ignore
          FFmpeg-Encode
          continue
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
          $handbrakehz = '48'
          $hbmixdown = '5point1'
          Write-Host -Object 'Handbrake Surround full convert'
          check-ignore
          Handbrake-Encoderfull
          continue
        }
        #stereo oder mono
        if($audiochanels -lt '3')
        {
          $handbrakeaudiocodec = ${hb-audiocodec}
          $handbrakeaudiobitrate = ${audio-codec-bitrate-128}
          $handbrakehz = '44.1'
          $handbrakenormalize = '1'
          $hbmixdown = 'stereo'
          Write-Host -Object 'Handbrake Stereo full convert'
          check-ignore
          Handbrake-Encoderfull
          continue
        }
      }

      #Mit ACC aber kein HEVC - Handbrake
      if ($audioformat -eq ${audio-codec-aac} -AND $videoformat -ne ${video-codec-hevc})
      {
        Write-Host -Object 'Handbrake copy audio'
        $handbrakeaudiocodec = 'copy'
        check-ignore
        Handbrake-Encoderaudiocopy
        continue
      }
    }
    Newfile-check
  }
  else
  {
    Write-Host -Object 'File Save Dialog Canceled' -ForegroundColor Yellow
  }
}
finally
{Get-Variable |Where-Object -Property Name -NotIn -Value $existingVariables.Name |Remove-Variable}
  

