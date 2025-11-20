#!/bin/bash
# Server Shell Setup Script
# Installs pfetch motd, zsh, and starship prompt
# Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/setup_server_shell.sh | bash

set -e

echo "============================================================"
echo "Setting up server shell configuration"
echo "============================================================"

# 1. Install pfetch
echo ""
echo "[1/6] Installing pfetch..."
if [ ! -f "/usr/local/bin/pfetch" ]; then
    curl -sSL https://github.com/dylanaraps/pfetch/raw/master/pfetch -o /tmp/pfetch
    sudo mv /tmp/pfetch /usr/local/bin/pfetch
    sudo chmod +x /usr/local/bin/pfetch
    echo "✓ pfetch installed"
else
    echo "✓ pfetch already installed"
fi

# 2. Create custom motd script
echo ""
echo "[2/6] Creating custom MOTD script..."
sudo tee /tmp/01-custom-motd > /dev/null << 'MOTD_EOF'
#!/bin/bash
# Custom colorful server overview using pfetch

# Run pfetch for system info
if command -v pfetch >/dev/null 2>&1; then
    pfetch
else
    # Fallback if pfetch not available
    echo ""
    echo "════════════════════════════════════════"
    echo "  Server: $(hostname)"
    echo "════════════════════════════════════════"
fi

echo ""
MOTD_EOF

sudo mv /tmp/01-custom-motd /etc/update-motd.d/01-custom
sudo chmod +x /etc/update-motd.d/01-custom
echo "✓ MOTD script created"

# 3. Disable verbose motd scripts
echo ""
echo "[3/6] Disabling verbose MOTD scripts..."
for script in 00-header 10-help-text 50-landscape-sysinfo 50-motd-news 90-updates-available 91-contract-ua-esm-status; do
    if [ -f "/etc/update-motd.d/$script" ]; then
        sudo chmod -x "/etc/update-motd.d/$script" 2>/dev/null || true
    fi
done
echo "✓ Verbose scripts disabled"

# 4. Install zsh
echo ""
echo "[4/6] Installing zsh..."
if ! command -v zsh &> /dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y zsh curl
    echo "✓ zsh installed"
else
    echo "✓ zsh already installed"
fi

# 5. Install starship
echo ""
echo "[5/6] Installing starship..."
if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes
    echo "✓ starship installed"
else
    echo "✓ starship already installed"
fi

# 6. Setup starship config
echo ""
echo "[6/6] Setting up starship configuration..."
mkdir -p ~/.config

cat > ~/.config/starship.toml << 'STARSHIP_EOF'
add_newline = false
format = "[$hostname](bold blue) in $directory$git_branch$git_status\n$character"

[hostname]
ssh_only = false
format = "[$hostname](bold blue) "

[character]
success_symbol = "[❯](bold green) "
error_symbol = "[❯](bold red) "

[directory]
style = "bold bright-green"
truncation_length = 3
truncate_to_repo = false

[git_branch]
style = "bold yellow"
symbol = " "

[git_status]
style = "bold red"
STARSHIP_EOF

echo "✓ Starship config created"

# Add starship init to zshrc
if [ -f ~/.zshrc ]; then
    if ! grep -q "starship init zsh" ~/.zshrc; then
        echo '' >> ~/.zshrc
        echo 'eval "$(starship init zsh)"' >> ~/.zshrc
        echo "✓ Starship init added to .zshrc"
    else
        echo "✓ Starship init already in .zshrc"
    fi
else
    echo 'eval "$(starship init zsh)"' > ~/.zshrc
    echo "✓ Created .zshrc with starship init"
fi

# Completion message
echo ""
echo "============================================================"
echo "Setup complete!"
echo "============================================================"
echo ""
echo "To set zsh as your default shell, run:"
echo "  sudo chsh -s \$(which zsh) \$USER"
echo ""
echo "Or for root:"
echo "  sudo chsh -s \$(which zsh) root"
echo ""
echo "Test the MOTD with:"
echo "  run-parts /etc/update-motd.d/"
echo ""
echo "Test the prompt with:"
echo "  zsh -c 'starship prompt'"

