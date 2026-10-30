// 영화·미드 자막 MCP 서버. 단어장 프로젝트 폴더의 .workbook-tutor/subtitles.mjs 로 들어가고, 학습자가 .mcp.json 에 적어 쓴다(원고 2-19 3절).
// 외부 패키지 없이 stdio 로 JSON-RPC 를 주고받는다. 학습자 폴더에서 npm install 을 하지 않게 하려는 것이다.
// 작품은 Cinemeta, 자막은 Stremio 의 OpenSubtitles 애드온에서 받는다. 둘 다 키가 없다. 받는 곳이 바뀌면 이 파일만 고치면
// 세션을 열 때 도우미가 학습자 폴더의 사본을 바꿔 넣는다.

import { createInterface } from "node:readline";

const META = process.env.SUBTITLES_META_URL || "https://v3-cinemeta.strem.io";
const SUBS =
  process.env.SUBTITLES_SUBS_URL || "https://opensubtitles-v3.strem.io";
const TIMEOUT_MS = 10000;

// 학습자가 줄 법한 두 글자 코드를 애드온의 세 글자 코드로
const LANGS = {
  en: "eng",
  ko: "kor",
  ja: "jpn",
  zh: "zho",
  es: "spa",
  fr: "fre",
  de: "ger",
  it: "ita",
  pt: "por",
  ru: "rus",
  vi: "vie",
  th: "tha",
  id: "ind",
  tr: "tur",
};

const TOOLS = [
  {
    name: "search_titles",
    description:
      "Find a movie or TV series and its IMDb id. Use the original English title for best results. Call this before get_subtitles.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Title to search, ideally the original English title",
        },
        type: {
          type: "string",
          enum: ["movie", "series"],
          description: "Leave empty to search both",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "get_subtitles",
    description:
      "Download subtitles for a movie or one episode of a series, as lines with their start time. Series need season and episode.",
    inputSchema: {
      type: "object",
      properties: {
        imdb_id: {
          type: "string",
          description: "IMDb id from search_titles, like tt0108778",
        },
        season: { type: "integer", description: "Season number (series only)" },
        episode: {
          type: "integer",
          description: "Episode number (series only)",
        },
        lang: { type: "string", description: "Language code, default en" },
        limit: {
          type: "integer",
          description: "Return only the first N lines. Empty returns all",
        },
      },
      required: ["imdb_id"],
    },
  },
];

class ToolError extends Error {}

async function getJson(url) {
  let res;
  try {
    res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch (e) {
    throw new ToolError(
      `Subtitle source unreachable (${e.name}). Do not invent lines; tell the learner to try again later.`,
    );
  }
  if (!res.ok)
    throw new ToolError(
      `Subtitle source unreachable (${res.status}). Do not invent lines; tell the learner to try again later.`,
    );
  return res.json();
}

async function getText(url) {
  let res;
  try {
    res = await fetch(url, { signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch (e) {
    throw new ToolError(
      `Subtitle source unreachable (${e.name}). Do not invent lines; tell the learner to try again later.`,
    );
  }
  if (!res.ok)
    throw new ToolError(
      `Subtitle source unreachable (${res.status}). Do not invent lines; tell the learner to try again later.`,
    );
  return res.text();
}

async function searchTitles({ query, type }) {
  if (!query || typeof query !== "string")
    throw new ToolError("Pass query, the title to search.");
  const types =
    type === "movie" || type === "series" ? [type] : ["series", "movie"];
  const found = [];
  for (const t of types) {
    const data = await getJson(
      `${META}/catalog/${t}/top/search=${encodeURIComponent(query)}.json`,
    );
    for (const m of (data.metas || []).slice(0, 5)) {
      found.push(
        `${m.imdb_id || m.id} · ${m.name}${m.releaseInfo ? ` (${m.releaseInfo})` : ""} · ${t}`,
      );
    }
  }
  if (!found.length)
    throw new ToolError(
      `No title matched "${query}". Retry with the original English title.`,
    );
  return found.slice(0, 5).join("\n");
}

// 극장에서 찍은 판과 CD 로 나눈 판은 대사가 빠지거나 반만 있어서 뒤로 미룬다
function pick(subs) {
  const bad = (s) =>
    /\b(cam|ts|telesync|hdcam)\b|cd\d/i.test(s.subtitleFileName || "") ||
    /cam|telesync/i.test(s.releaseFormat || "");
  return subs.find((s) => !bad(s)) || subs[0];
}

// 자막을 만든 사람·사이트를 알리는 줄. 대사가 아니다
const CREDIT = /opensubtitles|ripped by|subtitles? by|synced|sync by|www\.|https?:/i;

const stamp = (h, m, s) => `${h.padStart(2, "0")}:${m}:${s}`;

// SRT 를 [시각] 대사 줄로. 태그와 소리 설명([laughs], (sighs))은 떼고, 두 줄로 나뉜 대사는 한 줄로 잇는다
function parseSrt(text) {
  const out = [];
  for (const block of text
    .replace(/^\uFEFF/, "")
    .replace(/\r/g, "")
    .split(/\n\s*\n/)) {
    const lines = block.split("\n");
    const i = lines.findIndex((l) => l.includes("-->"));
    if (i < 0) continue;
    const t = lines[i].match(/(\d+):(\d{2}):(\d{2})/);
    if (!t) continue;
    const said = lines
      .slice(i + 1)
      .join(" ")
      .replace(/<[^>]+>|\{[^}]*\}/g, "")
      .replace(/\[[^\]]*\]|\([^)]*\)/g, "")
      .replace(/\s+/g, " ")
      .replace(/-\s*(?=-|$)/g, "")
      .trim();
    if (said && /\p{L}/u.test(said) && !CREDIT.test(said))
      out.push(`[${stamp(t[1], t[2], t[3])}] ${said}`);
  }
  return out;
}

async function getSubtitles({ imdb_id, season, episode, lang, limit }) {
  if (!/^tt\d+$/.test(imdb_id || ""))
    throw new ToolError("Pass imdb_id from search_titles, like tt0108778.");
  const series = season != null || episode != null;
  if (!series) {
    // 영화 목록은 미드 id 로 불러도 무언가를 돌려주므로, 미드인지 먼저 본다
    const meta = await getJson(`${META}/meta/series/${imdb_id}.json`);
    if (meta.meta) throw new ToolError("This is a series. Pass season and episode.");
  }
  if (series && (!Number.isInteger(season) || !Number.isInteger(episode))) {
    throw new ToolError("This is a series. Pass both season and episode.");
  }
  const code = String(lang || "en").toLowerCase();
  const want = LANGS[code] || code;
  const path = series
    ? `series/${imdb_id}:${season}:${episode}`
    : `movie/${imdb_id}`;
  const data = await getJson(`${SUBS}/subtitles/${path}.json`);
  const all = data.subtitles || [];
  const subs = all.filter((s) => s.lang === want);
  const where = series
    ? `${imdb_id} S${String(season).padStart(2, "0")}E${String(episode).padStart(2, "0")}`
    : imdb_id;
  if (!subs.length) {
    const have = [...new Set(all.map((s) => s.lang))].sort().join(", ");
    throw new ToolError(
      `No ${code} subtitles for ${where}.${have ? ` Available: ${have}` : " No subtitles at all; check the season and episode."}`,
    );
  }
  const sub = pick(subs);
  const lines = parseSrt(await getText(sub.url));
  if (!lines.length)
    throw new ToolError(
      `The subtitle file for ${where} was empty. Do not invent lines; tell the learner to try another title.`,
    );
  const shown =
    Number.isInteger(limit) && limit > 0 ? lines.slice(0, limit) : lines;
  return [
    `${where} · ${code} · ${lines.length} lines`,
    `source: ${sub.url}`,
    ...shown,
  ].join("\n");
}

const HANDLERS = { search_titles: searchTitles, get_subtitles: getSubtitles };

async function handle(msg) {
  switch (msg.method) {
    case "initialize":
      return {
        protocolVersion: msg.params?.protocolVersion || "2025-06-18",
        capabilities: { tools: {} },
        serverInfo: { name: "subtitles", version: "1.0.0" },
      };
    case "ping":
      return {};
    case "tools/list":
      return { tools: TOOLS };
    case "tools/call": {
      const fn = HANDLERS[msg.params?.name];
      if (!fn)
        return {
          content: [{ type: "text", text: `Unknown tool ${msg.params?.name}` }],
          isError: true,
        };
      try {
        return {
          content: [
            { type: "text", text: await fn(msg.params.arguments || {}) },
          ],
        };
      } catch (e) {
        if (!(e instanceof ToolError)) throw e;
        return { content: [{ type: "text", text: e.message }], isError: true };
      }
    }
    default:
      return undefined;
  }
}

function send(obj) {
  process.stdout.write(`${JSON.stringify(obj)}\n`);
}

createInterface({ input: process.stdin }).on("line", async (line) => {
  if (!line.trim()) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    send({
      jsonrpc: "2.0",
      id: null,
      error: { code: -32700, message: "Parse error" },
    });
    return;
  }
  if (msg.id === undefined) return; // 알림(notifications/*)에는 답하지 않는다
  try {
    const result = await handle(msg);
    if (result === undefined)
      send({
        jsonrpc: "2.0",
        id: msg.id,
        error: { code: -32601, message: `Method not found: ${msg.method}` },
      });
    else send({ jsonrpc: "2.0", id: msg.id, result });
  } catch (e) {
    send({
      jsonrpc: "2.0",
      id: msg.id,
      error: { code: -32603, message: String(e?.message || e) },
    });
  }
});
