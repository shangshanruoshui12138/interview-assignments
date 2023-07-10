# 正则表达式 (时间) (设备) (进程名称) (进程ID) (日志信息)
$regex = '(\S+\s+\S+\s+\S+)\s(\S+)\s([^[]+?)\[(\S+)](.+)'
# 定义哈希表来存储数据
$deviceSet = New-Object System.Collections.Generic.HashSet[string]

$processSet = New-Object System.Collections.Generic.HashSet[string]
$pidSet = New-Object System.Collections.Generic.HashSet[int]
$tEr = @{}
$tW = @()
# 定义一个字符串后面用于存储 JSON 结构 array[dict]
$description = @()

function SplitLine($line) {
    if ($line -match $regex) {
        $time = $matches[1]
        $device = $matches[2]
        $process = $matches[3]
        $proid = $matches[4]
        $message = $matches[5]
      
    } else {
        Write-Host "$line 正则未能匹配日志"
    }
    return $time,$device,$process,$proid,$message
}

function ConvertToJSON() {
    $deviceName = @($deviceSet -join '", "') # 转换为 JSON 数组
    $processName = @($processSet  -join '", "') # 转换为 JSON 数组
    $timeWindow = @($tEr.Keys -join '", "') # 转换为 JSON 数组
    $processId = @($pidSet -join '", "') # 转换为 JSON 数组
    $descriptions = $description | ForEach-Object {
        [PSCustomObject]@{
            "pid" = $_.pid
            "process" = $_.process
            "errorLog" = $_.errorLog
        }
    }

 
    $numberOfOccurrence = $tEr.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
        "date" = $_.Key
        "errorCount" = $_.Value
    }
}


    $requestBody = @{
        "deviceName" = $deviceName
        "processId" = $processId
        "processName" = $processName
        "timeWindow" = $timeWindow
        "numberOfOccurrence" = $numberOfOccurrence
        "description" = $descriptions
    } | ConvertTo-Json

    $requestBody # 返回 JSON 字符串
    #Invoke-RestMethod -Uri "https://foo.com/bar" -Method Post -Headers @{"Content-Type" = "application/json"} -Body $requestBody
}

function Main() {
    Get-Content -Path interview_data_set | ForEach-Object {
        $errorLog = $_ | Select-String -Pattern 'error'
        if ($errorLog) {
            $result=SplitLine($_)  
          
            [void]$deviceSet.Add($result[1])
            [void]$processSet.Add($result[2])
            [void]$pidSet.Add($result[3])
            $date = [DateTime]::ParseExact($result[0], "MMM d HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
            $hour = $date.ToString("MMM/d/HH")
            if ($tEr.ContainsKey($hour)) {
                $tEr[$hour]++
            } else {
                $tEr[$hour] = 1
            }

             $description += @{
                "pid" = $result[3]
                "process" = $result[2]
                "errorLog" = $result[4]
            }
        }
    }
    ConvertToJSON
}

Main
