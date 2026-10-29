# Run a pipeline Python script inside the p6drought conda environment without `conda activate`.
# Usage: powershell -File run_py.ps1 <script.py> [args...]
# conda env: $env:P6_CONDA_ENV if set, otherwise the default Anaconda location in the user profile
$envp = $env:P6_CONDA_ENV; if (-not $envp) { $envp = Join-Path $env:USERPROFILE "anaconda3\envs\p6drought" }
$env:PATH = "$envp;$envp\Library\mingw-w64\bin;$envp\Library\usr\bin;$envp\Library\bin;$envp\Scripts;$env:PATH"
$env:GDAL_DATA = "$envp\Library\share\gdal"
$env:PROJ_LIB = "$envp\Library\share\proj"
$env:PROJ_DATA = "$envp\Library\share\proj"
$env:PYTHONDONTWRITEBYTECODE = "1"
& "$envp\python.exe" -I @args
exit $LASTEXITCODE
