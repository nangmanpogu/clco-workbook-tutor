#!/bin/sh
# 학습 도우미 설치. 학습지 1-1 3절이 복사해 주는 한 줄이 이 파일을 받아 돌린다. 끝의 16자가 그 학습자의 설치 코드다.
#   curl -fsSL https://raw.githubusercontent.com/nangmanpogu/clcoach-workbook-tutor/main/install.sh | sh -s <설치 코드>
#
# 하는 일
#   1. Claude Code 설정(~/.claude/settings.json)에 마켓플레이스와 도우미를 더한다. 있던 설정은 그대로 둔다.
#      Claude 앱에 딸린 Claude Code 로 도우미를 바로 깐다. 앱은 설정만 보고도 받아 깔지만 1분 반쯤 걸리고, 그 전에 연
#      세션에는 도우미가 실리지 않는다(2026-10-28 실측). 앱의 claude 를 못 찾거나 실패하면 앱에 맡긴다.
#   2. 1부 연습 폴더가 쓸 목록을 학습지에서 받아 둔다.
#   3. 예전 판이 launchd 에 올린 다리가 있으면 내린다.
#   4. 설치 코드를 학습지 서버에 내고 연결 토큰을 받아 둔다. 학습지는 서버에 물어 설치를 확인한다.
#
# 이 파일은 `curl | sh` 로 돌아서 표준 입력이 곧 이 파일이다. 표준 입력을 읽는 명령에는 /dev/null 을 준다.
# 맥용이다. Windows 는 install.ps1 이다.
set -u

SITE=${WORKBOOK_TUTOR_SITE:-https://console.clcoach.nangmanpg.com}
STATE=${WORKBOOK_TUTOR_HOME:-$HOME/.workbook-tutor}
CONFIG=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
AGENTS=${WORKBOOK_TUTOR_AGENTS:-$HOME/Library/LaunchAgents}
LABEL=com.nangmanpogu.workbook-tutor
CODE=${1:-}

fail() {
  printf '\n설치하지 못했어요(%s). %s\n학습지의 「막혔어요」를 누르면 %s 를 푸는 법이 있어요.\n' "$1" "$2" "$1"
  exit 1
}

again='학습지에서 설치 줄을 다시 복사해 붙여 넣어요.'

[ "$(uname -s)" = Darwin ] || fail E1 '이 줄은 Mac 용이에요. Windows 는 학습지가 보여 주는 Windows 줄을 PowerShell 에 붙여 넣어요.'
printf '%s' "$CODE" | grep -Eq '^[a-z2-7]{16}$' ||
  fail E5 "설치 줄이 잘렸어요. $again"
printf '학습 도우미를 설치해요.\n'

# 1. 설정. JSON 은 맥에 기본으로 있는 JavaScript(osascript)로 합친다. 읽지 못하면 고치지 않는다
mkdir -p "$CONFIG"
merge='
function run(argv) {
  const path = argv[0];
  const fm = $.NSFileManager.defaultManager;
  let data = {};
  if (fm.fileExistsAtPath(path)) {
    const text = ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null)) || "";
    if (text.trim()) data = JSON.parse(text);
  }
  if (data === null || typeof data !== "object" || Array.isArray(data)) throw new Error("not an object");
  data.extraKnownMarketplaces = data.extraKnownMarketplaces || {};
  data.extraKnownMarketplaces.nangmanpogu = {
    source: { source: "github", repo: "nangmanpogu/clcoach-workbook-tutor" },
    autoUpdate: true,
  };
  data.enabledPlugins = data.enabledPlugins || {};
  data.enabledPlugins["workbook-tutor@nangmanpogu"] = true;
  const out = $.NSString.alloc.initWithUTF8String(JSON.stringify(data, null, 2) + "\n");
  if (!out.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)) throw new Error("write failed");
  return "ok";
}'
osascript -l JavaScript -e "$merge" "$CONFIG/settings.json" </dev/null >/dev/null 2>&1 ||
  fail E3 'Claude 설정 파일(~/.claude/settings.json)을 읽지 못해서 고치지 않았어요.'
printf '  Claude 설정에 도우미를 더했어요.\n'

# 앱에 딸린 Claude Code. 앱이 판마다 폴더를 따로 두므로 가장 최근 것을 고른다. 1분이 넘으면 멈춘다. 출력은 버린다
APP_DATA=${WORKBOOK_TUTOR_CLAUDE_APP:-$HOME/Library/Application Support/Claude}
claude_cli=$(ls -dt "$APP_DATA"/claude-code/*/*/claude.app/Contents/MacOS/claude "$APP_DATA"/claude-code/*/claude 2>/dev/null | head -n 1)
run_claude() {
  "$claude_cli" "$@" </dev/null >/dev/null 2>&1 &
  pid=$!
  waited=0
  while kill -0 "$pid" 2>/dev/null; do
    waited=$((waited + 1))
    [ $waited -gt 60 ] && kill "$pid" 2>/dev/null && return 1
    sleep 1
  done
  wait "$pid"
}
# 마켓플레이스가 이미 있으면 add 가 실패해서 update 로 새로 받는다. 「설치됨」 기록만 있고 캐시가 빈 맥은 plugin list 가 채운다
if [ -x "$claude_cli" ]; then
  run_claude plugin marketplace add nangmanpogu/clcoach-workbook-tutor ||
    run_claude plugin marketplace update nangmanpogu
  run_claude plugin install workbook-tutor@nangmanpogu --scope user
  run_claude plugin list
  # marketplace add 가 설정의 마켓플레이스 항목을 autoUpdate 없이 다시 쓴다(2.1.309 실측). 다시 합쳐 되살린다
  osascript -l JavaScript -e "$merge" "$CONFIG/settings.json" </dev/null >/dev/null 2>&1
  [ -n "$(find "$CONFIG/plugins/cache/nangmanpogu/workbook-tutor" -type f 2>/dev/null | head -n 1)" ] &&
    printf '  Claude 앱에 도우미를 깔았어요.\n'
fi

# 2. 예전 판의 다리. launchd 가 127.0.0.1 의 포트를 쥐고 있었다. 이제 학습지는 서버에 묻는다
if [ -f "$AGENTS/$LABEL.plist" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" </dev/null >/dev/null 2>&1
  rm -f "$AGENTS/$LABEL.plist"
fi
rm -rf "$STATE/bin"

# 3. 설치 코드를 연결 토큰으로 바꾼다. 코드는 한 번만 쓰이고 30분 산다. 토큰은 이 맥에만 둔다.
#    이 맥에 옛 토큰이 있으면 같이 내서 서버가 옛 연결을 끊게 한다
old=$(cat "$STATE/token" 2>/dev/null)
printf '%s' "$old" | grep -Eq '^[A-Za-z0-9_-]{43}$' || old=''
body="{\"code\":\"$CODE\"${old:+,\"replaces\":\"$old\"}}"
reply=$(mktemp)
status=$(curl -sS --max-time 15 -o "$reply" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' --data "$body" \
  "$SITE/api/clco/tutor/claim" </dev/null 2>/dev/null) || status=000
token=$(sed -n 's/.*"token":"\([A-Za-z0-9_-]\{43\}\)".*/\1/p' "$reply")
rm -f "$reply"
case $status in
  201) [ -n "$token" ] || fail E2 "학습지 서버의 답을 읽지 못했어요. $again" ;;
  404) fail E5 "이 설치 줄은 이미 썼거나 30분이 지났어요. $again" ;;
  *) fail E2 '인터넷 연결을 확인하고 같은 줄을 다시 붙여 넣어요.' ;;
esac
mkdir -p "$STATE"
(umask 077 && printf '%s' "$token" > "$STATE/token.part") && mv "$STATE/token.part" "$STATE/token" ||
  fail E2 "연결 정보를 저장하지 못했어요. $again"
rm -f "$STATE/token.hello"

# 4. 1부 연습 폴더의 목록. 학습지 서버가 연결 토큰을 보고 내준다. 토큰은 명령줄에 드러나지 않게 머리글 파일로
#    넘긴다. 못 받아도 세션을 열 때 다시 받는다
mkdir -p "$STATE/basics"
command -v chflags >/dev/null 2>&1 && chflags -R nouchg "$STATE/basics" 2>/dev/null
[ -f "$STATE/basics/log" ] || : > "$STATE/basics/log"
hdr=$(mktemp)
printf 'Authorization: Bearer %s\n' "$token" > "$hdr"
for f in steps.tsv prompts.tsv checks.tsv; do
  curl -fsS --max-time 15 -H "@$hdr" "$SITE/tutor/basics/$f" -o "$STATE/basics/$f.part" </dev/null 2>/dev/null &&
    mv "$STATE/basics/$f.part" "$STATE/basics/$f"
  rm -f "$STATE/basics/$f.part"
done
rm -f "$hdr"
command -v chflags >/dev/null 2>&1 && chflags -R uchg "$STATE/basics" 2>/dev/null

printf '\n설치했어요. 학습지로 돌아가 「설치 확인」을 눌러요.\n'
