$ErrorActionPreference = "Stop"

function Get-EditorialProjectRoot {
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..\..")).Path
}

function Get-EditorialTopic {
    param([string]$Topic)

    $projectRoot = Get-EditorialProjectRoot
    return & (Join-Path $projectRoot "scripts\common\Get-DailyRadarTopic.ps1") -Topic $Topic
}

function Read-EditorialConfig {
    param([object]$TopicConfig)

    $configDir = Split-Path -Parent ([string]$TopicConfig.TopicConfigPath)
    $path = Join-Path $configDir "wechat-editorial.json"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "WeChat editorial config does not exist: $path"
    }
    $config = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not [bool]$config.enabled) {
        throw "WeChat editorial workflow is disabled in: $path"
    }
    return [PSCustomObject]@{
        Path = (Resolve-Path -LiteralPath $path).Path
        Value = $config
    }
}

function Get-EditorialOutputPaths {
    param(
        [object]$TopicConfig,
        [DateTime]$Date
    )

    $projectRoot = Get-EditorialProjectRoot
    $runDir = Join-Path $projectRoot (Join-Path ([string]$TopicConfig.RunRoot) $Date.ToString("yyyy-MM-dd"))
    $wechatRoot = Join-Path $runDir "channels\wechat"
    $commonDir = Join-Path $wechatRoot "common"
    $outputDir = Join-Path $wechatRoot "editorial"
    $imageDir = Join-Path $outputDir "imgs"
    New-Item -ItemType Directory -Force -Path $commonDir, $outputDir, $imageDir | Out-Null

    return [PSCustomObject]@{
        RunDir = $runDir
        WeChatRoot = $wechatRoot
        CommonDir = $commonDir
        OutputDir = $outputDir
        ImageDir = $imageDir
        SourceManifestPath = Join-Path $outputDir "source-manifest.json"
        SelectionPromptPath = Join-Path $outputDir "editorial-selection-prompt.md"
        DecisionPath = Join-Path $outputDir "editorial-decision.json"
        ArticlePromptPath = Join-Path $outputDir "editorial-article-prompt.md"
        TitleCandidatesPath = Join-Path $outputDir "title-candidates.json"
        DraftPath = Join-Path $outputDir "wechat-article-draft.md"
        HumanizerPromptPath = Join-Path $outputDir "humanizer-prompt.md"
        HumanizedPath = Join-Path $outputDir "wechat-article-humanized.md"
        HumanizerReportPath = Join-Path $outputDir "humanizer-report.json"
        ReviewPromptPath = Join-Path $outputDir "editorial-review-prompt.md"
        ReviewReportPath = Join-Path $outputDir "editorial-review.json"
        ArticlePath = Join-Path $outputDir "wechat-article.md"
        AssetsPromptPath = Join-Path $outputDir "editorial-assets-prompt.md"
        VisualPlanPath = Join-Path $outputDir "visual-plan.json"
        CoverPath = Join-Path $imageDir "cover.png"
    }
}

function Read-RequiredJson {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required JSON file does not exist: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-FrontmatterValue {
    param(
        [string]$Markdown,
        [string]$Name
    )

    $pattern = '(?m)^' + [regex]::Escape($Name) + ':\s*["'']?(.*?)["'']?\s*$'
    $match = [regex]::Match($Markdown, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
    }
    return ""
}
