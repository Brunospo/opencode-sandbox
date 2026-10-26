FROM python:3.12-slim

# Copia o binário oficial do uv (muito rápido e recomendado pela Astral)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Ferramentas básicas + Node (necessário para o OpenCode)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates nodejs npm ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN npm i -g opencode-ai

# Usuário comum, sem root e sem sudo
# Usuário comum, sem root e sem sudo
RUN useradd -m -u 1000 dev \
 && mkdir -p /home/dev/.config/opencode \
              /home/dev/.local/share/opencode \
              /home/dev/.local/state \
              /home/dev/.cache \
 && chown -R dev:dev /home/dev

USER dev
WORKDIR /workspace

ENV PATH="/home/dev/.local/bin:${PATH}"
CMD ["bash"]