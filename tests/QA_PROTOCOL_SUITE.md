# QA PROTOCOL SUITE: Crom-OS Spirit Stress Testing

Este documento define a bateria de testes de "Engenharia do Caos" para garantir que o sistema sobreviva a falhas catastróficas. **Nenhum release é aprovado sem passar por 100% destes testes.**

---

## 🌪️ A. Testes de Sobrevivência (Chaos Engineering)

**Objetivo:** Simular o apocalipse do hardware e da rede.

### 1. O Teste "Arrancar o Disco" (Hot-Unplug)

- [ ] **Procedimento:** Com o sistema rodando, remover fisicamente o Pendrive USB.
- [ ] **Expectativa:** O sistema deve continuar operando normalmente (pois está 100% na RAM). Nenhum kernel panic deve ocorrer.
- [ ] **Validação:** Abrir 5 menus e executar um comando no terminal após a remoção.

### 2. O Teste "Blackout de Rede"

- [ ] **Procedimento:** Cortar a conexão (desligar roteador ou desconectar cabo) enquanto um vídeo está sendo transmitido via Nodus.
- [ ] **Expectativa:** O vídeo deve continuar tocando até o fim do buffer (Cache RAM). A UI deve mostrar ícone de "Offline" mas não travar.
- [ ] **Validação:** Reconectar a rede e verificar se o stream retoma sem intervenção do usuário.

### 3. O Teste "Memória Cheia" (OOM Killer)

- [ ] **Procedimento:** Executar script que aloca RAM até atingir 99% da capacidade.
- [ ] **Expectativa:** O Kernel deve invocar o OOM Killer e sacrificar processos não-essenciais (ex: cache do web browser) para salvar o Kernel e o Nexus UI.
- [ ] **Validação:** O Spirit-Manager nunca deve ser morto.

---

## 🛡️ B. Testes de Virtualização e Hardware

**Objetivo:** Garantir que o Passthrough de GPU não quebre o host.

### 4. Hot-Swap da GPU (Stress Loop)

- [ ] **Procedimento:** Script automático que alterna entre Spirit (Host) e Windows (VM) a cada 10 segundos.
- [ ] **Repetições:** 500 ciclos.
- [ ] **Expectativa:** Sem vazamento de memória VRAM. A tela não deve apresentar glitch ou artefatos.

### 5. Periféricos Fantasmas (USB Flood)

- [ ] **Procedimento:** Conectar e desconectar teclados, mouses e pendrives repetidamente (usar hub USB com switches ou emulação QEMU).
- [ ] **Expectativa:** O sistema de input deve reconhecer os novos dispositivos instantaneamente. A VM deve "pegar" o dispositivo se configurada para tal.

### 6. Boot em Hardware Hostil

- [ ] **Teste Legacy:** Bootar em um PC de 2010 (BIOS Legacy, MBR).
- [ ] **Teste UEFI Secure Boot:** Tentar bootar com Secure Boot ativado (deve falhar graciosamente ou pedir chave, se assinado).

---

## 👁️ C. Testes de Interface (Nexus UI)

**Objetivo:** Garantir que a UI proprietária seja sólida.

### 7. Fuzzing de Comandos

- [ ] **Procedimento:** Injetar 10.000 strings aleatórias e caracteres inválidos (`\x00`, Emojis, Buffer Overflow strings) no prompt do Nexus.
- [ ] **Expectativa:** O prompt deve limpar a entrada inválida. O processo Nexus nunca deve crashar (Segmentation Fault).

### 8. Resolução Dinâmica

- [ ] **Procedimento:** Mudar o cabo HDMI de um Monitor 4K para uma TV 720p com o sistema ligado.
- [ ] **Expectativa:** O Framebuffer deve redetectar a resolução via eventos DRM/KMS. O HUD deve redimensionar os elementos proporcionalmente.

---

## 🔒 D. Testes de Segurança (Red Team)

**Objetivo:** Impedir vazamento de dados entre os mundos.

### 9. Teste de Isolamento (VM Escape)

- [ ] **Procedimento:** Tentar ler endereços de memória do Host Spirit a partir de um compilador C rodando dentro da VM Windows.
- [ ] **Expectativa:** Violação de segmento ou acesso negado pelo IOMMU.

### 10. Spoofing de Nodus

- [ ] **Procedimento:** Criar um peer malicioso na rede que anuncia um arquivo com hash válido mas conteúdo corrompido.
- [ ] **Expectativa:** A verificação de integridade (Merkle Tree/Hash Check) deve rejeitar o bloco e banir o peer malicioso.
