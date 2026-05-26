# 指示書

## 目的

ホテルの予約に空きがあれば Discord に通知する事

## 方法

対象URLを１つづつ確認し、「空室」判定の条件を満たした場合、Discord に通知する

### 対象URL

- xxxxxxxxx

### 「空室」判定の条件

人数を確定後、「ツアーを予約する」ボタンを押下すると、満室の場合は「プランに空きがございません。」というポップアップ（アラート）が表示される。それ以外の文言や動作が行われた場合、「空室」判定とする

### 具体的な操作

対象URL１つに対して以下の操作を、**全ての対象URLに対して実施する**

1. browser-use を使ってURLを開く
2. 参加人数を「大人２人」に設定する. **"出発日"や"宿泊日数"は初期表示のままとする**
3. 「ツアーを予約する」ボタンを押下する
4. 「空室」判定の条件　の判定を行う

### Discord の通知判定

1つ以上の「空室」判定があれば、対象となるホテルの名前を列挙して Discord に通知する

## 補足事項

### 403回避のための User-Agent 上書き

対象サイトはデフォルトの headless Chromium の User-Agent では HTTP 403（アクセス拒否） を返す。実ブラウザの UAに上書きしないとページが開けないため、URLを開く前に以下を実施する。

```
# 1. ブラウザdaemonを起動（空ページで可）
/opt/browser-use-venv/bin/browser-use open "about:blank"

# 2. CDP経由でUser-Agentを上書き（下記スクリプトをファイル実行）
/opt/browser-use-venv/bin/browser-use python --file /tmp/setup_ua.py
```

/tmp/setup_ua.py

```python
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
sess = browser._session

async def _setup():
    cdp = await sess.get_or_create_cdp_session(target_id=None, focus=True)
    await cdp.cdp_client.send.Network.enable(session_id=cdp.session_id)
    await cdp.cdp_client.send.Network.setUserAgentOverride(
        params={'userAgent': UA}, session_id=cdp.session_id
    )
    return cdp.session_id

print("UA override set on session", browser._run(_setup()))
```

- この上書きは同一ブラウザターゲットで維持されるため、全URL分で1回だけ実施すればよい。
- 確認方法：browser-use get title でタイトルが取得できれば成功（403時は取得できない）。

### 「空室」判定の技術的な実装方法

対象サイトは Angular SPA で、満室時の「プランに空きがございません。」はネイティブのJSアラート（window.alert）で表示される。browser-use はアラートを自動的に閉じてしまい文言を取得できないため、「ツアーを予約する」を押下する前に window.alert / window.confirm を上書きして文言を変数に捕捉する。

ボタン押下の直前に注入.

```
/opt/browser-use-venv/bin/browser-use eval 'window.__alertMsg=null; window.__alertCount=0;
window.alert=function(m){window.__alertMsg=String(m);window.__alertCount++;}; window.confirm=function(m){window.__alertMsg=String(m);window.__alertCount++;return
true;}; window.__startURL=location.href; "ok"'
```

「ツアーを予約する」押下後に結果を取得

```
/opt/browser-use-venv/bin/browser-use eval
'JSON.stringify({alertMsg:window.__alertMsg,alertCount:window.__alertCount,startURL:window.__startURL,nowURL:location.href})'
```

判定ルール:
- alertMsg が "プランに空きがございません。" → 満室
- それ以外（alertMsg が null・別文言、または nowURL が startURL から変化＝予約/ログイン画面へ遷移）→ 空室

### 参加人数「大人2人」の設定手順

要素のindexはページ読み込みごとに変わるため、browser-use state で都度確認する。

1. browser-use state で「参加人数」欄の <a>（初期表示「人数を選択してください。」）のindexを特定 → クリックで人数選択モーダルが開く。
2. 「大人」の入力欄横のプラスボタン（モーダル内の x座標が大きい方 が＋）を2回クリックし、get value で「2人」を確認。
3. モーダル下部の 「決定」ボタン（最低2名に達すると disabled が外れる）をクリック。
4. 閉じると参加人数欄が「大人2人 ,小人0人 ,幼児0人」になり、「ツアーを予約する」ボタンが有効化される。

重要な注意点： このサイトは選択した人数をアプリ状態として保持するため、1件目で大人2人に設定すると、**2件目以降のURLは初期表示で既に「大人2人」**になっている可能性がある。その場合は手順1〜3を省略してよいが、押下前に必ず state で「大人2人」表示を確認すること。

### Discord 通知判定の明確化

- 空室が 0件（全プラン満室）の場合は 通知しない。
- 空室が 1件以上の場合のみ、空室だったホテル名を列挙して通知する：
/usr/local/bin/notify-discord.sh "$DISCORD_MENTION 空室あり: ○○ホテル, △△ホテル"

### 終了処理

全URL確認後はブラウザdaemonを閉じる

```
/opt/browser-use-venv/bin/browser-use close
```