param(
    [Parameter(Mandatory = $true)]
    [string]$DraftPath,
    [string]$DecisionPath = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Editorial.Common.ps1")

$resolvedDraftPath = (Resolve-Path -LiteralPath $DraftPath).Path
$outputDir = Split-Path -Parent $resolvedDraftPath
if ([string]::IsNullOrWhiteSpace($DecisionPath)) {
    $DecisionPath = Join-Path $outputDir "editorial-decision.json"
}
$resolvedDecisionPath = (Resolve-Path -LiteralPath $DecisionPath).Path
$decision = Read-RequiredJson -Path $resolvedDecisionPath
$manifestPath = Join-Path $outputDir "source-manifest.json"
$manifest = Read-RequiredJson -Path $manifestPath
$config = Read-RequiredJson -Path ([string]$manifest.editorial_config_path)
$articleTypeName = [string]$decision.article_type
$articleTypeProperty = $config.article_types.PSObject.Properties[$articleTypeName]
if ($null -eq $articleTypeProperty) {
    throw "Unknown article_type in editorial decision: $articleTypeName"
}
$articleType = $articleTypeProperty.Value
$skillPath = [string]$manifest.skill_path
$reviewPromptPath = Join-Path $outputDir "editorial-review-prompt.md"
$reviewReportPath = Join-Path $outputDir "editorial-review.json"
$articlePath = Join-Path $outputDir "wechat-article.md"
$reportPaths = @($manifest.reports | ForEach-Object { "- $($_.date): $($_.json_path)" }) -join [Environment]::NewLine

$prompt = @"
# Independently Review a WeChat Editorial Draft

Read the project skill completely:
$skillPath

Read the decision:
$resolvedDecisionPath

Read the draft:
$resolvedDraftPath

Read the source reports for fact checking:
$reportPaths

Act as an independent editor. Do not assume the draft is correct because another model wrote it.

Review requirements:
- Verify material facts, dates, numbers, product names, qualifications, and inline links.
- Check that the article proves this thesis: $($decision.thesis)
- Remove unrelated news, repeated conclusions, generic transitions, jargon, fake scenes, and forced humor.
- Preserve natural human variation in sentence and paragraph length.
- Keep humor restrained and appropriate to the subject.
- Confirm that the title promise is fully delivered.
- Confirm that the article length fits $articleTypeName ($($articleType.min_chars)-$($articleType.max_chars) Chinese characters) without padding.
- Do not add unsupported facts while revising.

Score out of 100 using:
- Facts and sources: $($config.quality_gate.facts_and_sources)
- Thesis and judgment: $($config.quality_gate.thesis_and_judgment)
- Reader value: $($config.quality_gate.reader_value)
- Natural voice and readability: $($config.quality_gate.natural_voice)
- Structure and length: $($config.quality_gate.structure_and_length)
- Title and opening: $($config.quality_gate.title_and_opening)
- Visual direction readiness: $($config.quality_gate.visual_direction)

Hard failures:
- A material fact is wrong or unsupported.
- The thesis cannot be stated in one sentence.
- The title promises more than the article delivers.
- Important claims lack source links.

Write a valid JSON review report to:
$reviewReportPath

Review schema:
~~~json
{
  "pass": true,
  "total_score": 0,
  "hard_failures": [],
  "scores": {
    "facts_and_sources": 0,
    "thesis_and_judgment": 0,
    "reader_value": 0,
    "natural_voice": 0,
    "structure_and_length": 0,
    "title_and_opening": 0,
    "visual_direction": 0
  },
  "issues_fixed": [],
  "remaining_issues": [],
  "final_thesis": ""
}
~~~

The minimum passing score is $($config.quality_gate.minimum_total), with no hard failures.

Revise the draft and write the publishable Markdown to:
$articlePath

If a factual gap cannot be repaired from the supplied sources, set pass=false, record it as a hard failure, and do not create the final Markdown. Never invent a repair.
"@
$prompt | Set-Content -LiteralPath $reviewPromptPath -Encoding UTF8

[PSCustomObject]@{
    DraftPath = $resolvedDraftPath
    DecisionPath = $resolvedDecisionPath
    ReviewPromptPath = $reviewPromptPath
    ReviewReportPath = $reviewReportPath
    ArticlePath = $articlePath
    MinimumScore = [int]$config.quality_gate.minimum_total
    NextStep = "Ask Codex to read editorial-review-prompt.md, write the review report, and create the final article only when it passes."
} | ConvertTo-Json -Depth 5
