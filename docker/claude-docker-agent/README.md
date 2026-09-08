# Install Rootless Docker

```bash
sudo adduser aiagent # "aiagent" is password
sudo usermod -aG sudo aiagent
su aiagent
sudo apt install -y docker-ce-rootless-extras uidmap iptables systemd-container
# sudo apt install -y --allow-downgrades "docker-ce-rootless-extras=$(dpkg-query -W -f='${Version}' docker-ce)"
sudo apt-mark hold docker-ce-rootless-extras
sudo machinectl shell aiagent@ /bin/bash -c "dockerd-rootless-setuptool.sh install"
## check
sudo machinectl shell aiagent@ /bin/bash -c 'systemctl --user restart docker && sleep 2 && systemctl --user status docker --no-pager | head -5'
sudo machinectl shell aiagent@ /bin/bash -c 'DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock docker run --rm hello-world'
```

# Run

```bash
su aiagent
sudo loginctl enable-linger aiagent
sudo machinectl shell aiagent@ /bin/bash -c 'systemctl --user start docker'
sudo machinectl shell aiagent@ /bin/bash -c 'systemctl --user status docker --no-pager | head -5'
# vi ~/.env # GH_TOKEN=ghp_xxx
set -a; source ~/.env; set +a; bash ./start.sh
```
