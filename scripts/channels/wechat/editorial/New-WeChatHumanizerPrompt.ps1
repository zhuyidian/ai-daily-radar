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
$projectRoot = Get-EditorialProjectRoot
$humanizerSkillPath = Join-Path $projectRoot "skills\humanizer-zh\SKILL.md"
if (-not (Test-Path -LiteralPath $humanizerSkillPath)) {
    throw "Humanizer skill does not exist: $humanizerSkillPath"
}

$humanizerPromptPath = Join-Path $outputDir "humanizer-prompt.md"
$humanizedPath = Join-Path $outputDir "wechat-article-humanized.md"
$humanizerReportPath = Join-Path $outputDir "humanizer-report.json"
$reportPaths = @($manifest.reports | ForEach-Object { "- $($_.date): $($_.json_path)" }) -join [Environment]::NewLine
$selectedItems = @($decision.selected_items | ForEach-Object {
    "- $($_.title) | role=$($_.role) | date=$($_.report_date) | source=$($_.source_url)"
}) -join [Environment]::NewLine

$prompt = @"
# Humanize a WeChat Editorial Draft

Read the Humanizer skill completely:
$humanizerSkillPath

Read the original draft:
$resolvedDraftPath

Read the editorial decision:
$resolvedDecisionPath

Read the source reports for fact locking:
$reportPaths

Core thesis that must not drift:
$($decision.thesis)

Selected evidence that must remain traceable:
$selectedItems

Rewrite the draft to reduce AI-like prose and make it feel naturally edited by a Chinese WeChat editor.

Hard boundaries:
- Do not add new facts, examples, sources, anecdotes, claims, or images.
- Do not remove or change ordinary Markdown source links.
- Do not change dates, numbers, company names, product names, model names, paper titles, or quoted technical terms.
- Do not turn reported claims into verified facts.
- Preserve uncertainty markers and source-qualification wording already present in the draft, including phrases equivalent to "reported", "the paper says", "researchers say", "if verified", and "still needs verification".
- Preserve the title promise and article thesis.
- Keep frontmatter valid and do not set author.
- Keep local image references unchanged if the draft already has them.

Improve:
- opening tension;
- sentence rhythm;
- paragraph variation;
- concrete verbs and nouns;
- natural transitions;
- visible but restrained editorial judgment;
- ending that gives a useful decision criterion instead of a summary loop.

Write the humanized Markdown to:
$humanizedPath

Write a valid JSON report to:
$humanizerReportPath

Report schema:
~~~json
{
  "pass": true,
  "facts_preserved": true,
  "links_preserved": true,
  "numbers_preserved": true,
  "thesis_preserved": true,
  "changes": [],
  "risk_notes": [],
  "protected_terms_checked": []
}
~~~

Set pass=false if you cannot safely preserve facts or links. If pass=false, do not let the next review stage use the humanized draft.
"@
$prompt | Set-Content -LiteralPath $humanizerPromptPath -Encoding UTF8

[PSCustomObject]@{
    DraftPath = $resolvedDraftPath
    DecisionPath = $resolvedDecisionPath
    HumanizerSkillPath = $humanizerSkillPath
    HumanizerPromptPath = $humanizerPromptPath
    HumanizedPath = $humanizedPath
    HumanizerReportPath = $humanizerReportPath
    NextStep = "Ask Codex to read humanizer-prompt.md, write wechat-article-humanized.md and humanizer-report.json, then review the humanized draft only if pass=true."
} | ConvertTo-Json -Depth 5
