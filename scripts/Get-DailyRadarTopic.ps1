param(
    [string]$Topic = "ai"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$topicPath = Join-Path $projectRoot (Join-Path "config\topics" (Join-Path $Topic "topic.json"))

if (-not (Test-Path -LiteralPath $topicPath)) {
    throw "Topic config does not exist: $topicPath"
}

$topicConfig = Get-Content -LiteralPath $topicPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Resolve-ProjectPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return (Join-Path $projectRoot $Path)
}

$topicConfig | Add-Member -NotePropertyName ProjectRoot -NotePropertyValue ([string]$projectRoot) -Force
$topicConfig | Add-Member -NotePropertyName TopicConfigPath -NotePropertyValue ([string]$topicPath) -Force
$topicConfig | Add-Member -NotePropertyName RunRoot -NotePropertyValue (Join-Path ".runs" ([string]$topicConfig.run_name)) -Force
$topicConfig | Add-Member -NotePropertyName CollectionConfigFullPath -NotePropertyValue (Resolve-ProjectPath ([string]$topicConfig.collection_config_path)) -Force
$topicConfig | Add-Member -NotePropertyName AutomationPromptFullPath -NotePropertyValue (Resolve-ProjectPath ([string]$topicConfig.automation_prompt_path)) -Force
$topicConfig | Add-Member -NotePropertyName SourcesFullPath -NotePropertyValue (Resolve-ProjectPath ([string]$topicConfig.sources_path)) -Force
$topicConfig | Add-Member -NotePropertyName SkillFullPath -NotePropertyValue (Resolve-ProjectPath ([string]$topicConfig.skill_path)) -Force
$topicConfig | Add-Member -NotePropertyName TemplateFullPath -NotePropertyValue (Resolve-ProjectPath ([string]$topicConfig.template_path)) -Force

$topicConfig
