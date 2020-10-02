param ([Parameter(Mandatory)]$authorizationHeaderValue, [int]$pageSize = 1000)

$baseUri = "https://cc-api-storage.adobe.io/id/";
$deleteGetParams = "?invocation_mode=ASYNC&recursive=true";
$successCount = 0;
$errorCount = 0;

function Get-Assets{
    try{
        $searchRequest = Invoke-WebRequest -Uri "https://adobesearch.adobe.io/universal-search/v2/search" `
                -Method "POST" `
                -Headers @{
                    "Authorization"="$($authorizationHeaderValue)"
                      "X-Api-Key"="CCXWeb1"
                      "X-Product"="AssetsWeb/2.0"
                      "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36"
                      "X-Product-Location"="Assets 2.0"
                      "Accept"="*/*"
                      "Origin"="https://assets.adobe.com"
                      "Sec-Fetch-Site"="cross-site"
                      "Sec-Fetch-Mode"="cors"
                      "Sec-Fetch-Dest"="empty"
                      "Referer"="https://assets.adobe.com/"
                      "Accept-Encoding"="gzip, deflate, br"
                      "Accept-Language"="en-US,en;q=0.9"
                    } `
                -ContentType "application/vnd.adobe.search-request+json" `
                -Body "{`"sort_orderby`":`"modify_date`",`"creative_cloud_archive`":true,`"creative_cloud_discarded_directly`":true,`"fetch_fields`":{`"includes`":[`"creative_cloud_colortheme`",`"creative_cloud_gradient`",`"_embedded`"]},`"q`":`"*`",`"scope`":[`"creative_cloud`"],`"hints`":{`"creative_cloud_rendition_v2`":true},`"sort_order`":`"desc`",`"limit`":$($pageSize)}"
        (($imgs.Content | ConvertFrom-Json).result_sets | Where-Object {$_.name -eq "creative_cloud"}).items.asset_id;
    }
    catch {
        $error = $_.ErrorDetails.Message | ConvertFrom-Json;

        if ($error.error_code -eq "401013"){
            Write-Error "Invalid or expired auth token was provided. Should be unexpired and in format of 'Bearer .......'."
        }
        else {
            Write-Error "Unexpected error: $($error.error_code) - $($error.message)"
        }


        exit -1
    }
}

function Delete-Asset {
    param (
        [string]$asset
    )

    Invoke-WebRequest -Uri "https://cc-api-storage.adobe.io/id/$($asset)?invocation_mode=ASYNC&recursive=true" `
        -Method "DELETE" `
        -Headers @{
            "Cache-Control"="max-age=0"
              "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36"
              "If-Match"="*"
              "Authorization"="$($authorizationHeaderValue)"
              "X-Api-Key"="CCXWeb1"
              "Accept"="*/*"
              "Origin"="https://assets.adobe.com"
              "Sec-Fetch-Site"="cross-site"
              "Sec-Fetch-Mode"="cors"
              "Sec-Fetch-Dest"="empty"
              "Referer"="https://assets.adobe.com/"
              "Accept-Encoding"="gzip, deflate, br"
              "Accept-Language"="en-US,en;q=0.9"
            }

}
$stopwatch =  [System.Diagnostics.Stopwatch]::StartNew()

$assets = Get-Assets;

do {
    foreach ($a in $assets){
        $response = Delete-Asset -asset $a

        $totalAttemptedDelete++;
        if ($response.StatusCode -eq 204){
            $successCount++;
        }
        else{
            $errorCount++;
        }
    }

    $assets = Get-Assets;
} while ($assets); 

$output = [PSCustomObject]@{
    Success = $successCount
    Error = $errorCount
    TotalFound = $successCount + $errorCount
    TimeElapsed = $stopwatch.Elapsed
}

Write-Output $output