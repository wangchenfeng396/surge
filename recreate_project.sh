#!/bin/bash

# Script to recreate Xcode project from scratch

echo "🔧 Recreating SurgeProxy Xcode Project..."
echo ""

cd "$(dirname "$0")/SurgeProxy"

# Remove old project
echo "1. Removing old project files..."
rm -rf SurgeProxy.xcodeproj
rm -rf SurgeProxy.xcodeproj.old
rm -rf Package.swift Sources .gitignore

echo "✅ Old project removed"
echo ""

# Create Package.swift for SPM
echo "2. Creating Swift Package..."
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SurgeProxy",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SurgeProxy", targets: ["SurgeProxy"])
    ],
    targets: [
        .executableTarget(
            name: "SurgeProxy",
            path: "SurgeProxy"
        )
    ]
)
EOF

echo "✅ Package.swift created"
echo ""

# Generate Xcode project from SPM
echo "3. Generating Xcode project from Swift Package..."
swift package generate-xcodeproj

if [ -f "SurgeProxy.xcodeproj/project.pbxproj" ]; then
    echo "✅ Xcode project generated successfully!"
    echo ""
    echo "4. Opening Xcode..."
    open SurgeProxy.xcodeproj
    echo ""
    echo "🎉 Done! Xcode should open now."
    echo ""
    echo "Next steps in Xcode:"
    echo "  1. Wait for indexing to complete"
    echo "  2. Select 'SurgeProxy' scheme"
    echo "  3. Press ⌘R to build and run"
else
    echo "❌ Failed to generate Xcode project"
    echo ""
    echo "Alternative: Create project manually in Xcode"
    echo "  1. Open Xcode"
    echo "  2. File > New > Project"
    echo "  3. macOS > App"
    echo "  4. Name: SurgeProxy"
    echo "  5. Interface: SwiftUI"
    echo "  6. Save to current directory"
    echo "  7. Add all .swift files from SurgeProxy/ folder"
fi
