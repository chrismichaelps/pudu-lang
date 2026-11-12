param([Parameter(Mandatory = $true)][string]$Program)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$Program = (Resolve-Path -LiteralPath $Program).Path
$nonce = [Guid]::NewGuid().ToString('N')
$marker = "pudu-storage-$nonce"
$temporary = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$root = Join-Path $temporary $marker
$previous = $env:LOCALAPPDATA
$previousProfile2 = $env:PUDU_STORAGE_PROFILE2
$previousProfile3 = $env:PUDU_STORAGE_PROFILE3

function Invoke-StoragePhase([string]$Phase, [int]$Views) {
    $output = & $Program $Phase $nonce 2>&1
    $code = $LASTEXITCODE
    $output | Out-File -LiteralPath "storage-$Phase.log" -Encoding utf8
    $output | Write-Output
    if ($code -ne 0) { throw "Storage $Phase process failed ($code)" }
    $text = $output -join "`n"
    if ($text -notmatch '(?m)^storage-browser-exited=1\r?$') {
        throw "Storage $Phase browser exit marker missing"
    }
    if ($text -notmatch "(?m)^storage-$Phase=1 views=$Views\r?$") {
        throw "Storage $Phase completion marker missing"
    }
}

try {
    New-Item -ItemType Directory -Path $root -ErrorAction Stop | Out-Null
    $env:LOCALAPPDATA = $root
    Invoke-StoragePhase 'write' 7
    $write = Get-Content -LiteralPath 'storage-write.log' -Raw
    foreach ($id in @(2, 3)) {
        $names = [regex]::Matches($write, "(?m)^storage-profile-$id=([a-zA-Z0-9_-]{1,80})\r?$")
        if ($names.Count -ne 1) { throw "Private profile $id identity missing or ambiguous" }
        [Environment]::SetEnvironmentVariable("PUDU_STORAGE_PROFILE$id", $names[0].Groups[1].Value, 'Process')
    }
    Invoke-StoragePhase 'read' 63
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction Stop
} finally {
    $env:LOCALAPPDATA = $previous
    $env:PUDU_STORAGE_PROFILE2 = $previousProfile2
    $env:PUDU_STORAGE_PROFILE3 = $previousProfile3
}
Write-Output 'storage-reopen=1'
