param(
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,
    [string]$ConfigPath = "",
    [string]$Account = "",
    [string]$Theme = "",
    [string]$Color = "",
    [switch]$NoCite,
    [switch]$KeepTitle
)

$ErrorActionPreference = "Stop"

function Get-BunCommand {
    $bunCandidates = @(where.exe bun 2>$null) | Where-Object { $_ -match '\.(cmd|exe)$' }
    if ($bunCandidates.Count -gt 0) {
        return @($bunCandidates)[0]
    }
    $bun = Get-Command bun -ErrorAction SilentlyContinue
    if ($bun -and $bun.Source -match '\.(cmd|exe)$') {
        return $bun.Source
    }
    $npxCandidates = @(where.exe npx 2>$null) | Where-Object { $_ -match '\.(cmd|exe)$' }
    if ($npxCandidates.Count -gt 0) {
        return @($npxCandidates)[0]
    }
    $npx = Get-Command npx -ErrorAction SilentlyContinue
    if ($npx -and $npx.Source -match '\.(cmd|exe)$') {
        return $npx.Source
    }
    throw "Neither bun nor npx was found. Install bun or npx before converting Markdown to HTML."
}

function Join-ProcessArguments {
    param([string[]]$Arguments)

    return (($Arguments | ForEach-Object {
        $arg = [string]$_
        if ($arg.Length -eq 0) {
            return '""'
        }
        if ($arg -notmatch '[\s"]') {
            return $arg
        }
        '"' + ($arg -replace '"', '\"') + '"'
    }) -join " ")
}

function Invoke-Utf8Process {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    if ($FilePath -match '\.(cmd|bat)$') {
        $commandLine = "chcp 65001 >nul & " + (Join-ProcessArguments -Arguments @($FilePath))
        if ($Arguments.Count -gt 0) {
            $commandLine += " " + (Join-ProcessArguments -Arguments $Arguments)
        }
        $startInfo.FileName = $env:ComSpec
        $startInfo.Arguments = '/d /s /c "' + ($commandLine -replace '"', '""') + '"'
    } else {
        $startInfo.FileName = $FilePath
        $startInfo.Arguments = Join-ProcessArguments -Arguments $Arguments
    }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
    } catch {
        throw "Failed to start process. FileName='$($startInfo.FileName)' Arguments='$($startInfo.Arguments)' OriginalFilePath='$FilePath'. $($_.Exception.Message)"
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        [Console]::Error.Write($stderr)
    }

    return [PSCustomObject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

function Remove-JsonHashComments {
    param([string]$Content)

    $builder = [System.Text.StringBuilder]::new()
    $inString = $false
    $escaped = $false
    for ($i = 0; $i -lt $Content.Length; $i++) {
        $char = $Content[$i]
        if ($inString) {
            [void]$builder.Append($char)
            if ($escaped) {
                $escaped = $false
            } elseif ($char -eq '\') {
                $escaped = $true
            } elseif ($char -eq '"') {
                $inString = $false
            }
            continue
        }
        if ($char -eq '"') {
            $inString = $true
            [void]$builder.Append($char)
            continue
        }
        if ($char -eq '#') {
            while ($i -lt $Content.Length -and $Content[$i] -notin @("`r", "`n")) {
                $i++
            }
            if ($i -lt $Content.Length) {
                [void]$builder.Append($Content[$i])
            }
            continue
        }
        [void]$builder.Append($char)
    }
    return $builder.ToString()
}

function Read-Config {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $Path = Join-Path $projectRoot "config\local.secrets.json"
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file does not exist: $Path. Copy config/local.secrets.example.json to config/local.secrets.json and fill in keys."
    }
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return (Remove-JsonHashComments -Content $content) | ConvertFrom-Json
}

function Get-WeChatAccount {
    param(
        [object]$Config,
        [string]$Alias
    )

    if ($null -eq $Config.wechat) {
        throw "Config is missing 'wechat' section."
    }
    $accounts = @($Config.wechat.accounts)
    if ($accounts.Count -eq 0) {
        throw "Config is missing wechat.accounts."
    }
    if ([string]::IsNullOrWhiteSpace($Alias)) {
        $Alias = [string]$Config.wechat.default_account
    }
    if ([string]::IsNullOrWhiteSpace($Alias) -and $accounts.Count -eq 1) {
        return $accounts[0]
    }
    $account = $accounts | Where-Object { $_.alias -eq $Alias } | Select-Object -First 1
    if ($null -eq $account) {
        throw "WeChat account not found in config: $Alias"
    }
    return $account
}

$resolvedMarkdownPath = Resolve-Path -LiteralPath $MarkdownPath
$config = Read-Config -Path $ConfigPath
$wechatAccount = Get-WeChatAccount -Config $config -Alias $Account

if ([string]::IsNullOrWhiteSpace($Theme)) {
    $Theme = if ($wechatAccount.theme) { [string]$wechatAccount.theme } else { "modern" }
}
if ([string]::IsNullOrWhiteSpace($Color)) {
    $Color = if ($wechatAccount.color) { [string]$wechatAccount.color } else { "blue" }
}

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptPath = Join-Path $projectRoot "skills\baoyu-markdown-to-html\scripts\main.ts"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "baoyu-markdown-to-html script not found: $scriptPath"
}

$cmd = Get-BunCommand
$cmdName = Split-Path -Leaf $cmd
$args = @()
if ($cmdName -like "npx*") {
    $args += @("-y", "bun")
}
$args += @($scriptPath, $resolvedMarkdownPath.ToString(), "--theme", $Theme)
if (-not [string]::IsNullOrWhiteSpace($Color)) {
    $args += @("--color", $Color)
}
if (-not $NoCite) {
    $args += "--cite"
}
if ($KeepTitle) {
    $args += "--keep-title"
}

$processResult = Invoke-Utf8Process -FilePath $cmd -Arguments $args
if ($processResult.ExitCode -ne 0) {
    throw "Markdown to HTML conversion failed."
}

$result = $processResult.Stdout | ConvertFrom-Json
[PSCustomObject]@{
    Account = [string]$wechatAccount.alias
    Theme = $Theme
    Color = $Color
    Cite = -not [bool]$NoCite
    Result = $result
} | ConvertTo-Json -Depth 8
