#!/usr/bin/env bash
# Public copy of the analysis repository (GitHub and Zenodo): the git-tracked files at HEAD without the agency data
# (data/pmd, data/wapda and the PMD rows of 02_obs_preprocess/stations_monthly.csv), plus an MIT licence.
# The public copy gets its own history, so the agency files in the private history are never published.
# Usage: bash scripts/30_public_export.sh "<output folder>"
set -euo pipefail
A="/d/Papers/Paper 6/analysis"; OUT="$1"
rm -rf "$OUT"; mkdir -p "$OUT"
git -C "$A" archive --format=tar HEAD -- . ':(exclude)data/pmd' ':(exclude)data/wapda' | tar -x -C "$OUT"
awk -F, 'NR==1 || $1 !~ /\(PMD\)/' "$A/02_obs_preprocess/stations_monthly.csv" > "$OUT/02_obs_preprocess/stations_monthly.csv"
if grep -q "(PMD)," "$OUT/02_obs_preprocess/stations_monthly.csv" || [ -e "$OUT/data/pmd" ] || [ -e "$OUT/data/wapda" ]; then
  echo "agency data left in $OUT"; exit 1
fi
cat > "$OUT/LICENSE" <<'EOF'
MIT License

Copyright (c) 2026 Owais Ali

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
printf '%s\n' "data/pmd/" "data/wapda/" "cache_R/" >> "$OUT/.gitignore"
echo "public export of $(git -C "$A" rev-parse --short HEAD): $(find "$OUT" -type f | wc -l) files"
