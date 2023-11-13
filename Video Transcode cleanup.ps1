﻿#requires -Version 3.0 -Modules Get-MediaInfo
Add-Type -AssemblyName System.Windows.Forms
  $anzahl = 0 
  $i = 0
  $errorduration = 0

Function Format-FileSize() 
{
  Param ([Parameter(Mandatory=$true)][long]$size)
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

Clear-Host
$PickFolder = New-Object -TypeName System.Windows.Forms.OpenFileDialog
$PickFolder.FileName = 'Your Mediafolder'
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


  $filelist = Get-ChildItem -Path "$destFolder" -Recurse |Where-Object -FilterScript {
    $_.Name -Like '*mkv' -or $_.Name -Like '*mp4' 
  }

  ForEach ($file in $filelist)
  {
    $i++
    $oldfile = $file.DirectoryName + '\' + $file.BaseName + $file.Extension
    $newfile = $file.DirectoryName + '\' + $file.BaseName + '.neu' + $file.Extension
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
    $ignorefile = $file.DirectoryName + '\' + '.ignore'

    Write-Host -Object "Processing - $oldfile"
    
    #Suche nach MKV Dateien
    if([IO.File]::Exists($oldfile) -AND [IO.File]::Exists($newfile))
    {
      Write-Host -Object 'beide da'
      Write-Host -Object "$oldfile"
      Write-Host -Object "$newfile"
      $anzahl++
      Write-Host -Object "Anzahl: $anzahl"

      #Wenn .mkv oder .mp4 im namen vorhanden        
      if ($oldfile -like '*.mkv*' -or $oldfile -like '*.mp4*')
      {
        Write-Host -Object 'ist mkv'
        $sizeold = Format-FileSize -size ((Get-Item -Path $oldfile).length)
        $sizenew = Format-FileSize -size ((Get-Item -Path $newfile).length)
        Write-Host 'Größe Alt':($sizeold)
        Write-Host 'Größe Neu':($sizenew)

        #region begin Vergleiche dauer
        [string]$videodaueralt = Get-MediaInfoValue -Path $oldfile -Kind General -Parameter 'Duration'
        $videodaueraltminuten = [math]::Floor($videodaueralt/60000)
        Write-Host -Object "Dauer Alt : $videodaueralt / $videodaueraltminuten"
        [string]$videodauerneu = Get-MediaInfoValue -Path $newfile -Kind General -Parameter 'Duration'
        $videodauerneuminuten = [math]::Floor($videodauerneu/60000)
        Write-Host -Object "Dauer Neu : $videodauerneu / $videodauerneuminuten"
        #endregion Vergleiche dauer
        
        #Wenn dauer gleich altes File löschen und neues File in altes File umbenennen
        if($videodaueraltminuten -eq $videodauerneuminuten) 
        {
          Remove-Item -LiteralPath $oldfile -Confirm:$false -Verbose
          Rename-Item -LiteralPath $newfile -NewName $oldfile -Confirm:$false -Verbose
        }
        else
        {
          Write-Host -Object "Länge unterschiedlich : $videodaueraltminuten / $videodauerneuminuten" -ForegroundColor Red
          $errorduration++
          $errordurationfolder = $file.DirectoryName
        }
        Start-Sleep -Seconds 2
      }
    }

    #Suche nach NFO Dateien
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
    if([IO.File]::Exists($ignorefile)){
      Remove-Item -LiteralPath $ignorefile -force -confirm:$false -Verbose
    }
  }
}
else 
{
  Write-Host -Object 'File Save Dialog Canceled' -ForegroundColor Yellow

  #    &$commands
}
Write-Host -Object "Anzahl bearbeitet : $anzahl" -ForegroundColor Green
Write-Host -Object "Anzahl mit Fehler: $errorduration" -ForegroundColor Red