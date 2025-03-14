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

!!!! ( Do below at the other host ) !!!!

```bash
sudo vi /etc/ufw/sysctl.conf
```

```diff
-#net/ipv4/ip_forward=1
+net/ipv4/ip_forward=1
```

```bash
sudo vi /etc/default/ufw
```

```diff
-DEFAULT_FORWARD_POLICY="DROP"
+DEFAULT_FORWARD_POLICY="ACCEPT"
```

```bash
sudo vi /etc/ufw/before.rules
```

Add end of the file.

```diff
+*nat
+:POSTROUTING ACCEPT [0:0]
+:PREROUTING ACCEPT [0:0]
+-F
+-A POSTROUTING -s 172.128.64.0/24 -o docker0 -j MASQUERADE
+-A PREROUTING -p tcp --dport 55432 -s 172.128.64.0/24 -j DNAT --to-destination 172.17.0.2:5432
+COMMIT
```

```bash
sudo ufw allow from 172.128.64.0/24 to any port 55432 # set db port if you need
sudo ufw reload
sudo ufw status
```