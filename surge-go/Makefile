# Makefile for surge-go

.PHONY: build clean test run

# Build directory
BUILD_DIR := bin

# Binary name
BINARY := surge-go

# Build the binary
build:
	@echo "Building surge-go..."
	@mkdir -p $(BUILD_DIR)
	go build -o $(BUILD_DIR)/$(BINARY) cmd/surge/main.go
	@echo "✓ Binary built: $(BUILD_DIR)/$(BINARY)"

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Clean complete"

# Run tests
test:
	@echo "Running tests..."
	go test ./...

# Run the binary
run: build
	@echo "Starting surge-go..."
	@$(BUILD_DIR)/$(BINARY)

# Build for release (optimized)
release:
	@echo "Building release binary..."
	@mkdir -p $(BUILD_DIR)
	go build -ldflags="-s -w" -o $(BUILD_DIR)/$(BINARY) cmd/surge/main.go
	@echo "✓ Release binary built: $(BUILD_DIR)/$(BINARY)"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod download
	@echo "✓ Dependencies installed"
