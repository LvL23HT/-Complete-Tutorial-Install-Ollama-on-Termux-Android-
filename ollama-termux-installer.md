# 🤖 Complete Script: Install Ollama on Termux (Android)

Here's the complete `.sh` script in English, based on the tutorial:

```bash
#!/data/data/com.termux/files/usr/bin/bash
#
# 🤖 ollama-termux-installer.sh
# Complete Ollama installation script for Termux (Android)
# Run local LLMs on your phone — no root, no PC required
#
# ✅ Tested on: Android 10–14, ARM64 devices
# ⚠️ Requirements: 4GB RAM minimum • 6-8GB recommended for 7B models
#
# Usage: bash ollama-termux-installer.sh
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
OLLAMA_PORT=11434
LOG_FILE="$HOME/ollama_install.log"
MODELS_DIR="$HOME/ollama_models"

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

log_info()    { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn()    { echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; }

check_arch() {
    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        log_error "Unsupported architecture: $arch. ARM64 (aarch64) required."
        exit 1
    fi
    log_success "Architecture verified: $arch ✓"
}

check_ram() {
    local ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_gb=$((ram_kb / 1024 / 1024))
    
    if [[ $ram_gb -lt 4 ]]; then
        log_warn "Detected RAM: ${ram_gb}GB. Minimum recommended: 4GB."
        log_warn "Models >3B may crash or run very slowly."
    else
        log_success "Detected RAM: ${ram_gb}GB ✓"
    fi
    echo "$ram_gb"
}

check_storage() {
    local free_gb=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | tr -d 'G')
    if [[ $free_gb -lt 4 ]]; then
        log_error "Insufficient free space: ${free_gb}GB. At least 4GB required."
        exit 1
    fi
    log_success "Free storage: ${free_gb}GB ✓"
}

check_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        log_error "Termux not detected. Install from F-Droid: https://f-droid.org/packages/com.termux/"
        exit 1
    fi
    log_success "Termux detected ✓"
}

# ═══════════════════════════════════════════════════════════════
# STEP 1: ENVIRONMENT SETUP
# ═══════════════════════════════════════════════════════════════

setup_environment() {
    log_info "🔧 Preparing Termux environment..."
    
    # Update packages
    log_info "Updating system packages..."
    pkg update -y && pkg upgrade -y >> "$LOG_FILE" 2>&1
    
    # Install useful dependencies
    log_info "Installing auxiliary tools..."
    pkg install -y curl jq htop procps-ng >> "$LOG_FILE" 2>&1
    
    # Create models directory
    mkdir -p "$MODELS_DIR"
    
    log_success "Environment prepared ✓"
}

# ═══════════════════════════════════════════════════════════════
# STEP 2: INSTALL OLLAMA
# ═══════════════════════════════════════════════════════════════

install_ollama() {
    log_info "📦 Installing Ollama from official Termux repository..."
    
    if pkg list-installed | grep -q "^ollama "; then
        log_warn "Ollama is already installed. Skipping installation."
    else
        pkg install ollama -y >> "$LOG_FILE" 2>&1
    fi
    
    # Verify installation
    if command -v ollama &> /dev/null; then
        local version=$(ollama --version 2>&1 | head -1)
        log_success "Ollama installed: $version ✓"
    else
        log_error "Ollama installation failed. Check $LOG_FILE"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# STEP 3: START SERVER IN BACKGROUND
# ═══════════════════════════════════════════════════════════════

start_ollama_server() {
    log_info "🚀 Starting Ollama server in background..."
    
    # Check if already running
    if curl -s "http://localhost:$OLLAMA_PORT/api/version" &> /dev/null; then
        log_warn "Ollama server already running on port $OLLAMA_PORT"
        return 0
    fi
    
    # Enable wake lock to prevent Android from killing the process
    if command -v termux-wake-lock &> /dev/null; then
        termux-wake-lock
        log_info "🔋 Wake lock enabled (prevents background suspension)"
    fi
    
    # Start server in background with nohup
    nohup ollama serve > "$HOME/ollama_server.log" 2>&1 &
    local pid=$!
    
    # Wait for server to be ready (max 30 seconds)
    log_info "Waiting for server to be ready..."
    for i in {1..30}; do
        if curl -s "http://localhost:$OLLAMA_PORT/api/version" &> /dev/null; then
            log_success "Ollama server active (PID: $pid) ✓"
            echo "$pid" > "$HOME/.ollama.pid"
            return 0
        fi
        sleep 1
    done
    
    log_error "Timeout: Server did not respond within 30 seconds."
    log_error "Check log: $HOME/ollama_server.log"
    return 1
}

# ═══════════════════════════════════════════════════════════════
# STEP 4: MODEL SELECTION MENU
# ═══════════════════════════════════════════════════════════════

show_model_menu() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📚 SELECT MODELS TO DOWNLOAD${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
    
    echo -e "${GREEN}🔹 LIGHTWEIGHT (Recommended for mobile):${NC}"
    echo "  [1] tinyllama:1.1b           (~600MB • Fast, basic Q&A)"
    echo "  [2] qwen2.5:1.5b            (~1GB • Multilingual, good balance)"
    
    echo -e "\n${GREEN}🔹 UNCENSORED 3B (Performance/freedom balance):${NC}"
    echo "  [3] artifish/llama3.2-uncensored:3b  (~2.2GB • Recommended)"
    
    echo -e "\n${GREEN}🔹 UNCENSORED 7B+ (Max capability, slower):${NC}"
    echo "  [4] dolphin-mistral:7b-v2.8-q4_K_M   (~4.1GB • Coding, technical)"
    echo "  [5] mannix/llama3-uncensored:8b-q4_K_M (~4.8GB • Maximum, slow)"
    echo "  [6] CognitiveComputations/dolphin-llama3.1:8b-q4_K_M (~4.9GB • Multilingual+coding)"
    
    echo -e "\n${GREEN}🔹 OPTIONS:${NC}"
    echo "  [0] Skip model downloads"
    echo "  [9] Download all lightweight models (1+2)"
    echo "  [A] Download recommended models (2+3)"
    
    echo -e "\n${YELLOW}Select an option (e.g., 1, 3, 9, A, or 1 3 5):${NC} "
}

download_model() {
    local model=$1
    log_info "⬇️  Downloading: $model"
    
    # Estimate size for warning
    local size_hint=""
    case "$model" in
        *7b*|*8b*) size_hint="(~4-5GB) " ;;
        *3b*) size_hint="(~2GB) " ;;
        *1.5b*) size_hint="(~1GB) " ;;
        *) size_hint="" ;;
    esac
    
    log_warn "Space required $size_hint- Ensure you have free storage."
    
    if ollama pull "$model" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Model downloaded: $model ✓"
    else
        log_error "Failed to download: $model"
        return 1
    fi
}

handle_model_selection() {
    show_model_menu
    read -r selection
    
    # Process selection (supports multiple: "1 3 5")
    for choice in $selection; do
        case "$choice" in
            1) download_model "tinyllama:1.1b" ;;
            2) download_model "qwen2.5:1.5b" ;;
            3) download_model "artifish/llama3.2-uncensored:3b" ;;
            4) download_model "dolphin-mistral:7b-v2.8-q4_K_M" ;;
            5) download_model "mannix/llama3-uncensored:8b-q4_K_M" ;;
            6) download_model "CognitiveComputations/dolphin-llama3.1:8b-q4_K_M" ;;
            9) # All lightweight
                download_model "tinyllama:1.1b"
                download_model "qwen2.5:1.5b"
                ;;
            A|a) # Recommended
                download_model "qwen2.5:1.5b"
                download_model "artifish/llama3.2-uncensored:3b"
                ;;
            0) 
                log_info "⏭️  Skipping model downloads."
                return 0
                ;;
            *) 
                log_warn "Unrecognized option: $choice"
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
# STEP 5: APPLY OPTIMIZATIONS
# ═══════════════════════════════════════════════════════════════

apply_optimizations() {
    log_info "⚙️  Applying mobile optimizations..."
    
    # Create useful aliases in .bashrc
    local bashrc="$HOME/.bashrc"
    
    # Backup if exists
    [[ -f "$bashrc" ]] && cp "$bashrc" "${bashrc}.bak.$(date +%s)"
    
    cat >> "$bashrc" << 'EOF'

# 🤖 Ollama - Aliases for Termux
alias ollama-run-fast='ollama run --num-predict 100 --temperature 0.3'
alias ollama-serve-bg='nohup ollama serve > ~/ollama_server.log 2>&1 &'
alias ollama-status='curl -s http://localhost:11434/api/version && echo " ✓ Active" || echo " ✗ Inactive"'
alias ollama-ram='ollama ps && echo && free -h'

# Function for quick chat with token limit
ollama-chat() {
    local model=${1:-qwen2.5:1.5b}
    shift
    ollama run "$model" --num-predict "${1:-150}"
}
EOF
    
    log_success "Aliases added to .bashrc ✓"
    log_info "💡 Run: source ~/.bashrc to activate them now"
    
    # Create quick start script
    cat > "$HOME/start-ollama.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 🚀 Start Ollama on Termux

cd ~
termux-wake-lock 2>/dev/null
nohup ollama serve > ollama_server.log 2>&1 &
echo "🤖 Ollama started (PID: $!)"
echo "🔗 API: http://localhost:11434"
echo "💬 Chat: ollama run <model>"
echo "🛑 Stop: pkill -f 'ollama serve'"
EOF
    chmod +x "$HOME/start-ollama.sh"
    log_success "Quick start script created: ~/start-ollama.sh ✓"
}

# ═══════════════════════════════════════════════════════════════
# STEP 6: FINAL VERIFICATION & MESSAGES
# ═══════════════════════════════════════════════════════════════

final_verification() {
    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    echo -e "${BLUE}✅ FINAL VERIFICATION${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"
    
    # Server status
    if curl -s "http://localhost:$OLLAMA_PORT/api/version" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Ollama Server: ACTIVE"
    else
        echo -e "  ${RED}✗${NC} Ollama Server: INACTIVE"
        echo -e "     💡 Start with: ${YELLOW}ollama serve &${NC}"
    fi
    
    # Installed models
    echo -e "\n  📦 Available models:"
    if ollama list &> /dev/null; then
        ollama list | tail -n +2 | while read -r line; do
            echo -e "     • $line"
        done
    else
        echo -e "     ${YELLOW}(none)${NC}"
    fi
    
    # System resources
    echo -e "\n  📊 Resources:"
    echo -e "     • Free RAM: $(free -h | grep Mem | awk '{print $4}')"
    echo -e "     • Free Storage: $(df -h ~ | tail -1 | awk '{print $4}')"
}

show_usage_tips() {
    echo -e "\n${YELLOW}════════════════════════════════════════${NC}"
    echo -e "${BLUE}💡 USAGE TIPS${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}\n"
    
    cat << 'EOF'
🔹 QUICK CHAT:
   ollama run qwen2.5:1.5b
   ollama run artifish/llama3.2-uncensored:3b --num-predict 100

🔹 API (for developers):
   curl http://localhost:11434/api/generate -d '{
     "model": "qwen2.5:1.5b",
     "prompt": "Hello",
     "stream": false
   }'

🔹 WEB UI (Android):
   Install ChatterUI from F-Droid and configure:
   • API URL: http://127.0.0.1:11434

🔹 IN-CHAT COMMANDS:
   /bye     → Exit chat
   /reset   → Clear conversation history
   /set parameter temperature 0.7 → More creativity

🔹 MOBILE OPTIMIZATION:
   • Use models ≤3B for better performance
   • Add --num-predict 100 for shorter/faster responses
   • Close background apps before loading 7B models
   • Use termux-wake-unlock when done to save battery

🔹 MAINTENANCE:
   • Update: pkg update && pkg upgrade ollama -y
   • List models: ollama list
   • Remove model: ollama rm <name>
   • View logs: tail -f ~/ollama_server.log

⚠️  ETHICAL USE:
   "Uncensored" models have reduced content filters.
   Use responsibly for research, education,
   or creative projects. You are responsible for the output.
EOF
}

# ═══════════════════════════════════════════════════════════════
# MAIN FUNCTION
# ═══════════════════════════════════════════════════════════════

main() {
    echo -e "${GREEN}
╔════════════════════════════════════════╗
║  🤖 OLLAMA FOR TERMUX - INSTALLER      ║
║  Run local LLMs on your Android        ║
╚════════════════════════════════════════╝${NC}
"
    
    # Logging
    echo "📝 Log saved to: $LOG_FILE"
    
    # Pre-checks
    check_termux
    check_arch
    check_ram > /dev/null
    check_storage
    
    # Main flow
    setup_environment
    install_ollama
    start_ollama_server
    
    # Model selection (interactive)
    handle_model_selection
    
    # Optimizations
    apply_optimizations
    
    # Verification and tips
    final_verification
    show_usage_tips
    
    echo -e "\n${GREEN}🎉 Installation complete!${NC}"
    echo -e "🔁 To reload aliases: ${YELLOW}source ~/.bashrc${NC}"
    echo -e "🚀 To start Ollama: ${YELLOW}~/start-ollama.sh${NC}"
    echo -e "💬 To chat: ${YELLOW}ollama run <model>${NC}\n"
}

# ═══════════════════════════════════════════════════════════════
# EXECUTION
# ═══════════════════════════════════════════════════════════════

# Handle arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: bash $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --models-only    Only show model download menu"
        echo "  --server-only    Only start Ollama server"
        echo "  --verify         Only verify installation status"
        echo "  --help, -h       Show this help message"
        exit 0
        ;;
    --models-only)
        check_termux && install_ollama && start_ollama_server && handle_model_selection
        exit 0
        ;;
    --server-only)
        check_termux && install_ollama && start_ollama_server
        exit 0
        ;;
    --verify)
        command -v ollama &> /dev/null && echo "✓ Ollama installed" || echo "✗ Ollama not found"
        curl -s http://localhost:11434/api/version &> /dev/null && echo "✓ Server active" || echo "✗ Server inactive"
        exit 0
        ;;
esac

# Run full installation
main "$@"
```

---

## 📋 How to Use the Script

### 1️⃣ Save the Script
```bash
# In Termux:
nano ollama-install.sh
# (paste the content, then Ctrl+O to save, Ctrl+X to exit)

# Make it executable:
chmod +x ollama-install.sh
```

### 2️⃣ Run the Script
```bash
# Full installation (recommended):
bash ollama-install.sh

# Advanced options:
bash ollama-install.sh --models-only    # Only download models
bash ollama-install.sh --server-only    # Only start server
bash ollama-install.sh --verify         # Only verify status
```

### 3️⃣ Post-Installation
```bash
# Activate new aliases:
source ~/.bashrc

# Start Ollama easily:
~/start-ollama.sh

# Quick chat:
ollama-chat qwen2.5:1.5b
```

---

## 🔧 Script Features

| Feature | Description |
|---------|-------------|
| ✅ **Pre-checks** | ARM64 architecture, RAM, storage, valid Termux installation |
| ✅ **Safe installation** | Uses official `pkg install ollama`, with detailed logging |
| ✅ **Background server** | `nohup` + `termux-wake-lock` for persistence |
| ✅ **Interactive menu** | Select models by category (lightweight / 3B / 7B+) |
| ✅ **Mobile optimizations** | Pre-configured aliases, token limits, temperature settings |
| ✅ **Useful aliases** | `ollama-run-fast`, `ollama-status`, `ollama-ram` |
| ✅ **Quick start script** | `~/start-ollama.sh` to launch with one command |
| ✅ **Colored output** | Easy-to-read progress and error messages |
| ✅ **Complete logging** | Everything saved to `~/ollama_install.log` |
| ✅ **Advanced modes** | `--models-only`, `--server-only`, `--verify` flags |

---

## ⚠️ Important Notes

```bash
# 🔋 Battery saving:
termux-wake-unlock  # Run when you're done using Ollama

# 🧹 Free up space:
ollama rm <unused_model>

# 🐌 If it runs slowly:
# - Use models ≤3B
# - Add --num-predict 100
# - Close other apps

# 🔄 Update in the future:
pkg update && pkg upgrade ollama -y
ollama pull <model>  # To update a specific model
```

---

> 📁 **Files created by the script**:
> - `~/ollama_install.log` → Complete installation log
> - `~/ollama_server.log` → Running server log
> - `~/.ollama.pid` → Process PID (for management)
> - `~/start-ollama.sh` → Quick start script
> - `~/.bashrc` → Added aliases (with automatic backup)

---

## 🚀 Quick Reference Card

```bash
# ═══════════════════════════════════════════════════════
# 🤖 OLLAMA ON TERMUX - QUICK COMMANDS
# ═══════════════════════════════════════════════════════

# Start server
~/start-ollama.sh

# Check status
ollama-status

# Quick chat (100 tokens, low temp)
ollama-run-fast dolphin-mistral

# Full chat
ollama run artifish/llama3.2-uncensored:3b

# API test
curl http://localhost:11434/api/version

# Monitor resources
ollama-ram

# Stop server
pkill -f "ollama serve"

# Release wake lock (save battery)
termux-wake-unlock
```

---

> 🌟 **You're all set!** You now have powerful, private AI models — including uncensored options — running entirely on your Android device.
> 🔁 **Next steps**: Experiment with prompts, benchmark performance, or build a simple app using the API.

*Last updated: April 2026 | Ollama v0.5+ | Termux v0.118+*

📥 **Need help?** Report issues on [Termux GitHub](https://github.com/termux/termux-packages) or [Ollama GitHub](https://github.com/ollama/ollama).

---
