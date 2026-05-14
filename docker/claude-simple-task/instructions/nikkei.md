# 指示書

## 目的



# 補足

日経のWEBページ ( `https://www.nikkei.com/` ) を表示し、 ログイン後、以下のコマンドで cookie を dump している

```bash
browser-use cookies export /workspace/nikkei_cookies.json
```

```bash
browser-use open "https://www.nikkei.com/"          # 空のセッションを立ち上げる
browser-use cookies import /workspace/nikkei_cookies.json
browser-use open "https://www.nikkei.com/"          # クッキー反映のためリロード
```
