# MASTER PLAN: Crom-OS Spirit Execution Guide

Este documento define o roteiro técnico granular para a construção do **Crom-OS Spirit**. O desenvolvimento é dividido em "Sprints" focadas em componentes isolados para garantir estabilidade incremental.

**Objetivo Final:** Versão 1.0 "Gold Master" (Boot instantâneo, UI 3D, Nodus P2P ativo, Virtualização GPU Passthrough).

---

## 🏁 Sprint 0: Foundation (Kernel & Boot) ✅

**Foco:** Criar o ambiente de execução mínimo (Kernel + RootFS + Init).

- [x] **Configuração do Toolchain**
  - [x] Instalar Go 1.22+ e compiladores C (GCC/Musl).
  - [x] Configurar flags de build para estático (`CGO_ENABLED=1`).
- [x] **Sistema Base (Alpine Linux)**
  - [x] Gerar RootFS Alpine mínimo (sem X11, sem Systemd).
  - [x] Criar script de injeção de dependências (`apk add ...`).
- [x] **Kernel Linux Customizado**
  - [x] Compilar Kernel com suporte a `vfio-pci`, `kvm`, `fuse` e `drm`.
  - [x] Habilitar drivers de input (`evdev`) e framebuffer (`fbdev`).
- [x] **Bootloader & Init**
  - [x] Configurar Syslinux/GRUB para boot USB.
  - [x] Criar `init` em Go (substituto do `/sbin/init` padrão).
  - [x] Teste: Bootar no QEMU e imprimir "Hello Spirit" no TTY.

---

## 🎨 Sprint 1: Visual (Nexus UI) ✅

**Foco:** Subir a interface gráfica sem servidor de display (X11/Wayland).

- [x] **Framebufer & Raylib**
  - [x] Inicializar Raylib em modo "DRM/KMS" ou "Framebuffer puro".
  - [x] Desenhar primitivas básicas (Círculo, Retângulo) na tela preta.
- [x] **Sistema de Input**
  - [x] Ler `/dev/input/event*` diretamente via Go.
  - [x] Mapear coordenadas do mouse para o sistema de coordenadas da Raylib.
  - [x] Implementar cursor de mouse por software (desenho na tela).
- [x] **Componentes UI Básicos**
  - [x] Criar o "Botão Flutuante" (Crom-Spirit Orb).
  - [x] Implementar menu radial ao clicar no botão.
  - [x] Teste: Clicar no botão e ver animação de expansão.

---

## 🌐 Sprint 2: Nodus Core (Rede & Storage) ✅

**Foco:** Implementar o sistema de arquivos distribuído e cache em RAM.

- [x] **Nodus Daemon**
  - [x] Inicializar node libp2p (Discovery, DHT).
  - [x] Conectar a peers locais na rede LAN.
- [x] **FUSE Filesystem**
  - [x] Criar montagem FUSE em `/mnt/nodus`.
  - [x] Interceptar chamadas `read()` e `write()`.
- [x] **Estratégia de Cache (RAM)**
  - [x] Implementar LRU Cache para blocos de dados quentes.
  - [x] Teste "Blackout": Desconectar rede e ler arquivo do cache.
- [x] **Persistência Volátil**
  - [x] Garantir que nada seja escrito no disco físico (Pendrive Read-Only).

---

## 🖥️ Sprint 3: Hypervisor (Virtualização) ✅

**Foco:** Orquestrar a VM Windows e o Passthrough de GPU.

- [x] **Libvirt Bindings**
  - [x] Conectar ao socket do QEMU/KVM via Go.
  - [x] Definir XML da VM Windows dinamicamente.
- [x] **GPU Detach (O Grande Truque)**
  - [x] Script para desvincular GPU do host (`vfio-pci bind`).
  - [x] Script para devolver GPU ao host (unbind e re-bind driver nvidia/amd).
- [x] **Nexus Integration**
  - [x] Comando `@windows` no terminal do Nexus dispara o boot da VM.
  - [x] Monitorar estado da VM (Running, Paused, Off) no HUD.
- [x] **Hot-Swap Test**
  - [x] Alternar entre Spirit (Linux) e Windows (VM) sem reiniciar a máquina.
