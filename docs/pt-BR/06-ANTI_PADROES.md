# 🚫 CROM-OS SPIRIT: Anti-Padrões e Restrições

---

## 1. A Regra de Ouro

> **"Tudo deve ser um binário estático. O sistema deve sobreviver se você deletar todo arquivo .so."**

O Spirit deve rodar com **zero dependências de runtime** em bibliotecas compartilhadas.

---

## 2. Tecnologias Proibidas

| Tecnologia           | Razão                        | Alternativa          |
| -------------------- | ---------------------------- | -------------------- |
| **Electron**         | 300MB+ RAM, bloat Chromium   | Go + Raylib          |
| **Node.js** (core)   | Runtime dinâmico, pesado     | Go (estático)        |
| **SystemD**          | Complexo, depende de disco   | OpenRC / init custom |
| **Python** (runtime) | Interpretador, startup lento | Go (compilado)       |
| **glibc**            | Grande, complexa             | musl libc            |
| **X11/Wayland**      | Servidores display pesados   | DRM/KMS direto       |
| **Docker** (core)    | Requer daemon                | Podman ou containerd |
| **WebViews**         | Overhead Chrome/Webkit       | UI nativa Raylib     |

---

## 3. Padrões Proibidos

### ❌ Assumir Disco

```go
// ERRADO: Assume que disco existe
config, _ := os.ReadFile("/etc/spirit/config.yaml")

// CORRETO: Fallback para rede/embutido
config, err := loadConfig()
if err != nil {
    config = embeddedDefaultConfig
}
```

### ❌ Caminhos Fixos

```go
// ERRADO: Caminho hardcoded
db := openDB("/var/lib/spirit/data.db")

// CORRETO: Memória primeiro, persistência opcional
db := openDB(":memory:")
if hasPersistentStorage() {
    db.Sync(getPersistentPath())
}
```

### ❌ Exigir Internet

```go
// ERRADO: Falha sem internet
user := fetchFromCloud()

// CORRETO: Offline-first
user, err := localCache.Get("user")
if err != nil && hasNetwork() {
    user = fetchFromCloud()
    localCache.Set("user", user)
}
```

---

## 4. Restrições Core

### C1: Tamanho do Binário

- Nexus HUD: < 15MB
- Spirit-init: < 5MB
- Sistema total: < 100MB

### C2: Tempo de Boot

- Kernel até Nexus: < 3 segundos
- Cold boot até usável: < 10 segundos

### C3: Uso de RAM

- Sistema ocioso: < 100MB
- Com uma VM pausada: < 200MB

### C4: Uso de Disco

- Imagem do sistema: < 500MB
- Mínimo para boot: 0 bytes (boot por rede)

---

## 5. Regras de Dependência

### Dependências Permitidas

```
✅ musl libc (link estático)
✅ OpenGL/Vulkan (driver)
✅ Kernel Linux (obrigatório)
✅ Go stdlib (compilado junto)
✅ Raylib (link estático)
```

### Dependências Proibidas

```
❌ glibc
❌ libstdc++
❌ Runtime Python
❌ Runtime Node.js
❌ Java/JVM
❌ Runtime .NET
❌ Electron/Chromium
```

---

## 6. Requisitos de Backup

### Sync Automático

```yaml
# Política de backup
backup:
  interval: 5m # Sync a cada 5 minutos
  targets:
    - nodus # Rede P2P (primário)
    - cloud # Armazenamento nuvem (secundário)
  encrypted: true # Sempre criptografado

  include:
    - /home # Dados do usuário
    - /etc/spirit # Configuração

  exclude:
    - /tmp
    - /var/cache
    - "*.log"
```

### Prevenção de Perda de Dados

```
Ao modificar arquivo:
  → Hash do bloco
  → Criptografar bloco
  → Enfileirar para sync Nodus
  → Confirmar replicação (3 peers)
  → Marcar como seguro

Perda de energia antes do sync:
  → No próximo boot, recuperar do Nodus
  → Máxima perda de dados: 5 minutos de trabalho
```

---

## 7. Modo Sobrevivência Offline

O sistema **deve funcionar** sem qualquer rede:

```
┌─────────────────────────────────────────────────────────────┐
│               MODO SOBREVIVÊNCIA OFFLINE                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Rede disponível:                                           │
│  ✓ Armazenamento P2P Nodus completo                         │
│  ✓ Sync com nuvem                                           │
│  ✓ Boot remoto                                              │
│  ✓ Recursos IA na nuvem                                     │
│                                                              │
│  Rede indisponível:                                         │
│  ✓ Boot de cache local/USB                                  │
│  ✓ Acesso a arquivos em cache                               │
│  ✓ IA local (Llama.cpp)                                     │
│  ✓ VMs continuam rodando                                    │
│  ✓ Mudanças enfileiradas para sync posterior                │
│  ✗ Sem novos arquivos remotos                               │
│                                                              │
│  Degradação graciosa, nunca crash                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Restrições de Segurança

| Regra                       | Justificativa           |
| --------------------------- | ----------------------- |
| Sem telemetria              | Privacidade por padrão  |
| Sem chaves cloud no binário | Segredos do usuário     |
| Apenas criptografia E2E     | Design zero-knowledge   |
| Verificar todos blocos      | Sem confiança na rede   |
| Assinar todos manifestos    | Garantia de integridade |

---

## 9. Checklist para Contribuidores

Antes de submeter código:

- [ ] Compila estaticamente? (`go build -ldflags '-extldflags "-static"'`)
- [ ] Roda sem disco? (Testar com root tmpfs)
- [ ] Funciona offline? (Testar sem rede)
- [ ] Uso de RAM aceitável? (Profile com `pprof`)
- [ ] Tamanho do binário < limite?
- [ ] Sem dependências proibidas?
- [ ] Dados backupeados antes de escrever?

---

_Versão do Documento: 1.0_  
_Projeto: Crom-OS Spirit (Project Aether)_  
_Classificação: Restrições de Desenvolvimento_
