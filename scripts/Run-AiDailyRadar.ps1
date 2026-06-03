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
    [switch]$TextOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$dateText = $Date.ToString("yyyy-MM-dd")

$invokeArgs = @{
    Date = $Date
    LookbackHours = $LookbackHours
}

$collectArgs = @{
    Date = $Date
    LookbackHours = $LookbackHours
    MaxItemsPerSource = $MaxItemsPerSource
}

$generateArgs = @{
    Date = $Date
    TopCandidateCount = $TopCandidateCount
}

if ($NoGoogleNews) {
    $collectArgs.NoGoogleNews = $true
}

$initJson = & (Join-Path $PSScriptRoot "Invoke-AiDailyRadar.ps1") @invokeArgs

$init = $initJson | ConvertFrom-Json

$markdownPath = [string]$init.MarkdownPath
$jsonPath = [string]$init.JsonPath
$promptPath = [string]$init.PromptPath
$runDir = [string]$init.RunDir
$candidatesPath = Join-Path $runDir "candidates.json"
$collect = $null
$generate = $null
$generatePromptPath = Join-Path $runDir "generate-prompt.md"
$legacyNextPromptPath = Join-Path $runDir "next-codex-prompt.md"

if (Test-Path -LiteralPath $legacyNextPromptPath) {
    Remove-Item -LiteralPath $legacyNextPromptPath -Force
}

if (-not $SkipCollect) {
    $collectJson = & (Join-Path $PSScriptRoot "Collect-AiNewsCandidates.ps1") @collectArgs
    $collect = $collectJson | ConvertFrom-Json
    $candidatesPath = [string]$collect.OutputPath
}

if (-not $SkipGenerate) {
    $generateJson = & (Join-Path $PSScriptRoot "Generate-AiDailyRadar.ps1") @generateArgs
    $generate = $generateJson | ConvertFrom-Json
    $generatePromptPath = [string]$generate.GeneratePromptPath
}

$feishuResult = $null
if ($DryRunFeishu -or $SendFeishu) {
    if (-not (Test-Path -LiteralPath $markdownPath)) {
        throw "Markdown file does not exist: $markdownPath"
    }

    $sendArgs = @{
        MarkdownPath = $markdownPath
    }
    if ($TextOnly) {
        $sendArgs.TextOnly = $true
    }
    if ($DryRunFeishu) {
        $sendArgs.DryRun = $true
    }

    $feishuResult = & (Join-Path $PSScriptRoot "Send-FeishuDailyRadar.ps1") @sendArgs
}

$candidateCount = if ($collect) { $collect.CandidateCount } else { $null }
$sourceCount = if ($collect) { $collect.SourceCount } else { $null }
$failedSourceCount = if ($collect) { $collect.FailedSourceCount } else { $null }

if ((-not $collect) -and (Test-Path -LiteralPath $candidatesPath)) {
    $existingCandidates = Get-Content -LiteralPath $candidatesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $candidateCount = $existingCandidates.candidate_count
    $sourceCount = @($existingCandidates.sources).Count
    $failedSourceCount = @($existingCandidates.sources | Where-Object { -not $_.ok }).Count
}

$metadataPath = Join-Path $runDir "run-metadata.json"
$metadata = [PSCustomObject]@{
    date = $dateText
    generated_at = ([DateTimeOffset]::Now).UtcDateTime.ToString("o")
    parameters = [PSCustomObject]@{
        lookback_hours = $LookbackHours
        max_items_per_source = $MaxItemsPerSource
        top_candidate_count = $TopCandidateCount
        no_google_news = [bool]$NoGoogleNews
        skip_collect = [bool]$SkipCollect
        skip_generate = [bool]$SkipGenerate
        dry_run_feishu = [bool]$DryRunFeishu
        send_feishu = [bool]$SendFeishu
        text_only = [bool]$TextOnly
    }
    paths = [PSCustomObject]@{
        run_dir = $runDir
        candidates = $candidatesPath
        generate_prompt = $generatePromptPath
        markdown = $markdownPath
        json = $jsonPath
        run_prompt = $promptPath
    }
    collection = [PSCustomObject]@{
        candidate_count = $candidateCount
        source_count = $sourceCount
        failed_source_count = $failedSourceCount
    }
}
$metadata | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

[PSCustomObject]@{
    Date = $dateText
    RunDir = $runDir
    CandidatesPath = $candidatesPath
    CandidateCount = $candidateCount
    SourceCount = $sourceCount
    FailedSourceCount = $failedSourceCount
    GeneratePromptPath = $generatePromptPath
    MarkdownPath = $markdownPath
    JsonPath = $jsonPath
    PromptPath = $promptPath
    MetadataPath = $metadataPath
    NextStep = "Ask Codex: Read today's generate-prompt.md and generate the report, but do not send to Feishu yet."
    FeishuResult = $feishuResult
} | ConvertTo-Json -Depth 8
