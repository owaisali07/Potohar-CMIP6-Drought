# Word-only finishing steps for the submission package (needs Microsoft Word):
#   PNG -> 600 dpi LZW TIFF for every figure, continuous line numbers in the manuscript, PDF export of the Word files.
# Usage: powershell -File scripts/24_word_finish.ps1 <submission_dir>
# Word runs inside a background job with a time limit, so that a hidden Word dialog cannot block the script indefinitely.
param([Parameter(Mandatory = $true)][string]$Sub)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# ---- figures: PNG -> TIFF (LZW, 600 dpi); the PNG copies are removed afterwards (kept for the graphical abstract) ----
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/tiff" }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Compression, [long][System.Drawing.Imaging.EncoderValue]::CompressionLZW)
$pngs = @(Get-ChildItem (Join-Path $Sub "03_Figures") -Filter "Fig*.png") + @(Get-ChildItem (Join-Path $Sub "05_Supplementary") -Filter "FigS*.png") + @(Get-ChildItem (Join-Path $Sub "06_Graphical_Abstract") -Filter "*.png")
foreach ($p in $pngs) {
  $img = [System.Drawing.Bitmap]::FromFile($p.FullName); $img.SetResolution(600, 600)
  $tif = [System.IO.Path]::ChangeExtension($p.FullName, ".tif"); $img.Save($tif, $codec, $ep); $img.Dispose()
  if ($p.Directory.Name -ne "06_Graphical_Abstract") { Remove-Item $p.FullName }
  Write-Output ("TIFF: " + $tif)
}

# ---- Word: line numbers (manuscript) and PDF export ----
Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force
$job = Start-Job -ArgumentList ((Resolve-Path $Sub).Path + "\") -ScriptBlock { param($root)
  $w = New-Object -ComObject Word.Application; $w.Visible = $false; $w.DisplayAlerts = 0
  try {
    foreach ($rel in @("01_Manuscript\Manuscript_clean.docx", "05_Supplementary\Supplementary_Material.docx", "02_Title_Page\Title_Page.docx", "07_Cover_Letter\Cover_Letter.docx", "09_Declarations\Declarations.docx")) {
      $f = $root + $rel; $d = $w.Documents.Open($f, $false, $false, $false)   # no conversion prompt, read-write, not added to recent files
      foreach ($sid in @(-1, -41)) { $d.Styles.Item($sid).Font.Name = "Times New Roman" }   # Normal and Line Number styles
      $d.Save()   # continuous line numbers and the equations are already in the manuscript XML (23_build_submission.R)
      if ($rel -like "01_*") { $pdf = $root + "01_Manuscript\Manuscript.pdf" } else { $pdf = [System.IO.Path]::ChangeExtension($f, ".pdf") }
      $d.ExportAsFixedFormat($pdf, 17)   # 17 = PDF
      "PDF: " + $pdf + " (" + $d.ComputeStatistics(2) + " pages)"; $d.Close(0)
    }
  } catch { "ERROR: " + $_ } finally { $w.Quit() }
}
if (Wait-Job $job -Timeout 420) { Receive-Job $job } else { Stop-Job $job; Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force; throw "Word did not finish within 7 minutes" }
