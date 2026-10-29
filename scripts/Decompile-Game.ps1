<#
.SYNOPSIS
    Decompiles the game's own assemblies into decompiled\, a PRIVATE local git repository with one branch per game version.

.DESCRIPTION
    Hearthstone Access DevTools workflow (docs/01-setup-and-tooling.md, docs/05-quality-and-updates.md):
    - decompiled\ is its own git repository, ignored by the mod repository. NEVER push, publish or share it:
      it contains the game's proprietary code.
    - Each run creates a branch named after the game version, forked from the branch you are on
      (the previous version), decompiles into it and commits. After a game update:
          .\scripts\Decompile-Game.ps1 -GamePath "C:\...\Game" -Version 1.4.2
          cd decompiled; git diff 1.4.1 1.4.2 --stat
      shows exactly what the update changed, then `git diff 1.4.1 1.4.2 -- <path of a hooked class>`.
    - Engine, framework and third-party assemblies are skipped: they are not the game's code and are huge.

    Requires: git, and ilspycmd (dotnet tool install ilspycmd -g).

.PARAMETER GamePath
    The game folder (contains the .exe). Defaults to the "game" junction at the project root if present.

.PARAMETER Version
    The game version, used as branch name (e.g. 1.4.2 or 2024-06-01). Read it from the game's title screen,
    launcher, Steam build id, or the mod loader log. Required: guessing a version would mix evidence of two builds.

.PARAMETER Only
    Optional: decompile only these assembly file names (e.g. Assembly-CSharp.dll). Default: all game assemblies.

.EXAMPLE
    .\scripts\Decompile-Game.ps1 -GamePath "C:\Games\MyGame" -Version 1.0.3
#>
param(
    [string]$GamePath = (Join-Path $PSScriptRoot "..\game"),
    [Parameter(Mandatory = $true)][string]$Version,
    [string[]]$Only
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$out = Join-Path $root "decompiled"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Error "git not found. Install it: winget install Git.Git" }
if (-not (Get-Command ilspycmd -ErrorAction SilentlyContinue)) { Write-Error "ilspycmd not found. Install it: dotnet tool install ilspycmd -g (then restart the terminal)" }
if (-not (Test-Path $GamePath)) { Write-Error "Game folder not found: $GamePath (pass -GamePath)" }

# Unity: <Game>_Data\Managed. Other .NET games: the folder with the game's DLLs (pass it as -GamePath).
$managed = Get-ChildItem -Path $GamePath -Directory -Filter "*_Data" | ForEach-Object { Join-Path $_.FullName "Managed" } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $managed) { $managed = $GamePath }
Write-Host "Assemblies: $managed"

# Not the game's own code. Extend for this game if needed (record the list in docs/game-api.md).
$skip = @("Unity", "System", "Mono.", "mscorlib", "netstandard", "Microsoft.", "Newtonsoft.", "Google.", "Firebase",
          "Facebook", "Sentry", "DOTween", "Cinemachine", "Rewired", "Steamworks", "com.rlabrecque", "TextMeshPro",
          "MelonLoader", "0Harmony", "BepInEx", "Il2Cpp")

# Private repository, created on first run.
if (-not (Test-Path (Join-Path $out ".git"))) {
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    git -C $out init -q
    Set-Content -Path (Join-Path $out "README.txt") -Value "PRIVATE. Decompiled proprietary game code. Never push, publish or share this repository."
    git -C $out add README.txt
    git -C $out -c user.name="decompiler" -c user.email="decompiler@localhost" commit -q -m "Private decompiled game code"
}

if (git -C $out status --porcelain) { Write-Error "decompiled\ has uncommitted changes. Commit or discard them first." }
if (git -C $out branch --list $Version) { Write-Error "Version $Version was already decompiled (branch exists). To redo: git -C decompiled branch -D $Version" }

$previous = git -C $out rev-parse --abbrev-ref HEAD
git -C $out checkout -q -b $Version
# Start from an empty tree so files the update removed disappear from the diff too.
Get-ChildItem -Path $out -Force | Where-Object { $_.Name -notin @(".git", "README.txt") } | Remove-Item -Recurse -Force

$assemblies = Get-ChildItem -Path $managed -Filter "*.dll" | Where-Object {
    $name = $_.Name
    if ($Only) { return $Only -contains $name }
    -not ($skip | Where-Object { $name.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })
}
$i = 0
foreach ($dll in $assemblies) {
    $i++
    Write-Host "($i/$($assemblies.Count)) $($dll.Name)"
    $target = Join-Path $out $dll.BaseName
    $ErrorActionPreference = "Continue"  # ilspycmd writes warnings to stderr; Windows PowerShell would turn them into errors
    ilspycmd -p -o $target -r $managed $dll.FullName 2>&1 | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    # One unreadable assembly (native stub, obfuscated helper) must not cost the whole version.
    if ($code -ne 0) { Write-Warning "  skipped $($dll.Name) (ilspycmd exit $code)"; if (Test-Path $target) { Remove-Item -Recurse -Force $target } }
}

Set-Content -Path (Join-Path $out "GAME_VERSION") -Value $Version
git -C $out add -A
git -C $out -c user.name="decompiler" -c user.email="decompiler@localhost" commit -q -m "Decompiled $Version"
Write-Host ""
Write-Host "Decompiled $Version into decompiled\ (branch $Version, forked from $previous)."
if ($previous -ne "master" -and $previous -ne "main") {
    Write-Host "What the update changed:  git -C decompiled diff $previous $Version --stat"
}
