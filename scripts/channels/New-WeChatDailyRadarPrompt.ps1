param(
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,
    [string]$JsonPath = "",
    [string]$Title = "",
    [int]$TopItemCount = 5,
    [int]$BriefCount = 3
)

$ErrorActionPreference = "Stop"

function Get-FirstHeading {
    param([string]$Markdown)
    $heading = ($Markdown -split "`r?`n" | Where-Object { $_ -match "^#\s+" } | Select-Object -First 1)
    if ($heading) {
        return ($heading -replace "^#\s+", "").Trim()
    }
    return ""
}

function Get-RunDirFromMarkdown {
    param([System.IO.FileInfo]$MarkdownFile)

    $markdownDir = $MarkdownFile.Directory.FullName
    if ((Split-Path -Leaf $markdownDir) -eq "common") {
        return Split-Path -Parent $markdownDir
    }
    return $markdownDir
}

$resolvedMarkdownPath = Resolve-Path -LiteralPath $MarkdownPath
$markdownFile = Get-Item -LiteralPath $resolvedMarkdownPath
$commonDir = $markdownFile.Directory.FullName
$runDir = Get-RunDirFromMarkdown -MarkdownFile $markdownFile
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$wechatArticleWriterSkillPath = Join-Path $projectRoot "skills\wechat-article-writer\SKILL.md"

if ([string]::IsNullOrWhiteSpace($JsonPath)) {
    $JsonPath = [System.IO.Path]::ChangeExtension($markdownFile.FullName, ".json")
}
$resolvedJsonPath = Resolve-Path -LiteralPath $JsonPath

$wechatDir = Join-Path (Join-Path $runDir "channels") "wechat"
$imageDir = Join-Path $wechatDir "imgs"
New-Item -ItemType Directory -Force -Path $wechatDir, $imageDir | Out-Null

$articlePath = Join-Path $wechatDir "wechat-article.md"
$promptPath = Join-Path $wechatDir "wechat-article-prompt.md"
$assetsPromptPath = Join-Path $wechatDir "wechat-assets-prompt.md"
$coverPath = Join-Path $imageDir "cover.png"
$heroPath = Join-Path $imageDir "hero.png"
$itemImagePath = Join-Path $imageDir "item-01.png"

$dailyMarkdown = Get-Content -LiteralPath $resolvedMarkdownPath -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = Get-FirstHeading -Markdown $dailyMarkdown
}
if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = [System.IO.Path]::GetFileNameWithoutExtension($markdownFile.Name)
}

$articlePrompt = @"
# Generate WeChat Official Account Article

Read the source daily report:
$resolvedMarkdownPath

Read the machine-readable report:
$resolvedJsonPath

Follow the third-party skill:
$wechatArticleWriterSkillPath

Write a WeChat Official Account article in Chinese.

Output file:
- Markdown: $articlePath

Required frontmatter:
```yaml
---
title: "<写一个自然、有判断的公众号标题；不要直接照搬“$Title”，除非它已经足够像人写的标题。>"
description: "用 80-120 字概括这篇文章最值得关注的变化。"
cover: "imgs/cover.png"
---
```

Writing requirements:
- Use the daily JSON as the source of truth; use the Markdown for editorial context.
- Do not set author in frontmatter; the publishing step will use config/local.secrets.json wechat.accounts[].author.
- Do not invent facts or new sources.
- Rewrite the briefing into a publishable WeChat article, not a copied list.
- Preserve source attribution as ordinary inline Markdown links in the article body.
- For every main point, include at least one source link next to the relevant fact, using `[source name](https://...)`.
- For important claims such as model releases, policy changes, funding, product launches, benchmarks, or company announcements, keep the original source URL from the daily JSON/Markdown.
- Do not use bare URLs, footnote syntax, or a hand-written "references" section; the WeChat publishing step will convert ordinary Markdown links into bottom citations.
- Keep about $TopItemCount main points and about $BriefCount short follow-up signals, but do not force every item to use the same length.
- Use a concrete opening scene or reader problem instead of a generic summary opening. The scene must be inferred from the report; do not invent specific people, companies, or events.
- Write like an industry editor explaining what they actually noticed today, not like an AI-generated briefing.
- Add interpretation for domestic developers, enterprises, and Chinese users where useful.
- Keep paragraphs short, but vary sentence length. Allow some one-sentence paragraphs for emphasis.
- Make editorial choices: write 1-2 items deeply, compress lower-priority items, and explain why this ordering matters.
- Avoid obvious AI-writing patterns:
  - Do not use boilerplate phrases such as "值得关注的是", "综上", "总体来看", "从...到...", "不仅...还...", "这意味着" repeatedly.
  - Reduce abstract buzzwords such as "赋能", "生态", "闭环", "底层逻辑", "范式", "基础设施" unless they are truly necessary.
  - Do not use perfectly symmetric headings for every section.
  - Do not over-explain every paragraph with "为什么重要"; turn it into natural judgement.
- After drafting, do one final "去 AI 味编辑" pass:
  - Replace template-like section titles with more conversational but still professional headings.
  - Remove repeated transition patterns.
  - Keep facts unchanged and links intact.
  - Make the article feel like it was selected and edited by a human.
- Insert these local images in the article:
  - `![封面](imgs/cover.png)` near the top only if it is useful for preview.
  - `![今日主线](imgs/hero.png)` after the introduction.
  - `![结构图](imgs/item-01.png)` before the analysis section.
- Before finishing, check that source links are still present and are written as ordinary Markdown links; the WeChat publishing step will convert them to bottom citations.
- Do not send to Feishu.
- Do not create or publish a WeChat draft in this step.

Suggested structure:
1. A human editorial headline and concrete opening.
2. A short "today's real signal" section, not necessarily named 今日主线.
3. Two deeper analysis sections plus several compressed signals.
4. Practical implications for developers, enterprises, or Chinese users.
5. A concise editorial judgement.
6. Follow-up watchlist.

After writing, ensure the Markdown renders cleanly and references only images under:
$imageDir
"@

$assetsPrompt = @"
# Generate WeChat Article Images

Use imagegen to create project-bound bitmap assets for the WeChat article.

Article Markdown:
$articlePath

Output directory:
$imageDir

Required assets:

1. Cover image
- Save as: $coverPath
- Use case: ads-marketing
- Asset type: WeChat Official Account cover image
- Style: restrained Chinese business/technology magazine cover, clean typography, low-saturation editorial palette, no sci-fi glow, no brand logos
- Text (verbatim): "$Title"
- Constraints: no fake company logos, no watermarks, readable Chinese title, no glowing brain, no cyberpunk city, no generic AI robot, no dense decorative data streams.

2. Hero image
- Save as: $heroPath
- Use case: infographic-diagram
- Asset type: article hero infographic
- Style: restrained editorial opener, like a magazine information spread or desk-note visual; concrete but abstract enough for industry analysis
- Text (verbatim): "今日主线"
- Constraints: do not include unsupported factual claims, no brand logos, no watermark, no glowing brain, no radar screen, no excessive futuristic UI, minimal labels.

3. Structure image
- Save as: $itemImagePath
- Use case: infographic-diagram
- Asset type: simple article structure chart
- Style: clean three-part editorial note card or whiteboard-style information graphic, low-saturation, plenty of whitespace
- Text (verbatim): "关键变化 | 工程影响 | 后续动作"
- Constraints: readable Chinese labels, no fake UI screenshots, no watermark, no dense generated text, no sci-fi dashboard.

After generation, keep final selected image files in the output directory above.
"@

$articlePrompt | Set-Content -LiteralPath $promptPath -Encoding UTF8
$assetsPrompt | Set-Content -LiteralPath $assetsPromptPath -Encoding UTF8

[PSCustomObject]@{
    MarkdownPath = $resolvedMarkdownPath.ToString()
    JsonPath = $resolvedJsonPath.ToString()
    RunDir = $runDir
    CommonDir = $commonDir
    WeChatDir = $wechatDir
    ArticlePath = $articlePath
    ArticlePromptPath = $promptPath
    AssetsPromptPath = $assetsPromptPath
    ImageDir = $imageDir
    CoverPath = $coverPath
    HeroPath = $heroPath
    ItemImagePath = $itemImagePath
    NextStep = "Ask Codex: Read wechat-article-prompt.md, generate wechat-article.md, then use imagegen with wechat-assets-prompt.md to create cover and article images."
} | ConvertTo-Json -Depth 6

