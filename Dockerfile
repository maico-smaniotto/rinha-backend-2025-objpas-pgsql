FROM ubuntu:22.04

# Evita interações durante a instalação
ENV DEBIAN_FRONTEND=noninteractive

# Instala dependências necessárias
RUN apt-get update && apt-get install -y \
    fpc \
    fpc-source \
    build-essential \
    wget \
    curl \
    ca-certificates \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Define o diretório de trabalho
WORKDIR /app

# Copia os arquivos do projeto
COPY . .

# Compila a aplicação considerando todas as subpastas
RUN fpc -O3 -XX -Xs -CX \
    -Fu./src \
    -Fi./src \
    Payments.lpr

# Cria um usuário não-root para executar a aplicação
RUN useradd -r -s /bin/false appuser && \
    chown -R appuser:appuser /app

# Muda para o usuário não-root
USER appuser

# Expõe a porta
EXPOSE 9999

# Define o comando para executar a aplicação
CMD ["./Payments"]
