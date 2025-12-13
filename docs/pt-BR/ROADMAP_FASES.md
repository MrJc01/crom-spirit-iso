# 🗺️ CROM-OS SPIRIT: Roadmap de Desenvolvimento

---

## Visão Geral

O desenvolvimento do Crom-OS Spirit é dividido em 4 fases progressivas:

```
┌─────────────────────────────────────────────────────────────────┐
│                     FASES DE DESENVOLVIMENTO                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FASE 1       FASE 2       FASE 3       FASE 4                  │
│  GÊNESIS      NEXUS        PONTE        ONIPRESENÇA             │
│  ════════     ═════        ═════        ═══════════             │
│                                                                  │
│  Boot Alpine  Integrar     Montar disco Boot por rede           │
│  na RAM       Nexus HUD    Conectar VMs GPU passthrough         │
│  Teste Raylib Terminal UI  Nodus P2P    Integração IA           │
│                                                                  │
│  ▓▓▓▓▓░░░░░   ░░░░░░░░░░   ░░░░░░░░░░   ░░░░░░░░░░             │
│  Em Progresso Planejado    Planejado    Planejado               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Fase 1: GÊNESIS (Semanas 1-4)

**Objetivo:** Bootar sistema mínimo inteiramente na RAM e exibir janela Raylib.

### Entregas

| Tarefa | Descrição                           | Status |
| ------ | ----------------------------------- | ------ |
| 1.1    | Criar base Alpine Linux (diskless)  | ⬜     |
| 1.2    | Configurar ZRAM + OverlayFS         | ⬜     |
| 1.3    | Buildar kernel customizado (mínimo) | ⬜     |
| 1.4    | Criar spirit-init (binário Go)      | ⬜     |
| 1.5    | Boot até Raylib "Hello World"       | ⬜     |
| 1.6    | Criar sistema de build (Makefile)   | ⬜     |
| 1.7    | Gerar ISO bootável                  | ⬜     |

### Critérios de Sucesso

```
✓ Sistema boota de USB em < 10 segundos
✓ Janela Raylib exibe na tela
✓ Sem mounts de disco (RAM pura)
✓ Tamanho ISO < 100MB
```

---

## Fase 2: INTEGRAÇÃO NEXUS (Semanas 5-8)

**Objetivo:** Portar a interface crom-nexus para rodar como UI primária.

### Entregas

| Tarefa | Descrição                         | Status |
| ------ | --------------------------------- | ------ |
| 2.1    | Portar codebase Nexus para Spirit | ⬜     |
| 2.2    | Implementar modo Bubble           | ⬜     |
| 2.3    | Implementar modo Dashboard        | ⬜     |
| 2.4    | Implementar Terminal Grid         | ⬜     |
| 2.5    | Integrar scripting QuickJS        | ⬜     |
| 2.6    | Adicionar sistema de widgets      | ⬜     |
| 2.7    | Criar browser headless            | ⬜     |

### Critérios de Sucesso

```
✓ Nexus roda como interface primária
✓ Comandos de terminal funcionam
✓ Transições de estado suaves (< 100ms)
✓ Widgets exibem info do sistema
```

---

## Fase 3: A PONTE (Semanas 9-12)

**Objetivo:** Conectar a armazenamento externo e virtualizar Windows/Linux.

### Entregas

| Tarefa | Descrição                      | Status |
| ------ | ------------------------------ | ------ |
| 3.1    | Implementar cliente Nodus P2P  | ⬜     |
| 3.2    | Criar sistema de mount NBD     | ⬜     |
| 3.3    | Ler partições Windows          | ⬜     |
| 3.4    | Integrar KVM/QEMU              | ⬜     |
| 3.5    | Criar gerenciador de VMs       | ⬜     |
| 3.6    | Implementar comando proxy @    | ⬜     |
| 3.7    | Adicionar agente virtio-serial | ⬜     |

### Critérios de Sucesso

```
✓ Spirit descobre peers Nodus
✓ Pode ler arquivos da partição Windows
✓ VM Windows boota dentro do Spirit
✓ Comando @windows executa na VM
```

---

## Fase 4: ONIPRESENÇA (Semanas 13-16)

**Objetivo:** Boot por rede sem mídia física e GPU passthrough única.

### Entregas

| Tarefa | Descrição                      | Status |
| ------ | ------------------------------ | ------ |
| 4.1    | Implementar servidor HTTP Boot | ⬜     |
| 4.2    | Criar chainloader iPXE         | ⬜     |
| 4.3    | Adicionar descoberta PXE/DHCP  | ⬜     |
| 4.4    | Implementar GPU passthrough    | ⬜     |
| 4.5    | Criar script de passthrough    | ⬜     |
| 4.6    | Integrar Llama.cpp             | ⬜     |
| 4.7    | Construir Sentinela IA         | ⬜     |
| 4.8    | Adicionar comandos de voz      | ⬜     |

### Critérios de Sucesso

```
✓ PC boota da rede (sem USB)
✓ GPU muda para VM Windows
✓ GPU retorna ao Spirit sem reboot
✓ IA responde a linguagem natural
```

---

## Resumo de Marcos

| Fase        | Duração   | Entrega Chave           |
| ----------- | --------- | ----------------------- |
| Gênesis     | 4 semanas | ISO bootável com Raylib |
| Nexus       | 4 semanas | Interface HUD completa  |
| Ponte       | 4 semanas | Integração VM Windows   |
| Onipresença | 4 semanas | Boot por rede + IA      |

**Tempo Total Estimado:** 16 semanas (4 meses)

---

## Fases Futuras (Pós-1.0)

- **Fase 5: Integração Cloud** - Backup cloud gerenciado
- **Fase 6: Companheiro Mobile** - App Android Nodus
- **Fase 7: Suporte ARM** - Raspberry Pi / Mac M-series
- **Fase 8: Secure Boot** - Suporte a kernel assinado

---

## Começando

```bash
# Clonar repositório
git clone https://github.com/user/crom-spirit

# Build Fase 1
cd crom-spirit
make genesis

# Testar em VM
make test-qemu

# Criar ISO
make iso
```

---

_Versão do Documento: 1.0_  
_Projeto: Crom-OS Spirit (Project Aether)_  
_Classificação: Roadmap de Desenvolvimento_
