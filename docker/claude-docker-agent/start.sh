#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

NAME=""
IMAGE="claude-code"
BUILD_ARGS=()
GPU_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --gpu)
            IMAGE="claude-code-gpu"
            BUILD_ARGS=(--build-arg "BASE_IMAGE=${CUDA_IMAGE:-nvidia/cuda:13.2.1-devel-ubuntu24.04}")
            GPU_ARGS=(--gpus all)
            ;;
        -*) echo "unknown option: $arg" >&2; exit 1 ;;
        *)
            if [ -n "$NAME" ]; then
                echo "multiple names given: $NAME, $arg" >&2
                exit 1
            fi
            NAME="$arg"
            ;;
    esac
done

if [ -n "$NAME" ]; then
    CONTAINER_NAME="claude-code-$NAME"
else
    CONTAINER_NAME="claude-code"
fi

# Rootless docker: run as the rootless user (e.g. aiagent), not root
export DOCKER_HOST="unix:///run/user/$(id -u)/docker.sock"

docker build -t "$IMAGE" "${BUILD_ARGS[@]}" "$SCRIPT_DIR"

docker run -itd \
    --name "$CONTAINER_NAME" \
    "${GPU_ARGS[@]}" \
    -e GH_TOKEN="$GH_TOKEN" \
    -v "/run/user/$(id -u)/docker.sock":/var/run/docker.sock \
    -v "$SCRIPT_DIR/workspace":/workspace \
    -v "$HOME/.claude/skills":/home/claude/.claude/skills:ro \
    "$IMAGE"