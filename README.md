# Proxy Reverso com NGINX + Docker

Projeto de estudo sobre **Proxy Reverso** utilizando NGINX como balanceador/roteador central de requisições HTTP para múltiplos serviços rodando em containers Docker.

---

## 📐 Arquitetura

```
Internet (cliente)
       │
       ▼
┌──────────────────────────────────────┐
│  nginx-proxy (porta 80 e 443)        │
│  Proxy Reverso Central               │
│  - Roteia por nome de domínio        │
│  - Resolver DNS interno do Docker    │
└──────┬──────────┬──────────┬─────────┘
       │          │          │
       ▼          ▼          ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ projeto1 │ │ projeto2 │ │ projeto3 │
│  :80     │ │  :80     │ │  :80     │
│ (interno)│ │ (interno)│ │ (interno)│
└──────────┘ └──────────┘ └──────────┘
   rede Docker interna: web-network
```

---

## 🔧 Estrutura de Diretórios

```
proxy/
├── nginx/
│   ├── nginx-proxy/          # Proxy reverso central
│   │   ├── docker-compose.yml
│   │   └── nginx.conf
│   ├── projeto1/             # Serviço 1
│   │   ├── docker-compose.yml
│   │   ├── nginx/
│   │   │   └── nginx.conf
│   │   └── html/
│   │       └── index.html
│   ├── projeto2/             # Serviço 2
│   │   ├── docker-compose.yml
│   │   ├── nginx/
│   │   │   └── nginx.conf
│   │   └── html/
│   └── projeto3/             # Serviço 3
│       ├── docker-compose.yml
│       ├── nginx/
│       │   └── nginx.conf
│       └── html/
└── traefik/                  # (diretório reservado para Traefik)
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

### Como funciona neste projeto

1. **Rede Docker compartilhada**: Todos os containers (proxy + projetos) estão na mesma rede Docker bridge chamada `web-network`. Isso permite que o proxy alcance os projetos pelo nome do container (ex: `projeto1`, `projeto2`, `projeto3`).

2. **Resolução DNS interna**: O NGINX proxy usa `resolver 127.0.0.11` (DNS interno do Docker) para resolver dinamicamente os nomes dos containers para IPs internos.

3. **Roteamento baseado em `server_name`**: O NGINX proxy inspeciona o cabeçalho `Host` da requisição HTTP e decide para qual container encaminhar:
   - `projeto1.empresa` → container `projeto1`
   - `projeto2.empresa` → container `projeto2`
   - `projeto3.empresa` → container `projeto3`

4. **Portas não expostas**: Os containers dos projetos **não expõem portas** para o host. Todo o tráfego passa obrigatoriamente pelo proxy.

### Comandos úteis

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

### Diretivas NGINX importantes usadas

| Diretiva | Função |
|----------|--------|
| `server_name` | Define qual domínio este bloco `server` atende |
| `proxy_pass` | Encaminha a requisição para o upstream especificado |
| `resolver` | Configura o servidor DNS para resolução de nomes |
| `set $upstream` | Define uma variável com o nome do container de destino |
| `listen` | Porta em que o NGINX escuta |

---

## 🔜 Próximos passos

- [ ] Configurar Traefik como alternativa ao NGINX (diretório `traefik/`)
- [ ] Adicionar suporte a HTTPS/SSL com certificados autoassinados ou Let's Encrypt
- [ ] Implementar balanceamento de carga com múltiplas réplicas
- [ ] Adicionar health checks nos backends
- [ ] Configurar cache e compressão gzip no proxy

---

## 📚 Referências

- [NGINX Reverse Proxy Guide](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [Docker Networking](https://docs.docker.com/network/)
- [NGINX server_name](https://nginx.org/en/docs/http/server_names.html)
- [NGINX proxy_pass](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass)