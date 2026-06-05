param(
    [DateTime]$Date = (Get-Date),
    [int]$LookbackHours = 24,
    [string]$OutputRoot,
    [string]$ConfigPath,
    [int]$MaxItemsPerSource = 20,
    [switch]$NoGoogleNews
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    throw "OutputRoot is required."
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    throw "ConfigPath is required."
}

function Get-TextValue {
    param($Value)
    if ($null -eq $Value) { return "" }
    if ($Value -is [System.Xml.XmlNode]) { return $Value.InnerText.Trim() }
    return ([string]$Value).Trim()
}

function Get-AtomLink {
    param($Entry)
    if ($null -eq $Entry.link) { return "" }
    foreach ($link in @($Entry.link)) {
        if ($link.href -and ($null -eq $link.rel -or $link.rel -eq "alternate")) {
            return ([string]$link.href).Trim()
        }
    }
    if ($Entry.link.href) { return ([string]$Entry.link.href).Trim() }
    return (Get-TextValue $Entry.link)
}

function ConvertTo-DateTimeOffsetOrNull {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    try {
        return [DateTimeOffset]::Parse($Value)
    }
    catch {
        return $null
    }
}

function Get-NormalizedUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return "" }
    try {
        $builder = [System.UriBuilder]::new($Url)
        if ($builder.Query) {
            $kept = New-Object System.Collections.Generic.List[string]
            foreach ($part in $builder.Query.TrimStart("?").Split("&")) {
                if ([string]::IsNullOrWhiteSpace($part)) { continue }
                $key = $part.Split("=")[0]
                if ($key -notmatch "^(utm_|fbclid|gclid)") {
                    $kept.Add($part)
                }
            }
            $builder.Query = ($kept -join "&")
        }
        return $builder.Uri.AbsoluteUri.TrimEnd("/").ToLowerInvariant()
    }
    catch {
        return $Url.TrimEnd("/").ToLowerInvariant()
    }
}

function Get-KeywordScore {
    param(
        [string]$Text,
        [string[]]$Keywords
    )
    $score = 0
    foreach ($keyword in $Keywords) {
        if ($Text -match [regex]::Escape($keyword)) {
            $score += 1
        }
    }
    return [Math]::Min($score, 8)
}

function Invoke-RssFetch {
    param(
        [string]$Name,
        [string]$FeedUrl,
        [int]$Priority,
        [string[]]$Topics,
        [DateTimeOffset]$WindowStart,
        [DateTimeOffset]$WindowEnd,
        [string[]]$Keywords,
        [int]$MaxItems
    )

    $items = New-Object System.Collections.Generic.List[object]
    $headers = @{
        "User-Agent" = "daily-radar/0.2"
    }

    try {
        $response = Invoke-WebRequest -Uri $FeedUrl -Headers $headers -UseBasicParsing -TimeoutSec 25
        [xml]$xml = ([string]$response.Content).TrimStart()
    }
    catch {
        return [PSCustomObject]@{
            source = $Name
            ok = $false
            error = $_.Exception.Message
            items = [object[]]@()
        }
    }

    $rawItems = @()
    if ($xml.rss.channel.item) {
        $rawItems = @($xml.rss.channel.item)
    }
    elseif ($xml.feed.entry) {
        $rawItems = @($xml.feed.entry)
    }

    foreach ($raw in ($rawItems | Select-Object -First $MaxItems)) {
        $isAtom = ($null -ne $xml.feed)
        $title = Get-TextValue $raw.title
        $link = if ($isAtom) { Get-AtomLink $raw } else { Get-TextValue $raw.link }
        $summary = if ($raw.summary) { Get-TextValue $raw.summary } elseif ($raw.description) { Get-TextValue $raw.description } else { "" }
        $publishedRaw = if ($raw.published) { Get-TextValue $raw.published } elseif ($raw.updated) { Get-TextValue $raw.updated } elseif ($raw.pubDate) { Get-TextValue $raw.pubDate } else { "" }
        $published = ConvertTo-DateTimeOffsetOrNull $publishedRaw

        if ($published -and ($published -lt $WindowStart -or $published -gt $WindowEnd)) {
            continue
        }

        $textForScore = "$title $summary"
        $keywordScore = Get-KeywordScore -Text $textForScore -Keywords $Keywords
        $recencyScore = 0
        if ($published) {
            $hoursOld = ($WindowEnd - $published).TotalHours
            if ($hoursOld -le 12) { $recencyScore = 3 }
            elseif ($hoursOld -le 24) { $recencyScore = 2 }
            elseif ($hoursOld -le 48) { $recencyScore = 1 }
        }

        $items.Add([PSCustomObject]@{
            title = $title
            url = $link
            source_name = $Name
            source_url = $FeedUrl
            published_at = if ($published) { $published.UtcDateTime.ToString("o") } else { $null }
            summary = $summary
            topics = $Topics
            priority = $Priority
            keyword_score = $keywordScore
            recency_score = $recencyScore
            candidate_score = $Priority + $keywordScore + $recencyScore
            collection_method = "rss"
        })
    }

    return [PSCustomObject]@{
        source = $Name
        ok = $true
        error = $null
        items = $items.ToArray()
    }
}

function New-GoogleNewsFeedUrl {
    param(
        [string]$Query,
        [int]$LookbackHours
    )
    $days = [Math]::Max(1, [Math]::Ceiling($LookbackHours / 24))
    $encoded = [System.Uri]::EscapeDataString("$Query when:${days}d")
    return "https://news.google.com/rss/search?q=$encoded&hl=en-US&gl=US&ceid=US:en"
}

$projectRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$configFullPath = Resolve-Path -LiteralPath (Join-Path $projectRoot $ConfigPath)
$config = Get-Content -LiteralPath $configFullPath -Raw -Encoding UTF8 | ConvertFrom-Json

$dateText = $Date.ToString("yyyy-MM-dd")
$runDir = Join-Path $projectRoot (Join-Path $OutputRoot $dateText)
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$windowEnd = [DateTimeOffset]$Date
$windowStart = $windowEnd.AddHours(-1 * $LookbackHours)
$keywords = @($config.keywords)
$sourceResults = New-Object System.Collections.Generic.List[object]

foreach ($source in @($config.direct_feeds)) {
    $sourceResults.Add((Invoke-RssFetch `
        -Name $source.name `
        -FeedUrl $source.feed_url `
        -Priority ([int]$source.priority) `
        -Topics @($source.topics) `
        -WindowStart $windowStart `
        -WindowEnd $windowEnd `
        -Keywords $keywords `
        -MaxItems $MaxItemsPerSource))
}

if (-not $NoGoogleNews) {
    foreach ($query in @($config.google_news_queries)) {
        $feedUrl = New-GoogleNewsFeedUrl -Query $query.query -LookbackHours $LookbackHours
        $sourceResults.Add((Invoke-RssFetch `
            -Name "Google News: $($query.name)" `
            -FeedUrl $feedUrl `
            -Priority ([int]$query.priority) `
            -Topics @($query.topics) `
            -WindowStart $windowStart `
            -WindowEnd $windowEnd `
            -Keywords $keywords `
            -MaxItems $MaxItemsPerSource))
    }
}

$seen = @{}
$candidates = New-Object System.Collections.Generic.List[object]
foreach ($result in $sourceResults) {
    foreach ($item in @($result.items)) {
        $key = Get-NormalizedUrl $item.url
        if ([string]::IsNullOrWhiteSpace($key)) {
            $key = ($item.title + "|" + $item.source_name).ToLowerInvariant()
        }
        if ($seen.ContainsKey($key)) {
            continue
        }
        $seen[$key] = $true
        $candidates.Add($item)
    }
}

$orderedCandidates = @($candidates | Sort-Object -Property @{ Expression = "candidate_score"; Descending = $true }, @{ Expression = "published_at"; Descending = $true })

$output = [PSCustomObject]@{
    date = $dateText
    window_start = $windowStart.UtcDateTime.ToString("o")
    window_end = $windowEnd.UtcDateTime.ToString("o")
    timezone = [TimeZoneInfo]::Local.Id
    generated_at = ([DateTimeOffset]::Now).UtcDateTime.ToString("o")
    candidate_count = $orderedCandidates.Count
    sources = @($sourceResults | ForEach-Object {
        [PSCustomObject]@{
            name = $_.source
            ok = $_.ok
            error = $_.error
            item_count = @($_.items).Count
        }
    })
    candidates = $orderedCandidates
}

$outputPath = Join-Path $runDir "candidates.json"
$output | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outputPath -Encoding UTF8

$failedSourceCount = 0
foreach ($sourceResult in $sourceResults) {
    if (-not $sourceResult.ok) {
        $failedSourceCount += 1
    }
}
$sourceCount = $sourceResults.Count

[PSCustomObject]@{
    Date = $dateText
    RunDir = $runDir
    OutputPath = $outputPath
    CandidateCount = $orderedCandidates.Count
    SourceCount = $sourceCount
    FailedSourceCount = $failedSourceCount
} | ConvertTo-Json -Depth 6
