<#
.SYNOPSIS
    Validates an accessibility mod project built from this template.

.DESCRIPTION
    Checks, in order:
    1. Game folder: exists, game EXE, architecture (from the EXE header), Unity, optional "game" junction.
    2. Mod loader: MelonLoader or BepInEx (detected), its DLL, log and mods folder;
       for MelonLoader also that the game path is plain ASCII.
    3. Speech DLL: Prism or Tolk (+ nvdaControllerClient) next to the EXE, with the game's architecture,
       and every DLL that ScreenReader.cs imports.
    4. Project files: csproj (placeholders, TargetFramework, excludes, embedded localization, loader reference,
       copy target), Main.cs / Plugin.cs with the loader attribute, ScreenReader.cs, DebugLogger.cs, ModConfig.cs.
    5. Accessibility core: AccessibilityMgr, components, AccessibleKey, menus, Compat, ReflectionHelper,
       localization classes; warns about leftovers of the old handler architecture.
    6. Localization: Localization\en\*.txt exists and every key declared in LocalizationKey*.cs has an
       English line (light regex check; "dotnet test Tests" is the real check).
    7. Tests project (Tests\*.csproj).
    8. decompiled\: own git repository, one branch per game version, no remote, ignored by the mod repository.

    Output is screen-reader friendly: one line per check starting with OK, ERROR or WARNING, then "Fix:" lines.
    See docs/01-setup-and-tooling.md, "Helper Scripts".

.PARAMETER GamePath
    Game folder (where the game EXE is). Default: the "game" junction in the project folder, if present.

.PARAMETER ProjectPath
    Mod project folder (where the csproj is). Default: current directory.

.PARAMETER Architecture
    "x64" or "x86". Default: read from the game EXE.

.EXAMPLE
    .\scripts\Test-ModSetup.ps1 -GamePath "C:\Games\MyGame"

.EXAMPLE
    .\scripts\Test-ModSetup.ps1 -GamePath "C:\Games\MyGame" -ProjectPath "C:\Mods\MyGameAccess" -Architecture x86
#>

param(
    [string]$GamePath,

    [string]$ProjectPath = (Get-Location).Path,

    [ValidateSet("x64", "x86")]
    [string]$Architecture
)

$script:errorCount = 0
$script:warningCount = 0
$script:successCount = 0

function Write-Check {
    param(
        [string]$Name,
        [ValidateSet("OK", "ERROR", "WARNING")]
        [string]$Status,
        [string]$Details = ""
    )
    Write-Host "${Status}: $Name"
    switch ($Status) {
        "OK"      { $script:successCount++ }
        "ERROR"   { $script:errorCount++ }
        "WARNING" { $script:warningCount++ }
    }
    if ($Details) { Write-Host "   $Details" }
}

function Write-Fix {
    param([string]$Text)
    Write-Host "   Fix: $Text"
}

# Architecture of a PE file (EXE/DLL) from its header: "x64", "x86", "arm64" or $null.
function Get-PEArchitecture {
    param([string]$Path)
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $reader = New-Object System.IO.BinaryReader($stream)
            $stream.Position = 0x3C
            $stream.Position = $reader.ReadInt32() + 4
            switch ($reader.ReadUInt16()) {
                0x8664 { return "x64" }
                0x014C { return "x86" }
                0xAA64 { return "arm64" }
                default { return $null }
            }
        } finally { $stream.Dispose() }
    } catch { return $null }
}

# Source files of the mod itself: not decompiled game code, templates, tests or build output.
function Get-ModSourceFiles {
    param([string]$Filter)
    $skip = @("decompiled", "templates", "Tests", "recon", "recon-records", "game", "bin", "obj", ".git", ".vs", "scripts", "docs")
    Get-ChildItem -LiteralPath $ProjectPath -Filter $Filter -File -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $ProjectPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $skip -notcontains $_.Name } |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter $Filter -File -Recurse -ErrorAction SilentlyContinue } |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' }
}

function Join-Short {
    param([string[]]$Items, [int]$Max = 10)
    $shown = ($Items | Select-Object -First $Max) -join ", "
    if ($Items.Count -gt $Max) { $shown += " (and $($Items.Count - $Max) more)" }
    return $shown
}

$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction SilentlyContinue).Path
if (-not $ProjectPath) {
    Write-Host "ERROR: Project folder not found."
    exit 1
}
$ProjectPath = $ProjectPath.TrimEnd('\')

$junction = Join-Path $ProjectPath "game"
if (-not $GamePath) {
    if (Test-Path $junction) {
        $GamePath = $junction
    } else {
        Write-Host "ERROR: No game folder given and no 'game' junction in the project folder."
        Write-Host "   Fix: .\scripts\Test-ModSetup.ps1 -GamePath `"C:\Path\to\Game`""
        exit 1
    }
}

Write-Host ""
Write-Host "Mod setup check"
Write-Host "==============="
Write-Host ""
Write-Host "Game folder: $GamePath"
Write-Host "Project folder: $ProjectPath"
Write-Host ""

# ===================
# 1. GAME FOLDER
# ===================

Write-Host "1. Game folder"
Write-Host ""

if (Test-Path -LiteralPath $GamePath) {
    $GamePath = (Resolve-Path -LiteralPath $GamePath).Path.TrimEnd('\')
    Write-Check "Game folder exists" "OK"
} else {
    Write-Check "Game folder exists" "ERROR" "Path not found: $GamePath"
    Write-Fix "Check the path for typos."
    Write-Host ""
    Write-Host "Stopped: the game folder must exist."
    exit 1
}

$gameItem = Get-Item -LiteralPath $GamePath
if ($gameItem.LinkType -eq "Junction" -and $gameItem.Target) {
    $realGamePath = @($gameItem.Target)[0]
} else {
    $realGamePath = $gameItem.FullName
}

$exeFiles = @(Get-ChildItem -LiteralPath $GamePath -Filter "*.exe" -File |
    Where-Object { $_.Name -notmatch "UnityCrashHandler|UnityPlayer|unins|Launcher|Setup|Redist" })
$gameExe = $null
if ($exeFiles.Count -gt 0) {
    $gameExe = $exeFiles[0]
    Write-Check "Game EXE found" "OK" $gameExe.Name
} else {
    Write-Check "Game EXE found" "WARNING" "No EXE in the game folder"
    Write-Fix "Point -GamePath at the folder that contains the game's EXE."
}

$exeArch = if ($gameExe) { Get-PEArchitecture $gameExe.FullName } else { $null }
if (-not $Architecture) {
    if ($exeArch -in @("x64", "x86")) {
        $Architecture = $exeArch
        Write-Check "Architecture" "OK" "$Architecture (read from $($gameExe.Name))"
    } else {
        $Architecture = "x64"
        Write-Check "Architecture" "WARNING" "Could not read it from the EXE, assuming x64"
        Write-Fix "Pass -Architecture x64 or -Architecture x86."
    }
} elseif ($exeArch -and $exeArch -ne $Architecture) {
    Write-Check "Architecture" "WARNING" "You passed $Architecture, but $($gameExe.Name) is $exeArch"
    Write-Fix "Use -Architecture $exeArch, or check that the right EXE was found."
} else {
    Write-Check "Architecture" "OK" $Architecture
}

$dataFolders = @(Get-ChildItem -LiteralPath $GamePath -Directory -Filter "*_Data" -ErrorAction SilentlyContinue)
$isIl2Cpp = Test-Path (Join-Path $GamePath "GameAssembly.dll")
if ((Test-Path (Join-Path $GamePath "UnityPlayer.dll")) -or $dataFolders.Count -gt 0) {
    $flavour = if ($isIl2Cpp) { "Il2Cpp" } else { "Mono" }
    Write-Check "Unity game" "OK" "$flavour build"
} else {
    Write-Check "Unity game" "WARNING" "No UnityPlayer.dll or *_Data folder: the loader checks below assume Unity"
    Write-Fix "For other engines see docs/appendix-d-other-engines.md."
}

if (Test-Path $junction) {
    Write-Check "'game' junction in the project folder" "OK"
} else {
    Write-Check "'game' junction in the project folder" "WARNING" "Optional, recommended (scripts and tests can use game\...)"
    Write-Fix "New-Item -ItemType Junction -Path `"$junction`" -Target `"$realGamePath`""
}

Write-Host ""

# ===================
# 2. MOD LOADER
# ===================

Write-Host "2. Mod loader"
Write-Host ""

$melonPath = Join-Path $GamePath "MelonLoader"
$bepinPath = Join-Path $GamePath "BepInEx"
$hasMelon = Test-Path $melonPath
$hasBepin = Test-Path $bepinPath
$loader = $null

if ($hasMelon -and $hasBepin) {
    Write-Check "Mod loader" "WARNING" "Both MelonLoader and BepInEx are installed"
    Write-Fix "Keep only the loader the project uses (docs/01-setup-and-tooling.md, Step 4e)."
    $csprojText = (Get-ModSourceFiles "*.csproj" | Select-Object -First 1 | ForEach-Object { Get-Content $_.FullName -Raw })
    $loader = if ($csprojText -match 'Include="BepInEx') { "BepInEx" } else { "MelonLoader" }
    Write-Host "   Checking as a $loader project."
} elseif ($hasMelon) {
    $loader = "MelonLoader"
    Write-Check "Mod loader" "OK" "MelonLoader"
} elseif ($hasBepin) {
    $loader = "BepInEx"
    Write-Check "Mod loader" "OK" "BepInEx"
} else {
    Write-Check "Mod loader" "ERROR" "Neither MelonLoader nor BepInEx is installed"
    Write-Fix "Install the loader the game's modding community uses (docs/01-setup-and-tooling.md, Step 4e)."
}

if ($loader -eq "MelonLoader") {
    $melonDlls = @("net6\MelonLoader.dll", "net35\MelonLoader.dll", "MelonLoader.dll") |
        ForEach-Object { Join-Path $melonPath $_ } | Where-Object { Test-Path $_ }
    if ($melonDlls) {
        Write-Check "MelonLoader.dll present" "OK" (@($melonDlls)[0].Substring($GamePath.Length).TrimStart('\'))
    } else {
        Write-Check "MelonLoader.dll present" "ERROR" "Not found in MelonLoader\net6, MelonLoader\net35 or MelonLoader\"
        Write-Fix "Reinstall MelonLoader: https://github.com/LavaGang/MelonLoader.Installer/releases"
    }

    if (Test-Path (Join-Path $melonPath "Latest.log")) {
        Write-Check "MelonLoader\Latest.log present" "OK"
        Write-Host "   Tip: .\scripts\Get-MelonLoaderInfo.ps1 -GamePath `"$GamePath`" reads Game Name, Developer and Runtime Type from it."
    } else {
        Write-Check "MelonLoader\Latest.log present" "WARNING" "The game was never started with MelonLoader"
        Write-Fix "Start the game once, then run Get-MelonLoaderInfo.ps1."
    }

    if (Test-Path (Join-Path $GamePath "Mods")) {
        Write-Check "Mods folder exists" "OK"
    } else {
        Write-Check "Mods folder exists" "WARNING" "Created on the first start with MelonLoader"
    }

    if ($realGamePath -match '[^\x20-\x7E]') {
        Write-Check "Game path is plain ASCII" "ERROR" "MelonLoader cannot load from a path with non-ASCII characters: $realGamePath"
        Write-Fix "Create a junction from an ASCII path (e.g. C:\Games\MyGame) to the game and install MelonLoader through it."
    } else {
        Write-Check "Game path is plain ASCII" "OK"
    }
}

if ($loader -eq "BepInEx") {
    $bepinDlls = @("core\BepInEx.dll", "core\BepInEx.Core.dll") |
        ForEach-Object { Join-Path $bepinPath $_ } | Where-Object { Test-Path $_ }
    if ($bepinDlls) {
        Write-Check "BepInEx core DLL present" "OK" (Split-Path @($bepinDlls)[0] -Leaf)
    } else {
        Write-Check "BepInEx core DLL present" "ERROR" "BepInEx\core\BepInEx.dll not found"
        Write-Fix "Extract the BepInEx ZIP matching the game's architecture into the game folder: https://github.com/BepInEx/BepInEx/releases"
    }

    if (Test-Path (Join-Path $bepinPath "LogOutput.log")) {
        Write-Check "BepInEx\LogOutput.log present" "OK"
    } else {
        Write-Check "BepInEx\LogOutput.log present" "WARNING" "The game was never started with BepInEx"
        Write-Fix "Start the game once so BepInEx creates its folders and log."
    }

    if (Test-Path (Join-Path $bepinPath "plugins")) {
        Write-Check "BepInEx\plugins folder exists" "OK"
    } else {
        Write-Check "BepInEx\plugins folder exists" "WARNING" "Created on the first start with BepInEx"
    }
}

Write-Host ""

# ===================
# 3. SPEECH DLL
# ===================

Write-Host "3. Speech DLL (Prism or Tolk)"
Write-Host ""

function Test-DllArchitecture {
    param([string]$Path)
    $name = Split-Path $Path -Leaf
    $arch = Get-PEArchitecture $Path
    if (-not $arch) {
        Write-Check "$name architecture" "WARNING" "Could not read the DLL header"
    } elseif ($arch -eq $Architecture) {
        Write-Check "$name architecture" "OK" $arch
    } else {
        Write-Check "$name architecture" "ERROR" "$name is $arch, the game is $Architecture"
        Write-Fix "Copy the $Architecture build of $name into the game folder."
    }
}

$prismDll = Get-ChildItem -LiteralPath $GamePath -Filter "prism*.dll" -File -ErrorAction SilentlyContinue | Select-Object -First 1
$tolkDll = Join-Path $GamePath "Tolk.dll"
$hasTolk = Test-Path $tolkDll

if ($prismDll) {
    Write-Check "Prism present" "OK" $prismDll.Name
    Test-DllArchitecture $prismDll.FullName
}

if ($hasTolk) {
    Write-Check "Tolk.dll present" "OK"
    Test-DllArchitecture $tolkDll

    $bits = if ($Architecture -eq "x64") { "64" } else { "32" }
    $otherBits = if ($bits -eq "64") { "32" } else { "64" }
    $nvdaDll = Join-Path $GamePath "nvdaControllerClient$bits.dll"
    if (Test-Path $nvdaDll) {
        Write-Check "nvdaControllerClient$bits.dll present" "OK"
    } else {
        Write-Check "nvdaControllerClient$bits.dll present" "ERROR" "Without it NVDA gets no speech"
        if (Test-Path (Join-Path $GamePath "nvdaControllerClient$otherBits.dll")) {
            Write-Host "   nvdaControllerClient$otherBits.dll is there instead: wrong architecture."
        }
        Write-Fix "Copy nvdaControllerClient$bits.dll from the $Architecture folder of the Tolk download (https://github.com/ndarilek/tolk/releases) into the game folder."
    }
}

if (-not $prismDll -and -not $hasTolk) {
    Write-Check "Speech DLL present" "ERROR" "Neither Prism nor Tolk.dll is in the game folder"
    Write-Fix "Copy Tolk.dll and nvdaControllerClient$(if ($Architecture -eq 'x64') {'64'} else {'32'}).dll ($Architecture) from https://github.com/ndarilek/tolk/releases, or the Prism DLL, next to the game EXE."
}

# The DLLs the mod actually imports must be there.
$screenReaderCs = Get-ModSourceFiles "ScreenReader.cs" | Select-Object -First 1
if ($screenReaderCs) {
    $imports = @([regex]::Matches((Get-Content $screenReaderCs.FullName -Raw), 'DllImport\(\s*"([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    foreach ($import in $imports) {
        $file = if ($import -like "*.dll") { $import } else { "$import.dll" }
        if (Test-Path (Join-Path $GamePath $file)) {
            Write-Check "ScreenReader.cs imports $file, present" "OK"
        } else {
            Write-Check "ScreenReader.cs imports $file" "ERROR" "$file is not in the game folder"
            Write-Fix "Copy $file ($Architecture) next to the game EXE, or change ScreenReader.cs to the speech library you installed."
        }
    }
}

Write-Host ""

# ===================
# 4. PROJECT FILES
# ===================

Write-Host "4. Project files"
Write-Host ""

$csprojFiles = @(Get-ChildItem -LiteralPath $ProjectPath -Filter "*.csproj" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch "Assembly-CSharp" })
$csprojPath = $null

if ($csprojFiles.Count -eq 0) {
    Write-Check "Project file (csproj)" "ERROR" "No csproj in the project folder"
    Write-Fix "Create it from templates\$(if ($loader -eq 'BepInEx') {'bepinex'} else {'melonloader'})\csproj.template."
} else {
    $csprojPath = $csprojFiles[0].FullName
    if ($csprojFiles.Count -eq 1) {
        Write-Check "Project file (csproj)" "OK" $csprojFiles[0].Name
    } else {
        Write-Check "Project file (csproj)" "WARNING" "Several found: $(($csprojFiles | ForEach-Object { $_.Name }) -join ', ')"
        Write-Fix "Always build with the file name: dotnet build $($csprojFiles[0].Name)"
    }
}

if ($csprojPath) {
    $csproj = Get-Content $csprojPath -Raw

    $placeholders = @("TARGET_FRAMEWORK", "SPIELORDNER", "SPIELNAME", "RUNTIME_ORDNER", ">MODNAME<", ">NAMESPACE<") |
        Where-Object { $csproj.Contains($_) } | ForEach-Object { $_.Trim('<', '>') }
    if ($placeholders) {
        Write-Check "csproj placeholders replaced" "ERROR" "Still there: $($placeholders -join ', ')"
        Write-Fix "Replace them as described at the end of the csproj template (game path, data folder, framework, mod name)."
    } else {
        Write-Check "csproj placeholders replaced" "OK"
    }

    if ($csproj -match '<TargetFramework>([^<]+)</TargetFramework>') {
        $framework = $matches[1]
        if ($framework -eq "netstandard2.0") {
            Write-Check "TargetFramework" "ERROR" "netstandard2.0: the mod loads but never initializes"
            Write-Fix "net35 games: net472. net6 games: net6.0. Read Runtime Type from the loader log."
        } else {
            if ($framework -ne "TARGET_FRAMEWORK") { Write-Check "TargetFramework" "OK" $framework }
        }
    } else {
        Write-Check "TargetFramework" "ERROR" "Not found"
    }

    $excludes = @("decompiled", "templates", "Tests", "recon") |
        Where-Object { $csproj -notmatch ('<Compile\s+Remove="' + $_ + '\\\*\*"') }
    if ($excludes) {
        Write-Check "Compile excludes" "ERROR" "Not excluded: $($excludes -join ', ')"
        Write-Fix "Add <Compile Remove=`"<folder>\**`" /> for each, as in the template (otherwise hundreds of build errors)."
    } else {
        Write-Check "Compile excludes (decompiled, templates, Tests, recon)" "OK"
    }

    if ($csproj -match '<EmbeddedResource\s+Include="Localization\\') {
        Write-Check "Localization embedded in the DLL" "OK"
    } else {
        Write-Check "Localization embedded in the DLL" "ERROR" "No EmbeddedResource for Localization\**\*.txt"
        Write-Fix "Copy the Localization ItemGroup from the csproj template."
    }

    if ($loader -eq "MelonLoader") {
        if ($csproj -match '<Reference\s+Include="MelonLoader"') { Write-Check "MelonLoader reference" "OK" }
        else { Write-Check "MelonLoader reference" "ERROR" "Not found"; Write-Fix "Use templates\melonloader\csproj.template." }
        if ($csproj -match 'CopyToMods') { Write-Check "Copy to Mods after build" "OK" }
        else { Write-Check "Copy to Mods after build" "WARNING" "The DLL is not copied automatically"; Write-Fix "Take the CopyToMods target from the template." }
    } elseif ($loader -eq "BepInEx") {
        if ($csproj -match '<Reference\s+Include="BepInEx') { Write-Check "BepInEx reference" "OK" }
        else { Write-Check "BepInEx reference" "ERROR" "Not found"; Write-Fix "Use templates\bepinex\csproj.template." }
        if ($csproj -match 'CopyToPlugins') { Write-Check "Copy to BepInEx\plugins after build" "OK" }
        else { Write-Check "Copy to BepInEx\plugins after build" "WARNING" "The DLL is not copied automatically"; Write-Fix "Take the CopyToPlugins target from the template." }
    }
}

$mainFile = @("Main.cs", "Plugin.cs") | ForEach-Object { Join-Path $ProjectPath $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($mainFile) {
    $mainName = Split-Path $mainFile -Leaf
    Write-Check "$mainName present" "OK"
    $main = Get-Content $mainFile -Raw
    if ($loader -eq "MelonLoader") {
        if ($main -match '\[assembly:\s*MelonGame\s*\(\s*"([^"]*)"\s*,\s*"([^"]*)"\s*\)\s*\]') {
            if ($matches[1] -eq "ENTWICKLER" -or $matches[2] -eq "SPIELNAME") {
                Write-Check "MelonGame attribute" "ERROR" "Placeholders not replaced"
                Write-Fix "Copy Developer and Game Name exactly from the log: .\scripts\Get-MelonLoaderInfo.ps1"
            } else {
                Write-Check "MelonGame attribute" "OK" "Developer: $($matches[1]), Game: $($matches[2])"
            }
        } else {
            Write-Check "MelonGame attribute" "ERROR" "Missing or malformed"
            Write-Fix "Add [assembly: MelonGame(`"Developer`", `"Game Name`")] with the values from the log."
        }
    } elseif ($loader -eq "BepInEx") {
        if ($main -match '\[BepInPlugin\s*\(\s*"([^"]*)"') {
            if ($matches[1] -match 'AUTOR|MODNAME') {
                Write-Check "BepInPlugin attribute" "WARNING" "GUID still has a placeholder: $($matches[1])"
                Write-Fix "Use a unique reverse-domain GUID, e.g. com.yourname.mygameaccess."
            } else {
                Write-Check "BepInPlugin attribute" "OK" $matches[1]
            }
        } else {
            Write-Check "BepInPlugin attribute" "ERROR" "Missing"
            Write-Fix "Take Main.cs from templates\bepinex."
        }
    }
} else {
    Write-Check "Main.cs (or Plugin.cs) present" "ERROR" "Entry point missing"
    Write-Fix "Create Main.cs from the loader's Main.cs.template."
}

foreach ($name in @("ScreenReader.cs", "DebugLogger.cs", "ModConfig.cs")) {
    if (Get-ModSourceFiles $name) {
        Write-Check "$name present" "OK"
    } else {
        Write-Check "$name present" "ERROR" "Missing"
        Write-Fix "Create it from the loader's $name.template."
    }
}

Write-Host ""

# ===================
# 5. ACCESSIBILITY CORE
# ===================

Write-Host "5. Accessibility core"
Write-Host ""

$coreFiles = @(
    "AccessibilityMgr.cs", "AccessibleComponent.cs", "AccessibleKey.cs", "AccessibleMenu.cs", "AccessibleItem.cs",
    "AccessibleListOfItems.cs", "AccessibleModSettings.cs", "Compat.cs", "ReflectionHelper.cs",
    "LocalizationKey.cs", "LocalizationTable.cs", "LocalizationUtils.cs"
)
$accessibilityDir = Join-Path $ProjectPath "Accessibility"
if (Test-Path $accessibilityDir) {
    $present = @(Get-ChildItem -LiteralPath $accessibilityDir -Filter "*.cs" -File -Recurse | ForEach-Object { $_.Name })
    $missing = @($coreFiles | Where-Object { $present -notcontains $_ })
    if ($missing.Count -eq 0) {
        Write-Check "Core files in Accessibility\" "OK" "$($coreFiles.Count) of $($coreFiles.Count)"
    } else {
        Write-Check "Core files in Accessibility\" "ERROR" "Missing: $($missing -join ', ')"
        Write-Fix "Create them from templates\shared (docs/03-architecture.md, 'Creating the core')."
    }
    $screens = @($present | Where-Object { $_ -like "Accessible*.cs" -and $coreFiles -notcontains $_ -and $_ -notlike "AccessibleKey.*" })
    Write-Host "   Screens and UIs so far: $(if ($screens) { Join-Short $screens } else { 'none' })"
} else {
    Write-Check "Accessibility folder" "ERROR" "Not found"
    Write-Fix "Create the core from templates\shared as described in docs/03-architecture.md, 'Creating the core'."
}

$legacy = @(Get-ModSourceFiles "*.cs" | Where-Object { $_.Name -match '^(.+Handler|AccessStateManager|Loc)\.cs$' } | ForEach-Object { $_.Name })
if ($legacy) {
    Write-Check "No old handler architecture" "WARNING" "Found: $(Join-Short $legacy)"
    Write-Fix "Migrate them to Accessible screens and LocalizationKey (docs/03-architecture.md, migration section)."
} else {
    Write-Check "No old handler architecture" "OK"
}

Write-Host ""

# ===================
# 6. LOCALIZATION
# ===================

Write-Host "6. Localization"
Write-Host ""

$localizationDir = Join-Path $ProjectPath "Localization"
$englishDir = Join-Path $localizationDir "en"
$englishKeys = @{}

if (Test-Path $englishDir) {
    $englishFiles = @(Get-ChildItem -LiteralPath $englishDir -Filter "*.txt" -File)
    if ($englishFiles.Count -gt 0) {
        Write-Check "Localization\en\*.txt" "OK" (($englishFiles | ForEach-Object { $_.Name }) -join ", ")
        foreach ($file in $englishFiles) {
            foreach ($line in Get-Content $file.FullName -Encoding UTF8) {
                $key = ($line -split "`t")[0].Trim()
                if ($key -and $key -ne "TAG" -and -not $key.StartsWith("#")) { $englishKeys[$key] = $true }
            }
        }
    } else {
        Write-Check "Localization\en\*.txt" "ERROR" "Folder exists but has no .txt files"
        Write-Fix "Copy templates\shared\Localization\en\Global.txt.template to Localization\en\Global.txt."
    }
    $languages = @(Get-ChildItem -LiteralPath $localizationDir -Directory | Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Filter "*.txt" -File).Count -gt 0 } | ForEach-Object { $_.Name })
    Write-Host "   Languages: $($languages -join ', ')"
} else {
    Write-Check "Localization\en folder" "ERROR" "Not found; English is required (it is the fallback)"
    Write-Fix "Create Localization\en\Global.txt from templates\shared\Localization\en\Global.txt.template."
}

$keyFiles = @(Get-ModSourceFiles "LocalizationKey*.cs")
if ($keyFiles.Count -gt 0) {
    $declared = @($keyFiles | ForEach-Object {
        $code = (Get-Content $_.FullName | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
        [regex]::Matches($code, 'new\s+LocalizationKey\s*\(\s*nameof\s*\(\s*(\w+)\s*\)') |
            ForEach-Object { $_.Groups[1].Value }
    } | Sort-Object -Unique)
    $noEnglish = @($declared | Where-Object { -not $englishKeys.ContainsKey($_) })
    if ($noEnglish.Count -eq 0) {
        Write-Check "Every LocalizationKey has an English line" "OK" "$($declared.Count) keys"
    } else {
        Write-Check "Every LocalizationKey has an English line" "ERROR" "$($noEnglish.Count) without English text: $(Join-Short $noEnglish)"
        Write-Fix "Add KEY<TAB>Text<TAB>Comment lines to Localization\en\<Feature>.txt, then run dotnet test Tests."
    }
} else {
    Write-Check "LocalizationKey*.cs" "ERROR" "No LocalizationKey class found"
    Write-Fix "Create Accessibility\Localization\LocalizationKey.cs from templates\shared\LocalizationKey.cs.template."
}

Write-Host ""

# ===================
# 7. TESTS
# ===================

Write-Host "7. Offline tests"
Write-Host ""

$testsProj = Get-ChildItem -LiteralPath (Join-Path $ProjectPath "Tests") -Filter "*.csproj" -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($testsProj) {
    $testsText = Get-Content $testsProj.FullName -Raw
    if ($testsText -match 'MODNAME|SPIELNAME|>SPIELORDNER<') {
        Write-Check "Tests project" "WARNING" "$($testsProj.Name) still has placeholders (MODNAME, SPIELORDNER or SPIELNAME)"
        Write-Fix "Replace them; the game compatibility test needs the game path."
    } else {
        Write-Check "Tests project" "OK" "Tests\$($testsProj.Name) - run: dotnet test Tests"
    }
} else {
    Write-Check "Tests project" "WARNING" "No Tests\*.csproj"
    Write-Fix "Copy templates\tests to Tests\ (docs/05-quality-and-updates.md)."
}

Write-Host ""

# ===================
# 8. DECOMPILED CODE
# ===================

Write-Host "8. Decompiled code (private)"
Write-Host ""

$hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
$decompiledPath = Join-Path $ProjectPath "decompiled"

if (-not (Test-Path $decompiledPath)) {
    Write-Check "decompiled folder" "WARNING" "Not there yet"
    Write-Fix ".\scripts\Decompile-Game.ps1 -GamePath `"$GamePath`" -Version <real game version>"
} elseif (-not (Test-Path (Join-Path $decompiledPath ".git"))) {
    Write-Check "decompiled is a git repository" "ERROR" "Plain folder: game updates cannot be diffed"
    Write-Fix "Move it away and run .\scripts\Decompile-Game.ps1 -Version <real game version>."
} elseif (-not $hasGit) {
    Write-Check "decompiled is a git repository" "WARNING" "git is not installed, branches not checked"
    Write-Fix "winget install Git.Git"
} else {
    Write-Check "decompiled is a git repository" "OK"
    $branches = @(git -C $decompiledPath branch --format="%(refname:short)" 2>$null | Where-Object { $_ -notin @("master", "main") })
    if ($branches.Count -gt 0) {
        Write-Check "One branch per game version" "OK" (Join-Short $branches)
    } else {
        Write-Check "One branch per game version" "WARNING" "No version branch"
        Write-Fix ".\scripts\Decompile-Game.ps1 -Version <real game version> creates one."
    }
    $remotes = @(git -C $decompiledPath remote 2>$null)
    if ($remotes.Count -gt 0) {
        Write-Check "decompiled has no remote" "WARNING" "Remote: $($remotes -join ', ')"
        Write-Fix "Never push decompiled game code. Remove it: git -C decompiled remote remove $($remotes[0])"
    } else {
        Write-Check "decompiled has no remote" "OK"
    }
}

foreach ($privateDir in @("decompiled", "recon-records")) {
    $ignored = $false
    if ($hasGit -and (Test-Path (Join-Path $ProjectPath ".git"))) {
        git -C $ProjectPath check-ignore -q "$privateDir/" 2>$null
        $ignored = ($LASTEXITCODE -eq 0)
    } elseif (Test-Path (Join-Path $ProjectPath ".gitignore")) {
        $ignored = [bool](Select-String -LiteralPath (Join-Path $ProjectPath ".gitignore") -Pattern "^/?$privateDir/?\s*$" -Quiet)
    }
    if ($ignored) {
        Write-Check "$privateDir is gitignored" "OK"
    } else {
        Write-Check "$privateDir is gitignored" "ERROR" "Proprietary game data could be committed"
        Write-Fix "Add the line $privateDir/ to .gitignore (the template's .gitignore has it)."
    }
}

Write-Host ""

# ===================
# SUMMARY
# ===================

Write-Host "Summary"
Write-Host "======="
Write-Host ""
Write-Host "OK: $script:successCount"
Write-Host "Warnings: $script:warningCount"
Write-Host "Errors: $script:errorCount"
Write-Host ""

if ($script:errorCount -eq 0 -and $script:warningCount -eq 0) {
    Write-Host "All good. Build with scripts\Build-Mod.ps1 (or dotnet build <ModName>.csproj), then run dotnet test Tests."
} elseif ($script:errorCount -eq 0) {
    Write-Host "The project can be built, but there are warnings. Fix them before the first build if you can."
} else {
    Write-Host "There are errors. Fix them before building."
}

Write-Host ""
if ($script:errorCount -gt 0) { exit 1 }
