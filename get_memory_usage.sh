#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v PODMAN_PROCESS_ANALYSIS_TOOL_PATH ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); PODMAN_PROCESS_ANALYSIS_TOOL_PATH=$(realpath --canonicalize-missing ${scriptpath}/${relativepath}); fi

# Include Library
source "${PODMAN_PROCESS_ANALYSIS_TOOL_PATH}/text_utils.sh"


# Only vsz is available through the podman top wrapper, NOT pss/rss/trs/uss:
# podman top CONTAINER_NAME_OR_ID pid hpid user huser group hgroup groups vsz

# On the other Hand. these don't work and return incomplete Information if an invalid Field is requested
# No Warning/Error is however emitted
#
# This Command returns some Mapping Information between Host and Container as well as the VSZ Memory Usage
# Other Fields such as pss/rss/trs/uss are NOT exposed and therefore we need a wrapper around it anyways
#
# podman top CONTAINER_NAME_OR_ID pid hpid user huser hpid hgroup group stime vsz
#
# podman top CONTAINER_NAME_OR_ID pid hpid user huser hpid hgroup group stime


# Clean NULL Byte Characters and translate it into Whitespace
clean_null_byte() {
    cat < /dev/stdin | tr '\000' ' '
}

# Get Containers in Pod
get_pod_containers() {
    # Input Arguments
    local lpodname="$1"
}

# Get Pod Property
get_pod_property() {
    # Input Arguments
    local lpodname="$1"
    local lpropertyname="$2"
}

# Get Container Property
get_container_property() {
    # Input Arguments
    local lcontainername="$1"
    local lpropertyname="$2"

    podman container inspect "${lcontainername}" -f "{{.${lpropertyname}}}"
}

# Get Host Process List
get_host_process_list() {
    # Input Arguments
    # ...

    ps --no-headers -eo pid,uid,gid,cgroup,cgroupns,netns,pidns,userns,utsns,%cpu,%mem,pcpu,rss,vsz,cmd,comm
}

# Get Host Process Field
get_host_process_field() {
    # Input Arguments
    local lpid="$1"
    local lfield="$2"

    ps --no-headers -q "${lpid}" -eo "${lfield}"
}

# Get CRUN Information
get_crun_container_list() {
    crun list --format=json
}

# Add to Process List
add_to_process_list() {
    # Input Arguments
    local lpid="$1"

    # Add to Array
    processes+=(format_process "${lpid}")
}

# Format Host Process into a standardized Representation
format_host_process() {
    # Input Arguments
    local lhostpid="$1"

    # 
}

# Scan Processes
scan_processes() {
    # Input Arguments
    local lrootpid="$1"


}

# Get Process Children PID
get_process_children() {
    # Input Arguments
    local lparentpid="$1"
}

# Get Container PID from Host PID
# https://docs.kernel.org/filesystems/proc.html
#
# NStgid: descendant namespace thread group ID hierarchy
# NSpid: descendant namespace process ID hierarchy
# NSpgid: descendant namespace process group ID hierarchy
# NSsid: descendant namespace session ID hierarchy
#
get_container_pid_from_host_pid() {
    # Input Arguments
    local lhostpid="$1"

    # Get PID inside Namespace
    local lcontainerpid
    lcontainerpid=$(cat "/proc/${lhostpid}/status" | grep -E "^NSpid:" | sed -E "s|^NSpid:\s+[0-9]+\s+([0-9]+)$|\1|")

    # Return Value
    echo "${lcontainerpid}"
}

# Get Host PID from Container PID
get_host_pid_from_container_pid() {
    # Input Arguments
    local lcontainerpid="$1"
    local lcontainername="$2"


}

# Define Pod
pod_name="<podname>"

# Initialize Array
processes=()

# Get all Containers in the Pod
mapfile -t pod_containers < <( podman pod inspect "${pod_name}" -f '{{range .Containers}}{{.Name}}\n{{end}}' | head -n-1 )

# Echo
echo -e "Analysing Pod ${pod_name}"

# Loop over all Containers
for pod_container in "${pod_containers[@]}"
do
    # Alias
    container_name="${pod_container}"

    # Echo
    indent_text_1 "- ${container_name}"

    # Get Container Properties
    container_id=$(get_container_property "${container_name}" "Id")
    container_cgroup_parent=$(get_container_property "${container_name}" "HostConfig.CgroupParent")
    container_pid=$(get_container_property "${container_name}" "State.Pid")

    # Debug
    indent_text_2 "- container_Id: ${container_id}"
    indent_text_2 "- container_CgroupParent: ${container_cgroup_parent}"
    indent_text_2 "- container_CgroupFolder: /sys/fs/cgroup/${container_cgroup_parent}/"
    indent_text_2 "- container_Pid: ${container_pid}"

    # Get Children Processes
    mapfile -t container_child_processes < <( find "/proc/${container_pid}/task" -maxdepth 1 -mindepth 1 -type d -print0 | xargs -0 -n1 basename )

    indent_text_2 "- Children Processes (Direct): ${#container_child_processes[@]}"
    for container_child_process in "${container_child_processes[@]}"
    do
        container_child_process_pid="${container_child_process}"
        container_child_process_path="/proc/${container_pid}/task/${container_child_process_pid}"
        # container_child_process_cmdline=$(cat "/proc/${container_pid}/task/${container_child_process_pid}/cmdline" | sed -E "s|x\0|\s|g" )
        container_child_process_cmdline=$(cat "/proc/${container_pid}/task/${container_child_process_pid}/cmdline" | tr '\000' ' ' )

        # Only show this if there are indeed children Processes
        #indent_text_2 "*"
        #indent_text_3 "- pid: ${container_child_process_pid}"
        #indent_text_3 "- path: ${container_child_process_path}"

        indent_text_3 "*"
        indent_text_4 "- pid_host: ${container_child_process_pid}"
        pid_container=$(get_container_pid_from_host_pid "${container_child_process_pid}")
        indent_text_4 "- pid_container: ${pid_container}"
        indent_text_4 "- path: ${container_child_process_path}"
        indent_text_4 "- cmdline: ${container_child_process_cmdline}"

        # Get list of Children Processes
        # mapfile -t -d" " container_child_subprocesses < <( cat "/proc/${container_pid}/task/${container_child_process_pid}/children" | sed -E "s|^([0-9 ]+)\n\$|\1|" | tr -d '\0' | awk -F" " '{$1=$1; print}' )
        mapfile -t -d" " container_child_subprocesses < <( cat "/proc/${container_pid}/task/${container_child_process_pid}/children" | sed -E "s|^([0-9 ]+)\n\$|\1|" | tr -d '\0' )

        if [ ${#container_child_subprocesses[@]} -gt 0 ]
        then
            # Only show this if there are indeed children Processes

            indent_text_5 "- Children Process (Forked): ${#container_child_subprocesses[@]}"

            # Debug
            #indent_text_6 "* /proc/${container_pid}/task/${container_child_process_pid}/children"

            for container_child_subprocess in "${container_child_subprocesses[@]}"
            do
                indent_text_6 "*"

                container_child_subprocess_pid="${container_child_subprocess}"
                indent_text_7 "- pid_host: ${container_child_subprocess_pid}"

                pid_container=$(get_container_pid_from_host_pid "${container_child_subprocess_pid}")
                indent_text_7 "- pid_container: ${pid_container}"

                container_child_subprocess_cmdline_file="/proc/${container_child_subprocess_pid}/cmdline"

                container_child_subprocess_cmdline=$(cat "${container_child_subprocess_cmdline_file}" | tr -d '\0')

                indent_text_7 "- cmdline: ${container_child_subprocess_cmdline}"

                container_child_subprocess_comm=$(get_host_process_field "${container_child_subprocess_pid}" "comm")
                indent_text_7 "- comm: ${container_child_subprocess_comm}"

                container_child_subprocess_rss=$(get_host_process_field "${container_child_subprocess_pid}" "rss")
                container_child_subprocess_vsz=$(get_host_process_field "${container_child_subprocess_pid}" "vsz")

                container_child_subprocess_cpu_percent=$(get_host_process_field "${container_child_subprocess_pid}" "%cpu")

                indent_text_7 "- rss: ${container_child_subprocess_rss} kB"
                indent_text_7 "- vsz: ${container_child_subprocess_vsz} kB"
                indent_text_7 "- %cpu: ${container_child_subprocess_cpu_percent} %"
            done
        fi
    done

    # Get list of Processes
done
