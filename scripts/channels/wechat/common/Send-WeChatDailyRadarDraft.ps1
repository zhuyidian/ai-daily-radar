param(
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,
    [string]$CoverPath = "",
    [string]$ConfigPath = "",
    [string]$Account = "",
    [string]$Theme = "",
    [string]$Color = "",
    [string]$Title = "",
    [string]$Author = "",
    [string]$Summary = "",
    [switch]$NoCite,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Get-BunCommand {
    foreach ($commandName in @("bun.cmd", "bun.exe", "bun", "npx.cmd", "npx.exe", "npx")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command -and $command.Source -match '\.(cmd|exe)$') {
            return $command.Source
        }
    }

    foreach ($candidate in @(
        "C:\Program Files\nodejs\npx.cmd",
        "C:\Program Files\nodejs\npx.exe",
        "$env:USERPROFILE\AppData\Roaming\npm\bun.cmd",
        "$env:USERPROFILE\AppData\Roaming\npm\bun.exe"
    )) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    throw "Neither bun nor npx was found. Install bun or npx before creating WeChat drafts."
}

function Read-Config {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..\..")).Path
        $Path = Join-Path $projectRoot "config\local.secrets.json"
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file does not exist: $Path. Copy config/local.secrets.example.json to config/local.secrets.json and fill in keys."
    }
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return (Remove-JsonHashComments -Content $content) | ConvertFrom-Json
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

function Escape-ExtendValue {
    param([string]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return ($Value -replace '"', '\"')
}

function Write-RuntimeExtend {
    param(
        [string]$RuntimeDir,
        [object]$Account,
        [string]$ResolvedTheme,
        [string]$ResolvedColor
    )

    $extendDir = Join-Path $RuntimeDir ".baoyu-skills\baoyu-post-to-wechat"
    New-Item -ItemType Directory -Force -Path $extendDir | Out-Null
    $extendPath = Join-Path $extendDir "EXTEND.md"

    $needOpenComment = if ($null -ne $Account.need_open_comment) { [int]$Account.need_open_comment } else { 1 }
    $onlyFansCanComment = if ($null -ne $Account.only_fans_can_comment) { [int]$Account.only_fans_can_comment } else { 0 }
    $publishMethod = if ($Account.publish_method) { [string]$Account.publish_method } else { "api" }
    $author = if ($Account.author) { [string]$Account.author } else { "" }
    $chromeProfilePath = if ($Account.chrome_profile_path) { [string]$Account.chrome_profile_path } else { "" }

    $lines = @(
        "default_theme: $ResolvedTheme",
        "default_color: $ResolvedColor",
        "default_publish_method: $publishMethod",
        "default_author: `"$((Escape-ExtendValue $author))`"",
        "need_open_comment: $needOpenComment",
        "only_fans_can_comment: $onlyFansCanComment",
        "accounts:",
        "  - name: `"$((Escape-ExtendValue ([string]$Account.name)))`"",
        "    alias: `"$((Escape-ExtendValue ([string]$Account.alias)))`"",
        "    default: true",
        "    default_publish_method: $publishMethod",
        "    default_author: `"$((Escape-ExtendValue $author))`"",
        "    need_open_comment: $needOpenComment",
        "    only_fans_can_comment: $onlyFansCanComment",
        "    app_id: `"$((Escape-ExtendValue ([string]$Account.app_id)))`"",
        "    app_secret: `"$((Escape-ExtendValue ([string]$Account.app_secret)))`""
    )
    if (-not [string]::IsNullOrWhiteSpace($chromeProfilePath)) {
        $lines += "    chrome_profile_path: `"$((Escape-ExtendValue $chromeProfilePath))`""
    }

    ($lines -join [Environment]::NewLine) | Set-Content -LiteralPath $extendPath -Encoding UTF8
    return $extendPath
}

function Write-RuntimeEnv {
    param(
        [string]$RuntimeDir,
        [object]$Account
    )

    $envDir = Join-Path $RuntimeDir ".baoyu-skills"
    New-Item -ItemType Directory -Force -Path $envDir | Out-Null
    $envPath = Join-Path $envDir ".env"
    $aliasEnvPrefix = if (-not [string]::IsNullOrWhiteSpace([string]$Account.alias)) {
        ([string]$Account.alias).ToUpperInvariant() -replace "-", "_"
    } else {
        ""
    }

    $lines = @(
        "WECHAT_APP_ID=$([string]$Account.app_id)",
        "WECHAT_APP_SECRET=$([string]$Account.app_secret)"
    )
    if (-not [string]::IsNullOrWhiteSpace($aliasEnvPrefix)) {
        $lines += "WECHAT_${aliasEnvPrefix}_APP_ID=$([string]$Account.app_id)"
        $lines += "WECHAT_${aliasEnvPrefix}_APP_SECRET=$([string]$Account.app_secret)"
    }

    ($lines -join [Environment]::NewLine) | Set-Content -LiteralPath $envPath -Encoding UTF8
    return $envPath
}

$resolvedMarkdownPath = Resolve-Path -LiteralPath $MarkdownPath
$runDir = Split-Path -Parent $resolvedMarkdownPath
$articleChannel = Split-Path -Leaf $runDir
$wechatRoot = if ($articleChannel -in @("daily-radar", "editorial")) {
    Split-Path -Parent $runDir
} else {
    $runDir
}
$sharedRuntimeRoot = Join-Path $wechatRoot "common\.baoyu-runtime"
$config = Read-Config -Path $ConfigPath
$wechatAccount = Get-WeChatAccount -Config $config -Alias $Account

if ([string]::IsNullOrWhiteSpace([string]$wechatAccount.app_id) -or [string]::IsNullOrWhiteSpace([string]$wechatAccount.app_secret)) {
    throw "WeChat account '$($wechatAccount.alias)' is missing app_id or app_secret in config."
}

if ([string]::IsNullOrWhiteSpace($Theme)) {
    $Theme = if ($wechatAccount.theme) { [string]$wechatAccount.theme } else { "modern" }
}
if ([string]::IsNullOrWhiteSpace($Color)) {
    $Color = if ($wechatAccount.color) { [string]$wechatAccount.color } else { "blue" }
}
if ([string]::IsNullOrWhiteSpace($Author) -and $wechatAccount.author) {
    $Author = [string]$wechatAccount.author
}

$resolvedCoverPath = ""
if (-not [string]::IsNullOrWhiteSpace($CoverPath)) {
    $resolvedCoverPath = (Resolve-Path -LiteralPath $CoverPath).ToString()
}

$runtimeDir = Join-Path $sharedRuntimeRoot $articleChannel
$extendPath = Write-RuntimeExtend -RuntimeDir $runtimeDir -Account $wechatAccount -ResolvedTheme $Theme -ResolvedColor $Color
$runtimeEnvPath = Write-RuntimeEnv -RuntimeDir $runtimeDir -Account $wechatAccount

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..\..")).Path
$scriptPath = Join-Path $projectRoot "skills\baoyu-post-to-wechat\scripts\wechat-api.ts"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "baoyu-post-to-wechat API script not found: $scriptPath"
}

$cmd = Get-BunCommand
$cmdName = Split-Path -Leaf $cmd
$args = @()
if ($cmdName -like "npx*") {
    if ([string]::IsNullOrWhiteSpace($env:npm_config_cache)) {
        $npmCacheDir = Join-Path $projectRoot ".runs\npm-cache"
        New-Item -ItemType Directory -Force -Path $npmCacheDir | Out-Null
        $env:npm_config_cache = $npmCacheDir
    }
    $env:NPX_COMMAND = $cmd
    $args += @("-y", "bun")
}
$args += @($scriptPath, $resolvedMarkdownPath.ToString(), "--theme", $Theme, "--account", ([string]$wechatAccount.alias))
if (-not [string]::IsNullOrWhiteSpace($Color)) {
    $args += @("--color", $Color)
}
if (-not [string]::IsNullOrWhiteSpace($Title)) {
    $args += @("--title", $Title)
}
if (-not [string]::IsNullOrWhiteSpace($Author)) {
    $args += @("--author", $Author)
}
if (-not [string]::IsNullOrWhiteSpace($Summary)) {
    $args += @("--summary", $Summary)
}
if (-not [string]::IsNullOrWhiteSpace($resolvedCoverPath)) {
    $args += @("--cover", $resolvedCoverPath)
}
if ($NoCite) {
    $args += "--no-cite"
}
if ($DryRun) {
    $args += "--dry-run"
}

Push-Location $runtimeDir
try {
    Remove-Item Env:WECHAT_APP_ID -ErrorAction SilentlyContinue
    Remove-Item Env:WECHAT_APP_SECRET -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace([string]$wechatAccount.alias)) {
        $aliasEnvPrefix = ([string]$wechatAccount.alias).ToUpperInvariant() -replace "-", "_"
        Remove-Item "Env:WECHAT_${aliasEnvPrefix}_APP_ID" -ErrorAction SilentlyContinue
        Remove-Item "Env:WECHAT_${aliasEnvPrefix}_APP_SECRET" -ErrorAction SilentlyContinue
    }
    $output = & $cmd @args
    if ($LASTEXITCODE -ne 0) {
        throw "WeChat draft command failed."
    }
}
finally {
    Pop-Location
    if (-not [string]::IsNullOrWhiteSpace($runtimeEnvPath) -and (Test-Path -LiteralPath $runtimeEnvPath)) {
        Remove-Item -LiteralPath $runtimeEnvPath -Force
    }
}

$result = $output | ConvertFrom-Json
$resultPath = Join-Path $runDir "wechat-draft-result.json"
$wrapped = [PSCustomObject]@{
    Account = [string]$wechatAccount.alias
    Method = "api"
    Theme = $Theme
    Color = $Color
    MarkdownPath = $resolvedMarkdownPath.ToString()
    CoverPath = $resolvedCoverPath
    RuntimeExtendPath = $extendPath
    CredentialsSource = "config/local.secrets.json"
    DryRun = [bool]$DryRun
    Result = $result
    CreatedAt = ([DateTimeOffset]::Now).UtcDateTime.ToString("o")
}
$wrapped | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding UTF8
$wrapped | ConvertTo-Json -Depth 12
