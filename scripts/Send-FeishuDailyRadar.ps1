param(
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,

    [string]$Title,
    [switch]$TextOnly,
    [switch]$DryRun,
    [int]$PollSeconds = 2,
    [int]$MaxPollAttempts = 20
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-RequiredEnv {
    param([string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required environment variable: $Name"
    }
    return $value
}

function Invoke-FeishuJson {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers,
        [object]$Body,
        [string]$Stage = "Feishu JSON request"
    )

    $jsonBody = $null
    if ($null -ne $Body) {
        $jsonBody = $Body | ConvertTo-Json -Depth 20 -Compress
    }

    if ($null -eq $Headers) {
        $Headers = @{}
    }
    $Headers["Content-Type"] = "application/json; charset=utf-8"
    $bodyBytes = $null
    if ($null -ne $jsonBody) {
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
    }

    try {
        $response = Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body $bodyBytes
    }
    catch {
        $responseText = ""
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseText = $reader.ReadToEnd()
        }
        throw "$Stage failed: $($_.Exception.Message) $responseText"
    }

    if ($null -ne $response.code -and $response.code -ne 0) {
        throw "$Stage failed: code=$($response.code), msg=$($response.msg)"
    }
    return $response
}

function Send-FeishuText {
    param(
        [string]$BaseUrl,
        [string]$Token,
        [string]$ChatId,
        [string]$Text
    )

    $headers = @{ Authorization = "Bearer $Token" }
    $body = @{
        receive_id = $ChatId
        msg_type = "text"
        content = (@{ text = $Text } | ConvertTo-Json -Compress)
    }

    Invoke-FeishuJson `
        -Method "POST" `
        -Uri "$BaseUrl/open-apis/im/v1/messages?receive_id_type=chat_id" `
        -Headers $headers `
        -Body $body `
        -Stage "Send Feishu text message" | Out-Null
}

function New-FeishuAccessToken {
    param(
        [string]$BaseUrl,
        [string]$AppId,
        [string]$AppSecret
    )

    $response = Invoke-FeishuJson `
        -Method "POST" `
        -Uri "$BaseUrl/open-apis/auth/v3/tenant_access_token/internal" `
        -Headers @{} `
        -Body @{ app_id = $AppId; app_secret = $AppSecret } `
        -Stage "Get Feishu tenant access token"

    if ([string]::IsNullOrWhiteSpace($response.tenant_access_token)) {
        throw "Feishu token response did not include tenant_access_token."
    }

    return $response.tenant_access_token
}

function Get-MarkdownSummary {
    param([string]$Content)

    $lines = $Content -split "`r?`n"
    $summaryLines = New-Object System.Collections.Generic.List[string]
    $itemCount = 0

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0) {
            continue
        }

        if ($trimmed -match "^###\s+") {
            $itemCount += 1
            $clean = $trimmed -replace "^###\s+\d+\.\s*", ""
            $summaryLines.Add("$itemCount. $clean")
        }

        if ($itemCount -ge 3) {
            break
        }
    }

    $summary = ($summaryLines -join "`n").Trim()
    if ($summary.Length -gt 600) {
        $summary = $summary.Substring(0, 600) + "`n..."
    }
    return $summary
}

function Invoke-FeishuMultipartUpload {
    param(
        [string]$Uri,
        [string]$Token,
        [System.IO.FileInfo]$File
    )

    Add-Type -AssemblyName System.Net.Http

    $client = [System.Net.Http.HttpClient]::new()
    $form = [System.Net.Http.MultipartFormDataContent]::new()
    $stream = $null
    $fileContent = $null

    try {
        $client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $Token)

        $utf8 = [System.Text.Encoding]::UTF8

        $form.Add([System.Net.Http.StringContent]::new($File.Name, $utf8), "file_name")
        $form.Add([System.Net.Http.StringContent]::new("ccm_import_open", $utf8), "parent_type")
        $form.Add([System.Net.Http.StringContent]::new($File.Length.ToString(), $utf8), "size")

        $extra = @{ obj_type = "docx"; file_extension = "md" } | ConvertTo-Json -Compress
        $form.Add([System.Net.Http.StringContent]::new($extra, $utf8), "extra")

        $stream = [System.IO.File]::OpenRead($File.FullName)
        $fileContent = [System.Net.Http.StreamContent]::new($stream)
        $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("text/markdown")
        $form.Add($fileContent, "file", $File.Name)

        $response = $client.PostAsync($Uri, $form).GetAwaiter().GetResult()
        $responseText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        if (-not $response.IsSuccessStatusCode) {
            throw "Feishu upload HTTP failed: status=$([int]$response.StatusCode), body=$responseText"
        }

        $result = $responseText | ConvertFrom-Json
        if ($result.code -ne 0) {
            throw "Feishu upload failed: code=$($result.code), msg=$($result.msg)"
        }

        return $result
    }
    finally {
        if ($null -ne $fileContent) { $fileContent.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
        $form.Dispose()
        $client.Dispose()
    }
}

function Import-MarkdownToFeishuDoc {
    param(
        [string]$BaseUrl,
        [string]$Token,
        [string]$Path,
        [string]$FileTitle,
        [string]$FolderToken,
        [int]$PollSeconds,
        [int]$MaxPollAttempts
    )

    $file = Get-Item -LiteralPath $Path
    $headers = @{ Authorization = "Bearer $Token" }

    $uploadResponse = Invoke-FeishuMultipartUpload `
        -Uri "$BaseUrl/open-apis/drive/v1/medias/upload_all" `
        -Token $Token `
        -File $file

    $fileToken = $uploadResponse.data.file_token
    if ([string]::IsNullOrWhiteSpace($fileToken)) {
        throw "Feishu upload response did not include file_token."
    }

    $importBody = @{
        file_extension = "md"
        file_token = $fileToken
        type = "docx"
        file_name = $FileTitle
        point = @{
            mount_type = 1
            mount_key = $FolderToken
        }
    }

    $importResponse = Invoke-FeishuJson `
        -Method "POST" `
        -Uri "$BaseUrl/open-apis/drive/v1/import_tasks" `
        -Headers $headers `
        -Body $importBody `
        -Stage "Create Feishu import task"

    $ticket = $importResponse.data.ticket
    if ([string]::IsNullOrWhiteSpace($ticket)) {
        throw "Feishu import response did not include ticket."
    }

    for ($i = 1; $i -le $MaxPollAttempts; $i++) {
        Start-Sleep -Seconds $PollSeconds

        $taskResponse = Invoke-RestMethod `
            -Method "GET" `
            -Uri "$BaseUrl/open-apis/drive/v1/import_tasks/$ticket" `
            -Headers $headers

        if ($taskResponse.code -ne 0) {
            throw "Feishu import task query failed: code=$($taskResponse.code), msg=$($taskResponse.msg)"
        }

        $result = $taskResponse.data.result
        if ($result.job_status -eq 0) {
            return [PSCustomObject]@{
                Url = $result.url
                Token = $result.token
                Type = $result.type
            }
        }

        if ($result.job_status -notin @(1, 2)) {
            throw "Feishu import failed: status=$($result.job_status), msg=$($result.job_error_msg)"
        }
    }

    throw "Feishu import did not finish after $MaxPollAttempts attempts."
}

$resolvedMarkdownPath = Resolve-Path -LiteralPath $MarkdownPath
$content = Get-Content -LiteralPath $resolvedMarkdownPath -Raw -Encoding UTF8

if ([string]::IsNullOrWhiteSpace($Title)) {
    $firstHeading = ($content -split "`r?`n" | Where-Object { $_ -match "^#\s+" } | Select-Object -First 1)
    if ($firstHeading) {
        $Title = ($firstHeading -replace "^#\s+", "").Trim()
    }
    else {
        $Title = "AI Daily Radar"
    }
}

$baseUrl = [Environment]::GetEnvironmentVariable("FEISHU_OPEN_API_BASE")
if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    $baseUrl = "https://open.feishu.cn"
}
$baseUrl = $baseUrl.TrimEnd("/")

$summary = Get-MarkdownSummary -Content $content

if ($DryRun) {
    [PSCustomObject]@{
        Mode = if ($TextOnly) { "text" } else { "docx" }
        Title = $Title
        MarkdownPath = $resolvedMarkdownPath.ToString()
        SummaryPreview = $summary
        WouldSend = $true
        BaseUrl = $baseUrl
    } | ConvertTo-Json -Depth 4
    return
}

$appId = Get-RequiredEnv "FEISHU_APP_ID"
$appSecret = Get-RequiredEnv "FEISHU_APP_SECRET"
$chatId = Get-RequiredEnv "FEISHU_CHAT_ID"
$folderToken = [Environment]::GetEnvironmentVariable("FEISHU_FOLDER_TOKEN")
if ($null -eq $folderToken) {
    $folderToken = ""
}

$token = New-FeishuAccessToken -BaseUrl $baseUrl -AppId $appId -AppSecret $appSecret

if ($TextOnly) {
    Send-FeishuText -BaseUrl $baseUrl -Token $token -ChatId $chatId -Text $summary
    [PSCustomObject]@{
        Mode = "text"
        Title = $Title
        Sent = $true
    } | ConvertTo-Json -Depth 4
    return
}

$doc = Import-MarkdownToFeishuDoc `
    -BaseUrl $baseUrl `
    -Token $token `
    -Path $resolvedMarkdownPath `
    -FileTitle $Title `
    -FolderToken $folderToken `
    -PollSeconds $PollSeconds `
    -MaxPollAttempts $MaxPollAttempts

$todayHighlightsLabel = [System.Text.Encoding]::UTF8.GetString([byte[]](0xE4,0xBB,0x8A,0xE6,0x97,0xA5,0xE9,0x87,0x8D,0xE7,0x82,0xB9))
$readFullLabel = [System.Text.Encoding]::UTF8.GetString([byte[]](0xE9,0x98,0x85,0xE8,0xAF,0xBB,0xE5,0x85,0xA8,0xE6,0x96,0x87))

$message = @(
    $Title,
    "",
    $todayHighlightsLabel,
    $summary,
    "",
    "${readFullLabel}:",
    $doc.Url
) -join [Environment]::NewLine

Send-FeishuText -BaseUrl $baseUrl -Token $token -ChatId $chatId -Text $message

[PSCustomObject]@{
    Mode = "docx"
    Title = $Title
    Url = $doc.Url
    Token = $doc.Token
    Sent = $true
} | ConvertTo-Json -Depth 4
