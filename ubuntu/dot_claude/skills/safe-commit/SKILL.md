---
name: safe-commit
description: Check git diff for secrets/personal info leaks, then stage, commit with a proper message, and push. Use when the user wants to commit and push safely.
argument-hint: [branch-name (optional)]
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
---

# Safe Commit & Push

git diff の内容を精査し、機密情報・個人情報の混入がないことを確認した上で、add / commit / push を行う。

---

## Step 1: Unstaged diff の取得

```
git diff
git diff --cached
git status
```

差分が空なら「コミットする変更がありません」と伝えて終了。

---

## Step 2: 機密情報・個人情報スキャン

diff の **追加行 (`+` で始まる行)** を対象に、以下のカテゴリを **すべて** チェックする。
検出した場合は **該当ファイル名・行番号・マッチ内容・カテゴリ** を一覧表示し、ユーザーに確認を求める。

### 2-1. クレデンシャル・シークレット

| パターン | 説明 |
|---------|------|
| `AKIA[0-9A-Z]{16}` | AWS Access Key ID |
| `(?i)(aws_secret_access_key\|aws_secret)\s*[=:]\s*\S+` | AWS Secret Key |
| `(?i)(api[_-]?key\|apikey\|api[_-]?token)\s*[=:]\s*["']?\S{8,}` | 汎用 API Key |
| `(?i)(secret[_-]?key\|secret[_-]?token\|client[_-]?secret)\s*[=:]\s*["']?\S{8,}` | Secret Key / Token |
| `(?i)(access[_-]?token\|auth[_-]?token\|bearer)\s*[=:]\s*["']?\S{8,}` | Access / Auth Token |
| `(?i)password\s*[=:]\s*["']?\S+` | パスワード (ハードコード) |
| `ghp_[0-9a-zA-Z]{36}` | GitHub Personal Access Token |
| `gho_[0-9a-zA-Z]{36}` | GitHub OAuth Token |
| `github_pat_[0-9a-zA-Z_]{22,}` | GitHub Fine-grained PAT |
| `glpat-[0-9a-zA-Z_-]{20,}` | GitLab Personal Access Token |
| `sk-[0-9a-zA-Z]{32,}` | OpenAI / Stripe Secret Key |
| `sk-ant-[0-9a-zA-Z-]{80,}` | Anthropic API Key |
| `xox[bpras]-[0-9a-zA-Z-]+` | Slack Token |
| `(?i)(heroku.*[=:]\s*)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}` | Heroku API Key |
| `SG\.[0-9a-zA-Z_-]{22}\.[0-9a-zA-Z_-]{43}` | SendGrid API Key |
| `(?i)twilio.*[=:]\s*SK[0-9a-f]{32}` | Twilio API Key |

### 2-2. 秘密鍵・証明書

| パターン | 説明 |
|---------|------|
| `-----BEGIN (RSA\|DSA\|EC\|OPENSSH\|PGP) PRIVATE KEY-----` | 秘密鍵ヘッダ |
| `-----BEGIN CERTIFICATE-----` | 証明書 (用途次第で問題) |

### 2-3. 個人情報 (PII)

| パターン | 説明 |
|---------|------|
| `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}` | メールアドレス (**ただし** `noreply@`, `example.com`, `test.com`, `localhost` は除外) |
| `\b0[789]0-?\d{4}-?\d{4}\b` | 日本の携帯電話番号 |
| `\b0\d{1,4}-?\d{1,4}-?\d{4}\b` | 日本の固定電話番号 |
| `\b\d{3}[-.]?\d{4}[-.]?\d{4}\b` | 一般的な電話番号パターン |
| `\b\d{3}-\d{2}-\d{4}\b` | 米国 SSN |
| `\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b` | クレジットカード番号候補 |
| `\b[12]\d{3}[01]\d[0-3]\d{7}\b` | マイナンバー (12桁数字) |

### 2-4. ネットワーク・インフラ情報

| パターン | 説明 |
|---------|------|
| `\b(?:10\.\|172\.(?:1[6-9]\|2\d\|3[01])\.\|192\.168\.)\d{1,3}\.\d{1,3}\b` | プライベート IP アドレス |
| `(?i)(jdbc\|mysql\|postgresql\|mongodb\|redis\|amqp):\/\/[^\s"']+` | DB 接続文字列 (ユーザー名・パスワード含む可能性) |
| `(?i)(https?:\/\/)(([^:@\s"']+):([^@\s"']+)@)` | URL 内の認証情報 (user:pass@host) |

### 2-5. ローカル環境固有値

| パターン | 説明 |
|---------|------|
| `/home/[a-zA-Z0-9_-]+/` | Linux ホームディレクトリパス |
| `/Users/[a-zA-Z0-9_-]+/` | macOS ホームディレクトリパス |
| `C:\\Users\\[a-zA-Z0-9_-]+\\` | Windows ホームディレクトリパス |
| `(?i)(localhost\|127\.0\.0\.1):\d{4,5}` | ローカルホストのポート指定 (**ただし** テストコード・設定テンプレート内は除外) |

### 2-6. 環境変数ファイル

以下のファイルが diff に含まれていたら **即座に警告**:

- `.env`, `.env.local`, `.env.production`, `.env.staging`
- `credentials.json`, `service-account*.json`
- `*.pem`, `*.key`, `*.p12`, `*.pfx`
- `*_rsa`, `*_ecdsa`, `*_ed25519`
- `.netrc`, `.npmrc` (authToken 含む場合), `.pypirc`

### スキャン時の注意事項

- **コメント内・テストデータ・ドキュメント例示** であっても検出対象とする。
  意図的なものであればユーザーが承認すればよい。
- **`Co-Authored-By` 行のメールアドレス** (`noreply@anthropic.com` 等) は除外する。
- **`.env.example`** 内のプレースホルダー値 (`your_password_here`, `changeme`, `xxx` 等) は除外する。
- 除外判定に迷う場合は **検出として報告** し、ユーザーに判断を委ねる。

---

## Step 3: スキャン結果の報告

### 検出なしの場合

「機密情報・個人情報は検出されませんでした。」と報告し、Step 4 へ進む。

### 検出ありの場合

以下のフォーマットで報告:

```
## 検出された項目

| # | ファイル | 行 | カテゴリ | 内容 (マスク済) |
|---|---------|-----|---------|----------------|
| 1 | src/config.rs | 42 | API Key | sk-****abcd |
| 2 | .env | 3 | パスワード | password=**** |

上記の変更を含めてコミットしますか？
- [y] 全て承認してコミット
- [n] コミットを中止
- [番号] 特定の項目について詳細確認
```

ユーザーが承認しない限り、**絶対に add / commit / push を実行しない**。

---

## Step 4: ステージング (git add)

- `git status` で untracked / modified ファイルを確認
- **ステージ対象のファイルをユーザーに提示** し、確認を得てから `git add <files>`
- `.env`, 秘密鍵ファイル等は `.gitignore` に含まれていても **明示的に除外確認** する
- `git add .` や `git add -A` は使わず、ファイル名を明示して add する

---

## Step 5: Staged diff の最終確認

```
git diff --cached --stat
git diff --cached
```

- Step 2 と同じスキャンを **staged diff に対して再実行** する
- 意図しないファイルが含まれていないか確認
- 問題があれば `git reset HEAD <file>` で unstage し、ユーザーに報告

---

## Step 6: コミットメッセージ作成 & コミット

- `git log --oneline -10` でリポジトリのコミットメッセージスタイルを確認
- 差分内容から **日本語または英語** (リポジトリの慣習に合わせる) でメッセージを作成
- 形式:
  ```
  <type>: <簡潔な要約> (50文字以内)

  <変更の詳細・理由> (必要な場合のみ)

  Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
  ```
- type: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `perf`, `style` 等
- メッセージ案をユーザーに提示し、承認を得てからコミット
- HEREDOC 形式でメッセージを渡す:
  ```bash
  git commit -m "$(cat <<'EOF'
  メッセージ

  Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Step 7: プッシュ

- `git branch -vv` で現在のブランチとリモート追跡状態を確認
- 追跡ブランチがなければ `git push -u origin <branch>` を提案
- 追跡ブランチがあれば `git push` を実行
- **force push は絶対にしない** (ユーザーが明示的に要求した場合のみ例外)
- push 失敗時はエラー内容を報告し、対処法を提案する

---

## 中止条件

以下のいずれかに該当する場合、**即座に中止** してユーザーに報告:

1. Step 2/5 で機密情報を検出し、ユーザーが承認しなかった
2. `git status` でコンフリクトが存在する
3. detached HEAD 状態である
4. リモートに push 済みのコミットを改変しようとしている
