# Redash

### Create Instance

```bash
sudo apt update && sudo apt install -y git pwgen
cd ~
git clone https://github.com/getredash/setup.git redash
cd ~/redash
git checkout 9289121b43a66bed1f2a08e0fc4d38d6931c90de
vi setup.sh
```

I don't know why but it didn't work when I edited ./data/compose.yaml directoly.

```diff
  sed -i "s|__TAG__|$TAG|" compose.yaml
+  perl -0777 -pi -e 's/ports:.*?"5000:5000"//sg' compose.yaml
+  sed -i -e 's/"80:80"/"28880:80"/g' compose.yaml
+  sed -i -e '/^\s*$/d' compose.yaml
  export COMPOSE_FILE="$REDASH_BASE_PATH"/compose.yaml
  export COMPOSE_PROJECT_NAME=redash
```

```bash
sudo bash setup.sh --version 25.8.0
```

### Stop redash

```bash
# sudo docker network disconnect redash_default postgres # If you added network
sudo docker compose -f /opt/redash/compose.yaml down
```

### Start redash

```bash
sudo docker compose -f /opt/redash/compose.yaml up -d
```

### Delete ALL

```bash
sudo rm -rf /opt/redash/*
sudo bash setup.sh --version 25.8.0
```

# Network

### Connect to other container with same host

```bash
sudo docker network connect redash_default postgres
sudo docker inspect postgres
```

### Connect to other container with other host

see: https://github.com/kazukingh01/kkpsgre/tree/2a66db8b6b7d8040853c21a528fac7ba8a413758?tab=readme-ov-file#port-forward-to-container
