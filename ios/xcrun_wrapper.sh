#!/bin/bash

# Wrapper script to fix Swift version parsing issue
# This script provides the expected format for Flutter builds

if [ "$1" == "version" ]; then
    # Get the actual xcrun version
    XCRUN_VERSION=$(xcrun --version 2>/dev/null | head -1)
    
    # Get Swift version information
    SWIFT_VERSION=$(xcrun swift --version 2>/dev/null | head -1)
    
    # Output in the expected format
    echo "$XCRUN_VERSION"
    echo "$SWIFT_VERSION"
else
    # For all other commands, pass through to real xcrun
    exec xcrun "$@"
fi 