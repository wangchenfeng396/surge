#!/bin/bash

# Build Go backend & Copy to App Bundle & Code Sign
echo "🔨 Building Go backend..."

# 1. Setup PATH
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/local/go/bin:$HOME/go/bin:$PATH"

# 2. Check Go
if ! command -v go &> /dev/null; then
    echo "⚠️  Go not found. Skipping backend build."
    exit 0
fi

# 3. Navigate to Go project
cd "${PROJECT_DIR}/../surge-go" 2>/dev/null || {
    echo "⚠️  surge-go directory not found. Skipping."
    exit 0
}

# 4. Resolve Dependencies (Fix for "missing endpoint registry")
echo "   Resolving dependencies..."
go mod tidy

# 5. Define Output Paths
TARGET_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources"
mkdir -p "$TARGET_DIR"
TARGET_BIN="${TARGET_DIR}/surge-go"

# 6. Build
# -w -s flags strip debug info to reduce size
go build -ldflags="-s -w" -o "$TARGET_BIN" cmd/surge/main.go 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Go backend built and installed to App Bundle"
    
    # 7. Set Permissions & Sign
    chmod +x "$TARGET_BIN"
    
    # Force ad-hoc signature (Critical for Apple Silicon)
    codesign --remove-signature "$TARGET_BIN" 2>/dev/null
    codesign -s - --force "$TARGET_BIN"
    echo "🔏 Ad-hoc signature applied"
    
    # Backup for reference
    mkdir -p bin
    cp "$TARGET_BIN" bin/surge-go
    
    ls -l "$TARGET_BIN"
else
    echo "⚠️  Go build failed!"
    exit 1
fi

exit 0
