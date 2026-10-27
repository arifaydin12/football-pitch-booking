<#
.SYNOPSIS
  Builds the Firebase-free demo and copies it into docs/ for GitHub Pages.

.DESCRIPTION
  GitHub Pages serves the `main` branch from /docs, so the generated site is
  committed. The app is built with DEMO_MODE=true (in-memory sample data, no
  Firebase) and a base href that matches the repository page.

.EXAMPLE
  ./scripts/build_demo.ps1
  ./scripts/build_demo.ps1 -BaseHref /my-fork/
#>
param(
  [string]$BaseHref = '/football-pitch-booking/'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

  flutter build web --release --dart-define=DEMO_MODE=true --base-href $BaseHref
  if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

  $docs = Join-Path $root 'docs'
  if (-not (Test-Path $docs)) { New-Item -ItemType Directory -Path $docs | Out-Null }

  # Replace the previous build but leave anything that is not generated alone.
  Get-ChildItem -Path $docs -Force | Remove-Item -Recurse -Force
  Copy-Item -Path (Join-Path $root 'build/web/*') -Destination $docs -Recurse -Force

  # Keep the committed site small: this JavaScript build only needs the
  # CanvasKit renderer, not the Wasm renderers or the debug symbol files.
  $renderers = Join-Path $docs 'canvaskit'
  if (Test-Path $renderers) {
    Get-ChildItem -Path $renderers -Recurse -File |
      Where-Object { $_.Name -like '*.symbols' } | Remove-Item -Force
    Get-ChildItem -Path $renderers -File |
      Where-Object { $_.Name -like 'skwasm*' -or $_.Name -like 'wimp*' } | Remove-Item -Force
    $webParagraph = Join-Path $renderers 'webparagraph'
    if (Test-Path $webParagraph) { Remove-Item -Path $webParagraph -Recurse -Force }
  }

  Remove-Item -Path (Join-Path $docs '.last_build_id') -Force -ErrorAction SilentlyContinue

  # Tell GitHub Pages not to run Jekyll over the generated files.
  New-Item -ItemType File -Path (Join-Path $docs '.nojekyll') -Force | Out-Null

  Write-Host "Demo written to docs/ (base href $BaseHref)."
}
finally {
  Pop-Location
}
