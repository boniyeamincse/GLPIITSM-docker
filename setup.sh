#!/bin/bash
#
# GLPI Docker Setup Script
# Automated installation for Debian/Ubuntu and RedHat/CentOS platforms
# This script installs all prerequisites and starts the GLPI stack

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VERSION=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        VERSION=$(cat /etc/redhat-release | sed 's/.*release \([0-9.]*\).*/\1/')
    else
        OS=$(uname -s)
        VERSION=$(uname -r)
    fi

    echo "Detected OS: $OS $VERSION"
}

# Function to install prerequisites on Debian/Ubuntu
install_debian_prereqs() {
    echo -e "${BLUE}[INFO] Installing prerequisites for Debian/Ubuntu...${NC}"

    # Update package lists
    sudo apt-get update -qq

    # Install basic tools
    sudo apt-get install -y -qq \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https

    # Install Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}[INFO] Installing Docker...${NC}"
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker $USER
    else
        echo -e "${GREEN}[INFO] Docker is already installed${NC}"
    fi

    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}[INFO] Installing Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${GREEN}[INFO] Docker Compose is already installed${NC}"
    fi

    # Install Python and pip for webhook dependencies
    sudo apt-get install -y -qq python3 python3-pip python3-venv openssl

    echo -e "${GREEN}[SUCCESS] All prerequisites installed for Debian/Ubuntu${NC}"
}

# Function to install prerequisites on RedHat/CentOS
install_redhat_prereqs() {
    echo -e "${BLUE}[INFO] Installing prerequisites for RedHat/CentOS...${NC}"

    # Install basic tools
    sudo yum install -y -q \
        curl \
        wget \
        git \
        ca-certificates \
        gnupg2 \
        yum-utils \
        device-mapper-persistent-data \
        lvm2

    # Install Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}[INFO] Installing Docker...${NC}"
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y -q docker-ce docker-ce-cli containerd.io
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker $USER
    else
        echo -e "${GREEN}[INFO] Docker is already installed${NC}"
    fi

    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}[INFO] Installing Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo -e "${GREEN}[INFO] Docker Compose is already installed${NC}"
    fi

    # Install Python and pip for webhook dependencies
    sudo yum install -y -q python3 python3-pip openssl

    echo -e "${GREEN}[SUCCESS] All prerequisites installed for RedHat/CentOS${NC}"
}

# Function to setup environment variables
setup_environment() {
    echo -e "${BLUE}[INFO] Setting up environment variables...${NC}"

    # Check if .env file exists
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}[INFO] Creating .env file from template...${NC}"
        cp .env.example .env

        # Generate random passwords
        MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
        MYSQL_PASSWORD=$(openssl rand -base64 12)
        SMTP_PASSWORD=$(openssl rand -base64 12)
        GLPI_API_TOKEN=$(openssl rand -base64 16)

        # Update .env file with random passwords
        sed -i "s/your_secure_root_password/$MYSQL_ROOT_PASSWORD/" .env
        sed -i "s/glpi_password/$MYSQL_PASSWORD/" .env
        sed -i "s/email_password/$SMTP_PASSWORD/" .env
        sed -i "s/your_api_token_here/$GLPI_API_TOKEN/" .env

        echo -e "${GREEN}[INFO] Generated secure passwords in .env file${NC}"
        echo -e "${YELLOW}[WARNING] Please review .env file and update other settings as needed${NC}"
    else
        echo -e "${GREEN}[INFO] .env file already exists${NC}"
    fi
}

# Function to start GLPI stack
start_glpi_stack() {
    echo -e "${BLUE}[INFO] Starting GLPI Docker stack...${NC}"

    # Check if Docker is running
    if ! sudo systemctl is-active --quiet docker; then
        echo -e "${RED}[ERROR] Docker service is not running. Starting Docker...${NC}"
        sudo systemctl start docker
        sleep 5
    fi

    # Build and start containers
    echo -e "${YELLOW}[INFO] Building webhook container...${NC}"
    docker-compose build

    echo -e "${YELLOW}[INFO] Starting all services...${NC}"
    docker-compose up -d

    # Wait for services to start
    echo -e "${BLUE}[INFO] Waiting for services to initialize...${NC}"
    sleep 30

    # Check service status
    echo -e "${BLUE}[INFO] Checking service status...${NC}"
    docker-compose ps

    echo -e "${GREEN}[SUCCESS] GLPI stack is now running!${NC}"
}

# Function to display access information
display_access_info() {
    echo -e "${BLUE}\n========================================${NC}"
    echo -e "${GREEN}GLPI SETUP COMPLETE!${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="localhost"
    fi

    echo -e "${YELLOW}Access GLPI at: ${GREEN}http://$SERVER_IP:8080${NC}"
    echo -e "${YELLOW}Webhook URL: ${GREEN}http://$SERVER_IP:5000/webhook${NC}"
    echo -e "${YELLOW}SMTP Server: ${GREEN}$SERVER_IP:25${NC}"

    echo -e "${BLUE}\nNext Steps:${NC}"
    echo -e "1. Access GLPI web interface at http://$SERVER_IP:8080"
    echo -e "2. Complete the web installation wizard"
    echo -e "3. Configure Wazuh to send alerts to http://$SERVER_IP:5000/webhook"
    echo -e "4. Update GLPI API token in .env file after first login"

    echo -e "${BLUE}\nService Management:${NC}"
    echo -e "${YELLOW}Start services: ${GREEN}docker-compose up -d${NC}"
    echo -e "${YELLOW}Stop services: ${GREEN}docker-compose down${NC}"
    echo -e "${YELLOW}View logs: ${GREEN}docker-compose logs -f${NC}"
    echo -e "${YELLOW}Update services: ${GREEN}docker-compose pull && docker-compose up -d${NC}"

    echo -e "${BLUE}\n========================================${NC}"
}

# Main installation function
main() {
    echo -e "${BLUE}"
    echo "  _____ _ _      _____"
    echo " |_   _(_) | __ |_   _|__  _ __ ___  ___"
    echo "   | | | | |/ /   | |/ _ \| '__/ _ \/ __|"
    echo "   | | | |   <    | | (_) | | |  __/\__ \\"
    echo "   |_| |_|_|\_\   |_|\___/|_|  \___||___/"
    echo -e "${NC}"
    echo -e "${GREEN}GLPI Docker Setup Script${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Check if running as root
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${RED}[ERROR] Please do not run this script as root. Use a regular user with sudo privileges.${NC}"
        exit 1
    fi

    # Detect distribution
    detect_distro

    # Install prerequisites based on distribution
    case $OS in
        ubuntu|debian|linuxmint)
            install_debian_prereqs
            ;;
        centos|rhel|fedora)
            install_redhat_prereqs
            ;;
        *)
            echo -e "${RED}[ERROR] Unsupported Linux distribution: $OS${NC}"
            echo -e "${YELLOW}This script supports Debian/Ubuntu and RedHat/CentOS based systems.${NC}"
            exit 1
            ;;
    esac

    # Ask for confirmation before proceeding
    echo -e "${YELLOW}\n[WARNING] This script will install Docker, Docker Compose, and other dependencies.${NC}"
    echo -e "${YELLOW}It will also generate random passwords and start the GLPI stack.${NC}"
    read -p "Do you want to continue? (y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}[INFO] Installation cancelled by user.${NC}"
        exit 0
    fi

    # Setup environment
    setup_environment

    # Start GLPI stack
    start_glpi_stack

    # Display access information
    display_access_info

    echo -e "${GREEN}\nInstallation completed successfully!${NC}"
}

# Run main function
main