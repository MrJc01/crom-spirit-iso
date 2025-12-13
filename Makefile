.PHONY: all clean init nexus nodus hypervisor iso docker-build

BUILD_DIR = build
ISO_NAME = spirit-v1.0.iso

# Default target - build all binaries
all: init nexus nodus hypervisor

# Build the Go Init process (Linux only)
init:
	@echo "🚀 Building Spirit Init..."
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o $(BUILD_DIR)/init ./cmd/init

# Build the Nexus UI
nexus:
	@echo "🎨 Building Nexus UI..."
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o $(BUILD_DIR)/nexus ./cmd/nexus

# Build the Nodus P2P Daemon
nodus:
	@echo "🌐 Building Nodus Daemon..."
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o $(BUILD_DIR)/nodus ./cmd/nodus

# Build the Hypervisor Manager
hypervisor:
	@echo "🖥️  Building Hypervisor..."
	@mkdir -p $(BUILD_DIR)
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o $(BUILD_DIR)/hypervisor ./cmd/hypervisor

# Build the ISO (requires Linux environment)
iso: all
	@echo "💿 Building ISO..."
	@bash scripts/build_iso.sh $(ISO_NAME)

# Build using Docker (works on any OS)
docker-build:
	@echo "🐳 Building with Docker..."
	docker build -t spirit-builder .
	docker run --rm -v $(PWD)/output:/output spirit-builder cp /spirit-v1.0.iso /output/

# Development build (faster, no optimizations)
dev:
	@echo "🔧 Development build..."
	@mkdir -p $(BUILD_DIR)
	go build -o $(BUILD_DIR)/init ./cmd/init
	go build -o $(BUILD_DIR)/nexus ./cmd/nexus
	go build -o $(BUILD_DIR)/nodus ./cmd/nodus
	go build -o $(BUILD_DIR)/hypervisor ./cmd/hypervisor

# Run tests
test:
	go test -v ./...

# Format code
fmt:
	go fmt ./...

# Lint code
lint:
	golangci-lint run

# Clean all build artifacts
clean:
	@echo "🧹 Cleaning..."
	@rm -rf $(BUILD_DIR) output iso_staging
	@rm -f *.iso

# Help
help:
	@echo "Crom-OS Spirit Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all          Build all binaries (default)"
	@echo "  iso          Build bootable ISO (Linux only)"
	@echo "  docker-build Build ISO using Docker (any OS)"
	@echo "  dev          Quick development build"
	@echo "  test         Run tests"
	@echo "  clean        Remove build artifacts"
	@echo "  help         Show this message"
