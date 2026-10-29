<#
.SYNOPSIS
    Reads the values a MelonLoader mod needs from the MelonLoader log.

.DESCRIPTION
    Parses MelonLoader\Latest.log and extracts:
    - Game Name and Game Developer (for the MelonGame attribute in Main.cs)
    - Runtime Type (net35 or net6: TargetFramework and the MelonLoader DLL folder in the csproj)
    - Game Type (Mono or Il2Cpp) and Game Arch, if the log has them
    - Unity version and MelonLoader version

    Prints the ready-to-copy MelonGame attribute and the csproj values (TargetFramework, RUNTIME_FOLDER).
    Output is screen-reader friendly: one value per line, no tables.
    See docs/01-setup-and-tooling.md, "CRITICAL: Before First Build - Check Log!".

.PARAMETER GamePath
    Game folder. The log is read from <GamePath>\MelonLoader\Latest.log.

.PARAMETER LogPath
    Path to Latest.log directly. Default: from -GamePath, else game\MelonLoader\Latest.log (the project's
    "game" junction), else MelonLoader\Latest.log in the current directory.

.EXAMPLE
    .\scripts\Get-MelonLoaderInfo.ps1 -GamePath "C:\Program Files (x86)\Steam\steamapps\common\MyGame"

.EXAMPLE
    .\scripts\Get-MelonLoaderInfo.ps1 -LogPath "C:\Games\MyGame\MelonLoader\Latest.log"
#>

param(
    [string]$GamePath,
    [string]$LogPath
)

if (-not $LogPath) {
    if ($GamePath) {
        $LogPath = Join-Path $GamePath "MelonLoader\Latest.log"
    } elseif (Test-Path "game\MelonLoader\Latest.log") {
        $LogPath = "game\MelonLoader\Latest.log"
    } else {
        $LogPath = "MelonLoader\Latest.log"
    }
}

Write-Host ""
Write-Host "MelonLoader log reader"
Write-Host "======================"
Write-Host ""

if (-not (Test-Path -LiteralPath $LogPath)) {
    Write-Host "ERROR: Log file not found."
    Write-Host "   Looked for: $LogPath"
    Write-Host "   Possible causes: MelonLoader is not installed, the game was never started with it, or the path is wrong."
    Write-Host "   Fix: Start the game once with MelonLoader, then run this script again with -GamePath."
    exit 1
}

Write-Host "Log found: $LogPath"
Write-Host ""

$log = Get-Content -LiteralPath $LogPath -Raw

# First match of a "Label: value" line (log lines start with a [time] prefix).
function Get-LogValue {
    param([string]$Pattern)
    if ($log -match "(?m)$Pattern[ \t]*(.+?)[ \t]*\r?$") { return $matches[1].Trim() }
    return $null
}

$gameName = Get-LogValue "Game Name:"
$developer = Get-LogValue "Game Developer:"
$runtime = Get-LogValue "Runtime Type:"
$gameType = Get-LogValue "Game Type:"
$gameArch = Get-LogValue "Game Arch:"
$unity = Get-LogValue "Unity Version:"
if (-not $unity -and $log -match "Game Engine:\s*Unity\s*v?([\d\.]+\w*)") { $unity = $matches[1] }
$melonVersion = if ($log -match "MelonLoader\s+v([\d\.]+)") { $matches[1] } else { $null }

Write-Host "Values found:"
Write-Host "-------------"
Write-Host ""
foreach ($pair in @(
        @("Game Name", $gameName), @("Game Developer", $developer), @("Runtime Type", $runtime),
        @("Game Type", $gameType), @("Game Arch", $gameArch), @("Unity Version", $unity),
        @("MelonLoader Version", $melonVersion))) {
    $value = if ($pair[1]) { $pair[1] } else { "NOT FOUND" }
    Write-Host "$($pair[0]): $value"
}

Write-Host ""
Write-Host "For your project:"
Write-Host "-----------------"
Write-Host ""

if ($developer -and $gameName) {
    Write-Host "MelonGame attribute (Main.cs), copy exactly, capitalization and spaces included:"
    Write-Host "[assembly: MelonGame(`"$developer`", `"$gameName`")]"
    Write-Host "   With a wrong value the mod loads but never initializes, and the log shows no error."
} else {
    Write-Host "WARNING: Cannot build the MelonGame attribute, Game Name or Game Developer is missing."
    Write-Host "   Fix: Open the log and copy both values by hand."
}

Write-Host ""

$runtimeKey = if ($runtime) { $runtime.ToLower() } else { "" }
switch -Regex ($runtimeKey) {
    "^net35$" {
        Write-Host "TargetFramework (csproj): <TargetFramework>net472</TargetFramework>"
        Write-Host "RUNTIME_FOLDER (csproj): net35  (MelonLoader DLLs from MelonLoader\net35\)"
        Write-Host "IMPORTANT: Use net472, NOT netstandard2.0. With netstandard2.0 the mod fails silently."
    }
    "^net6" {
        Write-Host "TargetFramework (csproj): <TargetFramework>net6.0</TargetFramework>"
        Write-Host "RUNTIME_FOLDER (csproj): net6  (MelonLoader DLLs from MelonLoader\net6\)"
    }
    "^$" {
        Write-Host "WARNING: Cannot determine TargetFramework, Runtime Type is missing."
        Write-Host "   Fix: Check which of MelonLoader\net35 and MelonLoader\net6 exists in the game folder."
    }
    default {
        Write-Host "WARNING: Unknown Runtime Type '$runtime'. Check TargetFramework by hand (docs/appendix-a-unity-loaders-harmony.md)."
    }
}

if ($gameType -match "Il2Cpp") {
    Write-Host ""
    Write-Host "Il2Cpp game: reference the generated assemblies in MelonLoader\Il2CppAssemblies\ instead of <Game>_Data\Managed\ (docs/appendix-a-unity-loaders-harmony.md)."
}

if ($unity -match "^(\d+)\." -and [int]$matches[1] -le 5) {
    Write-Host ""
    Write-Host "WARNING: Unity $unity is old. Read docs/appendix-c-legacy-unity.md."
}

$gameRoot = Split-Path (Split-Path (Resolve-Path -LiteralPath $LogPath).Path -Parent) -Parent
if ($gameRoot -match '[^\x20-\x7E]') {
    Write-Host ""
    Write-Host "WARNING: The game path contains non-ASCII characters: $gameRoot"
    Write-Host "   Fix: MelonLoader cannot load from such a path. Create a junction from an ASCII path and install MelonLoader through it (docs/01-setup-and-tooling.md, Tooling Pipeline)."
}

Write-Host ""
Write-Host "Done."
