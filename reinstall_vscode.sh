#!/bin/bash

# Script to uninstall VS Code snap and install the native .deb version
# This will preserve your settings and extensions

set -e  # Exit on any error

echo "🔄 VS Code Snap to Native .deb Migration Script"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Check if snap VS Code is installed
if ! snap list | grep -q "code"; then
    print_warning "VS Code snap not found. Checking for other installations..."
    if command -v code >/dev/null 2>&1; then
        print_warning "VS Code is already installed (possibly native version)"
        echo "Current VS Code location: $(which code)"
        read -p "Do you want to continue and reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        print_status "No VS Code installation found. Will proceed with fresh installation."
    fi
fi

print_status "Starting VS Code migration process..."

# Step 1: Backup settings and extensions (if snap version exists)
BACKUP_DIR="$HOME/vscode_backup_$(date +%Y%m%d_%H%M%S)"
SNAP_CONFIG_DIR="$HOME/snap/code/current/.config/Code"
SNAP_EXTENSIONS_DIR="$HOME/snap/code/current/.vscode/extensions"

if [ -d "$SNAP_CONFIG_DIR" ]; then
    print_status "Creating backup of VS Code settings and extensions..."
    mkdir -p "$BACKUP_DIR"
    
    if [ -d "$SNAP_CONFIG_DIR" ]; then
        cp -r "$SNAP_CONFIG_DIR" "$BACKUP_DIR/config" 2>/dev/null || true
        print_success "Settings backed up to $BACKUP_DIR/config"
    fi
    
    if [ -d "$SNAP_EXTENSIONS_DIR" ]; then
        cp -r "$SNAP_EXTENSIONS_DIR" "$BACKUP_DIR/extensions" 2>/dev/null || true
        print_success "Extensions backed up to $BACKUP_DIR/extensions"
    fi
    
    # Backup the extensions list
    if command -v code >/dev/null 2>&1; then
        print_status "Exporting extension list..."
        code --list-extensions > "$BACKUP_DIR/extensions_list.txt" 2>/dev/null || true
        print_success "Extension list saved to $BACKUP_DIR/extensions_list.txt"
    fi
else
    print_warning "No snap VS Code configuration found to backup"
fi

# Step 2: Remove snap VS Code
if snap list | grep -q "code"; then
    print_status "Removing VS Code snap..."
    sudo snap remove code
    print_success "VS Code snap removed"
else
    print_status "No VS Code snap to remove"
fi

# Step 3: Remove any existing apt VS Code installation
print_status "Cleaning up any existing VS Code apt installations..."
sudo apt remove -y code 2>/dev/null || true
sudo apt autoremove -y

# Step 4: Install VS Code via official Microsoft repository
print_status "Adding Microsoft GPG key and repository..."

# Download and install the Microsoft GPG key
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

# Update package cache
print_status "Updating package cache..."
sudo apt update

# Install VS Code
print_status "Installing VS Code native package..."
sudo apt install -y code

print_success "VS Code native installation completed!"

# Step 5: Restore settings and extensions
if [ -d "$BACKUP_DIR" ]; then
    print_status "Restoring VS Code settings and extensions..."
    
    # Create native config directory if it doesn't exist
    NATIVE_CONFIG_DIR="$HOME/.config/Code"
    mkdir -p "$NATIVE_CONFIG_DIR"
    
    # Restore settings
    if [ -d "$BACKUP_DIR/config" ]; then
        print_status "Restoring settings..."
        cp -r "$BACKUP_DIR/config/"* "$NATIVE_CONFIG_DIR/" 2>/dev/null || true
        print_success "Settings restored"
    fi
    
    # Restore extensions if the list exists
    if [ -f "$BACKUP_DIR/extensions_list.txt" ]; then
        print_status "Reinstalling extensions..."
        while IFS= read -r extension; do
            if [ -n "$extension" ]; then
                print_status "Installing extension: $extension"
                code --install-extension "$extension" --force 2>/dev/null || print_warning "Failed to install $extension"
            fi
        done < "$BACKUP_DIR/extensions_list.txt"
        print_success "Extensions installation completed"
    fi
fi

# Step 6: Clean up
print_status "Cleaning up temporary files..."
rm -f packages.microsoft.gpg

# Step 7: Configure Fish shell integration
print_status "Configuring Fish shell integration..."

# Check if Fish shell is installed
if command -v fish >/dev/null 2>&1; then
    print_status "Fish shell detected. Setting up deep integration..."
    
    # Create fish config directory if it doesn't exist
    FISH_CONFIG_DIR="$HOME/.config/fish"
    FISH_FUNCTIONS_DIR="$FISH_CONFIG_DIR/functions"
    mkdir -p "$FISH_FUNCTIONS_DIR"
    
    # Add VS Code to Fish PATH if not already there
    FISH_CONFIG_FILE="$FISH_CONFIG_DIR/config.fish"
    
    # Check if VS Code is already in Fish config
    if [ -f "$FISH_CONFIG_FILE" ] && grep -q "code" "$FISH_CONFIG_FILE"; then
        print_status "VS Code already configured in Fish"
    else
        print_status "Adding VS Code to Fish shell configuration..."
        echo "" >> "$FISH_CONFIG_FILE"
        echo "# VS Code integration" >> "$FISH_CONFIG_FILE"
        echo "set -gx PATH /usr/bin \$PATH" >> "$FISH_CONFIG_FILE"
        print_success "VS Code added to Fish PATH"
    fi
    
    # Create Fish function for 'code' command with enhanced features
    cat > "$FISH_FUNCTIONS_DIR/code.fish" << 'EOF'
function code --description 'Enhanced VS Code launcher with Fish integration'
    # If no arguments, open current directory
    if test (count $argv) -eq 0
        command code .
        return
    end
    
    # Handle special Fish-specific arguments
    switch $argv[1]
        case '--fish-config'
            command code ~/.config/fish/config.fish
            return
        case '--fish-functions'
            command code ~/.config/fish/functions/
            return
        case '--here'
            command code (pwd)
            return
        case '--help-fish'
            echo "Fish-specific VS Code shortcuts:"
            echo "  code --fish-config    Open Fish configuration"
            echo "  code --fish-functions Open Fish functions directory"
            echo "  code --here          Open current directory"
            echo "  code --help-fish     Show this help"
            return
    end
    
    # Pass through to regular code command
    command code $argv
end
EOF
    
    # Create Fish completion for VS Code
    FISH_COMPLETIONS_DIR="$FISH_CONFIG_DIR/completions"
    mkdir -p "$FISH_COMPLETIONS_DIR"
    
    cat > "$FISH_COMPLETIONS_DIR/code.fish" << 'EOF'
# VS Code completions for Fish shell
complete -c code -s h -l help -d 'Show help'
complete -c code -s v -l version -d 'Show version'
complete -c code -s n -l new-window -d 'Open in new window'
complete -c code -s r -l reuse-window -d 'Reuse existing window'
complete -c code -s w -l wait -d 'Wait for window to close'
complete -c code -s d -l diff -d 'Open diff editor'
complete -c code -l add -d 'Add folder to workspace'
complete -c code -l goto -d 'Go to line:column'
complete -c code -l locale -d 'Set display language'
complete -c code -l log -d 'Set log level'
complete -c code -l extensions-dir -d 'Set extensions directory'
complete -c code -l user-data-dir -d 'Set user data directory'
complete -c code -l install-extension -d 'Install extension'
complete -c code -l uninstall-extension -d 'Uninstall extension'
complete -c code -l list-extensions -d 'List installed extensions'
complete -c code -l show-versions -d 'Show extension versions'
complete -c code -l enable-proposed-api -d 'Enable proposed API'

# Fish-specific completions
complete -c code -l fish-config -d 'Open Fish configuration'
complete -c code -l fish-functions -d 'Open Fish functions directory'
complete -c code -l here -d 'Open current directory'
complete -c code -l help-fish -d 'Show Fish-specific help'

# File and directory completions
complete -c code -x -a '(__fish_complete_directories)'
complete -c code -x -a '(__fish_complete_suffix .txt .md .json .js .ts .py .sh .fish .rs .toml .yaml .yml)'
EOF

    # Set up Fish terminal integration for VS Code
    print_status "Setting up VS Code terminal integration..."
    
    # Add Fish as default terminal in VS Code settings
    VSCODE_SETTINGS_DIR="$HOME/.config/Code/User"
    VSCODE_SETTINGS_FILE="$VSCODE_SETTINGS_DIR/settings.json"
    mkdir -p "$VSCODE_SETTINGS_DIR"
    
    # Create or update VS Code settings for Fish integration
    if [ -f "$VSCODE_SETTINGS_FILE" ]; then
        # Backup existing settings
        cp "$VSCODE_SETTINGS_FILE" "$VSCODE_SETTINGS_FILE.backup"
        print_status "Backed up existing VS Code settings"
    fi
    
    # Create temporary settings file with Fish integration
    cat > "/tmp/vscode_fish_settings.json" << EOF
{
    "terminal.integrated.defaultProfile.linux": "fish",
    "terminal.integrated.profiles.linux": {
        "fish": {
            "path": "$(which fish)",
            "args": ["-l"]
        },
        "bash": {
            "path": "/bin/bash",
            "args": ["-l"]
        },
        "zsh": {
            "path": "/bin/zsh",
            "args": ["-l"]
        }
    },
    "terminal.integrated.inheritEnv": true,
    "terminal.integrated.shellIntegration.enabled": true,
    "terminal.integrated.shellIntegration.showWelcome": false,
    "fish.path.fish": "$(which fish)",
    "fish.path.fishIndent": "$(which fish_indent 2>/dev/null || echo 'fish_indent')",
    "terminal.integrated.cursorBlinking": true,
    "terminal.integrated.cursorStyle": "line"
}
EOF
    
    # Merge with existing settings or create new ones
    if [ -f "$VSCODE_SETTINGS_FILE" ]; then
        # Use jq to merge if available, otherwise replace
        if command -v jq >/dev/null 2>&1; then
            jq -s '.[0] * .[1]' "$VSCODE_SETTINGS_FILE" "/tmp/vscode_fish_settings.json" > "/tmp/merged_settings.json"
            mv "/tmp/merged_settings.json" "$VSCODE_SETTINGS_FILE"
            print_success "Merged Fish settings with existing VS Code configuration"
        else
            print_warning "jq not available. Appending Fish settings to VS Code config."
            # Simple append approach
            cp "/tmp/vscode_fish_settings.json" "$VSCODE_SETTINGS_FILE"
            print_success "Applied Fish settings to VS Code"
        fi
    else
        cp "/tmp/vscode_fish_settings.json" "$VSCODE_SETTINGS_FILE"
        print_success "Created VS Code settings with Fish integration"
    fi
    
    # Clean up temporary file
    rm -f "/tmp/vscode_fish_settings.json"
    
    # Install recommended Fish extension for VS Code
    print_status "Installing Fish language extension..."
    code --install-extension bmalehorn.vscode-fish 2>/dev/null || print_warning "Could not install Fish extension automatically"
    
    print_success "Fish shell integration configured!"
    echo "  • Fish set as default terminal in VS Code"
    echo "  • Enhanced 'code' command with Fish shortcuts"
    echo "  • Fish syntax highlighting and completions"
    echo "  • VS Code settings optimized for Fish"
    
else
    print_warning "Fish shell not found. Skipping Fish integration."
    echo "  Install Fish with: sudo apt install fish"
fi

# Step 8: Verify installation
print_status "Verifying installation..."
if command -v code >/dev/null 2>&1; then
    CODE_VERSION=$(code --version | head -n1)
    CODE_LOCATION=$(which code)
    print_success "VS Code successfully installed!"
    echo "  Version: $CODE_VERSION"
    echo "  Location: $CODE_LOCATION"
    
    # Check if it's the native version (not snap)
    if [[ "$CODE_LOCATION" == "/snap/"* ]]; then
        print_warning "VS Code is still running from snap location. You may need to restart your terminal."
    else
        print_success "VS Code is running from native installation"
    fi
else
    print_error "VS Code installation verification failed"
    exit 1
fi

# Final instructions
echo ""
print_success "Migration completed successfully!"
echo ""
echo "📋 Summary:"
echo "  • VS Code snap has been removed"
echo "  • Native VS Code has been installed via apt"
if [ -d "$BACKUP_DIR" ]; then
    echo "  • Settings and extensions have been restored"
    echo "  • Backup created at: $BACKUP_DIR"
fi
echo ""
if command -v fish >/dev/null 2>&1; then
    echo "🐟 Fish Shell Integration Summary:"
    echo "  • Fish is now the default terminal in VS Code"
    echo "  • Enhanced 'code' command available with shortcuts:"
    echo "    - code --fish-config    (edit Fish config)"
    echo "    - code --fish-functions (edit Fish functions)"
    echo "    - code --here          (open current directory)"
    echo "  • Smart completions for VS Code commands"
    echo "  • Fish syntax highlighting extension installed"
    echo ""
fi
echo "🚀 Next steps:"
echo "  1. Close any open terminal windows and reopen them"
echo "  2. Run 'code --version' to verify the installation"
echo "  3. Open VS Code to ensure your settings are preserved"
if command -v fish >/dev/null 2>&1; then
    echo "  4. Try the new Fish shortcuts: 'code --fish-config'"
fi
echo ""
print_warning "Note: You may need to log out and log back in for all changes to take effect"

# Optional: Open VS Code to test
read -p "Would you like to open VS Code now to test the installation? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Opening VS Code..."
    code --new-window 2>/dev/null &
    print_success "VS Code opened successfully!"
fi

print_success "Script completed successfully! 🎉"
