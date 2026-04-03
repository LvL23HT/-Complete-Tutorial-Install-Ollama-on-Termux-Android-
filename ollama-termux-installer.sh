#!/data/data/com.termux/files/usr/bin/bash
#
# 🤖 ollama-termux-installer.sh
# Script de instalación completa de Ollama en Termux (Android)
# Ejecuta LLMs locales en tu móvil — sin root, sin PC
#
# ✅ Probado en: Android 10–14, dispositivos ARM64
# ⚠️ Requiere: 4GB RAM mínimo • 6-8GB recomendado para modelos 7B
#
# Uso: bash ollama-termux-installer.sh
#

set -e  # Salir ante errores

# Colores para output
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
# FUNCIONES AUXILIARES
# ═══════════════════════════════════════════════════════════════

log_info()    { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn()    { echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"; }

check_arch() {
    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        log_error "Arquitectura no soportada: $arch. Se requiere ARM64 (aarch64)."
        exit 1
    fi
    log_success "Arquitectura verificada: $arch ✓"
}

check_ram() {
    local ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_gb=$((ram_kb / 1024 / 1024))
    
    if [[ $ram_gb -lt 4 ]]; then
        log_warn "RAM detectada: ${ram_gb}GB. Mínimo recomendado: 4GB."
        log_warn "Los modelos >3B pueden fallar o ser muy lentos."
    else
        log_success "RAM detectada: ${ram_gb}GB ✓"
    fi
    echo "$ram_gb"
}

check_storage() {
    local free_gb=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | tr -d 'G')
    if [[ $free_gb -lt 4 ]]; then
        log_error "Espacio libre insuficiente: ${free_gb}GB. Se requieren al menos 4GB."
        exit 1
    fi
    log_success "Espacio libre: ${free_gb}GB ✓"
}

check_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        log_error "Termux no detectado. Instálalo desde F-Droid: https://f-droid.org/packages/com.termux/"
        exit 1
    fi
    log_success "Termux detectado ✓"
}

# ═══════════════════════════════════════════════════════════════
# PASO 1: PREPARACIÓN DEL ENTORNO
# ═══════════════════════════════════════════════════════════════

setup_environment() {
    log_info "🔧 Preparando entorno Termux..."
    
    # Actualizar paquetes
    log_info "Actualizando paquetes del sistema..."
    pkg update -y && pkg upgrade -y >> "$LOG_FILE" 2>&1
    
    # Instalar dependencias útiles
    log_info "Instalando herramientas auxiliares..."
    pkg install -y curl jq htop procps-ng >> "$LOG_FILE" 2>&1
    
    # Crear directorio para modelos
    mkdir -p "$MODELS_DIR"
    
    log_success "Entorno preparado ✓"
}

# ═══════════════════════════════════════════════════════════════
# PASO 2: INSTALAR OLLAMA
# ═══════════════════════════════════════════════════════════════

install_ollama() {
    log_info "📦 Instalando Ollama desde repositorio oficial de Termux..."
    
    if pkg list-installed | grep -q "^ollama "; then
        log_warn "Ollama ya está instalado. Saltando instalación."
    else
        pkg install ollama -y >> "$LOG_FILE" 2>&1
    fi
    
    # Verificar instalación
    if command -v ollama &> /dev/null; then
        local version=$(ollama --version 2>&1 | head -1)
        log_success "Ollama instalado: $version ✓"
    else
        log_error "Falló la instalación de Ollama. Revisa $LOG_FILE"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# PASO 3: CONFIGURAR SERVIDOR EN BACKGROUND
# ═══════════════════════════════════════════════════════════════

start_ollama_server() {
    log_info "🚀 Iniciando servidor Ollama en background..."
    
    # Verificar si ya está corriendo
    if curl -s "http://localhost:$OLLAMA_PORT/api/version" &> /dev/null; then
        log_warn "El servidor Ollama ya está ejecutándose en puerto $OLLAMA_PORT"
        return 0
    fi
    
    # Bloquear wake lock para evitar que Android mate el proceso
    if command -v termux-wake-lock &> /dev/null; then
        termux-wake-lock
        log_info "🔋 Wake lock activado (evita suspensión en background)"
    fi
    
    # Iniciar servidor en background con nohup
    nohup ollama serve > "$HOME/ollama_server.log" 2>&1 &
    local pid=$!
    
    # Esperar a que el servidor esté listo (máx. 30 segundos)
    log_info "Esperando que el servidor esté listo..."
    for i in {1..30}; do
        if curl -s "http://localhost:$OLLAMA_PORT/api/version" &> /dev/null; then
            log_success "Servidor Ollama activo (PID: $pid) ✓"
            echo "$pid" > "$HOME/.ollama.pid"
            return 0
        fi
        sleep 1
    done
    
    log_error "Timeout: El servidor no respondió en 30 segundos."
    log_error "Revisa el log: $HOME/ollama_server.log"
    return 1
}

# ═══════════════════════════════════════════════════════════════
# PASO 4: MENÚ DE SELECCIÓN DE MODELOS
# ═══════════════════════════════════════════════════════════════

show_model_menu() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📚 SELECCIONA MODELOS PARA DESCARGAR${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
    
    echo -e "${GREEN}🔹 LIVIANOS (Recomendados para móvil):${NC}"
    echo "  [1] tinyllama:1.1b           (~600MB • Rápido, Q&A básico)"
    echo "  [2] qwen2.5:1.5b            (~1GB • Multilingüe, buen equilibrio)"
    
    echo -e "\n${GREEN}🔹 UNCENSORED 3B (Balance rendimiento/libertad):${NC}"
    echo "  [3] artifish/llama3.2-uncensored:3b  (~2.2GB • Recomendado)"
    
    echo -e "\n${GREEN}🔹 UNCENSORED 7B+ (Máxima capacidad, más lento):${NC}"
    echo "  [4] dolphin-mistral:7b-v2.8-q4_K_M   (~4.1GB • Coding, técnico)"
    echo "  [5] mannix/llama3-uncensored:8b-q4_K_M (~4.8GB • Máximo, lento)"
    echo "  [6] dolphin-llama3.1:8b-q4_K_M       (~4.9GB • Multilingüe+coding)"
    
    echo -e "\n${GREEN}🔹 OPCIONES:${NC}"
    echo "  [0] Saltar descarga de modelos"
    echo "  [9] Descargar todos los livianos (1+2)"
    echo "  [A] Descargar recomendados (2+3)"
    
    echo -e "\n${YELLOW}Selecciona una opción (ej: 1, 3, 9, A, o 1 3 5):${NC} "
}

download_model() {
    local model=$1
    log_info "⬇️  Descargando: $model"
    
    # Estimar tamaño para advertencia
    local size_hint=""
    case "$model" in
        *7b*|*8b*) size_hint="(~4-5GB) " ;;
        *3b*) size_hint="(~2GB) " ;;
        *1.5b*) size_hint="(~1GB) " ;;
        *) size_hint="" ;;
    esac
    
    log_warn "Espacio requerido $size_hint- Asegúrate de tener espacio libre."
    
    if ollama pull "$model" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Modelo descargado: $model ✓"
    else
        log_error "Falló la descarga de: $model"
        return 1
    fi
}

handle_model_selection() {
    show_model_menu
    read -r selection
    
    # Procesar selección (soporta múltiple: "1 3 5")
    for choice in $selection; do
        case "$choice" in
            1) download_model "tinyllama:1.1b" ;;
            2) download_model "qwen2.5:1.5b" ;;
            3) download_model "artifish/llama3.2-uncensored:3b" ;;
            4) download_model "dolphin-mistral:7b-v2.8-q4_K_M" ;;
            5) download_model "mannix/llama3-uncensored:8b-q4_K_M" ;;
            6) download_model "CognitiveComputations/dolphin-llama3.1:8b-q4_K_M" ;;
            9) # Todos los livianos
                download_model "tinyllama:1.1b"
                download_model "qwen2.5:1.5b"
                ;;
            A|a) # Recomendados
                download_model "qwen2.5:1.5b"
                download_model "artifish/llama3.2-uncensored:3b"
                ;;
            0) 
                log_info "⏭️  Saltando descarga de modelos."
                return 0
                ;;
            *) 
                log_warn "Opción no reconocida: $choice"
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
# PASO 5: CONFIGURACIÓN DE OPTIMIZACIONES
# ═══════════════════════════════════════════════════════════════

apply_optimizations() {
    log_info "⚙️  Aplicando optimizaciones para móvil..."
    
    # Crear alias útiles en .bashrc
    local bashrc="$HOME/.bashrc"
    
    # Backup si existe
    [[ -f "$bashrc" ]] && cp "$bashrc" "${bashrc}.bak.$(date +%s)"
    
    cat >> "$bashrc" << 'EOF'

# 🤖 Ollama - Aliases para Termux
alias ollama-run-fast='ollama run --num-predict 100 --temperature 0.3'
alias ollama-serve-bg='nohup ollama serve > ~/ollama_server.log 2>&1 &'
alias ollama-status='curl -s http://localhost:11434/api/version && echo " ✓ Activo" || echo " ✗ Inactivo"'
alias ollama-ram='ollama ps && echo && free -h'

# Función para chat rápido con límite de tokens
ollama-chat() {
    local model=${1:-qwen2.5:1.5b}
    shift
    ollama run "$model" --num-predict "${1:-150}"
}
EOF
    
    log_success "Aliases añadidos a .bashrc ✓"
    log_info "💡 Usa: source ~/.bashrc para activarlos ahora"
    
    # Crear script de inicio rápido
    cat > "$HOME/start-ollama.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 🚀 Iniciar Ollama en Termux

cd ~
termux-wake-lock 2>/dev/null
nohup ollama serve > ollama_server.log 2>&1 &
echo "🤖 Ollama iniciado (PID: $!)"
echo "🔗 API: http://localhost:11434"
echo "💬 Chat: ollama run <modelo>"
echo "🛑 Detener: pkill -f 'ollama serve'"
EOF
    chmod +x "$HOME/start-ollama.sh"
    log_success "Script de inicio creado: ~/start-ollama.sh ✓"
}

# ═══════════════════════════════════════════════════════════════
# PASO 6: VERIFICACIÓN FINAL Y MENSAJES
# ═══════════════════════════════════════════════════════════════

final_verification() {
    echo -e "\n${GREEN}════════════════════════════════════════${NC}"
    echo -e "${BLUE}✅ VERIFICACIÓN FINAL${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}\n"
    
    # Estado del servidor
    if curl -s "http://localhost:$OLLAMA_PORT/api/version" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Servidor Ollama: ACTIVO"
    else
        echo -e "  ${RED}✗${NC} Servidor Ollama: INACTIVO"
        echo -e "     💡 Inicia con: ${YELLOW}ollama serve &${NC}"
    fi
    
    # Modelos instalados
    echo -e "\n  📦 Modelos disponibles:"
    if ollama list &> /dev/null; then
        ollama list | tail -n +2 | while read -r line; do
            echo -e "     • $line"
        done
    else
        echo -e "     ${YELLOW}(ninguno)${NC}"
    fi
    
    # Recursos del sistema
    echo -e "\n  📊 Recursos:"
    echo -e "     • RAM libre: $(free -h | grep Mem | awk '{print $4}')"
    echo -e "     • Almacenamiento libre: $(df -h ~ | tail -1 | awk '{print $4}')"
}

show_usage_tips() {
    echo -e "\n${YELLOW}════════════════════════════════════════${NC}"
    echo -e "${BLUE}💡 CONSEJOS DE USO${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}\n"
    
    cat << 'EOF'
🔹 CHAT RÁPIDO:
   ollama run qwen2.5:1.5b
   ollama run artifish/llama3.2-uncensored:3b --num-predict 100

🔹 API (para desarrolladores):
   curl http://localhost:11434/api/generate -d '{
     "model": "qwen2.5:1.5b",
     "prompt": "Hola",
     "stream": false
   }'

🔹 WEB UI (Android):
   Instala ChatterUI desde F-Droid y configura:
   • API URL: http://127.0.0.1:11434

🔹 COMANDOS EN CHAT:
   /bye     → Salir
   /reset   → Limpiar historial
   /set parameter temperature 0.7 → Más creatividad

🔹 OPTIMIZACIÓN PARA MÓVIL:
   • Usa modelos ≤3B para mejor rendimiento
   • Añade --num-predict 100 para respuestas más cortas/rápidas
   • Cierra apps en background antes de usar modelos 7B
   • Usa termux-wake-unlock cuando termines para ahorrar batería

🔹 MANTENIMIENTO:
   • Actualizar: pkg update && pkg upgrade ollama -y
   • Listar modelos: ollama list
   • Eliminar modelo: ollama rm <nombre>
   • Ver logs: tail -f ~/ollama_server.log

⚠️  USO ÉTICO:
   Los modelos "uncensored" tienen menos filtros.
   Úsalos responsablemente para investigación, educación
   o proyectos creativos. Tú eres responsable del output.
EOF
}

# ═══════════════════════════════════════════════════════════════
# FUNCIÓN PRINCIPAL
# ═══════════════════════════════════════════════════════════════

main() {
    echo -e "${GREEN}
╔════════════════════════════════════════╗
║  🤖 OLLAMA PARA TERMUX - INSTALADOR    ║
║  Ejecuta LLMs locales en tu Android    ║
╚════════════════════════════════════════╝${NC}
"
    
    # Registro
    echo "📝 Log guardado en: $LOG_FILE"
    
    # Verificaciones previas
    check_termux
    check_arch
    check_ram > /dev/null
    check_storage
    
    # Flujo principal
    setup_environment
    install_ollama
    start_ollama_server
    
    # Selección de modelos (interactivo)
    handle_model_selection
    
    # Optimizaciones
    apply_optimizations
    
    # Verificación y consejos
    final_verification
    show_usage_tips
    
    echo -e "\n${GREEN}🎉 ¡Instalación completada!${NC}"
    echo -e "🔁 Para recargar aliases: ${YELLOW}source ~/.bashrc${NC}"
    echo -e "🚀 Para iniciar Ollama: ${YELLOW}~/start-ollama.sh${NC}"
    echo -e "💬 Para chatear: ${YELLOW}ollama run <modelo>${NC}\n"
}

# ═══════════════════════════════════════════════════════════════
# EJECUCIÓN
# ═══════════════════════════════════════════════════════════════

# Manejo de argumentos
case "${1:-}" in
    --help|-h)
        echo "Uso: bash $0 [OPCIÓN]"
        echo ""
        echo "Opciones:"
        echo "  --models-only    Solo menú de descarga de modelos"
        echo "  --server-only    Solo iniciar servidor Ollama"
        echo "  --verify         Solo verificar instalación"
        echo "  --help, -h       Mostrar esta ayuda"
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
        command -v ollama &> /dev/null && echo "✓ Ollama instalado" || echo "✗ Ollama no encontrado"
        curl -s http://localhost:11434/api/version &> /dev/null && echo "✓ Servidor activo" || echo "✗ Servidor inactivo"
        exit 0
        ;;
esac

# Ejecutar instalación completa
main "$@"
