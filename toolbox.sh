#!/usr/bin/env bash
# @name toolbox.sh
# @brief **toolbox.sh** is a utility script for installing the SonarQube dev environment.

CURRENT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$CURRENT_PATH/docker.env"

# Global variables
HELP=0 INIT=0 START=0 STOP=0 CLEAN=0 DISPLAY_LOGS=0 VERBOSE=0
ECOCODE_JAVA_PLUGIN_JAR="$CURRENT_PATH/target/ecocode-java-plugin-$ECOCODE_JAVA_PLUGIN_VERSION-SNAPSHOT.jar"

declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[0;33m'
    [BLUE]='\033[0;34m'
    [WHITE]='\033[0;37m'
    [NOCOLOR]='\033[0;0m'
)

function info() {
    echo -e "${COLORS[WHITE]}$*${COLORS[NOCOLOR]}"
}

function debug() {
    [[ $VERBOSE -gt 0 ]] && echo -e "${COLORS[BLUE]}$*${COLORS[NOCOLOR]}"
}

function error() {
    echo -e "${COLORS[RED]}$*${COLORS[NOCOLOR]}"
}

# @description Building the ecoCode plugin and creating containers.
# @noargs
# @exitcode 0 If successful.
# @exitcode 1 If the ecoCode plugin is not present in the target folder.
function init() {
    # Building project code in the target folder if necessary
    if [[ ! -f "$ECOCODE_JAVA_PLUGIN_JAR" ]]; then
        info "Building project code in the target folder"
        debug "mvn clean package -DskipTests"
        mvn clean package -DskipTests
    fi
    # Check that the plugin is present in the target folder
    if ! [[ -f $ECOCODE_JAVA_PLUGIN_JAR ]]; then
        error "Cannot find ecoCode plugin in target directory" && return 1
    fi
    # Creating and starting Docker containers from the docker-compose.yml file
    info "Creating and starting Docker containers"
    debug "docker compose --env-file $CURRENT_PATH/docker.env -f $CURRENT_PATH/docker-compose.yml up --build -d"
    docker compose --env-file "$CURRENT_PATH/docker.env" -f "$CURRENT_PATH/docker-compose.yml" up --build -d
    return 0
}

# @description Starting Docker containers.
# @noargs
# @exitcode 0 If successful.
# @exitcode 1 If the ecoCode plugin is not present in the target folder.
function start() {
    # Check that the plugin is present in the target folder
    if ! [[ -f $ECOCODE_JAVA_PLUGIN_JAR ]]; then
        error "Cannot find ecoCode plugin in target directory" && return 1
    fi
    info "Starting Docker containers"
    debug "docker compose --env-file $CURRENT_PATH/docker.env -f $CURRENT_PATH/docker-compose.yml start"
    docker compose --env-file "$CURRENT_PATH/docker.env" -f "$CURRENT_PATH/docker-compose.yml" start
    return 0
}

# @description Stopping Docker containers.
# @noargs
# @exitcode 0 If successful.
function stop() {
    info "Stopping Docker containers"
    debug "docker compose --env-file $CURRENT_PATH/docker.env -f $CURRENT_PATH/docker-compose.yml stop"
    docker compose --env-file "$CURRENT_PATH/docker.env" -f "$CURRENT_PATH/docker-compose.yml" stop
    return 0
}

# @description Stop and remove containers, networks and volumes.
# @noargs
# @exitcode 0 If successful.
function clean() {
    info "Remove Docker containers, networks and volumes"
    debug "docker compose --env-file $CURRENT_PATH/docker.env -f $CURRENT_PATH/docker-compose.yml down --volumes"
    docker compose --env-file "$CURRENT_PATH/docker.env" -f "$CURRENT_PATH/docker-compose.yml" down --volumes
    return 0
}

# @description Display Docker container logs.
# @noargs
# @exitcode 0 If successful.
function display_logs() {
    info "Display Docker container logs"
    debug "docker compose --env-file $CURRENT_PATH/docker.env -f $CURRENT_PATH/docker-compose.yml logs -f"
    docker compose --env-file "$CURRENT_PATH/docker.env" -f "$CURRENT_PATH/docker-compose.yml" logs -f
    return 0
}

# @description Check if docker is correctly installed.
# @noargs
# @exitcode 0 If successful.
# @exitcode 1 If docker is not installed.
# @exitcode 2 If the docker compose module is not installed.
# @exitcode 3 If the minimum version is not installed.
function check_env_docker() {
    # Check if docker is installed
    ! [[ -x "$(command -v docker)" ]] && error "Please install docker" && return 1
    # Check if the docker compose module is installed
    if ! [[ -x "$(command -v docker compose|tail -n1|grep compose)" ]]; then
        error "Please install docker compose module" && return 2
    fi
    # Check docker compose version
    local dc_version_major dc_version_current
    dc_version_major=$(docker compose  version  --short | cut -d '.' -f 1)
    dc_version_current=$(docker compose  version  --short)
    if [[ $dc_version_major -lt 2 ]]; then
      error "$dc_version_current is not a supported docker compose version, please upgrade to the minimum supported version: 2.0"
      return 3
    fi
    return 0
}

# @description Check local environment.
# @noargs
# @exitcode 0 If successful.
# @exitcode 1 If docker is not correctly installed.
# @exitcode 2 If java is not installed.
# @exitcode 3 If maven is not installed.
function check_env() {
    # Check if docker is correctly installed.
    debug "Check if docker is correctly installed"
    ! check_env_docker && return 1
    # Check if java is installed
    debug "Check if java is installed"
    ! [[ -x "$(command -v javap)" ]] && error "Please install java" && return 2
    # Check if maven is installed
    debug "Check if maven is installed"
    ! [[ -x "$(command -v mvn)" ]] && error "Please install maven" && return 3
    return 0
}

# @description Check options passed as script parameters.
# @noargs
# @exitcode 0 If successful.
function check_opts() {
    read -ra opts <<< "$@"
    local skip_check_opts=0;
    for opt in "${opts[@]}"; do
        if [[ $skip_check_opts -eq 0 ]]; then
            case "$opt" in
                -h|--help) HELP=1 ;;
                -i|--init) INIT=1 ;;
                -s|--start) START=1 ;;
                -t|--stop) STOP=1 ;;
                -c|--clean) CLEAN=1 ;;
                -l|--logs) DISPLAY_LOGS=1 ;;
                -v|--verbose) VERBOSE=1 ;;
                *) CMD_DOCKER+=("$opt") && skip_check_opts=1 ;;
            esac
        else
            CMD_DOCKER+=("$opt")
        fi
    done
    # Help is displayed if no option is passed as script parameter
    if [[ $((HELP+INIT+START+STOP+CLEAN+DISPLAY_LOGS+${#CMD_DOCKER[@]})) -eq 0 ]]; then
        HELP=1
    fi
    return 0
}

# @description Execute tasks based on script parameters or user actions.
# @noargs
# @exitcode 0 If successful.
# @exitcode 1 If an error has been encountered displaying help.
# @exitcode 2 If an error was encountered while initialize docker compose.
# @exitcode 3 If an error is encountered when starting Docker containers.
# @exitcode 4 If an error is encountered when stopping Docker containers.
# @exitcode 5 If an error is encountered when cleaning Docker containers.
# @exitcode 5 If an error is encountered when displaying Docker logs.
function execute_tasks() {
    # Display help
    if [[ $HELP -gt 0 ]]; then
        ! display_help && return 1
        return 0
    fi
    # Building the ecoCode plugin and creating Docker containers
    if [[ $INIT -gt 0 ]]; then
        ! init && return 2
    fi
    # Starting Docker containers
    if [[ $START -gt 0 ]]; then
        ! start && return 3
    fi
    # Stopping Docker containers
    if [[ $STOP -gt 0 ]]; then
        ! stop && return 4
    fi
    # Stop and remove containers, networks and volumes
    if [[ $CLEAN -gt 0 ]]; then
        ! clean && return 5
    fi
    # Display Docker container logs
    if [[ $DISPLAY_LOGS -gt 0 ]]; then
        ! display_logs && return 6
    fi
    return 0
}

# @description Display help.
# @noargs
# @exitcode 0 If successful.
function display_help() {
    local output=""
    output="
${COLORS[YELLOW]}Usage${COLORS[WHITE]} $(basename "$0") [OPTION]
${COLORS[YELLOW]}Options:${COLORS[NOCOLOR]}
  ${COLORS[GREEN]}-h, --help${COLORS[WHITE]}            Display help
  ${COLORS[GREEN]}-i, --init${COLORS[WHITE]}            Building the ecoCode plugin and creating containers
  ${COLORS[GREEN]}-s, --start${COLORS[WHITE]}           Starting Docker containers
  ${COLORS[GREEN]}-t, --stop${COLORS[WHITE]}            Stopping Docker containers
  ${COLORS[GREEN]}-s, --clean${COLORS[WHITE]}           Stop and remove containers, networks and volumes
  ${COLORS[GREEN]}-s, --logs${COLORS[WHITE]}            Display Docker container logs
  ${COLORS[GREEN]}-v, --verbose${COLORS[WHITE]}         Make the command more talkative
    "
    echo -e "$output\n"|sed '1d; $d'
    return 0
}

# @description Main function.
# @noargs
# @exitcode 0 If successful.
# @exitcode 1 If the options check failed.
# @exitcode 2 If the environment check failed.
# @exitcode 3 If task execution failed.
function main() {
    # Check options passed as script parameters and execute tasks
    ! check_opts "$@" && return 1
    ! check_env && return 2
    ! execute_tasks && return 3
    return 0
}

main "$@"
