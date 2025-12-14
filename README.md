# 🔮 Crom-OS Spirit

**Sistema operacional 100% em RAM com storage P2P e GPU passthrough.**

---

## 🚀 Build no Codespaces

```bash
# 1. Abrir terminal no Codespaces

# 2. Build da ISO
docker build --target iso-builder -t spirit . --no-cache

# 3. Extrair ISO
mkdir -p output
docker run --rm spirit cat /spirit-v1.0.iso > output/spirit-v1.0.iso

# 4. Baixar: Clique direito em output/spirit-v1.0.iso → Download
```

---

## 🧪 Testar no Linux

```bash
# Instalar QEMU
sudo apt update && sudo apt install -y qemu-system-x86

# Rodar a ISO
qemu-system-x86_64 -cdrom spirit-v1.0.iso -m 1024
```

---

## 🎮 Comandos no Spirit

| Comando      | Função         |
| ------------ | -------------- |
| `spirit`     | Menu principal |
| `nodus`      | Storage P2P    |
| `hypervisor` | Gerenciar VMs  |
| `poweroff`   | Desligar       |
| `reboot`     | Reiniciar      |
| `shelp`      | Ajuda          |

---

## 📚 Docs

- [Manifesto](docs/pt-BR/00-MANIFESTO_CENTRAL.md)
- [Boot](docs/pt-BR/01-KERNEL_E_BOOT.md)
- [Nexus UI](docs/pt-BR/02-SISTEMA_VISUAL_NEXUS.md)
- [Nodus P2P](docs/pt-BR/03-PROTOCOLO_ARMAZENAMENTO_NODUS.md)
- [VMs](docs/pt-BR/04-GERENCIADOR_VIRTUALIZACAO.md)
- [IA](docs/pt-BR/05-IA_SYSOPS.md)

---

**MIT License**
