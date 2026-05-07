---
name: new-branch
description: Switch to main, pull, delete merged local branches, then create and switch to a new claude/YYYYMMDD branch.
allowed-tools: Bash
---

# New Branch

main に切り替え、pull し、マージ済みローカルブランチを削除してから、新しい作業ブランチを作成する。

---

## Step 1: main に切り替え & pull

```bash
git switch main
git pull
```

pull が失敗した場合はエラーを報告して終了。

---

## Step 2: マージ済みローカルブランチの削除

pull によって main にマージされたブランチを特定し、削除する。

```bash
git branch --merged main
```

- `main` 自身と `*` 付き（現在のブランチ）は除外
- 対象ブランチ一覧をユーザーに表示し、確認を得てから削除

```bash
git branch -d <branch-name>
```

- `-d`（安全な削除）を使用する。**`-D` は使わない**
- 削除対象がなければ「削除対象のブランチはありません」と報告してスキップ

---

## Step 3: 新しいブランチを作成して切り替え

ブランチ名の形式: `claude/YYYYMMDD`

1. 今日の日付から `claude/YYYYMMDD` を生成（例: `claude/20260330`）
2. 同名ブランチが既に存在するか確認（ローカル + リモート両方）:

```bash
git branch --list 'claude/YYYYMMDD*'
git branch -r --list 'origin/claude/YYYYMMDD*'
```

3. 命名ルール（ローカル・リモートいずれかに存在すれば「存在する」と判定）:
   - `claude/YYYYMMDD` が存在しない → `claude/YYYYMMDD` を使用
   - `claude/YYYYMMDD` が存在する → `claude/YYYYMMDD-2` を使用
   - `claude/YYYYMMDD-2` も存在する → `claude/YYYYMMDD-3` を使用
   - 以降同様にインクリメント

4. ブランチを作成して切り替え:

```bash
git switch -c claude/YYYYMMDD[-X]
```

---

## Step 4: 完了報告

以下を報告する:
- 削除したブランチ名（あれば）
- 作成・切り替えたブランチ名
