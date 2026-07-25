# Proxy Reverso — NGINX + Traefik + Monitoramento

Projeto de estudo sobre **Proxy Reverso** utilizando **NGINX** e **Traefik** como balanceadores/roteadores centrais de requisições HTTP para múltiplos serviços rodando em containers Docker, com stack de monitoramento integrada.

---

## 📐 Arquitetura Geral

```
Internet (cliente)
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  Proxy Reverso Central (escolha um)                       │
│  ┌─────────────────────┐  ┌────────────────────────────┐ │
│  │ NGINX Proxy (:80)   │  │ Traefik Proxy (:80/:443)   │ │
│  │ Roteia por           │  │ Descobre containers via     │ │
│  │ server_name estático │  │ labels Docker (dinâmico)    │ │
│  └─────────┬───────────┘  └─────────────┬──────────────┘ │
└────────────┼────────────────────────────┼────────────────┘
             │                            │
             ▼                            ▼
┌──────────────────────────────────────────────────────────┐
│  Serviços Backend (rede Docker interna: web-network)      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │ projeto1 │  │ projeto2 │  │ projeto3 │               │
│  │  :80     │  │  :80     │  │  :80     │               │
│  └──────────┘  └──────────┘  └──────────┘               │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  Stack de Monitoramento (também na web-network)           │
│  ┌──────────┐ ┌───────────────┐ ┌──────────┐            │
│  │ cAdvisor │ │ Node Exporter │ │ Grafana  │            │
│  │ :8080    │ │ :9100         │ │ :3000    │            │
│  └──────────┘ └───────────────┘ └──────────┘            │
│  ┌──────────┐                                            │
│  │ Dockhand │  Gerenciador de containers com interface   │
│  │ :3000    │  web integrada ao Docker                    │
│  └──────────┘                                            │
└──────────────────────────────────────────────────────────┘
```

---

## 🔧 Estrutura de Diretórios

```
proxy/
├── nginx/                        # Proxy reverso com NGINX
│   ├── nginx-proxy/              # Proxy reverso central (NGINX)
│   │   ├── docker-compose.yml
│   │   └── nginx.conf
│   ├── projeto1/                 # Serviço 1 (NGINX)
│   │   ├── docker-compose.yml
│   │   ├── nginx/
│   │   │   └── nginx.conf
│   │   └── html/
│   │       └── index.html
│   ├── projeto2/                 # Serviço 2 (NGINX)
│   │   ├── docker-compose.yml
│   │   ├── nginx/
│   │   │   └── nginx.conf
│   │   └── html/
│   │       └── index.html
│   └── projeto3/                 # Serviço 3 (NGINX)
│       ├── docker-compose.yml
│       ├── nginx/
│       │   └── nginx.conf
│       └── html/
│           └── index.html
│
├── traefik/                      # Proxy reverso com Traefik (alternativa ao NGINX)
│   ├── traefik-proxy/            # Proxy reverso central (Traefik v3)
│   │   ├── docker-compose.yml
│   │   └── traefik.yml
│   ├── projeto1/                 # Serviço 1 (Traefik)
│   │   ├── docker-compose.yml
│   │   └── html/
│   │       └── index.html
│   ├── projeto2/                 # Serviço 2 (Traefik)
│   │   ├── docker-compose.yml
│   │   └── html/
│   │       └── index.html
│   └── projeto3/                 # Serviço 3 (Traefik)
│       ├── docker-compose.yml
│       └── html/
│           └── index.html
│
├── monitoring/                   # Stack de monitoramento
│   ├── docker-compose.yml        # Define cAdvisor, Node Exporter, Grafana e Dockhand
│   ├── grafana/
│   │   └── datasources/          # Configurações de datasources do Grafana
│   └── prometheus/               # (diretório reservado — configurações removidas)
│
├── hey/                          # Ferramenta de teste de carga
│   └── testes.bat                # Script de benchmark HTTP (hey)
│
├── README.md                     # Este arquivo
└── commit.txt                    # Histórico resumido de alterações
```

---

## 🧠 Anotações sobre Proxy Reverso

### O que é um Proxy Reverso?

Um **proxy reverso** é um servidor que fica entre o cliente (navegador/internet) e os servidores de aplicação (backends). Ele recebe as requisições do cliente e as encaminha para o servidor interno apropriado. A resposta do backend volta pelo proxy até o cliente.

### Por que usar?

| Benefício | Descrição |
|-----------|-----------|
| **Roteamento por domínio** | Um único IP/porta pode servir múltiplos sites com base no `Host` header (ex: `projeto1.empresa`, `projeto2.empresa`) |
| **Segurança** | Backends não precisam expor portas para a internet — ficam isolados em rede interna Docker |
| **Terminação SSL/TLS** | O proxy lida com HTTPS, enquanto os backends usam HTTP simples internamente |
| **Balanceamento de carga** | Distribui tráfego entre múltiplas instâncias do mesmo serviço |
| **Cache e compressão** | Pode cachear respostas e comprimir dados, reduzindo carga nos backends |

---

## 🟢 NGINX — Proxy Reverso (abordagem estática)

### Como funciona

1. **Rede Docker compartilhada**: Todos os containers (proxy + projetos) estão na mesma rede Docker bridge chamada `web-network`. Isso permite que o proxy alcance os projetos pelo nome do container (ex: `projeto1`, `projeto2`, `projeto3`).

2. **Resolução DNS interna**: O NGINX proxy usa `resolver 127.0.0.11` (DNS interno do Docker) para resolver dinamicamente os nomes dos containers para IPs internos.

3. **Roteamento baseado em `server_name`**: O NGINX proxy inspeciona o cabeçalho `Host` da requisição HTTP e decide para qual container encaminhar:
   - `projeto1.empresa` → container `projeto1`
   - `projeto2.empresa` → container `projeto2`
   - `projeto3.empresa` → container `projeto3`

4. **Portas não expostas**: Os containers dos projetos **não expõem portas** para o host. Todo o tráfego passa obrigatoriamente pelo proxy.

### Diretivas NGINX importantes usadas

| Diretiva | Função |
|----------|--------|
| `server_name` | Define qual domínio este bloco `server` atende |
| `proxy_pass` | Encaminha a requisição para o upstream especificado |
| `resolver` | Configura o servidor DNS para resolução de nomes |
| `set $upstream` | Define uma variável com o nome do container de destino |
| `listen` | Porta em que o NGINX escuta |

### Comandos para subir (NGINX)

```bash
# Subir o proxy central (primeiro, para criar a rede)
cd nginx/nginx-proxy
docker-compose up -d

# Subir os projetos
cd nginx/projeto1 && docker-compose up -d
cd nginx/projeto2 && docker-compose up -d
cd nginx/projeto3 && docker-compose up -d

# Testar (adicionar ao /etc/hosts ou usar curl com header Host)
curl -H "Host: projeto1.empresa" http://localhost
curl -H "Host: projeto2.empresa" http://localhost
curl -H "Host: projeto3.empresa" http://localhost
```

---

## 🔵 Traefik — Proxy Reverso (abordagem dinâmica)

O **Traefik** foi adicionado como alternativa moderna ao NGINX. A principal diferença é que o Traefik **descobre containers automaticamente** via labels Docker, sem necessidade de editar arquivos de configuração para cada novo serviço.

### Como funciona

1. **Descoberta automática**: O Traefik monitora o Docker socket (`/var/run/docker.sock`) e detecta containers com a label `traefik.enable=true`.

2. **Roteamento por labels**: Cada serviço define suas regras de roteamento diretamente no `docker-compose.yml` via labels:
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.projeto1.rule=Host(`projeto1.empresa`)"
     - "traefik.http.services.projeto1.loadbalancer.server.port=80"
   ```

3. **Dashboard integrado**: O Traefik expõe um dashboard na porta `8080` para visualizar rotas, serviços e middlewares em tempo real.

4. **EntryPoints**: O Traefik configura dois pontos de entrada:
   - `web` — porta `80` (HTTP)
   - `websecure` — porta `443` (HTTPS — preparado para SSL futuro)

### Comparação NGINX vs Traefik

| Característica | NGINX | Traefik |
|---------------|-------|---------|
| Configuração | Arquivos estáticos (`nginx.conf`) | Labels Docker (dinâmico) |
| Descoberta de serviços | Manual (precisa editar conf) | Automática (Docker provider) |
| Dashboard | Não (precisa de ferramenta externa) | Sim, nativo na porta 8080 |
| Hot-reload | Precisa de `nginx -s reload` | Automático ao criar/remover containers |
| Curva de aprendizado | Moderada | Baixa para Docker |
| Flexibilidade | Muito alta | Alta |

### Comandos para subir (Traefik)

```bash
# Subir o proxy Traefik (primeiro, para criar a rede)
cd traefik/traefik-proxy
docker-compose up -d

# Subir os projetos gerenciados pelo Traefik
cd traefik/projeto1 && docker-compose up -d
cd traefik/projeto2 && docker-compose up -d
cd traefik/projeto3 && docker-compose up -d

# Testar
curl -H "Host: projeto1.empresa" http://localhost
curl -H "Host: projeto2.empresa" http://localhost
curl -H "Host: projeto3.empresa" http://localhost

# Acessar Dashboard do Traefik
# http://localhost:8080
```

---

## 📊 Stack de Monitoramento

O diretório `monitoring/` contém um `docker-compose.yml` que sobe uma stack completa de observabilidade, toda roteada pelo **Traefik** via labels Docker:

| Serviço | Descrição | Acesso |
|---------|-----------|--------|
| **cAdvisor** | Coleta métricas de uso de recursos dos containers (CPU, memória, rede, disco) | `cadvisor.empresa` |
| **Node Exporter** | Exporta métricas do host/servidor (CPU, memória, disco, rede do sistema) | `node-exporter.empresa` |
| **Grafana** | Plataforma de visualização para criar dashboards a partir das métricas coletadas. Credenciais padrão: `admin` / `admin` | `grafana.empresa` |
| **Dockhand** | Gerenciador visual de containers Docker com interface web intuitiva | `dockhand.empresa` |

### Comandos para subir (Monitoramento)

```bash
# Subir a stack de monitoramento
cd monitoring
docker-compose up -d

# Acessar os serviços (via Traefik)
# Grafana:    http://grafana.empresa
# cAdvisor:   http://cadvisor.empresa
# Node Exporter: http://node-exporter.empresa
# Dockhand:   http://dockhand.empresa
```

> **Nota sobre o Prometheus**: O serviço Prometheus foi removido da stack de monitoramento. O diretório `monitoring/prometheus/` permanece como reserva para futura reimplementação. Atualmente, o Grafana pode ser configurado manualmente com outras fontes de dados conforme necessário.

---

## 🔨 Teste de Carga — Hey

O diretório `hey/` contém scripts para teste de carga HTTP utilizando a ferramenta [hey](https://github.com/rakyll/hey) (originalmente em Go).

### Uso

```bash
# Windows
cd hey
testes.bat

# Linux/macOS (instalar hey primeiro)
go install github.com/rakyll/hey@latest
hey -n 1000 -c 50 -H "Host: projeto1.empresa" http://localhost
```

| Parâmetro | Significado |
|-----------|-------------|
| `-n` | Número total de requisições |
| `-c` | Número de workers concorrentes |
| `-H` | Header HTTP personalizado |

---

## 📚 Referências

- [NGINX Reverse Proxy Guide](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Networking](https://docs.docker.com/network/)
- [cAdvisor](https://github.com/google/cadvisor)
- [Node Exporter](https://github.com/prometheus/node_exporter)
- [Grafana](https://grafana.com/docs/)
- [Dockhand](https://github.com/fnsys/dockhand)
- [hey - HTTP Load Generator](https://github.com/rakyll/hey)
