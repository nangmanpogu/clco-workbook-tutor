# 학습 도우미 설치(Windows). 학습지 1-1 3절이 복사해 주는 한 줄이 이 파일을 받아 돌린다. 끝의 16자가 그 학습자의 설치 코드다.
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/nangmanpogu/clcoach-workbook-tutor/main/install.ps1))) <설치 코드>
#
# 하는 일
#   1. Git for Windows 가 없으면 winget 으로 깐다. Windows 의 Claude Code 는 Git Bash 가 있어야 도우미(sh)의 훅과 명령을
#      돌린다. 없으면 PowerShell 로 돌려서 도우미가 아무 일도 하지 못한다.
#   2. Claude Code 설정(~\.claude\settings.json)에 마켓플레이스와 도우미를 더한다. 있던 설정은 그대로 둔다.
#      Git Bash 의 자리(CLAUDE_CODE_GIT_BASH_PATH)도 적는다. 방금 깐 Git 은 켜져 있던 Claude 앱이 모른다.
#   3. Claude 앱에 딸린 Claude Code(claude.exe)로 도우미를 바로 깐다. 앱은 설정만 보고는 「설치됨」 기록만 남기고
#      파일을 캐시에 두지 않아, 새 세션을 열어도 앱을 다시 켜도 도우미가 실리지 않는다(Claude Code 2.1.308 실측).
#      claude.exe 를 못 찾거나 실패하면 앱에 맡긴다. 1-3 에서 안 실리면 학습지가 이 줄을 다시 붙여 넣게 한다.
#   4. 설치 코드를 학습지 서버에 내고 연결 토큰을 받아 둔다. 학습지는 서버에 물어 설치를 확인한다.
#   5. 1부 연습 폴더가 쓸 목록을 학습지에서 받아 둔다.
#
# 스크립트 블록으로 돌아서 exit 를 쓰면 학습자의 PowerShell 창이 닫힌다. 멈출 때는 Fail 이 예외를 던진다.
# Windows PowerShell 5.1 에서 돈다. 맥은 install.sh 다. 오류 번호(E1~E5)는 install.sh 와 같고 E4 만 Windows 것이다.
param([string]$Code = '')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$site = if ($env:WORKBOOK_TUTOR_SITE) { $env:WORKBOOK_TUTOR_SITE } else { 'https://console.clcoach.nangmanpg.com' }
$state = if ($env:WORKBOOK_TUTOR_HOME) { $env:WORKBOOK_TUTOR_HOME } else { Join-Path $HOME '.workbook-tutor' }
$config = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$again = '학습지에서 설치 줄을 다시 복사해 붙여 넣어요.'
$noGit = 'Git for Windows 를 깔지 못했어요. 관리자 확인 창이 뜨면 「예」를 눌러요. 그래도 안 되면 git-scm.com 에서 Git for Windows 를 받아 깐 뒤 같은 줄을 다시 붙여 넣어요.'
$utf8 = New-Object System.Text.UTF8Encoding $false
$stop = 'workbook-tutor-stop'

function Fail([string]$id, [string]$why) {
  Write-Host ''
  Write-Host "설치하지 못했어요($id). $why"
  Write-Host "학습지의 「막혔어요」를 누르면 $id 를 푸는 법이 있어요."
  throw $stop
}

# 파일을 .part 에 쓰고 바꿔 넣는다. 쓰다 멈춰도 원래 파일은 그대로다
function Write-Utf8([string]$path, [string]$text) {
  [IO.File]::WriteAllText("$path.part", $text, $utf8)
  Move-Item -LiteralPath "$path.part" -Destination $path -Force
}

# Git Bash(bash.exe)의 자리. Claude Code 가 보는 곳과 Git for Windows 가 까는 곳을 차례로 본다
function Find-GitBash {
  $places = @($env:CLAUDE_CODE_GIT_BASH_PATH)
  $git = Get-Command git.exe -ErrorAction SilentlyContinue
  if ($git) { $places += Join-Path (Split-Path (Split-Path $git.Source)) 'bin\bash.exe' }
  $places += Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
  if (${env:ProgramFiles(x86)}) { $places += Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe' }
  if ($env:LOCALAPPDATA) { $places += Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe' }
  foreach ($p in $places) {
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
  }
  return $null
}

# Claude 앱에 딸린 claude.exe. 앱이 판마다 폴더를 따로 두므로 가장 최근 것을 고른다. PATH 의 claude.exe 도 본다
function Find-Claude {
  $found = @()
  foreach ($pattern in @(
      (Join-Path $env:LOCALAPPDATA 'Claude-Data\*\claude-code\*\*\claude.exe'),
      (Join-Path $env:LOCALAPPDATA 'Claude-Data\*\claude-code\*\claude.exe'),
      (Join-Path $env:APPDATA 'Claude\claude-code\*\*\claude.exe'),
      (Join-Path $env:APPDATA 'Claude\claude-code\*\claude.exe'))) {
    $found += @(Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue)
  }
  $cli = Get-Command claude.exe -ErrorAction SilentlyContinue
  if ($cli) { $found += Get-Item -LiteralPath $cli.Source -ErrorAction SilentlyContinue }
  $pick = $found | Where-Object { $_ } | Sort-Object LastWriteTime | Select-Object -Last 1
  if ($pick) { return $pick.FullName }
  return $null
}

# claude.exe 를 창 없이 돌리고 끝나기를 1분까지 기다린다. 출력은 버린다. 성공이면 $true
function Invoke-Claude([string]$exe, [string[]]$arguments) {
  $out = [IO.Path]::GetTempFileName()
  $err = [IO.Path]::GetTempFileName()
  try {
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -NoNewWindow -PassThru `
      -RedirectStandardOutput $out -RedirectStandardError $err
    if (-not $p.WaitForExit(60000)) { $p.Kill(); return $false }
    return ($p.ExitCode -eq 0)
  } catch {
    return $false
  } finally {
    Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
  }
}

function Set-Field($obj, [string]$name, $value) {
  $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
}

# 설정에 마켓플레이스와 도우미, Git Bash 의 자리를 더한다. 있던 설정은 그대로 둔다. 읽거나 쓰지 못하면 $false
function Merge-Settings([string]$settings, [string]$bash) {
  try {
    New-Item -ItemType Directory -Force -Path (Split-Path $settings) | Out-Null
    $data = $null
    if (Test-Path -LiteralPath $settings) {
      $text = [IO.File]::ReadAllText($settings)
      if ($text.Trim()) { $data = ConvertFrom-Json -InputObject $text }
    }
    if ($null -eq $data) { $data = [pscustomobject]@{} }
    # [pscustomobject] 는 -is 에서 PSObject 로 읽혀 무엇이든 맞으므로 실제 타입 이름을 쓴다
    if ($data -isnot [System.Management.Automation.PSCustomObject]) { return $false }
    if ($null -eq $data.extraKnownMarketplaces) { Set-Field $data 'extraKnownMarketplaces' ([pscustomobject]@{}) }
    Set-Field $data.extraKnownMarketplaces 'nangmanpogu' ([pscustomobject]@{
        source     = [pscustomobject]@{ source = 'github'; repo = 'nangmanpogu/clcoach-workbook-tutor' }
        autoUpdate = $true
      })
    if ($null -eq $data.enabledPlugins) { Set-Field $data 'enabledPlugins' ([pscustomobject]@{}) }
    Set-Field $data.enabledPlugins 'workbook-tutor@nangmanpogu' $true
    if ($null -eq $data.env) { Set-Field $data 'env' ([pscustomobject]@{}) }
    if (-not $data.env.CLAUDE_CODE_GIT_BASH_PATH) { Set-Field $data.env 'CLAUDE_CODE_GIT_BASH_PATH' $bash }
    Write-Utf8 $settings ((ConvertTo-Json -InputObject $data -Depth 100) + "`n")
    return $true
  } catch {
    return $false
  }
}

try {
  if ($env:OS -ne 'Windows_NT') { Fail E1 '이 줄은 Windows 용이에요. Mac 은 학습지가 보여 주는 Mac 줄을 터미널에 붙여 넣어요.' }
  if ($Code -cnotmatch '^[a-z2-7]{16}$') { Fail E5 "설치 줄이 잘렸어요. $again" }
  Write-Host '학습 도우미를 설치해요.'

  # 1. Git for Windows
  $bash = Find-GitBash
  if (-not $bash) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { Fail E4 $noGit }
    Write-Host '  Git for Windows 를 깔아요. 관리자 확인 창이 뜨면 「예」를 눌러요. 몇 분 걸릴 수 있어요.'
    & winget.exe install --id Git.Git --exact --source winget --silent --accept-package-agreements --accept-source-agreements | Out-Null
    $bash = Find-GitBash
    if (-not $bash) { Fail E4 $noGit }
    Write-Host '  Git for Windows 를 깔았어요.'
  }

  # 2. 설정. 읽지 못하면 고치지 않는다
  $settings = Join-Path $config 'settings.json'
  if (-not (Merge-Settings $settings $bash)) { Fail E3 'Claude 설정 파일(~\.claude\settings.json)을 읽지 못해서 고치지 않았어요.' }
  Write-Host '  Claude 설정에 도우미를 더했어요.'

  # 3. 앱의 Claude Code 로 바로 깐다. 마켓플레이스가 이미 있으면 add 가 실패해서 update 로 새로 받는다.
  #    이미 「설치됨」 기록만 있고 캐시가 빈 컴퓨터는 plugin list 가 캐시를 채운다
  $claude = Find-Claude
  if ($claude) {
    if (-not (Invoke-Claude $claude @('plugin', 'marketplace', 'add', 'nangmanpogu/clcoach-workbook-tutor'))) {
      Invoke-Claude $claude @('plugin', 'marketplace', 'update', 'nangmanpogu') | Out-Null
    }
    Invoke-Claude $claude @('plugin', 'install', 'workbook-tutor@nangmanpogu', '--scope', 'user') | Out-Null
    Invoke-Claude $claude @('plugin', 'list') | Out-Null
    # marketplace add 가 설정의 마켓플레이스 항목을 autoUpdate 없이 다시 쓴다(2.1.309 실측). 다시 합쳐 되살린다
    Merge-Settings $settings $bash | Out-Null
    $cache = Join-Path $config 'plugins\cache\nangmanpogu\workbook-tutor'
    if (Get-ChildItem -LiteralPath $cache -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1) {
      Write-Host '  Claude 앱에 도우미를 깔았어요.'
    }
  }

  # 4. 설치 코드를 연결 토큰으로 바꾼다. 코드는 한 번만 쓰이고 30분 산다. 토큰은 이 컴퓨터에만 둔다.
  #    이 컴퓨터에 옛 토큰이 있으면 같이 내서 서버가 옛 연결을 끊게 한다
  $body = '{"code":"' + $Code + '"}'
  $tokenFile = Join-Path $state 'token'
  if (Test-Path -LiteralPath $tokenFile) {
    $old = ([IO.File]::ReadAllText($tokenFile)).Trim()
    if ($old -cmatch '^[A-Za-z0-9_-]{43}$') { $body = '{"code":"' + $Code + '","replaces":"' + $old + '"}' }
  }
  $status = 0
  $reply = ''
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 -Method Post -ContentType 'application/json' `
      -Body $body -Uri "$site/api/clco/tutor/claim"
    $status = [int]$r.StatusCode
    $reply = [string]$r.Content
  } catch {
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
  }
  $token = [regex]::Match($reply, '"token":"([A-Za-z0-9_-]{43})"')
  if ($status -eq 404) { Fail E5 "이 설치 줄은 이미 썼거나 30분이 지났어요. $again" }
  if ($status -ne 201) { Fail E2 '인터넷 연결을 확인하고 같은 줄을 다시 붙여 넣어요.' }
  if (-not $token.Success) { Fail E2 "학습지 서버의 답을 읽지 못했어요. $again" }
  $saved = $false
  try {
    New-Item -ItemType Directory -Force -Path $state | Out-Null
    Write-Utf8 (Join-Path $state 'token') $token.Groups[1].Value
    $saved = $true
  } catch {}
  if (-not $saved) { Fail E2 "연결 정보를 저장하지 못했어요. $again" }
  Remove-Item -LiteralPath (Join-Path $state 'token.hello') -Force -ErrorAction SilentlyContinue

  # 5. 1부 연습 폴더의 목록. 학습지 서버가 연결 토큰을 보고 내준다. 못 받아도 세션을 열 때 다시 받는다
  $basics = Join-Path $state 'basics'
  New-Item -ItemType Directory -Force -Path $basics | Out-Null
  $log = Join-Path $basics 'log'
  if (-not (Test-Path -LiteralPath $log)) { [IO.File]::WriteAllText($log, '', $utf8) }
  $auth = @{ Authorization = 'Bearer ' + $token.Groups[1].Value }
  foreach ($f in 'steps.tsv', 'prompts.tsv', 'checks.tsv') {
    $dest = Join-Path $basics $f
    try {
      Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 -Headers $auth -Uri "$site/tutor/basics/$f" -OutFile "$dest.part"
      Move-Item -LiteralPath "$dest.part" -Destination $dest -Force
    } catch {
      Remove-Item -LiteralPath "$dest.part" -Force -ErrorAction SilentlyContinue
    }
  }

  Write-Host ''
  Write-Host '설치했어요. 학습지로 돌아가 「설치 확인」을 눌러요.'
} catch {
  if ("$_" -ne $stop) {
    Write-Host ''
    Write-Host "설치하지 못했어요(E2). $_"
    Write-Host '학습지의 「막혔어요」를 누르면 E2 를 푸는 법이 있어요.'
  }
}
