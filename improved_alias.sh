#!/bin/bash

# Store the current directory
ORIGINAL_DIR=$(pwd)

# Change to the q-developer-cli directory
cd ~/experiments/amazon-q-developer-cli

# Run the cargo command with the original directory as the working directory
RUST_BACKTRACE=1 cargo run --bin q_cli -- chat --working-dir="$ORIGINAL_DIR"

# Return to the original directory
cd "$ORIGINAL_DIR"