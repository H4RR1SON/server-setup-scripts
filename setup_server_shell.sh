#!/bin/bash
set -e

# ============================================================================
# Server Setup Script
# ============================================================================

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✔  $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠  $1${NC}"
}

log_step() {
    echo -e "\n${CYAN}==> $1${NC}"
}

banner() {
    echo -e "${CYAN}"
    echo "   _____ZSH_SERVER_SETUP_____"
    echo "   Automated Environment Config"
    echo -e "${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ] && [ -z "$SUDO_USER" ]; then
        log_warn "This script might need sudo privileges for some parts."
    fi
}

# ============================================================================
# Main Logic
# ============================================================================

banner
check_root

# 1. Update System
log_step "Updating system packages..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update -qq && sudo apt-get upgrade -y -qq
    log_success "System updated"
else
    log_warn "Not a Debian/Ubuntu system? Skipping apt update."
fi

# 2. Install Basic Dev Tools
log_step "Installing basic development tools..."
PACKAGES=(curl wget git unzip zip software-properties-common build-essential zsh)
if command -v apt-get &> /dev/null; then
    sudo apt-get install -y "${PACKAGES[@]}"
    log_success "Basic tools installed"
fi

# 3. Install Python & uv
log_step "Installing Python & uv..."
if ! command -v python3 &> /dev/null; then
    sudo apt-get install -y python3 python3-pip python3-venv
fi
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    log_success "uv installed"
else
    log_success "uv already installed"
fi

# 4. Install Docker
log_step "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    log_success "Docker installed"
else
    log_success "Docker already installed"
fi

# 5. Install Node.js & NPM
log_step "Installing Node.js & NPM..."
if ! command -v npm &> /dev/null; then
    # Installing LTS version setup
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    log_success "Node.js & NPM installed"
else
    log_success "Node.js & NPM already installed"
fi

# 6. Install AI Tools (Claude, Gemini, Codex, Cursor)
log_step "Installing AI Tools..."

# Claude
if ! command -v claude &> /dev/null; then
    log_info "Installing Claude..."
    curl -fsSL https://claude.ai/install.sh | bash || log_warn "Failed to install Claude via curl, continuing..."
else
    log_success "Claude already installed"
fi

# Gemini CLI
if ! npm list -g @google/gemini-cli &> /dev/null; then
    log_info "Installing @google/gemini-cli..."
    sudo npm install -g @google/gemini-cli
else
    log_success "@google/gemini-cli already installed"
fi

# OpenAI Codex
if ! npm list -g @openai/codex &> /dev/null; then
    log_info "Installing @openai/codex..."
    sudo npm install -g @openai/codex || log_warn "Could not install @openai/codex (package might not exist publicly), continuing..."
else
    log_success "@openai/codex already installed"
fi

# Cursor
log_info "Installing Cursor..."
curl -fsSL https://cursor.com/install | bash || log_warn "Failed to install Cursor via curl, continuing..."


# 7. Setup SSH Configuration
log_step "Configuring SSH..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# SSH Config
log_info "Writing ~/.ssh/config..."
cat > ~/.ssh/config << 'EOF'
# ~/.ssh/config

# Global settings for all hosts
Host *
  AddKeysToAgent yes
  UseKeychain yes
  Compression yes
  ServerAliveInterval 60
  ServerAliveCountMax 3
  TCPKeepAlive yes
  IdentitiesOnly yes

# ============================================================================
# Application Servers
# ============================================================================

# app-gw-01 - Application Gateway Server
# Location: Nuremberg | Region: eu-central
# Specs: CX23 | x86 | 40 GB
Host app-gw-01
  HostName 91.98.235.207
  User root
  IdentityFile ~/.ssh/id_ed25519
  Port 22
  ForwardAgent no
  # Private IP: 10.0.0.4 (use if connecting from within the same network)

# ============================================================================
# Database Servers
# ============================================================================

# db-clickhouse-01 - ClickHouse Database Server
# Location: Nuremberg | Region: eu-central
# Specs: CX43 | x86 | 160 GB + 250 GB
Host db-clickhouse-01
  HostName 91.99.60.254
  User root
  IdentityFile ~/.ssh/id_ed25519
  Port 22
  ForwardAgent no
  # Private IP: 10.0.0.3 (use if connecting from within the same network)

# db-core-01 - Core Database Server
# Location: Falkenstein | Region: eu-central
# Specs: CX53 | x86 | 320 GB
Host db-core-01
  HostName 46.224.69.195
  User root
  IdentityFile ~/.ssh/id_ed25519
  Port 22
  ForwardAgent no
  # Private IP: 10.0.0.2 (use if connecting from within the same network)

# ============================================================================
# Short Aliases (for convenience)
# ============================================================================

Host gw
  HostName 91.98.235.207
  User root
  IdentityFile ~/.ssh/id_ed25519

Host clickhouse
  HostName 91.99.60.254
  User root
  IdentityFile ~/.ssh/id_ed25519

Host db-core
  HostName 46.224.69.195
  User root
  IdentityFile ~/.ssh/id_ed25519
EOF
chmod 600 ~/.ssh/config
log_success "SSH Config updated"

# SSH Private Key
log_info "Setting up SSH Private Key..."
echo -e "${YELLOW}Please paste your SSH private key (Ed25519) content below.${NC}"
echo -e "${YELLOW}Press Ctrl+D (on a new line) when finished:${NC}"

# Create a temporary file to store the key
TMP_KEY_FILE=$(mktemp)
cat > "$TMP_KEY_FILE"

# Check if the key is not empty
if [ -s "$TMP_KEY_FILE" ]; then
    cat "$TMP_KEY_FILE" > ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519
    log_success "SSH Private Key saved to ~/.ssh/id_ed25519"
else
    log_warn "No key provided. Skipping SSH key setup."
fi
rm -f "$TMP_KEY_FILE"

# 8. Shell Customization (pfetch, starship)
log_step "Customizing Shell (pfetch & starship)..."

# pfetch
if [ ! -f "/usr/local/bin/pfetch" ]; then
    sudo curl -sSL https://github.com/dylanaraps/pfetch/raw/master/pfetch -o /usr/local/bin/pfetch
    sudo chmod +x /usr/local/bin/pfetch
fi

# MOTD
sudo tee /etc/update-motd.d/01-custom > /dev/null << 'MOTD_EOF'
#!/bin/bash
if command -v pfetch >/dev/null 2>&1; then
    pfetch
else
    echo "Server: $(hostname)"
fi
MOTD_EOF
sudo chmod +x /etc/update-motd.d/01-custom

# Disable default Ubuntu MOTDs
for script in 00-header 10-help-text 50-landscape-sysinfo 50-motd-news 90-updates-available; do
    [ -f "/etc/update-motd.d/$script" ] && sudo chmod -x "/etc/update-motd.d/$script" 2>/dev/null
done

# Starship
if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes
fi

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
STARSHIP_EOF

# Update .zshrc
if [ -f ~/.zshrc ]; then
    if ! grep -q "starship init zsh" ~/.zshrc; then
        echo 'eval "$(starship init zsh)"' >> ~/.zshrc
    fi
else
    echo 'eval "$(starship init zsh)"' > ~/.zshrc
fi

log_success "Shell customization complete"

# 9. Completion
log_step "Setup Finished!"
echo -e "${GREEN}All tasks completed successfully.${NC}"
echo -e "Please restart your session or run 'zsh' to see changes."
echo -e "Don't forget to change your default shell: sudo chsh -s \$(which zsh) \$USER"
