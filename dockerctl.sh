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
# FUNCTIONS
# ====================

# Check if Docker daemon is running
check_docker() {
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
}

# Get running containers with status icon
get_containers() {
    # No-op, icons will be added next to the container ID in the output below
    docker ps -a --format "{{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}" | while IFS=$'\t' read -r id image status name; do
        # Determine status icon
        if [[ "$status" == Up* ]]; then
            icon="🟢"
        elif [[ "$status" == Exited* ]]; then
            icon="🔴"
        elif [[ "$status" == Created* ]]; then
            icon="🟡"
        else
            icon="⚪"
        fi
        printf "%s\t%s\t%s\n" "$id" "$icon $name" "$image"
    done
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
    --preview='docker inspect {1} | jq -r " .[] | \"
Id: \(.Id[0:12])
Name: \(.Name[1:])
Created: \(.Created)
Status: \(.State.Status)
Health: \(.State.Health.Status // \"N/A\")
Image: \(.Config.Image)
Restart policy: \(.HostConfig.RestartPolicy.Name)
Binds:
\(
if (.HostConfig.Binds == \{} or .HostConfig.Binds == null) then
    \"- none\"
else
    (.HostConfig.Binds | map(\"- \" + .) | join(\"\n\"))
end
)
Ports:
\(
if (.HostConfig.PortBindings == \{} or .HostConfig.PortBindings == null) then
    \"- none\"
else
    (.HostConfig.PortBindings | to_entries | map(\"- \(.key) (HostPort: \(.value[0].HostPort))\") | join(\"\n\"))
end
)
Networks:
\(
if (.NetworkSettings.Networks == \{} or .NetworkSettings.Networks == null) then
    \"- none\"
else
    (.NetworkSettings.Networks // \{} | keys | map(\"- \" + .) | join(\"\n\"))
end
)
\""' \
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

# Get container name from ID
get_container_name_by_id() {
    local container_id="$1"
    docker inspect -f '{{.Name}}' "$container_id" | sed 's|^/||'  # Remove leading slash
}

# Get the status icon for a container's status
get_status_icon() {
    # Extract the status from docker using the container ID or name as argument
    local status=""
    status=$(docker inspect -f '{{.State.Status}}' "$1")

    if [[ "$status" == "running" ]]; then
        echo "🟢"
    elif [[ "$status" == "exited" ]]; then
        echo "🔴"
    else
        echo "⚪"
    fi
}

# Show action menu
show_actions() {
    clear
    local container_name="$1"
    local container_id="$2"
    local container_image="$3"
    local container_icon=""
    container_icon="$(get_status_icon "$container_id")"
    echo -e "${BLUE}Container: $container_icon $container_name${NC}"
    echo -e "${YELLOW}ID: $container_id${NC}"
    echo -e "${GREEN}Image: $container_image${NC}"
    echo "---------------------------------"
    echo "Choose an action:"
    echo "---------------------------------"
    echo "1) Start container"
    echo "2) Stop container"
    echo "3) Restart container"
    echo "4) Delete container"
    echo "5) View logs"
    echo "6) Exec bash"
    echo "7) Exec custom command"
    echo "8) Export container to tar"
    echo "9) Create image from container"
    echo "b) Back to container selection"
    echo "q) Quit"
}

# Start container
start_container() {
    local container_id="$1"
    local container_name="$2"

    echo -e "${YELLOW}Starting container $container_name...${NC}"
    if docker start "$container_id"; then
        echo -e "${GREEN}Container $container_name started successfully${NC}"
    else
        echo -e "${RED}Failed to start container $container_name${NC}"
    fi
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

# Delete container
delete_container() {
    local container_id="$1"
    local container_name="$2"

    echo -e "${YELLOW}Deleting container $container_name...${NC}"
    if docker rm "$container_id"; then
        echo -e "${GREEN}Container $container_name deleted successfully${NC}"
    else
        echo -e "${RED}Failed to delete container $container_name${NC}"
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

# Export container
export_container() {
    local container_id="$1"
    local container_name="$2"

    read -r -p "Export filename (default: ${container_name}.tar): " export_file
    export_file=${export_file:-"${container_name}.tar"}

    echo -e "${YELLOW}Exporting $container_name to $export_file${NC}"
    docker export "$container_id" > "$export_file"
    echo -e "${GREEN}Container exported successfully${NC}"
}

# Create image from container
create_image() {
    local container_id="$1"
    local container_name="$2"

    read -r -p "New image name: " image_name
    read -r -p "Tag (default: latest): " tag
    tag=${tag:-latest}

    if [[ -n "$image_name" ]]; then
        echo -e "${YELLOW}Creating image $image_name:$tag from $container_name${NC}"
        docker commit "$container_id" "$image_name:$tag"
        echo -e "${GREEN}Image created successfully${NC}"
    fi
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
        container_image=$(get_container_name "$selected")

        # Action loop for selected container
        while true; do
            echo
            container_name=$(get_container_name_by_id "$container_id")
            show_actions "$container_name" "$container_id" "$container_image"
            read -r -p "Enter choice: " action

            case $action in
                1)
                    start_container "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    ;;
                2)
                    stop_container "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    break  # Go back to container selection since container is stopped
                    ;;
                3)
                    restart_container "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    ;;
                4)
                    delete_container "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    break  # Go back to container selection since container is deleted
                    ;;
                5)
                    view_logs "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    ;;
                6)
                    exec_bash "$container_id" "$container_name"
                    ;;
                7)
                    exec_custom_command "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    ;;
                8)
                    export_container "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    ;;
                9)
                    create_image "$container_id" "$container_name"
                    read -r -p "Press Enter to continue..."
                    ;;
                b|B)
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
