. "$PSScriptRoot\PulseHudProCommon.ps1"

function Get-GameLibraryConfig {
    $profiles = Get-ProProfiles
    return $profiles.GameLibrary
}

function Get-GameCatalogPath {
    $config = Get-GameLibraryConfig
    return Resolve-ProPath $config.CatalogPath
}

function ConvertTo-GameId {
    param([string]$Text)

    $hash = [System.Security.Cryptography.SHA1]::Create()
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text.ToLowerInvariant())
    $digest = $hash.ComputeHash($bytes)
    return -join ($digest | ForEach-Object { $_.ToString("x2") })
}

function New-GameEntry {
    param(
        [string]$Name,
        [string]$Source,
        [string]$InstallPath = "",
        [string]$LaunchPath = "",
        [string]$Arguments = "",
        [string]$UninstallString = "",
        [bool]$CanDeleteFiles = $false
    )

    $key = "$Name|$Source|$InstallPath|$LaunchPath|$UninstallString"
    [pscustomobject]@{
        Id = ConvertTo-GameId $key
        Name = $Name
        Source = $Source
        InstallPath = $InstallPath
        LaunchPath = $LaunchPath
        Arguments = $Arguments
        UninstallString = $UninstallString
        CanUninstall = -not [string]::IsNullOrWhiteSpace($UninstallString)
        CanDeleteFiles = $CanDeleteFiles
        LastSeen = (Get-Date).ToString("s")
    }
}

function Get-ShortcutTarget {
    param([string]$Path)

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($Path)
        if ([string]::IsNullOrWhiteSpace($shortcut.TargetPath)) { return $null }
        [pscustomobject]@{
            TargetPath = $shortcut.TargetPath
            Arguments = $shortcut.Arguments
            WorkingDirectory = $shortcut.WorkingDirectory
        }
    } catch {
        return $null
    }
}

function Get-RegistryGames {
    $items = @()
    $config = Get-GameLibraryConfig
    $gameRoots = @($config.GameRoots | ForEach-Object { Resolve-ProPath $_ } | Where-Object { $_ } | ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd("\") })
    $paths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
            $name = [string]$_.DisplayName
            if ([string]::IsNullOrWhiteSpace($name)) { return }

            $publisher = [string]$_.Publisher
            $install = [string]$_.InstallLocation
            $uninstall = [string]$_.UninstallString
            $displayIcon = [string]$_.DisplayIcon
            $looksGame = $false
            foreach ($word in @("Steam", "Epic Games", "GOG", "Ubisoft", "EA app", "Electronic Arts", "Riot Games", "Battle.net", "Xbox", "Minecraft", "Roblox", "Valve")) {
                if ($name -match [regex]::Escape($word) -or $publisher -match [regex]::Escape($word) -or $install -match [regex]::Escape($word) -or $displayIcon -match [regex]::Escape($word)) {
                    $looksGame = $true
                    break
                }
            }
            if (-not $looksGame -and $install) {
                $fullInstall = ""
                try { $fullInstall = [IO.Path]::GetFullPath($install).TrimEnd("\") } catch {}
                foreach ($root in $gameRoots) {
                    if ($fullInstall.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                        $looksGame = $true
                        break
                    }
                }
            }
            if (-not $looksGame) { return }

            $items += New-GameEntry -Name $name -Source "Registro" -InstallPath $install -UninstallString $uninstall
        }
    }

    return $items
}

function Get-StartMenuGames {
    $items = @()
    $dirs = @(
        [Environment]::GetFolderPath("Programs"),
        [Environment]::GetFolderPath("CommonPrograms")
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    $launcherNames = @((Get-GameLibraryConfig).KnownLaunchers)
    foreach ($dir in $dirs) {
        Get-ChildItem -LiteralPath $dir -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
            $target = Get-ShortcutTarget $_.FullName
            if ($null -eq $target) { return }
            $fileName = [IO.Path]::GetFileName($target.TargetPath).ToLowerInvariant()
            $targetText = "$($target.TargetPath) $($target.Arguments)"
            $isGameLink = ($launcherNames -contains $fileName) -or ($targetText -match "steam://|com.epicgames.launcher|goggalaxy://|uplay://|origin://|xbox")
            if (-not $isGameLink) { return }
            $items += New-GameEntry -Name $_.BaseName -Source "Atalho" -LaunchPath $target.TargetPath -Arguments $target.Arguments
        }
    }

    return $items
}

function Get-FolderGames {
    $config = Get-GameLibraryConfig
    $items = @()
    $maxDepth = [Math]::Max(1, [int]$config.MaxFolderDepth)

    foreach ($root in @($config.GameRoots)) {
        $resolved = Resolve-ProPath $root
        if ([string]::IsNullOrWhiteSpace($resolved) -or -not (Test-Path -LiteralPath $resolved)) { continue }

        Get-ChildItem -LiteralPath $resolved -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dir = $_
            $exe = Get-ChildItem -LiteralPath $dir.FullName -Recurse -Filter *.exe -ErrorAction SilentlyContinue |
                Where-Object {
                    $relative = $_.FullName.Substring($dir.FullName.Length).TrimStart("\")
                    (($relative -split "\\").Count -le $maxDepth) -and
                    ($_.Name -notmatch "unins|setup|install|redist|crash|launcherhelper|unitycrash")
                } |
                Sort-Object Length -Descending |
                Select-Object -First 1

            $launch = if ($exe) { $exe.FullName } else { "" }
            $items += New-GameEntry -Name $dir.Name -Source "Pasta" -InstallPath $dir.FullName -LaunchPath $launch -CanDeleteFiles $true
        }
    }

    return $items
}

function Merge-GameEntries {
    param([object[]]$Entries)

    $seen = @{}
    $merged = @()
    foreach ($entry in @($Entries | Where-Object { $_ -and $_.Name })) {
        $dedupeKey = if ($entry.InstallPath) {
            try { [IO.Path]::GetFullPath([string]$entry.InstallPath).TrimEnd("\").ToLowerInvariant() } catch { ([string]$entry.InstallPath).TrimEnd("\").ToLowerInvariant() }
        } elseif ($entry.LaunchPath) {
            try { [IO.Path]::GetFullPath([string]$entry.LaunchPath).TrimEnd("\").ToLowerInvariant() } catch { ([string]$entry.LaunchPath).TrimEnd("\").ToLowerInvariant() }
        } else {
            $entry.Name.ToLowerInvariant()
        }
        if ($seen.ContainsKey($dedupeKey)) { continue }
        $seen[$dedupeKey] = $true
        $merged += $entry
    }
    return $merged | Sort-Object Name
}

function Invoke-GameScan {
    $config = Get-GameLibraryConfig
    $entries = @()
    if ($config.ScanRegistry) { $entries += Get-RegistryGames }
    if ($config.ScanStartMenu) { $entries += Get-StartMenuGames }
    if ($config.ScanFolders) { $entries += Get-FolderGames }
    $catalog = Merge-GameEntries $entries
    Save-GameCatalog $catalog
    return $catalog
}

function Get-GameCatalog {
    $path = Get-GameCatalogPath
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try {
        return @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
    } catch {
        Write-ProLog "game-library" "Catalogo invalido: $($_.Exception.Message)"
        return @()
    }
}

function Save-GameCatalog {
    param([object[]]$Entries)

    $path = Get-GameCatalogPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    @($Entries) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
}

function Remove-GameFromCatalog {
    param([string]$Id)

    $entries = @(Get-GameCatalog | Where-Object { $_.Id -ne $Id })
    Save-GameCatalog $entries
    return $entries
}

function Start-GameEntry {
    param($Entry)

    if ($Entry.LaunchPath -and (Test-Path -LiteralPath $Entry.LaunchPath)) {
        Start-Process -FilePath $Entry.LaunchPath -ArgumentList $Entry.Arguments -WorkingDirectory (Split-Path -Parent $Entry.LaunchPath)
        return
    }
    if ($Entry.InstallPath -and (Test-Path -LiteralPath $Entry.InstallPath)) {
        Start-Process explorer.exe -ArgumentList "`"$($Entry.InstallPath)`""
    }
}

function Start-GameUninstall {
    param($Entry)

    if (-not $Entry.UninstallString) { throw "Este jogo nao tem comando oficial de desinstalacao no catalogo." }
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $Entry.UninstallString
}

function Remove-GameFilesToRecycleBin {
    param($Entry)

    if (-not $Entry.CanDeleteFiles -or -not $Entry.InstallPath -or -not (Test-Path -LiteralPath $Entry.InstallPath)) {
        throw "Nao ha pasta segura para remover."
    }

    $config = Get-GameLibraryConfig
    $allowed = @($config.GameRoots | ForEach-Object { Resolve-ProPath $_ } | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd("\") })
    $target = [IO.Path]::GetFullPath($Entry.InstallPath).TrimEnd("\")
    $insideAllowedRoot = $false
    foreach ($root in $allowed) {
        if ($target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            $insideAllowedRoot = $true
            break
        }
    }
    if (-not $insideAllowedRoot) { throw "A pasta nao esta dentro de uma GameRoot configurada." }

    $shell = New-Object -ComObject Shell.Application
    $parent = Split-Path -Parent $target
    $leaf = Split-Path -Leaf $target
    $folder = $shell.NameSpace($parent)
    $item = $folder.ParseName($leaf)
    if ($null -eq $item) { throw "Pasta nao encontrada para remocao." }
    $folder.MoveHere($item, 0x40)
}
