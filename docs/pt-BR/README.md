# 🌌 Documentação Crom-OS Spirit (Português)

> _"O corpo é temporário. O Spirit é eterno."_

Bem-vindo à documentação técnica do **Crom-OS Spirit (Project Aether)** — um meta-sistema operacional revolucionário que roda inteiramente na RAM, gerencia hardware e VMs, e conecta-se a uma rede de armazenamento distribuído.

---

## 📚 Índice de Documentação

| #   | Documento                                                              | Descrição                                    |
| --- | ---------------------------------------------------------------------- | -------------------------------------------- |
| 0   | [Manifesto Central](./00-MANIFESTO_CENTRAL.md)                         | Filosofia, três pilares, modos de existência |
| 1   | [Kernel e Boot](./01-KERNEL_E_BOOT.md)                                 | Cascata de boot, tiers de memória, build     |
| 2   | [Sistema Visual Nexus](./02-SISTEMA_VISUAL_NEXUS.md)                   | Interface HUD, estados, widgets, scripting   |
| 3   | [Protocolo Armazenamento Nodus](./03-PROTOCOLO_ARMAZENAMENTO_NODUS.md) | Armazenamento P2P, streaming, criptografia   |
| 4   | [Gerenciador Virtualização](./04-GERENCIADOR_VIRTUALIZACAO.md)         | KVM/QEMU, GPU passthrough, comandos VM       |
| 5   | [IA SysOps](./05-IA_SYSOPS.md)                                         | Integração Llama.cpp, sentinela, NLP         |
| 6   | [Anti-Padrões](./06-ANTI_PADROES.md)                                   | Restrições, tecnologias proibidas            |
| -   | [Roadmap](./ROADMAP_FASES.md)                                          | Plano de desenvolvimento em 4 fases          |

---

## 🔑 Conceitos Chave

### Três Pilares

- **Imortalidade** — Sistema somente-leitura na RAM, incorruptível
- **Onipresença** — Boot em qualquer lugar, dados via rede
- **Controle** — Gerencia hardware e orquestra VMs

### Três Modos

- **Parasita** — Vive dentro do Windows/Linux como pasta
- **Semente** — Boot USB mínimo, streaming do resto pela rede
- **Nômade** — Boot por rede puro, zero mídia física

### Stack de Tecnologia

- **Kernel:** Alpine Linux (musl, OpenRC)
- **Interface:** Go + Raylib (Nexus HUD)
- **Armazenamento:** Protocolo P2P Crom-Nodus
- **Virtualização:** KVM/QEMU com VFIO
- **IA:** Llama.cpp (LLM local)

---

## 🚀 Início Rápido

```bash
# Clonar e buildar
git clone https://github.com/user/crom-spirit
cd crom-spirit
make genesis

# Testar no QEMU
make test-qemu

# Criar ISO bootável
make iso
```

---

## 📋 Status do Projeto

| Fase | Nome             | Status          |
| ---- | ---------------- | --------------- |
| 1    | Gênesis          | 🔄 Em Progresso |
| 2    | Integração Nexus | ⬜ Planejado    |
| 3    | A Ponte          | ⬜ Planejado    |
| 4    | Onipresença      | ⬜ Planejado    |

---

## 🤝 Contribuindo

Veja [06-ANTI_PADROES.md](./06-ANTI_PADROES.md) para restrições de desenvolvimento antes de contribuir.

---

_Crom-OS Spirit — Project Aether_
