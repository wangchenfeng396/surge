#!/bin/bash
set -e

echo "🛠️  Fixing TUN Mode Dependencies..."

# 1. Pin to a stable gVisor release (fixes 'stack vs bridge' package error)
echo "📦 Downgrading gVisor to release-20231023.0..."
go get gvisor.dev/gvisor@release-20231023.0
go mod tidy

# 2. Enable TUN Code (internal/tun/tun.go)
echo "🔓 Enabling internal/tun/tun.go..."
# Remove //go:build ignore
sed -i '' 's/\/\/go:build ignore//g' internal/tun/tun.go

# 3. Wiring Engine (internal/engine/engine.go)
echo "🔌 Wiring TUN into Engine..."
# Uncomment import
sed -i '' 's/\/\/ "github.com\/surge-proxy\/surge-go\/internal\/tun"/"github.com\/surge-proxy\/surge-go\/internal\/tun"/g' internal/engine/engine.go
# Uncomment field
sed -i '' 's/\/\/ TUNDevice    \*tun.Device/TUNDevice    \*tun.Device/g' internal/engine/engine.go
# Uncomment EnableTUN body (simplified approach: we will instruct user to copy code or use a patch if complex)
# Since sed on multi-line blocks is hard, we'll just print instruction for that or try a unified patch?
# Actually, the 'EnableTUN' method was replaced with an error return. We need to restore it.

cat <<EOF > internal/tun/tun.go.patch
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -467,13 +467,13 @@
 
 // EnableTUN enables TUN mode
 func (e *Engine) EnableTUN() error {
-	return fmt.Errorf("TUN mode implementation disabled due to gVisor build issues")
+	e.mu.Lock()
+	defer e.mu.Unlock()
+
+	if e.TUNDevice != nil {
+		return nil // Already enabled
+	}
+
+	// Start TUN
+	// Hardcoded IP for now or from config?
+	// Using 198.18.0.1 as gateway usually for fake IP
+	dev, err := tun.Start("utun", "198.18.0.1", e)
+	if err != nil {
+		return err
+	}
+	e.TUNDevice = dev
+	return nil
 }
EOF

echo "📝 Applying Engine Patch..."
# Try git apply, else fallback
if git apply --check internal/tun/tun.patch 2>/dev/null; then
    git apply internal/tun/tun.patch
else
    echo "⚠️  Could not automatically patch EnableTUN in engine.go. Please manually restore the implementation."
fi
rm internal/tun/tun.go.patch

echo "✅ Done! Try running 'go build ./...' now."
