# 前提条件/共通のルール

@Z_1_shared_rules.md に従う

# 本指示書について

既存のプロジェクトから作成されたデータベースについて、そのスキーマやテーブル、カラムの意味についてまとめるための指示書である.
PostgreSQL を想定して、読み取り専用ユーザにより実際に接続して確認可能なものを目指す.

# 事前準備

以下のコマンドは、あなたではなく私が行う環境準備です

```bash
sudo apt update
sudo apt-get install -y postgresql-client
```

# 目的

「方法」に従い、@./DESIGN_database.md を作成し、中身を完成させよ

# DB接続

## 接続情報

./conninfo.txt に私が記載する.

```bash
postgresql://myuser:mypassword@localhost:5432/mydb # example
```

## 接続方法

次のコマンドでSQLを実行できる.

```bash
psql "$(cat ./conninfo.txt)" -c "SELECT * FROM table_name LIMIT 100;"
```

- DELETE / INSERT / UPDATE / DROP TABLE など、データを変更する操作は一切行わないこと
- あなたは SELECT のみ実行できる
- 必ず LIMIT をつけ、データを制限すること. MAX は LIMIT 1000 までとする

# 方法

1. @./DESIGN_database.md を新規作成する
2. プロジェクトのソースコードを読み、実装を理解する
3. 以下の点に注意し、以下の templace に従って、"DESIGN_database.md" を完成させる
  - スキーマを定義するファイルがある場合、それを正として良い
  - あるカラムのデータは、複数のスクリプトにまたがって、INSERTされ、UPDATEされている可能性がある. プログラムの処理の順番を慎重に考慮して判断せよ
  - 判断に曖昧さが残る場合は、その旨も記載せよ

```template
[table]
table name 1:
  テーブルの説明をいれる
- column A: カラムの型
  どんなプログラムから、どんなアルゴリズムによって作成/取得され、どんなデータがあるか, Primary key や uniqu key であるのか, デフォルトではどんな値となるか, について記載する.
  `psql "$(cat ./conninfo.txt)" -c "WITH A AS (SELECT col FROM t LIMIT 1000) SELECT col FROM A GROUP BY col;" といった方法で実際のデータを確認し、どういったデータが入っているのかの例を３つ程度記載する.

- column B:
...

table name 2
...

[relation]
テーブルとテーブルのリレーションが、どのカラムによって関係しているかを記載する. 

[view]
view name 1 ※view が定義されていれば
...
```

