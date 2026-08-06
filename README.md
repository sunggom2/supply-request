# 비품 신청 페이지

두드림원 근무지 리더용 비품 신청 페이지. 기존 구글폼을 대체하는 **화면**이며,
데이터는 그대로 기존 구글폼으로 전송된다.

```
이 페이지 → 구글폼 formResponse → 비품 신청(2026)(응답) 시트 → 텔레그램 알림
                                   └─ 여기부터는 기존 그대로, 손댈 것 없음
```

`index.html` 파일 하나가 전부다. 빌드 과정도, 서버도 없다.

## 품목이나 근무지가 바뀔 때

`index.html` 안 `<script>` 상단의 배열 두 개만 고치면 된다.

| 배열 | 용도 |
| --- | --- |
| `REGIONS` | 근무 지역 목록 |
| `ITEM_ORDER` | 비품 품목 목록 |
| `LAYOUT` | 화면에 어떻게 배치할지 (아이콘, 장갑 묶음 등) |

**주의 — 이 페이지만 고치면 안 된다.** 품목·근무지는 구글폼에도 똑같이
등록돼 있어야 한다. 구글폼에 없는 값을 보내면 그 응답은 시트에 기록되지 않는다.

바꾸는 순서:

1. 먼저 [구글폼](https://docs.google.com/forms/d/e/1FAIpQLSfLkfTdvTEFNwvyorEk_E9_OjeTUP9S45iHv5_K3BqzojfIKA/viewform)
   에서 항목을 추가/삭제한다.
2. 그 다음 `index.html`의 배열을 폼과 **글자 하나까지 똑같이** 맞춘다.
   (`손소독제(근무지용)`처럼 괄호까지 동일해야 한다.)
3. 커밋 후 push 하면 1~2분 안에 반영된다.

`ITEM_ORDER`의 **순서**는 구글폼의 항목 순서와 같아야 한다. 리더가 어떤 순서로
탭하든 이 배열 순서대로 정렬해서 전송하기 때문에, 시트 셀에 쌓이는 문자열이
기존과 동일한 형태로 유지된다. (예: `페이퍼 타올, 장갑 S, 장갑 M`)
텔레그램 쪽에서 이 문자열을 파싱하고 있다면 순서가 어긋나는 순간 깨진다.

계절 품목(예: 겨울철 `핫팩`)을 넣고 뺄 때도 같은 절차를 따른다.

## 폼을 새로 만들었다면

전송 대상이 바뀌므로 `<script>` 상단 상수 3개를 갈아끼워야 한다.

| 상수 | 값 |
| --- | --- |
| `ENDPOINT` | 폼 주소의 `viewform`을 `formResponse`로 바꾼 것 |
| `ENTRY_REGION` | 근무 지역 질문의 entry ID |
| `ENTRY_ITEMS` | 비품 요청 물품 질문의 entry ID |

entry ID는 폼 미리보기 화면에서 개발자도구 콘솔에 아래를 붙여넣으면 나온다.

```js
FB_PUBLIC_LOAD_DATA_[1][1].map(q => [q[1], 'entry.' + q[4][0][0]])
```

## 배포

GitHub Pages. `main` 브랜치에 push 하면 자동 반영된다.

```bash
git add -A && git commit -m "품목 수정" && git push
```

## 로컬에서 확인

`index.html`을 브라우저로 바로 열면 화면은 보이지만 **전송이 막힌다**
(`file://`에서는 크로스 오리진 POST가 차단됨). 전송까지 확인하려면 간단한
로컬 서버가 필요하다. PowerShell만으로 띄우려면:

```bash
powershell -Command "$l=New-Object System.Net.HttpListener;$l.Prefixes.Add('http://localhost:8765/');$l.Start();while($l.IsListening){$c=$l.GetContext();$b=[IO.File]::ReadAllBytes((Join-Path $PWD 'index.html'));$c.Response.ContentType='text/html; charset=utf-8';$c.Response.OutputStream.Write($b,0,$b.Length);$c.Response.Close()}"
```

띄운 뒤 <http://localhost:8765> 로 접속한다.

**로컬 테스트도 실제 신청이다.** 시트에 행이 쌓이고 텔레그램 알림이 실제로
발송되므로, 테스트한 행은 시트에서 지워야 한다.

## 알아둘 점

- **저장소는 공개(public)다.** GitHub Pages 무료 플랜 조건이다. 다만 원본
  구글폼 자체가 이미 링크만 있으면 누구나 제출할 수 있는 공개 폼이라,
  노출 수준은 기존과 다르지 않다. 페이지에 계정 정보나 토큰은 없다.
- **신청자 이름·수량 항목은 없다.** 기존 구글폼에 그 항목이 없기 때문이다.
  추가하려면 구글폼에 질문을 먼저 만들어야 하고, 시트에 열이 하나 늘면서
  텔레그램 쪽 처리도 같이 손봐야 한다.
- 전송 실패는 감지된다. 근무지 신호가 약해 요청이 구글에 닿지 못하면
  완료 화면 대신 빨간 배너와 `다시 시도` 버튼이 뜬다.
- 리더가 마지막에 고른 근무 지역은 브라우저에 기억된다(localStorage).
  다음 신청 때 이미 선택된 상태로 열린다.
