#!/bin/bash

# Docker Cleanup Script
# Removes volumes, cache, and unused resources before Kind setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Show current Docker usage
show_usage() {
    print_section "Current Docker Disk Usage"
    docker system df
}

# Clean Docker resources
cleanup_docker() {
    print_section "Starting Docker Cleanup"

    print_warning "This will remove:"
    echo "  - All stopped containers"
    echo "  - All unused networks"
    echo "  - All unused images"
    echo "  - All build cache"
    echo "  - All volumes not used by running containers"
    echo ""

    read -p "Continue with cleanup? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled"
        exit 0
    fi

    # Stop all running containers first
    print_status "Stopping all running containers..."
    docker stop $(docker ps -q) 2>/dev/null || true

    # Remove all stopped containers
    print_status "Removing stopped containers..."
    docker container prune -f

    # Remove all unused volumes
    print_status "Removing unused volumes..."
    docker volume prune -f

    # Remove all dangling images
    print_status "Removing dangling images..."
    docker image prune -f

    # Remove all unused images (not just dangling)
    print_status "Removing all unused images..."
    docker image prune -a -f

    # Clean build cache
    print_status "Cleaning build cache..."
    docker builder prune -f

    # Remove all unused networks
    print_status "Removing unused networks..."
    docker network prune -f

    # Full system prune (everything)
    print_status "Running full system prune..."
    docker system prune -a --volumes -f
}

# Clean Kind clusters
cleanup_kind() {
    print_section "Cleaning Kind Clusters"

    if command -v kind &> /dev/null; then
        print_status "Looking for existing Kind clusters..."
        CLUSTERS=$(kind get clusters 2>/dev/null)

        if [ -n "$CLUSTERS" ]; then
            print_warning "Found Kind clusters:"
            echo "$CLUSTERS"

            read -p "Delete all Kind clusters? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                for cluster in $CLUSTERS; do
                    print_status "Deleting cluster: $cluster"
                    kind delete cluster --name $cluster
                done
            fi
        else
            print_status "No Kind clusters found"
        fi
    else
        print_status "Kind not installed yet"
    fi
}

# Restart Docker Desktop (Windows)
restart_docker_windows() {
    print_section "Restarting Docker Desktop"

    print_status "Stopping Docker Desktop..."

    # Try multiple methods to stop Docker
    taskkill //F //IM "Docker Desktop.exe" 2>/dev/null || true
    taskkill //F //IM "com.docker.service" 2>/dev/null || true

    # Stop Docker service
    net stop com.docker.service 2>/dev/null || true

    print_status "Waiting for Docker to stop..."
    sleep 5

    print_status "Starting Docker Desktop..."

    # Common Docker Desktop locations on Windows
    if [ -f "/c/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
        "/c/Program Files/Docker/Docker/Docker Desktop.exe" &
    elif [ -f "$HOME/AppData/Local/Docker/Docker Desktop.exe" ]; then
        "$HOME/AppData/Local/Docker/Docker Desktop.exe" &
    else
        print_warning "Could not find Docker Desktop executable"
        print_warning "Please start Docker Desktop manually"
    fi

    print_status "Waiting for Docker to be ready..."
    MAX_WAIT=60
    WAIT=0
    while ! docker info &>/dev/null; do
        if [ $WAIT -ge $MAX_WAIT ]; then
            print_warning "Docker is taking too long to start"
            print_warning "Please check Docker Desktop manually"
            break
        fi
        echo -n "."
        sleep 2
        ((WAIT+=2))
    done
    echo ""

    if docker info &>/dev/null; then
        print_status "Docker is ready!"
    fi
}

# Show final usage
show_final_usage() {
    print_section "Docker Disk Usage After Cleanup"
    docker system df

    print_status "Cleanup complete!"

    # Show space saved
    echo ""
    print_status "Docker is now clean and ready for Kind setup"
}

# Main execution
main() {
    print_section "Docker Cleanup for WCD Platform"

    show_usage
    cleanup_kind
    cleanup_docker

    # Ask about Docker restart
    read -p "Restart Docker Desktop for a fresh start? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        restart_docker_windows
    fi

    show_final_usage

    print_section "Next Steps"
    echo "1. Run: ./setup-kind.sh"
    echo "2. Run: ./build-images.sh"
    echo "3. Run: ./deploy.sh local apply"
    echo "4. Run: ./test-local.sh"
}

# Run main
main "$@"