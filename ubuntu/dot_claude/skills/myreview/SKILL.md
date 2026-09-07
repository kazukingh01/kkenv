---
name: myreview
description: /code-review に通し番号管理・前回指摘との重複除去・PR コメント返信を追加したレビュー。引数はそのまま /code-review に引き継ぐ。
argument-hint: [PR番号 | ブランチ | パス] [low|medium|high|max|ultra] [--fix]
allowed-tools: Bash, Read, Grep, Glob, Skill
---

# My Review

`/code-review` を実行し、その結果を **通し番号付き・前回指摘との重複除去済み** で PR にコメント返信するスキル。

引数 `$ARGUMENTS` は解釈せず、**そのまま `/code-review` へ引き渡す** (PR 番号・ブランチ・パス・効果レベル・`--fix` など全て)。
ただし `--comment` は渡さない。PR への投稿は本スキルが Step 4 で 1 本のコメントとして行う。

---

## Step 1: 対象 PR の特定

1. `$ARGUMENTS` に PR 番号があればそれを使う
2. 無ければ現在のブランチから `gh pr view --json number,url` で特定する
3. PR が特定できない場合はレビューのみ行い、Step 2 / Step 4 は「PR が無いため省略」と明示して結果を表示する

---

## Step 2: 前回以前の指摘の読み込み

採番の正本は **PR のコメント本文のみ**。ソースコード中の `レビュー No.xx` コメントは別 PR の系列が混在するため根拠にしない。

```bash
gh api repos/{owner}/{repo}/issues/<PR番号>/comments --paginate > <scratchpad>/pr-<PR番号>-comments.json
gh api repos/{owner}/{repo}/pulls/<PR番号>/comments --paginate > <scratchpad>/pr-<PR番号>-review-comments.json
```

- `head` で切らず **全件・末尾まで** 読む。長い場合はファイルに落として全文確認する
- 収集する事項:
  - **最終番号 N**: 過去コメントに含まれる指摘番号 (`No.N`) の最大値。無ければ 0
  - **既出指摘の一覧**: 番号・タイトル・file:line
  - **「仕様 / 不問 / 指摘が誤り」と確定した項目**: 次回以降も再検出されるため、明示的に除外リストにする

---

## Step 3: レビュー実行

`Skill` ツールで `code-review` を `$ARGUMENTS` 付きで呼び出す (`--comment` は除く)。

得られた指摘に対して以下を行う:

1. **重複除去**: Step 2 の既出指摘・確定済み項目と同じ内容 (同一箇所・同一趣旨) は省く。
   省いた項目は捨てずに「前回 No.N と重複のため省略」として控えておく
2. **採番**: 残った指摘を severity 順 (重大なものから) に並べ、**N+1 から連番** で番号を振る。欠番・重複採番を作らない
3. 各指摘の形式:

   ```
   No.<番号> [<severity>] <タイトル> — <file>:<line>
   <内容 (失敗シナリオ・根拠)>
   ```

---

## Step 4: PR へコメント返信

Step 3 の結果を **1 本のコメント** として PR に投稿する。

```bash
gh pr comment <PR番号> --body-file <scratchpad>/pr-<PR番号>-review.md
```

コメントの構成:

```markdown
## レビュー (第 R ラウンド: No.<N+1>〜No.<M>)

### 指摘
No.<N+1> [severity] タイトル — file:line
...

### 前回指摘との重複のため省略
- No.x と同旨: <短い理由>
- 確定済み仕様 (No.y): <短い理由>

### 対象
- レビュー対象: <PR番号 / ブランチ / コミット範囲>
- 効果レベル: <level>
```

- 新規指摘が 0 件でも投稿する (「新規指摘なし。前回 No.N までの対応を確認」の形で)
- 「省略」節は空でも見出しを残し「なし」と書く。重複除去を実施した事が読み手に分かるようにする

---

## Step 5: 完了報告

以下を報告する:

- 投稿したコメントの URL
- 今回の採番範囲 (No.N+1〜No.M) と件数
- 省いた件数とその根拠 (前回重複 / 確定済み仕様)
- `--fix` を渡した場合は、適用した変更の要約。**コミットはしない** (ユーザーの明示指示か `/safe-commit` のみ)
