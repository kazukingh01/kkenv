# Redash

### Create Instance

```bash
sudo apt update && sudo apt install -y git pwgen
cd ~
git clone https://github.com/getredash/setup.git redash
cd ~/redash
git checkout 96e4f16e70ab9fa354e7333ff8e03eb06337027c
vi setup.sh
```

Remove extra port forwarding.

```diff
  sed -i "s|__TAG__|$TAG|" compose.yaml
+  perl -0777 -pi -e 's/ports:.*?"5000:5000"//sg' compose.yaml
+  sed -i -e 's/"80:80"/"28880:80"/g' compose.yaml
+  sed -i -e '/^\s*$/d' compose.yaml
  export COMPOSE_FILE="$REDASH_BASE_PATH"/compose.yaml
  export COMPOSE_PROJECT_NAME=redash
```

```bash
cd ~/redash
sudo bash setup.sh
```

### Stop redash

```bash
sudo docker network disconnect redash_default postgres # If you added network
sudo docker compose -f /opt/redash/compose.yaml down
sudo rm -rf /opt/redash/*
```

# Network

### Connect to other container with same host

```bash
sudo docker network connect redash_default postgres
sudo docker inspect postgres
```

### Connect to other container with other host

see: https://github.com/kazukingh01/kkpsgre/tree/2a66db8b6b7d8040853c21a528fac7ba8a413758?tab=readme-ov-file#port-forward-to-container
