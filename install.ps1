# iz4 installer for Windows (PowerShell 5.1 or newer):
#
#     irm https://raw.githubusercontent.com/nige123/cli.iz4.you/main/install.ps1 | iex
#
# Fetches the standalone iz4.exe published for Windows x64 into your
# profile, verifies its checksum, and puts it on your PATH. Nothing
# system-wide, no administrator rights. Afterwards 'iz4 update' keeps it
# current. Written for the CLI's published files; if it misbehaves on your
# machine, please report it at https://github.com/nige123/cli.iz4.you/issues.
#
# Overrides: $env:IZ4_RELEASE_URL (where the files are), $env:IZ4_BIN (where
# iz4.exe goes; default $env:LOCALAPPDATA\iz4\bin).
$ErrorActionPreference = 'Stop'
$release = if ($env:IZ4_RELEASE_URL) { $env:IZ4_RELEASE_URL } else { 'https://github.com/nige123/cli.iz4.you/releases/latest/download' }
$binDir  = if ($env:IZ4_BIN) { $env:IZ4_BIN } else { Join-Path $env:LOCALAPPDATA 'iz4\bin' }
$asset   = 'iz4-windows-x64.exe'
if (-not [Environment]::Is64BitOperatingSystem) { throw 'iz4 is published for 64-bit Windows only' }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("iz4-install-" + [IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $tmp | Out-Null
Write-Host "fetching $asset"
Invoke-WebRequest -UseBasicParsing -Uri "$release/$asset" -OutFile (Join-Path $tmp $asset)
Invoke-WebRequest -UseBasicParsing -Uri "$release/$asset.sha256" -OutFile (Join-Path $tmp "$asset.sha256")
$expected = ((Get-Content (Join-Path $tmp "$asset.sha256") -Raw) -replace '\s','') -replace '^([0-9a-fA-F]{64}).*$','$1'
$got = (Get-FileHash -Algorithm SHA256 (Join-Path $tmp $asset)).Hash
if ($expected.ToLower() -ne $got.ToLower()) { throw "checksum mismatch for ${asset}: expected $expected, got $got; nothing was installed" }

New-Item -ItemType Directory -Force -Path $binDir | Out-Null
$exe = Join-Path $binDir 'iz4.exe'
if (Test-Path $exe) { Move-Item -Force $exe "$exe.old" }
Move-Item (Join-Path $tmp $asset) $exe
Remove-Item -Recurse -Force $tmp
& $exe version | Out-Null
if ($LASTEXITCODE -ne 0) { throw "installed, but iz4 does not run; please report this" }

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $binDir) {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $binDir), 'User')
    $env:Path = "$env:Path;$binDir"
    Write-Host "added $binDir to your PATH (open a new terminal for other windows to see it)"
}
Write-Host "installed: $exe ($(& $exe version))"

# 321.do, an agent launcher: iz4 uses it for everything agentic when it is
# there. Fetched beside iz4 unless one is already installed; $env:IZ4_NO_321=1
# skips it. iz4 works without it, so a failure here is a note, never an error.
if ($env:IZ4_NO_321 -ne '1') {
    $existing = Get-Command 321 -ErrorAction SilentlyContinue
    $marker = Join-Path $binDir '.321-from-iz4'
    if ($existing -and -not (Test-Path $marker)) {
        Write-Host "321.do, an agent launcher, is already installed at $($existing.Source); left as is"
    } else {
        try {
            Write-Host 'install 321.do, an agent launcher'
            $lrelease = if ($env:IZ4_321_RELEASE_URL) { $env:IZ4_321_RELEASE_URL } else { 'https://github.com/nige123/cli.321.do/releases/latest/download' }
            $lasset = '321-windows-x64.exe'
            $ltmp = Join-Path ([IO.Path]::GetTempPath()) ("iz4-321-" + [IO.Path]::GetRandomFileName())
            New-Item -ItemType Directory -Path $ltmp | Out-Null
            Invoke-WebRequest -UseBasicParsing -Uri "$lrelease/$lasset" -OutFile (Join-Path $ltmp $lasset)
            Invoke-WebRequest -UseBasicParsing -Uri "$lrelease/$lasset.sha256" -OutFile (Join-Path $ltmp "$lasset.sha256")
            $lexpected = ((Get-Content (Join-Path $ltmp "$lasset.sha256") -Raw) -replace '\s','') -replace '^([0-9a-fA-F]{64}).*$','$1'
            $lgot = (Get-FileHash -Algorithm SHA256 (Join-Path $ltmp $lasset)).Hash
            if ($lexpected.ToLower() -ne $lgot.ToLower()) { throw "checksum mismatch for $lasset" }
            $lexe = Join-Path $binDir '321.exe'
            if (Test-Path $lexe) { Move-Item -Force $lexe "$lexe.old" }
            Move-Item (Join-Path $ltmp $lasset) $lexe
            Remove-Item -Recurse -Force $ltmp
            & $lexe version | Out-Null
            if ($LASTEXITCODE -ne 0) { throw '321.exe does not run here' }
            Set-Content -Path $marker -Value 'installed by iz4'
            Write-Host "installed: $lexe ($(& $lexe version)) - 'iz4 update' keeps it current"
        } catch {
            Write-Host "could not install 321.do ($($_.Exception.Message)); iz4 works without it"
        }
    }
}
Write-Host "next: cd your-project; iz4 init"
