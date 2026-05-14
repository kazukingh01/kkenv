# 指示書

## 目的

日経記事(`https://www.nikkei.com/`)を要約し、原稿形式に修正し、それを音声ファイルに変換する事である.
保存された音声ファイルは、私がストレッチや散歩中などに再生し、情報収集の効率化を図る.

## 成果物

- 記事単位の本文テキスト ( `XXXXX.org` マークダウン形式 )
- 記事単位の要約 ( `XXXXX.md` マークダウン形式 )
- `XXXXX.md` を原稿形式に変換したテキストファイル ( `XXXXX.txt` ファイル形式 )
- `XXXXX.txt` を変換した音声ファイル ( `XXXXX.wav` ファイル形式 )
※ `XXXXX` は後述の `article_id` である

## 要約記事の管理

過去・未来に対しての要約記事の重複を避けるため sqlite を使って記事の管理を行う. 管理するデータは以下である. テーブル名は `data` とする.

- `datetime`: 記事の作成日時
- `article_id`: 記事のID. `https://www.nikkei.com/article/XXXXX/` のように URL の `XXXXX` となっている箇所を一意のIDとする

`/workspace/data.sqlite` として管理し（なければ作成せよ）、音声ファイルの変換まで完了した際にレコードを作成する.

## URLの開き方

ログイン情報がある cookei が保存されているので、それを利用してURLを開く.

```bash
browser-use open "https://www.nikkei.com/"          # 空のセッションを立ち上げる
browser-use cookies import /workspace/nikkei_cookies.json
browser-use open "https://www.nikkei.com/"          # クッキー反映のためリロード
```

## 対象記事の絞り方

ある実行ラウンド毎で、対象記事の一覧を毎回作成する. 以下の操作を機械的に実行すること. 対象記事は「アクセスランキング・朝刊・夕刊」から収集される

- `echo "" > /workspace/tmp.txt` で空のファイルを作成する
- **あらゆる広告(PR)リンクや記事は対象外である**. そのことに注意して対象記事を選定せよ

### アクセスランキング

`https://www.nikkei.com/access/` を開き、top 20 までの記事について、記事IDの一覧を入手し、`/workspace/tmp.txt` に追加する. HTMLの構造は以下のようになっていると予想される.
```html
<span class="m-miM32_itemTitle">
    <span class="m-miM32_itemTitleText">
        <a href="/article/DGXZQOUB140P5TU6A510C2000000/">日経平均終値618円安、「フジクラショック」で一転下げ　AI株でも選別</a>
    </span>
    <span class="m-miM32_itemkeyword"><span class="m-miM32_itemDate">2026/5/14 12:10</span></span>
</span>
```

### 朝刊

朝刊を開く(`https://www.nikkei.com/paper/morning/?b=YYYYMMDD`). `YYYYMMDD` には本日の日付を入力せよ.
朝刊では「１面」「総合１」「総合２」にある記事を対象とする.

HTMLは以下のようになっていると予想される. `<a>` タグの `ng=XXXXX` となっている `XXXXX` が `article_id` である.

```html
<div class="cmn-article_text ">
    <p class="">
    ニデックのモーター部品などで品質不正の疑いがあることが12日、わかった。...<a href="/paper/article/?b=20260513&amp;ng=XXXXX" class="cmnc-continue">…続き</a></p>
</div>
```

「１面」「総合１」「総合２」にある全ての記事の `article_id` を `/workspace/tmp.txt` に追加せよ.

### 夕刊

夕刊を開く(`https://www.nikkei.com/paper/evening/?b=YYYYMMDD`). `YYYYMMDD` には本日の日付を入力せよ.
夕刊では「１面」「総合」にある記事を対象とする.

HTMLは以下のようになっていると予想される. `<a>` タグの `ng=XXXXX` となっている `XXXXX` が `article_id` である.

```html
<div class="cmn-article_text ">
    <p class="">
    ニデックのモーター部品などで品質不正の疑いがあることが12日、わかった。...<a href="/paper/article/?b=20260513&amp;ng=XXXXX" class="cmnc-continue">…続き</a></p>
</div>
```

「１面」「総合」にある全ての記事の `article_id` を `/workspace/tmp.txt` に追加せよ.

## 成果物の作成

### 重複記事の除外

`/workspace/tmp.txt` の全ての `article_id` に対して、`/workspace/data.sqlite` に対して SELECT 検索し、既に存在している `article_id` は `/workspace/tmp.txt` から削除せよ

### 対象記事の要約と音声変換

`/workspace/tmp.txt` にある全ての `article_id` に対して以下をループする.

1. `https://www.nikkei.com/article/XXXXX/` ( `XXXXX` は `article_id` ) を開く
2. 記事本文のテキストをそのまま出力し、`/workspace/share/nikkei/XXXXX.org` に保存
3. 記事本文のテキストをマークダウン用に整形し、`/workspace/share/nikkei/XXXXX.md` に保存
4. `/workspace/share/nikkei/XXXXX.md` を入力として、読み上げるニュース原稿形式にテキスト変換し、`/workspace/share/nikkei/XXXXX.txt` に保存
5. `tts.sh -v ja-JP-KeitaNeural -f /workspace/share/nikkei/XXXXX.txt /workspace/share/nikkei/XXXXX.wav` に保存する
6. `/workspace/data.sqlite` に `article_id` と `datetime` を INSER する
7. 次の `article_id` で 作業1. から再度行う

# 補足

日経のWEBページ ( `https://www.nikkei.com/` ) を表示し、 ログイン後、以下のコマンドで cookie を dump している

```bash
browser-use cookies export /workspace/nikkei_cookies.json
```
