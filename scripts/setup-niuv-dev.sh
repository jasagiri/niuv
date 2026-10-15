#!/bin/bash
# niuv Development Environment Setup Script

set -e

echo "=== niuv Development Environment Setup ==="
echo

# Check if niuv is installed
if ! command -v niuv &> /dev/null; then
    echo "Installing niuv..."
    nimble install -y niuv
fi

# Function to create and setup environment
setup_env() {
    local env_name=$1
    local description=$2
    local extra_deps=$3
    
    echo "Setting up $env_name environment - $description"
    
    # Create environment if it doesn't exist
    if ! niuv list | grep -q "^$env_name"; then
        niuv init $env_name --nim-version 2.0.0
    fi
    
    # Activate and install dependencies
    cat << EOF > setup_${env_name}.sh
#!/bin/bash
source \$(niuv activate $env_name --print)
nimble refresh
nimble install -y chronos nimcrypto results
$extra_deps
echo "Environment $env_name is ready!"
EOF
    
    chmod +x setup_${env_name}.sh
    ./setup_${env_name}.sh
    rm setup_${env_name}.sh
}

# Create main environments
echo "Creating main development environments..."

setup_env "dev" "General development" ""
setup_env "test" "Testing environment" "nimble install -y unittest2"
setup_env "release" "Release builds" ""

# Create domain-specific environments
echo
echo "Creating domain-specific environments..."

# Foundation Trinity
setup_env "domain-tamayura" "Storage domain development" "nimble install -y zippy"
setup_env "domain-yugen" "Compute domain development" ""
setup_env "domain-kotozute" "Network domain development" ""

# Harmony Trinity
setup_env "domain-tokiwa" "Time sync domain development" ""
setup_env "domain-akashi" "Identity domain development" ""
setup_env "domain-kotowari" "Consensus domain development" ""

# Support Trinity
setup_env "domain-utsushi" "Cache domain development" ""
setup_env "domain-miwatashi" "Observability domain development" ""
setup_env "domain-future" "Extension framework development" ""

# Create helper scripts
echo
echo "Creating helper scripts..."

# Create activation script
cat > activate-env.sh << 'EOF'
#!/bin/bash
# Helper script to activate niuv environments

if [ -z "$1" ]; then
    echo "Usage: source activate-env.sh <environment>"
    echo
    echo "Available environments:"
    niuv list
else
    eval "$(niuv activate $1 --print)"
    echo "Activated environment: $1"
fi
EOF
chmod +x activate-env.sh

# Create development runner
cat > run-dev.sh << 'EOF'
#!/bin/bash
# Run development tasks in appropriate environments

task=$1
shift

case $task in
    storage)
        source $(niuv activate domain-tamayura --print)
        nim c -r src/core/tamayura/storage.nim "$@"
        ;;
    compute)
        source $(niuv activate domain-yugen --print)
        nim c -r src/core/yugen/actors.nim "$@"
        ;;
    network)
        source $(niuv activate domain-kotozute --print)
        nim c -r src/core/kotozute/network.nim "$@"
        ;;
    test)
        source $(niuv activate test --print)
        nimble test
        ;;
    build)
        source $(niuv activate release --print)
        nimble build
        ;;
    *)
        echo "Usage: ./run-dev.sh <task> [args]"
        echo "Tasks: storage, compute, network, test, build"
        ;;
esac
EOF
chmod +x run-dev.sh

# Create parallel development script
cat > parallel-dev.sh << 'EOF'
#!/bin/bash
# Launch multiple terminals for parallel development

# Terminal 1: Storage development
osascript -e 'tell app "Terminal" to do script "cd '"$PWD"' && source activate-env.sh domain-tamayura && echo \"Storage Domain Development\""' 2>/dev/null || \
gnome-terminal --tab --title="Storage" -- bash -c "cd $PWD && source activate-env.sh domain-tamayura; bash" 2>/dev/null || \
echo "Terminal 1: source activate-env.sh domain-tamayura"

# Terminal 2: Compute development
osascript -e 'tell app "Terminal" to do script "cd '"$PWD"' && source activate-env.sh domain-yugen && echo \"Compute Domain Development\""' 2>/dev/null || \
gnome-terminal --tab --title="Compute" -- bash -c "cd $PWD && source activate-env.sh domain-yugen; bash" 2>/dev/null || \
echo "Terminal 2: source activate-env.sh domain-yugen"

# Terminal 3: Testing
osascript -e 'tell app "Terminal" to do script "cd '"$PWD"' && source activate-env.sh test && echo \"Test Environment\""' 2>/dev/null || \
gnome-terminal --tab --title="Test" -- bash -c "cd $PWD && source activate-env.sh test; bash" 2>/dev/null || \
echo "Terminal 3: source activate-env.sh test"

echo "Parallel development environments launched!"
EOF
chmod +x parallel-dev.sh

echo
echo "=== Setup Complete ==="
echo
echo "Available environments:"
niuv list
echo
echo "Quick start commands:"
echo "  source activate-env.sh <env-name>  # Activate an environment"
echo "  ./run-dev.sh <task>               # Run specific tasks"
echo "  ./parallel-dev.sh                 # Launch parallel terminals"
echo
echo "Example workflow:"
echo "  source activate-env.sh dev"
echo "  nimble build"
echo "  ./run-dev.sh test"
echo
echo "For domain-specific development:"
echo "  source activate-env.sh domain-tamayura"
echo "  nim c -r src/core/tamayura/storage.nim"