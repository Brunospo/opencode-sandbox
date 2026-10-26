#!/usr/bin/env bash
# Uso: ./run.sh /caminho/do/projeto
PROJ="${1:-$PWD}"

docker run -it --rm \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  --memory=4g --cpus=2 \
  -v "$(realpath "$PROJ")":/workspace \
  -v opencode-config:/home/dev/.config/opencode \
  -v opencode-data:/home/dev/.local/share/opencode \
  opencode-py