# Upload the staged Zenodo deposit as a DRAFT (never published by this script) and reserve its DOI.
# Token: a Zenodo personal access token (scopes deposit:write, deposit:actions) saved in $HOME\.zenodo_token.
# Rerunning resumes: the draft id is kept in deposition.json and files already uploaded with the same MD5 are skipped.
# Usage: powershell -File scripts/29_zenodo_upload.ps1 "<Submission folder>\11_Zenodo" [-Sandbox]
param([Parameter(Mandatory = $true)][string]$Dir, [switch]$Sandbox)
$ErrorActionPreference = "Stop"
$api = if ($Sandbox) { "https://sandbox.zenodo.org/api" } else { "https://zenodo.org/api" }
$tokFile = Join-Path $HOME ".zenodo_token"
if (-not (Test-Path $tokFile)) { throw "No token: save it in $tokFile" }
$tok = (Get-Content $tokFile -Raw).Trim()
$hdr = @{ Authorization = "Bearer $tok" }
$state = Join-Path $Dir "deposition.json"

function Utf8([string]$s) { , [byte[]][Text.Encoding]::UTF8.GetBytes($s) }   # leading comma: return the byte array unrolled-free

if (Test-Path $state) {
    $id = (Get-Content $state -Raw | ConvertFrom-Json).id
    $dep = Invoke-RestMethod -Uri "$api/deposit/depositions/$id" -Headers $hdr
} else {
    $meta = Get-Content (Join-Path $Dir "zenodo_metadata.json") -Raw -Encoding UTF8
    $dep = Invoke-RestMethod -Method Post -Uri "$api/deposit/depositions" -Headers $hdr -ContentType "application/json" -Body (Utf8 "{}")
    $dep = Invoke-RestMethod -Method Put -Uri "$api/deposit/depositions/$($dep.id)" -Headers $hdr -ContentType "application/json" -Body (Utf8 "{`"metadata`": $meta}")
    @{ id = $dep.id; doi = $dep.metadata.prereserve_doi.doi; api = $api } | ConvertTo-Json | Set-Content $state -Encoding UTF8
}
if ($dep.submitted) { throw "Deposition $($dep.id) is already published; create a new version instead." }
$bucket = $dep.links.bucket
$have = @{}; $fid = @{}; foreach ($f in $dep.files) { $have[$f.filename] = $f.checksum; $fid[$f.filename] = $f.id }

# smallest first, so code, supplementary material and README are online before the large data archives
$files = @(Get-ChildItem $Dir -Filter *.zip) + @(Get-Item (Join-Path $Dir "README.md"), (Join-Path $Dir "SHA256SUMS.txt")) | Sort-Object Length
foreach ($f in $files) {
    $md5 = (Get-FileHash $f.FullName -Algorithm MD5).Hash.ToLower()
    if ($have[$f.Name] -eq $md5) { Write-Output "skip  $($f.Name) (already uploaded)"; continue }
    if ($fid[$f.Name]) {                                   # changed since the last upload: remove the old copy first
        Invoke-RestMethod -Method Delete -Uri "$api/deposit/depositions/$($dep.id)/files/$($fid[$f.Name])" -Headers $hdr | Out-Null
        Write-Output "del   $($f.Name) (changed)"
    }
    Write-Output ("put   {0} ({1:N1} MB)" -f $f.Name, ($f.Length / 1MB))
    $out = & curl.exe -sS --fail --retry 3 -H "Authorization: Bearer $tok" -H "Content-Type: application/octet-stream" --upload-file $f.FullName "$bucket/$($f.Name)"
    if ($LASTEXITCODE -ne 0) { throw "Upload of $($f.Name) failed (curl exit $LASTEXITCODE)" }
    $got = ($out | ConvertFrom-Json).checksum -replace "^md5:", ""
    if ($got -ne $md5) { throw "MD5 mismatch for $($f.Name): local $md5, Zenodo $got" }
}
$doi = (Get-Content $state -Raw | ConvertFrom-Json).doi
Write-Output "Draft $($dep.id) ready; reserved DOI $doi"
Write-Output "Review and publish at $($dep.links.html)"
