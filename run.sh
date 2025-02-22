#!/bin/bash

# Set the working directory
BLOCKSCOUT_DIR="/data/src/github.com/blockscout"
DOCKER_COMPOSE_DIR="${BLOCKSCOUT_DIR}/docker-compose"
COMPOSE_FILE="${DOCKER_COMPOSE_DIR}/igra-dev.yml"

# Function to check if docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker is not running or you don't have permissions"
        exit 1
    fi
}

# Function to create required directories and set permissions
setup_directories() {
    local dirs=(
        "redis-data"
        "blockscout-db-data"
        "stats-db-data"
        "logs"
        "dets"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$BLOCKSCOUT_DIR/$dir"
        chmod 777 "$BLOCKSCOUT_DIR/$dir"
    done
}

# Function to check environment files
check_env_files() {
    local env_files=(
        "${DOCKER_COMPOSE_DIR}/envs/common-blockscout.env"
        "${DOCKER_COMPOSE_DIR}/envs/common-frontend.env"
        "${DOCKER_COMPOSE_DIR}/envs/common-stats.env"
        "${DOCKER_COMPOSE_DIR}/envs/common-user-ops-indexer.env"
        "${DOCKER_COMPOSE_DIR}/envs/common-visualizer.env"
    )

    for env_file in "${env_files[@]}"; do
        if [ ! -f "$env_file" ]; then
            echo "Warning: $env_file not found"
            return 1
        fi
    done
    return 0
}

# Function to handle temporary directory
setup_tmp() {
    # Create a temporary directory in /data instead of /tmp
    export TMPDIR="/data/tmp/blockscout"
    mkdir -p "$TMPDIR"
    chmod 777 "$TMPDIR"
}

# Function to start services
start_services() {
    cd "$BLOCKSCOUT_DIR" || exit 1
    
    # Pull latest images
    docker compose -f "$COMPOSE_FILE" pull
    
    # Start services
    docker compose -f "$COMPOSE_FILE" up -d
    
    echo "Waiting for services to be healthy..."
    sleep 10
    
    # Check service status
    docker compose -f "$COMPOSE_FILE" ps
}

# Function to stop services
stop_services() {
    cd "$BLOCKSCOUT_DIR" || exit 1
    docker compose -f "$COMPOSE_FILE" down
}

# Function to show logs
show_logs() {
    cd "$BLOCKSCOUT_DIR" || exit 1
    docker compose -f "$COMPOSE_FILE" logs -f
}

# Function to clean up
cleanup() {
    cd "$BLOCKSCOUT_DIR" || exit 1
    docker compose -f "$COMPOSE_FILE" down -v
    rm -rf redis-data/* blockscout-db-data/* stats-db-data/* logs/* dets/*
}

# Main script
case "$1" in
    "start")
        check_docker
        setup_directories
        setup_tmp
        if ! check_env_files; then
            read -p "Some environment files are missing. Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "logs")
        show_logs
        ;;
    "clean")
        read -p "This will remove all data. Are you sure? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|logs|clean}"
        exit 1
        ;;
esac