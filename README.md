# OpenCode em Docker (ambiente isolado para projetos Python)

Setup para rodar o [OpenCode](https://opencode.ai) (versão 1.x) dentro de um container Docker, isolado do resto do computador. O container enxerga **apenas a pasta do projeto**, sem acesso ao home, chaves SSH, tokens ou arquivos pessoais.

Testado no Pop!_OS (base Ubuntu) com zsh, mas funciona em qualquer Linux com Docker.

## Por que isolar?

O OpenCode é um agente que executa comandos no terminal e edita arquivos. O risco não é o modelo "roubar" algo, e sim ele (ou um prompt malicioso escondido em um repositório ou arquivo) rodar um comando destrutivo ou ler arquivos sensíveis. Com o container, o estrago máximo fica limitado à pasta do projeto montada.

## Como funciona

```
Seu PC                                Container
~/projetos-teste/calculadora  <-->    /workspace
```

- A pasta do projeto **fica no seu PC**. O container apenas a enxerga através de um volume (`-v`).
- Tudo que o OpenCode criar em `/workspace` aparece na pasta real, e vice-versa.
- Se o container for apagado (o `--rm` faz isso ao sair), o projeto continua no seu PC.
- Login e configuração do OpenCode ficam em **volumes nomeados do Docker**, separados dos seus arquivos pessoais.

## Estrutura recomendada

```
~/opencode-sandbox/
├── Dockerfile
└── run.sh
```

## Instalação

### 1. Instalar o Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo usermod -aG docker $USER
```

Faça logout/login (ou reinicie) para o grupo valer. Teste:

```bash
docker run hello-world
```

### 2. Criar a pasta do ambiente

```bash
mkdir -p ~/opencode-sandbox && cd ~/opencode-sandbox
```

### 3. Criar o `Dockerfile`

```dockerfile
FROM python:3.12-slim

# Ferramentas básicas + Node (necessário para o OpenCode)
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates nodejs npm ripgrep \
    && rm -rf /var/lib/apt/lists/*

# OpenCode 1.x e uv (gerenciador de pacotes Python)
RUN npm i -g opencode-ai
RUN pip install --no-cache-dir uv

# Usuário comum (sem root e sem sudo).
# Os diretórios são criados aqui, já com o dono correto, para que os
# volumes nomeados herdem a permissão do usuário "dev".
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
```

### 4. Construir a imagem

```bash
cd ~/opencode-sandbox
docker build -t opencode-py .
```

### 5. Criar o `run.sh`

```bash
#!/usr/bin/env bash
# Uso: ./run.sh /caminho/do/projeto   (sem argumento, usa a pasta atual)
PROJ="${1:-$PWD}"

docker run -it --rm \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  --memory=4g --cpus=2 \
  -v "$(realpath "$PROJ")":/workspace \
  -v opencode-config:/home/dev/.config/opencode \
  -v opencode-data:/home/dev/.local/share/opencode \
  -v opencode-state:/home/dev/.local/state \
  opencode-py

# Para apps web (Flask/FastAPI), adicione antes de "opencode-py":
#   -p 8000:8000 \
```

Dê permissão de execução:

```bash
chmod +x run.sh
```

### 6. Criar um atalho (alias)

No **zsh**:

```bash
echo "alias oc='~/opencode-sandbox/run.sh'" >> ~/.zshrc
source ~/.zshrc
```

No **bash**, troque `~/.zshrc` por `~/.bashrc`.

O `run.sh` usa `#!/usr/bin/env bash` e roda em bash independentemente do shell do terminal, então não precisa mudar nada nele.

## Uso diário

**No terminal normal (fora do container):**

```bash
mkdir -p ~/projetos-teste/calculadora
cd ~/projetos-teste/calculadora
oc
```

**Dentro do container** (`dev@...:/workspace$`):

```bash
git init
uv init          # cria pyproject.toml e main.py
opencode
```

No OpenCode, peça o que quiser, por exemplo: "crie uma calculadora em Python com interface de terminal".

Você pode abrir a mesma pasta no VS Code do seu PC enquanto o OpenCode trabalha: os dois editam os mesmos arquivos.

## Pacotes Python (uv)

Sempre use o `uv` **dentro do container**, na pasta `/workspace`:

```bash
uv add fastapi uvicorn     # instala e registra no pyproject.toml / uv.lock
uv run main.py             # roda o programa
uv sync                    # recria o .venv a partir do uv.lock
```

- `uv add` grava o ambiente na pasta do projeto, então **persiste** no seu PC.
- Evite `pip install` solto fora de um venv: ele instala no Python do container e some ao sair.
- O que realmente define as dependências é o `pyproject.toml` + `uv.lock`. O `.venv` é descartável.
- Coloque `.venv/` no `.gitignore`.

> **Atenção:** o `.venv` criado no container usa o Python do container. Se você rodar `uv sync` ou `uv run` direto no PC, pode dar erro ou recriar o ambiente. Escolha um único lugar para rodar o projeto (o container) ou apague o `.venv` ao trocar (`rm -rf .venv && uv sync`).

## Permissões do OpenCode (modo "perguntar")

Crie um `opencode.json` na raiz de cada projeto:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "edit": "ask",
    "bash": "ask"
  }
}
```

Assim o OpenCode pede confirmação antes de editar arquivos ou rodar comandos. Leia o comando antes de aprovar.

## Apps web (FastAPI, Flask)

1. Descomente/adicione `-p 8000:8000` no `run.sh`.
2. Dentro do container, rode o servidor escutando em todas as interfaces:
   ```bash
   uv run uvicorn main:app --host 0.0.0.0 --reload
   ```
3. Acesse `http://localhost:8000` no navegador do seu PC.

O container não tem tela, então interfaces gráficas (Tkinter etc.) não abrem. Prefira terminal ou web.

## Mais de uma instância

**Outro projeto em outro terminal:** basta rodar `oc` na outra pasta. Cada `oc` cria um container independente.

```bash
# terminal 1
cd ~/projetos-teste/calculadora && oc
# terminal 2
cd ~/projetos-teste/api-teste && oc
```

- Se os dois expuserem portas, use portas diferentes (`-p 8001:8000` no segundo).
- Os dois compartilham os mesmos volumes de configuração (o login vale para ambos).

**Mesmo projeto em dois terminais:** não abra outro `oc`. Entre no container que já está rodando:

```bash
docker ps
docker exec -it <nome-ou-id> bash
```

## Solução de problemas

### `EACCES: permission denied, mkdir '/home/dev/.local/share/opencode/repos'`

Os volumes nomeados nasceram com dono `root` porque o diretório não existia na imagem quando foram criados. A correção é criar os diretórios no Dockerfile com `chown` (já incluído acima), apagar os volumes antigos e reconstruir:

```bash
docker volume rm opencode-config opencode-data opencode-state
docker build -t opencode-py .
```

Será necessário refazer o login do OpenCode uma vez.

### `port is already allocated`

Outra instância já usa a porta. Mude a porta do host (`-p 8001:8000`).

### Arquivos criados com dono errado no PC

O container usa UID 1000. Confira o seu com `id -u`. Se for diferente, troque o `-u 1000` do `useradd` no Dockerfile e reconstrua a imagem.

### Comando `oc` não encontrado

Confira se o alias foi gravado: `tail -1 ~/.zshrc`, e rode `source ~/.zshrc`.

## Boas práticas de segurança

- **Monte só a pasta do projeto.** Nunca monte `~` inteiro, `~/.ssh`, `~/.aws` ou pastas com tokens.
- **Sem credenciais reais no ambiente:** evite `.env` com chaves de produção dentro do projeto de teste.
- **Mantenha `edit` e `bash` em `"ask"`** e leia antes de aprovar.
- **Use Git** com commits frequentes para reverter edições indesejadas.
- **Modelos gratuitos:** a política de dados pode ser diferente (alguns usam o conteúdo para treino). Não envie código proprietário ou segredos nos prompts.
- **Prompt injection:** repositórios, READMEs e páginas baixadas podem conter instruções escondidas para o agente. Não aponte o agente para material não confiável fora do isolamento.
- **Limite a rede se usar modelo local** (Ollama): `--network none` no `docker run` impede qualquer envio para fora (mas bloqueia também modelos remotos).
- Para isolamento ainda maior, use uma **VM** (Multipass, VirtualBox) ou um ambiente descartável na nuvem (Codespaces, VPS).

## Configurando em outra máquina (resumo rápido)

```bash
# 1. Docker
sudo apt update && sudo apt install -y docker.io
sudo usermod -aG docker $USER   # depois, logout/login

# 2. Clonar este repositório (contém Dockerfile e run.sh)
git clone <url-do-seu-repo> ~/opencode-sandbox
cd ~/opencode-sandbox

# 3. Construir e criar o alias
docker build -t opencode-py .
chmod +x run.sh
echo "alias oc='~/opencode-sandbox/run.sh'" >> ~/.zshrc && source ~/.zshrc

# 4. Usar
mkdir -p ~/projetos-teste/meu-app && cd ~/projetos-teste/meu-app
oc
```

## Observação sobre o OpenCode 2.0

Este README cobre a versão **1.x** (pacote npm `opencode-ai`). O OpenCode 2.0 é distribuído como um pacote separado (`@opencode/cli`) e tem mudanças de arquitetura, como um serviço em segundo plano e plugins incompatíveis com o V1. Se for migrar, troque a linha `npm i -g opencode-ai` do Dockerfile e confira se o formato de permissões do `opencode.json` continua válido.
