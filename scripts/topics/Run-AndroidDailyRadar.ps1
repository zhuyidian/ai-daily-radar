param(
    [DateTime]$Date = (Get-Date),
    [int]$LookbackHours = 24,
    [int]$MaxItemsPerSource = 20,
    [int]$TopCandidateCount = 30,
    [switch]$NoGoogleNews,
    [switch]$SkipCollect,
    [switch]$SkipGenerate,
    [switch]$DryRunFeishu,
    [switch]$SendFeishu,
    [switch]$TextOnly,
    [string]$ConfigPath = "",
    [switch]$CreateWeChatDraft,
    [switch]$DryRunWeChat,
    [string]$WeChatArticlePath = "",
    [string]$WeChatCoverPath = "",
    [string]$WeChatAccount = "",
    [string]$WeChatTheme = "",
    [string]$WeChatColor = ""
)

$ErrorActionPreference = "Stop"

$runArgs = @{
    Topic = "android"
    Date = $Date
    LookbackHours = $LookbackHours
    MaxItemsPerSource = $MaxItemsPerSource
    TopCandidateCount = $TopCandidateCount
    ConfigPath = $ConfigPath
    WeChatArticlePath = $WeChatArticlePath
    WeChatCoverPath = $WeChatCoverPath
    WeChatAccount = $WeChatAccount
    WeChatTheme = $WeChatTheme
    WeChatColor = $WeChatColor
}

foreach ($switchName in @("NoGoogleNews", "SkipCollect", "SkipGenerate", "DryRunFeishu", "SendFeishu", "TextOnly", "CreateWeChatDraft", "DryRunWeChat")) {
    if ((Get-Variable -Name $switchName).Value) {
        $runArgs[$switchName] = $true
    }
}

$commonRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "common"
& (Join-Path $commonRoot "Run-DailyRadar.ps1") @runArgs
