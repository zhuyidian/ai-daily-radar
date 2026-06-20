param(
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,
    [string]$ReviewPath = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Editorial.Common.ps1")

$resolvedMarkdownPath = (Resolve-Path -LiteralPath $MarkdownPath).Path
$outputDir = Split-Path -Parent $resolvedMarkdownPath
if ([string]::IsNullOrWhiteSpace($ReviewPath)) {
    $ReviewPath = Join-Path $outputDir "editorial-review.json"
}
$review = Read-RequiredJson -Path $ReviewPath
if (-not [bool]$review.pass) {
    throw "Editorial review has pass=false. Visual assets will not be planned."
}
$manifest = Read-RequiredJson -Path (Join-Path $outputDir "source-manifest.json")
$config = Read-RequiredJson -Path ([string]$manifest.editorial_config_path)
$markdown = Get-Content -LiteralPath $resolvedMarkdownPath -Raw -Encoding UTF8
$title = Get-FrontmatterValue -Markdown $markdown -Name "title"
if ([string]::IsNullOrWhiteSpace($title)) {
    throw "Article frontmatter is missing title: $resolvedMarkdownPath"
}

$imageDir = Join-Path $outputDir "imgs"
New-Item -ItemType Directory -Force -Path $imageDir | Out-Null
$assetsPromptPath = Join-Path $outputDir "editorial-assets-prompt.md"
$visualPlanPath = Join-Path $outputDir "visual-plan.json"
$coverPath = Join-Path $imageDir "cover.png"
$avoid = @($config.visual.avoid | ForEach-Object { "- $_" }) -join [Environment]::NewLine

$prompt = @"
# Plan and Create WeChat Editorial Visuals

Read the final article:
$resolvedMarkdownPath

Final title:
$title

First write a visual plan as valid JSON to:
$visualPlanPath

The plan must define:
- one cover concept tied to the article's thesis;
- between $($config.visual.body_image_min) and $($config.visual.body_image_max) body images, only when each image adds information;
- the purpose, placement, source type, composition, palette, and exact output filename for every image;
- whether a real screenshot, verified chart, simple diagram, collage, or editorial illustration is best.

Visual direction:
- Style: $($config.visual.style)
- Palette: $($config.visual.palette)
- Use one visual idea, generous whitespace, slight asymmetry, and restrained texture.
- Prefer real screenshots with annotations or simple diagrams when they explain the content better than illustration.
- For generated images, create the visual base without long Chinese text. Add real typography later when possible.
- Do not generate fake interfaces, fake statistics, fake company logos, watermarks, or unsupported claims.

Avoid:
$avoid

Required cover output:
$coverPath

Use imagegen only for bitmap assets that genuinely benefit from generation. Keep every final image under:
$imageDir

After creating the selected images, insert body-image Markdown references into the article only at positions specified by the visual plan. Keep the cover path in frontmatter; do not duplicate the cover as the first body image.
"@
$prompt | Set-Content -LiteralPath $assetsPromptPath -Encoding UTF8

[PSCustomObject]@{
    MarkdownPath = $resolvedMarkdownPath
    ReviewPath = (Resolve-Path -LiteralPath $ReviewPath).Path
    AssetsPromptPath = $assetsPromptPath
    VisualPlanPath = $visualPlanPath
    ImageDir = $imageDir
    CoverPath = $coverPath
    NextStep = "Ask Codex to read editorial-assets-prompt.md, write visual-plan.json, and create only the justified assets."
} | ConvertTo-Json -Depth 5
