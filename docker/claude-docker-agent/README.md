# Install Rootless Docker

```bash
sudo adduser aiagent
sudo apt install -y docker-ce-rootless-extras uidmap iptables systemd-container
# sudo apt install -y --allow-downgrades "docker-ce-rootless-extras=$(dpkg-query -W -f='${Version}' docker-ce)"
sudo apt-mark hold docker-ce-rootless-extras
sudo loginctl enable-linger aiagent
sudo machinectl shell aiagent@ /bin/bash -c "dockerd-rootless-setuptool.sh install"
## check
sudo -l -U aiagent   # must say "not allowed to run sudo"
sudo machinectl shell aiagent@ /bin/bash -c 'systemctl --user restart docker && sleep 2 && systemctl --user status docker --no-pager | head -5'
sudo machinectl shell aiagent@ /bin/bash -c 'DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock docker run --rm hello-world'
```

# GPU (optional)

Requires the NVIDIA driver on the host and [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

```bash
# as an admin user
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place   # required for rootless
sudo machinectl shell aiagent@ /bin/bash -c 'nvidia-ctk runtime configure --runtime=docker --config=$HOME/.config/docker/daemon.json'
sudo machinectl shell aiagent@ /bin/bash -c 'systemctl --user restart docker'
## check
sudo machinectl shell aiagent@ /bin/bash -c 'DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock docker run --rm --gpus all ubuntu nvidia-smi'
```

# Run

```bash
# as an admin user
sudo machinectl shell aiagent@ /bin/bash -c 'systemctl --user start docker'
sudo machinectl shell aiagent@ /bin/bash -c 'systemctl --user status docker --no-pager | head -5'
# as aiagent
su aiagent
GH_TOKEN=ghp_xxx bash ./start.sh            # or: bash ./start.sh <name>
GH_TOKEN=ghp_xxx bash ./start.sh --gpu      # with GPU, based on nvidia/cuda devel image (see "GPU" above)
CUDA_IMAGE=nvidia/cuda:13.0.2-devel-ubuntu24.04 GH_TOKEN=ghp_xxx bash ./start.sh --gpu   # pick a CUDA version your host driver supports
history -c && history -w
```