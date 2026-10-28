# Acessando outras redes

para ter acesso a outras redes:

## 1. Devo criar uma nova rede no docker

```bash
docker network create minha-rede
```

## 2. Se for preciso add no docker-composer:

```yaml
version: "3.5"

services:
  api01-test:
    hostname: api01
    build: .
    environment:
      DB_HOST: mongodb
      DB_NAME: customers
    ports:
      - "9999:9999"
    command: npm run start
    volumes:
      - .:/src
      - nodemodules:/src/node_modules
    depends_on:
      - mongodb
    networks:
      - minha-rede # <--- Adicionado

  mongodb:
    image: mongo
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: example
    networks:
      - minha-rede # <--- Adicionado

volumes:
  nodemodules: {}

networks:
  minha-rede:
    external: true # <--- Informa que a rede já existe no host
```

## 3. Inserrir o comando no run.sh:

--net minha-rede \

## OBS:

se no codigo a URL for localhost, alterar para o host da api, por exemplo:  http://172.19.0.1:9999