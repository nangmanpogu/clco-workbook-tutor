---
name: 시작
description: 클코 학습지 2부의 프로젝트를 이 폴더에서 시작한다. 프로그램을 깔고 연습 재료를 samples 폴더에 넣는다. 학습자가 /시작 블로그 처럼 직접 부른다.
argument-hint: 블로그 | 투자 | 운동 | 단어장
disable-model-invocation: true
allowed-tools: Bash(workbook-tutor:*)
---

학습 도우미의 /시작 이다. 학습자가 보낸 이름은 `$ARGUMENTS` 다.

## 순서

1. Bash 로 `workbook-tutor start $ARGUMENTS` 를 부른다. 학습자의 지금 폴더에서 그대로 부른다. `cd` 를 앞에 붙이지 않는다. Node.js 를 내려받을 수 있어서 timeout 은 600000 으로 준다.
2. 출력의 첫 줄로 다음을 정한다.

   | 첫 줄                            | 할 일                                                                                                                                                                                                                                         |
   | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | `REFUSED`                        | 다음 줄의 문장을 그대로 학습자에게 전하고 끝낸다. 다른 일은 하지 않는다                                                                                                                                                                       |
   | `ASK_PROJECT`, `UNKNOWN_PROJECT` | `PROJECT` 줄(이름, 프로젝트, 폴더)로 AskUserQuestion 을 띄운다. 질문은 「어느 프로젝트를 시작할까요?」, 머리는 「프로젝트」, 선택지 이름은 `PROJECT` 줄의 이름, 설명은 「<프로젝트> · <폴더> 폴더에서 해요」다. 고른 이름으로 1부터 다시 한다 |
   | `STARTED`                        | 3으로 간다                                                                                                                                                                                                                                    |

3. `NODE_` 로 시작하는 줄을 본다.
   - `NODE_OK`, `NODE_INSTALLED`, `NODE_SKIPPED`: 할 일이 없다.
   - `NODE_MISSING`, `NODE_DOWNLOAD_FAILED`, `NODE_CHECKSUM_FAILED`: Node.js 24 LTS 를 깐다(22.23.4 이상이어야 2부의 Astro 가 돈다). Windows 면 `winget install OpenJS.NodeJS.LTS` 를 먼저 해 본다. 무엇을 하는지 한 줄로 알리고 한다.
4. 학습자에게 끝났다고 짧게 알린다. 해요체로, 세 줄 안에.
   - 프로그램: 3의 `NODE_` 줄로 정한다. `NODE_INSTALLED` 이거나 3에서 직접 깔았으면 「Node.js 를 설치했어요」. `NODE_OK`·`NODE_SKIPPED` 면 깐 것이 없으니 「필요한 프로그램은 이미 있었어요」. `NODE_OK` 뒤의 버전과 경로는 이미 있던 Node.js 의 것이다.
   - 재료: 「연습 재료를 samples 폴더에 넣었어요」.
   - 다음: 「학습지로 돌아가 다음 단계를 이어서 해요.」

## 하지 않는 것

- 출력에 없는 파일을 만들거나 고치지 않는다. CLAUDE.md, index.html, references, drafts, plans, .claude 폴더 같은 것은 학습자가 학습지를 따라 직접 만든다.
- `.workbook-tutor` 폴더를 열어 보거나 설명하지 않는다.
- 학습지의 뒤 내용을 미리 알려 주지 않는다.
