# MongoDB

# 説明

非常にややこしいので、日本語で記載する.

### 概念

登場人物は以下の３種類.
- config server: sharding と replica set の設定を管理する
- shard server: 1 shard は必ず 1 replica set を持つ
- mongos: client はここに接続する. どの shard に割り振るかのルーティングを行う

```
                 ▲
                 │
            [ mongos ]   ← ルーター
                 │
        ┌────────┴─────────┐
        │                  │
 [config server]      [shard X server]
  mongod(config.conf)  mongod(shardX.conf)
```

### Sharding と ReplicaSet

**Sharding** とは、データの分割である. Sharding がN個の場合、データをN個に分割して、Nノードに配置する（厳密にはN個のレプリカセットに分割する、だが、実質的にはNノードに分割する事が多いため、そう記載する）
**ReplicaSet** とは、データのレプリケーションに関するクラスターである. Primary, Secondary, Arbiter(データの実態を持たない) が存在し、データの複製とそのグループを管理する.

1 shard は必ず 1つの replica set を持つ（ **1つしか持てない** ）.
これだけでは実はデータのレプリケーションについて情報が不十分である.

replica set が member を 1つ持つ.
この設定だと、つまりある shard A (1つしかないが) は Primary を持つという事である.
replica set が member を 2つ持つ.
この設定だと、つまりある shard A (1つしかないが) は Primary と Secondary を持つ（2ノードで管理する）という事である.

要するに、（ config の ReplicaSet を除く）**ReplicaSetの名前の種類の数が、Sharding 数である**。
そして各 ReplicaSet に登録された ( Arbiterを除く ) member の数が、レプリケーションの数である

# 構成例

### 1ノード構成

```
server X
 ├─ mongos (44400)
 ├─ config server (configReplSet, 44415)
 └─ shard A server (ReplicaSetA, 44417)
```

**config server**

`/etc/mongod.config.conf`

```
storage:
  dbPath: /var/lib/mongodb-config
  journal:
    enabled: true

systemLog:
  destination: file
  path: /var/log/mongodb/config.log
  logAppend: true

net:
  bindIp: 127.0.0.1
  port: 44415

sharding:
  clusterRole: configsvr

replication:
  replSetName: configReplSet
```

mongod プロセス ( config server ) の起動

```bash
sudo mkdir -p /var/lib/mongodb-config /var/log/mongodb
sudo chown -R mongodb:mongodb /var/lib/mongodb-config /var/log/mongodb
sudo -u mongodb mongod --config /etc/mongod.config.conf
```

`configReplSet` の初期化

```bash
mongosh --host localhost --port 44415
```

```js
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "localhost:44415" }
  ]
})
```

**shard A server（ ReplicaSetA ）**

`/etc/mongod.shardA.conf`

```
storage:
  dbPath: /var/lib/mongodb-shardA
  journal:
    enabled: true

systemLog:
  destination: file
  path: /var/log/mongodb/shardA.log
  logAppend: true

net:
  bindIp: 127.0.0.1
  port: 44417

sharding:
  clusterRole: shardsvr

replication:
  replSetName: ReplicaSetA
```

mongod プロセス ( shard A server ) の起動

```bash
sudo mkdir -p /var/lib/mongodb-shardA
sudo chown -R mongodb:mongodb /var/lib/mongodb-shardA
sudo -u mongodb mongod --config /etc/mongod.shardA.conf
```

`ReplicaSetA` の初期化

```bash
mongosh --host localhost --port 44417
```

```js
rs.initiate({
  _id: "ReplicaSetA",
  members: [
    { _id: 0, host: "localhost:44417" }
  ]
})
```

**mongos**

`/etc/mongos.conf`

```
systemLog:
  destination: file
  path: /var/log/mongodb/mongos.log
  logAppend: true

net:
  bindIp: 127.0.0.1
  port: 44400

sharding:
  configDB: configReplSet/localhost:44415
```

mongos プロセスの起動

```bash
sudo -u mongodb mongos --config /etc/mongos.conf
```

shard の追加（ルーティングに追加）

```bash
mongosh --host localhost --port 44400
```

```js
use admin
// ReplicaSetA を shard として追加
sh.addShard("ReplicaSetA/localhost:44417")
// 確認
sh.status()
```

### 2ノード&ノーレプリケーション構成

```
server X
 ├─ mongos (44400)
 ├─ config server (configReplSet, 44415)
 └─ shard A server (ReplicaSetA, 44417)

server Y
 └─ shard B server (ReplicaSetB, 44427) <-- New !!
```

**server Y / shard B server（ ReplicaSetA ）**

**server Y** / `/etc/mongod.shardB.conf`

```
storage:
  dbPath: /var/lib/mongodb-shardB
  journal:
    enabled: true

systemLog:
  destination: file
  path: /var/log/mongodb/shardB.log
  logAppend: true

net:
  bindIp: 0.0.0.0          # 他ホストからもアクセスしたいので 0.0.0.0
  port: 44427              # 空いているポートを1つ決める

sharding:
  clusterRole: shardsvr    # shard 用の mongod

replication:
  replSetName: ReplicaSetB # shard B 用レプリカセット名
```

server Y / mongod プロセス ( shard B server ) の起動

```bash
sudo mkdir -p /var/lib/mongodb-shardB
sudo chown -R mongodb:mongodb /var/lib/mongodb-shardB
sudo -u mongodb mongod --config /etc/mongod.shardB.conf
```

`ReplicaSetB` の初期化

```bash
mongosh --host localhost --port 44427
```

```js
rs.initiate({
  _id: "ReplicaSetB",
  members: [
    { _id: 0, host: "localhost:44427" }
  ]
})
```

**mongos**

**server X** / mongosから shard B のルーティングを追加

```bash
mongosh --host serverX --port 44400
```

```js
use admin
// shard B（ReplicaSetB）を追加
sh.addShard("ReplicaSetB/serverY:44427")
// 確認
sh.status()
```

### 2ノード&ノーレプリケーション構成(config のみレプリケーション)

```
server X
 ├─ mongos (44400)
 ├─ config server (configReplSet, 44415)
 └─ shard A server (ReplicaSetA, 44417)

server Y
 ├─ config server (configReplSet, 44415) <-- New !!
 └─ shard B server (ReplicaSetB, 44427)
```

**config server**

**server Y** / `/etc/mongod.config.conf`

```
storage:
  dbPath: /var/lib/mongodb-config
  journal:
    enabled: true

systemLog:
  destination: file
  path: /var/log/mongodb/config.log
  logAppend: true

net:
  bindIp: 0.0.0.0   # server X からアクセスしたいので 0.0.0.0
  port: 44415

sharding:
  clusterRole: configsvr

replication:
  replSetName: configReplSet
```

**server Y** / mongod プロセス ( config server ) の起動

```bash
sudo mkdir -p /var/lib/mongodb-config /var/log/mongodb
sudo chown -R mongodb:mongodb /var/lib/mongodb-config /var/log/mongodb
sudo -u mongodb mongod --config /etc/mongod.config.conf
```

**server X** の Primary（既存 config server）から rs.add する

```bash
mongosh --host serverX --port 44415
```

```js
rs.add({
  _id: 1,
  host: "serverY:44415"
})
```

### 構成変更サマリ

##### ①レプリケーションの追加（ ReplicaSet の member を追加. config server の追加もこれに該当する ）

1. 追加したい ReplicaSet ( Primary ) がある serverAの config1 とほぼ同じものを、追加したい serverB に config2 として配備
2. serverB で dir などの環境を作成する
3. serverB で config2 の mongod プロセスを起動
4. serverA ( Primary ) で ```rs.add``` で serverB を加える
5. ※オプション※ config のレプリケーション追加のみ、```/etc/mongos.conf``` を編集して再起動を推奨. shard のレプリケーション追加では必要ない

##### ②shard の追加

1. 追加したい serverB に 新規の shard config ( ReplicaSetB ) を配備
2. serverB で dir などの環境を作成する
3. serverB で shard config の mongod プロセスを起動
4. serverB で ReplicaSetB を初期化
5. serverA の mongos で ```sh.addShard``` して shard を追加. ※ config server には何もしなくて良い. mongos が勝手に知らせてくれる

という流れであり、実際には②＋①のような複合的な操作が行われている。※多くの場合、②の作業に①が伴う
つまり、作業としては、①が行われるか、②＋①が行われるかという事である