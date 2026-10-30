// 학습 도우미의 미리보기 서버. Claude 앱의 내장 브라우저가 작업 폴더의 .claude/launch.json 으로 띄운다.
// 내장 브라우저는 HTML 을 파일로 열면 그 파일 하나만 사본으로 띄워 같은 폴더의 사진·css 를 읽지 못한다. 그래서 작업
// 폴더를 이 서버로 내준다. 이 컴퓨터(127.0.0.1)에서만 열리고, 작업 폴더 밖의 파일은 내주지 않는다.
// 포트는 앱이 넘기는 PORT 다. 2부는 /시작 이 Node.js 를 깔아 두어 맥과 Windows 가 같은 서버를 쓴다.
import { createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, resolve, sep } from "node:path";

const root = resolve(process.cwd());
const port = Number(process.env.PORT) || 4311;

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".htm": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".md": "text/plain; charset=utf-8",
  ".csv": "text/csv; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".avif": "image/avif",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
  ".mp4": "video/mp4",
  ".webm": "video/webm",
  ".mp3": "audio/mpeg",
};

// 주소의 경로를 작업 폴더 안의 파일로 바꾼다. 폴더면 그 안의 index.html 이다. 밖으로 나가거나 없으면 null
function fileOf(url) {
  let path;
  try {
    path = decodeURIComponent(new URL(url, "http://localhost").pathname);
  } catch {
    return null;
  }
  let file = resolve(join(root, path));
  if (file !== root && !file.startsWith(root + sep)) return null;
  try {
    if (statSync(file).isDirectory()) file = join(file, "index.html");
    return statSync(file).isFile() ? file : null;
  } catch {
    return null;
  }
}

createServer((req, res) => {
  const file = fileOf(req.url ?? "/");
  if (!file) {
    res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    res.end("없는 파일이에요");
    return;
  }
  res.writeHead(200, {
    "content-type":
      TYPES[extname(file).toLowerCase()] ?? "application/octet-stream",
    // 클코가 고친 화면을 새로 고치면 바로 보이게 한다
    "cache-control": "no-store",
  });
  createReadStream(file).pipe(res);
}).listen(port, "127.0.0.1");
