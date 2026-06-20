param(
    [string]$Topic = "ai",
    [DateTime]$Date = (Get-Date),
    [int]$LookbackDays = 0
)

$ErrorActionPreference = "Stop"

$selectionScript = Join-Path $PSScriptRoot "New-WeChatEditorialSelectionPrompt.ps1"
$selectionJson = & $selectionScript -Topic $Topic -Date $Date -LookbackDays $LookbackDays
$selection = $selectionJson | ConvertFrom-Json
$outputDir = [string]$selection.OutputDir
$workflowPromptPath = Join-Path $outputDir "editorial-workflow-prompt.md"
$articleScript = Join-Path $PSScriptRoot "New-WeChatEditorialArticlePrompt.ps1"
$reviewScript = Join-Path $PSScriptRoot "New-WeChatEditorialReviewPrompt.ps1"
$assetsScript = Join-Path $PSScriptRoot "New-WeChatEditorialAssetsPrompt.ps1"

$prompt = @"
# Run the WeChat Editorial Workflow

Complete this topic-driven WeChat article workflow in order. Do not convert or send the article to WeChat in this workflow.

## Stage 1: topic selection

Read and follow:
$($selection.SelectionPromptPath)

Write:
$($selection.DecisionPath)

Validate that the decision file is valid JSON. If publish is false, stop immediately and report the reason. Do not force an article for daily cadence.

## Stage 2: article draft

When publish is true, run:

~~~powershell
& "$articleScript" -DecisionPath "$($selection.DecisionPath)"
~~~

Read the generated editorial-article-prompt.md, then write both title-candidates.json and wechat-article-draft.md exactly as requested.

## Stage 3: independent editorial review

Run:

~~~powershell
& "$reviewScript" -DraftPath "$outputDir\wechat-article-draft.md"
~~~

Read the generated editorial-review-prompt.md. Write editorial-review.json. Create the final wechat-article.md only if the score passes and there are no hard failures.

If review fails because evidence is insufficient, stop and report the blocker. Never invent a factual repair.

## Stage 4: visual direction and assets

When review passes, run:

~~~powershell
& "$assetsScript" -MarkdownPath "$outputDir\wechat-article.md"
~~~

Read editorial-assets-prompt.md, write visual-plan.json, and create only the justified bitmap assets. Use imagegen for generated bitmap assets. Prefer real screenshots, verified charts, or simple diagrams when they add more information than an illustration.

## Final checks

- Confirm the final article has ordinary inline source links.
- Confirm every referenced local image exists under $outputDir\imgs.
- Confirm the cover exists at $outputDir\imgs\cover.png.
- Do not send to Feishu.
- Do not create or publish a WeChat draft in this workflow.

Return the decision, final review score, final article path, cover path, and any unresolved issues.
"@
$prompt | Set-Content -LiteralPath $workflowPromptPath -Encoding UTF8

[PSCustomObject]@{
    Topic = $Topic
    Date = $Date.ToString("yyyy-MM-dd")
    OutputDir = $outputDir
    WorkflowPromptPath = $workflowPromptPath
    SelectionPromptPath = [string]$selection.SelectionPromptPath
    DecisionPath = [string]$selection.DecisionPath
    NextStep = "Ask Codex to read editorial-workflow-prompt.md and complete the gated editorial workflow."
} | ConvertTo-Json -Depth 5
