# Deploy da Etapa 1 - n8n self-hosted no VPS (CyberPanel/LiteSpeed)

> Arquitetura: **n8n em `127.0.0.1:5678` + proxy reverso do LiteSpeed/CyberPanel**, SSL
> Let's Encrypt gerenciado pelo painel. Sem Traefik (as portas 80/443 sao do LiteSpeed/FIN365).
> Mesmo padrao ja usado pela Evolution API neste VPS.

## Pre-requisitos (ja presentes no VPS do FIN365)
- Docker + Docker Compose (a Evolution API ja roda via Docker).
- CyberPanel (AlmaLinux 9) + LiteSpeed nas portas 80/443.
- DNS na Cloudflare (SSL/TLS Full Strict).

## Passo a passo

### 1. DNS
Criar registro **A** do subdominio (ex: `n8n.<dominio>`) apontando para `<IP_DO_SEU_VPS>`.
Na Cloudflare, deixar o registro como **DNS only** (nuvem cinza) ao emitir o SSL no CyberPanel,
depois pode voltar a proxied se desejado.

### 2. Subir a stack
```bash
sudo mkdir -p /opt/monitor-vagas-tech-n8n
# copiar o repo para /opt/monitor-vagas-tech-n8n (git clone ou rsync)
cd /opt/monitor-vagas-tech-n8n
cp .env.example .env
# preencher .env: N8N_HOST, N8N_ENCRYPTION_KEY (openssl rand -hex 32),
#                 DB_POSTGRESDB_PASSWORD (openssl rand -hex 24)
chmod 600 .env
docker compose --env-file .env up -d
docker compose ps        # postgres healthy + n8n up
curl -s http://127.0.0.1:5678/healthz   # {"status":"ok"}
```

### 3. Website + SSL + proxy reverso no CyberPanel
1. CyberPanel > **Websites > Create Website**: dominio `n8n.<dominio>`.
2. **SSL > Manage SSL > Issue SSL** (Let's Encrypt) para o subdominio.
3. **Websites > Manage > vHost Conf** (ou Rewrite Rules) - adicionar o proxy para o container:
   ```
   context / {
     type                    proxy
     handler                 http://127.0.0.1:5678
     addDefaultCharset       off
   }
   ```
   > Em OpenLiteSpeed tambem e possivel criar um **External App (Web Server / proxy)**
   > apontando para `127.0.0.1:5678` e um **context** `/` do tipo proxy para ele.
   > Garantir que o header `X-Forwarded-Proto: https` seja repassado (o n8n usa `N8N_PROXY_HOPS=1`).
4. Reiniciar o LiteSpeed: `/usr/local/lsws/bin/lswsctrl restart`.

### 4. Firewall
Nenhuma porta nova publica: o 5678 esta preso em `127.0.0.1`. Conferir que `5678` NAO aparece
publico: `ss -tlnp | grep 5678` deve mostrar `127.0.0.1:5678` apenas.

### 5. Primeiro acesso
Abrir `https://n8n.<dominio>` - o n8n pede para criar a **conta owner** (auth nativa).
Sem login nao ha acesso ao editor (atende ao Gate 3 "acesso sem auth e negado").

### 6. Backup
Agendar o dump diario:
```bash
chmod +x /opt/monitor-vagas-tech-n8n/scripts/backup-postgres.sh
crontab -e
# 0 3 * * * /opt/monitor-vagas-tech-n8n/scripts/backup-postgres.sh >> /var/log/n8n-backup.log 2>&1
```

## Smoke test (Gate 3 - executar apos o deploy)
- **Feliz:** `https://n8n.<dominio>` responde 200/302 com cadeado valido e pede login.
- **Invalido:** chamar o editor sem sessao -> redireciona para login (nao expoe workflows).
- **Ausencia:** subir sem `.env` -> `docker compose up` falha com variavel ausente (nao sobe com
  credencial default exposta).

## Rollback
`docker compose down` remove os containers; os volumes `pg_data`/`n8n_data` persistem.
Nenhuma alteracao e feita no LiteSpeed/FIN365 fora do vHost do subdominio novo (reversivel
removendo o website `n8n.<dominio>` no CyberPanel).
