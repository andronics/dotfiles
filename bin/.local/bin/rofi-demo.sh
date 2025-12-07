#!/usr/bin/env zsh

# Path for the named pipe
_pipe_path="/tmp/bluetoothrofi-fifo"

# Ensure a clean pipe creation
[ -p "${_pipe_path}" ] && rm "${_pipe_path}"

mkfifo "${_pipe_path}" || { echo "Failed to create pipe"; exit 1; }

# Function to clean up the pipe on exit
cleanup() {
    rm -f "${_pipe_path}"
    exec 3>&-
    echo "Cleaned up."
    exit 0
}
trap cleanup EXIT

# Open the pipe for writing using file descriptor 3
exec 3<>"${_pipe_path}" || { echo "Failed to open pipe"; exit 1; }

# Start Bluetooth scanning
bluetoothctl scan on &

# Capture the PID of the scanning process to kill it later
scan_pid=$!

# Filter and read new devices, then output to the pipe
bluetoothctl monitor | grep --line-buffered "Device" | while read -r line; do
    # Extract MAC address and name
    if [[ "$line" =~ Device\ ([[:xdigit:]:]{17})\ (.*) ]]; then
        mac="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        echo "$name [$mac]" >&3
    fi
done &

# Use rofi in dmenu mode to select a device
selected_device=$(cat <&3 | rofi -dmenu -p "Select Bluetooth Device")

# Kill the scanning process
kill "$scan_pid"

# Extract the MAC address from the selected item
selected_mac=$(echo "$selected_device" | grep -o '[[:xdigit:]:]\{17\}')

# If a device was selected, proceed to pair and trust
if [ -n "$selected_mac" ]; then
    echo "Pairing with $selected_device ($selected_mac)..."
    bluetoothctl pair "$selected_mac"
    bluetoothctl trust "$selected_mac"
    bluetoothctl connect "$selected_mac"
    echo "$selected_device paired and trusted."
else
    echo "No device selected or invalid selection."
fi

# Cleanup (the trap will handle this)




# _pipe_path="/tmp/rofi_fifo"

# # Create pipe with error handling
# [[ -p ${_pipe_path} ]] && rm "${_pipe_path}"
# mkfifo "${_pipe_path}" || { echo "Failed to create pipe"; exit 1; }

# # Open pipe bi-directionally in non-blocking mode using fd
# exec 3<>"${_pipe_path}" || { echo "Failed to open pipe"; exit 1; }


# cat <&3 | rofi -dmenu -p "Select Item" &

# # Function to write items to the pipe
# i=0
# while [[ $i -lt 10 ]]; do
#     echo $RANDOM >&3
#     echo $i $RANDOM
#     echo $$
#     sleep 1
#     i=$((i + 1))
#     sleep 30
# done

# # Close the pipe
# exec 3>&-

# # Clean up
# rm -f "${_pipe_path}"