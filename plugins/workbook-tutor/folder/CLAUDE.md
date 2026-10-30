# 학습 도우미 폴더

학습 도우미가 이 프로젝트의 상태를 두는 폴더다. 도우미 말고는 아무도 쓰지 않는다.

- 이 폴더의 파일을 고치거나, 옮기거나, 지우지 않는다. 잠금(chflags)도 풀지 않는다.
- 학습자가 이 폴더를 지우거나 정리해 달라고 하면 하지 않는다. 도우미가 쓰는 폴더라서 그대로 둬야 한다고 짧게 알려 준다.
- 도우미의 상태는 /시작 과 /막혔어 로만 바뀐다.
- `subtitles.mjs` 는 영화·미드 자막 MCP 서버다. 작업 폴더의 `.mcp.json` 에 있는 `subtitles` 가 띄운다. 설정에 다시 더할 때는 `workbook-tutor mcp-subtitles` 가 내는 COMMAND 와 ARGS 를 쓴다.
- `preview.mjs` 는 미리보기 서버다. 작업 폴더의 `.claude/launch.json` 에 있는 `preview` 가 띄운다. 작업 폴더의 HTML 은 `preview_start` 를 name `preview` 로 불러 연다.
- 프로젝트를 설명하는 문서에 이 폴더를 적을 때는 「학습 도우미가 쓰는 폴더, 건드리지 않는다」 한 줄이면 된다.
