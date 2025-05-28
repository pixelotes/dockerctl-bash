#!/bin/bash

# dockerctl - Interactive Docker container management script
# Requirements: docker, fzf

# ====================
# VARIABLES
# ====================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ====================
# DEPENDENCY CHECK
# ====================

# Check if required tools are installed
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: docker is not installed or not in PATH${NC}"
        exit 1
    fi
    
    if ! command -v fzf &> /dev/null; then
        echo -e "${RED}Error: fzf is not installed or not in PATH${NC}"
        echo "Install fzf: https://github.com/junegunn/fzf#installation"
        exit 1
    fi
}

# ====================
# HELPER FUNCTIONS
# ====================

# Check if Docker daemon is running
check_docker() {
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
}

# Get running containers with formatted output
get_containers() {
    docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Names}}" | tail -n +2
}

# Select container using fzf
select_container() {
    local containers
    containers=$(get_containers)
    
    if [ -z "$containers" ]; then
        echo -e "${YELLOW}No running containers found${NC}"
        exit 0
    fi
    
    echo "$containers" | fzf \
        --header="Select a container:" \
        --header-lines=0 \
        --preview='docker inspect {1} | head -20' \
        --preview-window=right:50%:wrap \
        --prompt="Container> " \
        --height=80% \
        --border \
        --ansi
}

# Extract container ID from selected line
get_container_id() {
    echo "$1" | awk '{print $1}'
}

# Extract container name from selected line
get_container_name() {
    echo "$1" | awk '{print $NF}'
}

# Show action menu
show_actions() {
    local container_name="$1"
    echo -e "${BLUE}Container: $container_name${NC}"
    echo "Choose an action:"
    echo "1) Stop container"
    echo "2) Restart container"
    echo "3) View logs"
    echo "4) Exec bash"
    echo "5) Exec custom command"
    echo "6) Back to container selection"
    echo "q) Quit"
}

# Stop container
stop_container() {
    local container_id="$1"
    local container_name="$2"
    
    echo -e "${YELLOW}Stopping container $container_name...${NC}"
    if docker stop "$container_id"; then
        echo -e "${GREEN}Container $container_name stopped successfully${NC}"
    else
        echo -e "${RED}Failed to stop container $container_name${NC}"
    fi
}

# Restart container
restart_container() {
    local container_id="$1"
    local container_name="$2"
    
    echo -e "${YELLOW}Restarting container $container_name...${NC}"
    if docker restart "$container_id"; then
        echo -e "${GREEN}Container $container_name restarted successfully${NC}"
    else
        echo -e "${RED}Failed to restart container $container_name${NC}"
    fi
}

# View logs
view_logs() {
    local container_id="$1"
    local container_name="$2"
    
    echo -e "${BLUE}Showing logs for $container_name (Press Ctrl+C to exit)${NC}"
    echo "Choose log options:"
    echo "1) Show last 50 lines"
    echo "2) Follow logs (tail -f)"
    echo "3) Show all logs"
    read -r -p "Enter choice [1-3]: " log_choice
    
    case $log_choice in
        1)
            docker logs --tail 50 "$container_id"
            ;;
        2)
            docker logs -f "$container_id"
            ;;
        3)
            docker logs "$container_id"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
}

# Execute bash in container
exec_bash() {
    local container_id="$1"
    local container_name="$2"
    
    echo -e "${BLUE}Executing bash in $container_name${NC}"
    echo "Trying different shells..."
    
    # Try different shells in order of preference
    if docker exec -it "$container_id" bash 2>/dev/null; then
        return
    elif docker exec -it "$container_id" sh 2>/dev/null; then
        return
    else
        echo -e "${RED}Could not execute shell in container${NC}"
    fi
}

# Execute custom command
exec_custom_command() {
    local container_id="$1"
    local container_name="$2"
    
    echo -e "${BLUE}Execute custom command in $container_name${NC}"
    read -r -p "Enter command: " custom_cmd
    
    if [ -n "$custom_cmd" ]; then
        echo -e "${YELLOW}Executing: $custom_cmd${NC}"
        docker exec -it "$container_id" "$custom_cmd"
    else
        echo -e "${RED}No command entered${NC}"
    fi
}

# ==================
# MAIN
# ==================

# Main loop
main() {
    check_dependencies
    check_docker
    
    while true; do
        echo -e "${GREEN}=== Docker Container Manager ===${NC}"
        
        # Select container
        selected=$(select_container)
        
        if [ -z "$selected" ]; then
            echo -e "${YELLOW}No container selected. Exiting.${NC}"
            exit 0
        fi
        
        container_id=$(get_container_id "$selected")
        container_name=$(get_container_name "$selected")
        
        # Action loop for selected container
        while true; do
            echo
            show_actions "$container_name"
            read -r -p "Enter choice: " action
            
            case $action in
                1)
                    stop_container "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    break  # Go back to container selection since container is stopped
                    ;;
                2)
                    restart_container "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    ;;
                3)
                    view_logs "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    ;;
                4)
                    exec_bash "$container_id" "$container_name"
                    ;;
                5)
                    exec_custom_command "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    ;;
                6)
                    break  # Go back to container selection
                    ;;
                q|Q)
                    echo -e "${GREEN}Goodbye!${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid choice. Please try again.${NC}"
                    ;;
            esac
        done
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Operation cancelled${NC}"; exit 0' INT

# Run main function
main "$@"
