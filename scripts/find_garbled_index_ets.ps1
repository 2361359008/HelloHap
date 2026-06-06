param(
  [string]$FilePath = "d:\DevEcoProjects\HelloHap\entry\src\main\ets\pages\Index.ets"
)

if (-not (Test-Path $FilePath)) {
  Write-Host "File not found: $FilePath"
  exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($FilePath)
$textUtf8 = [System.Text.Encoding]::UTF8.GetString($bytes)
$textGbk = [System.Text.Encoding]::GetEncoding(936).GetString($bytes)

$patterns = @(
  '[\uFFFD]',
  '[\uFFFE]',
  '[\uFFFF]'
)

$extraPatterns = @(
  '缂栬瘧',
  '鍔犺浇',
  '瑙ｆ瀽',
  '鎵ц',
  '鐢熸垚',
  '杩涜',
  '璋冪敤',
  '鍚姩',
  '鍚屾',
  '鍙戣',
  '闈欐€',
  '鍖',
  '鐩',
  '閿',
  '鍏',
  '閸旂姾娴'
)

function Find-SuspectLines {
  param(
    [string]$Text,
    [string]$Label
  )

  Write-Host "=== $Label ==="
  $lines = $Text -split "`r?`n"
  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    $matched = $false

    foreach ($pattern in $patterns) {
      if ($line -match $pattern) {
        $matched = $true
        break
      }
    }

    if (-not $matched) {
      foreach ($pattern in $extraPatterns) {
        if ($line -match $pattern) {
          $matched = $true
          break
        }
      }
    }

    if ($matched) {
      $safe = $line.Replace("`t", "    ")
      Write-Host (("{0,5}: {1}" -f ($i + 1), $safe))
    }
  }
  Write-Host ""
}

Find-SuspectLines -Text $textUtf8 -Label "UTF-8 decode"
Find-SuspectLines -Text $textGbk -Label "GBK decode"
