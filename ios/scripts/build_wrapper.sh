#!/bin/bash

# Flutter build wrapper to fix xcrun version parsing issue

# Create a temporary directory for our custom xcrun
TEMP_BIN_DIR=$(mktemp -d)

# Create custom xcrun script
cat > "$TEMP_BIN_DIR/xcrun" << 'EOF'
#!/bin/bash
if [ "$1" == "version" ]; then
    echo "xcrun version 70."
    echo "Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)"
else
    exec /usr/bin/xcrun "$@"
fi
EOF

# Make it executable
chmod +x "$TEMP_BIN_DIR/xcrun"

# Add to PATH
export PATH="$TEMP_BIN_DIR:$PATH"

# Set additional environment variables for Swift detection
export SWIFT_VERSION=5.0
export SWIFT_EXEC=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
export TOOLCHAIN_DIR=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Run the original Flutter build script
exec /bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" "$@" 