#!/bin/bash

# Set the Rotation Period 
rotation_period="$1"

# Set the remote host and directory path
Remote_Host="192.168.233.16"
Remote_Dir="/mnt/nfs_shares/vrli-archive/"

# Set the local mount point path
Local_Mount_Point="/mnt/vrli-archive/"

# Set the log file path
Log_File="/var/log/RotateOldervRLIArchiveFiles.log"

# Define a function to log messages
function log_message {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$Log_File"
  echo "$1"
}

function mount_Remote_Directory {
  if [ ! -d "$Local_Mount_Point" ]; then
    log_message "Error: local mount point directory $Local_Mount_Point does not exist."
    # Create the local mount point directory if it does not exist
    mkdir -p "$Local_Mount_Point"
  fi
  
  if ! mountpoint -q "$Local_Mount_Point"; then
    log_message "Mounting remote directory $Remote_Dir on $Local_Mount_Point..."
    if sudo mount -o rw,user "$Remote_Host:$Remote_Dir" "$Local_Mount_Point"; then # Mount the mount point with rw permission
      log_message "Mounted remote directory $Remote_Dir on $Local_Mount_Point."
    else
      log_message "Error mounting remote directory $Remote_Dir on $Local_Mount_Point."
      exit 1
    fi
  else
    log_message "Remote directory $Remote_Dir is already mounted on $Local_Mount_Point."
  fi
}

# Define a function to set the Rotation Period
function Rotation_Period {
  # Number of days as a Rotation Period
  local rotation_period="$1"
  echo "Rotation period: $rotation_period"
  
  if [ -z "$rotation_period" ]; then
    log_message "Error: rotation period argument is missing."
    exit 1
  fi 

  if ! [[ "$rotation_period" =~ ^[1-9][0-9]*$ ]]; then
    log_message "Invalid rotation period: $rotation_period"
    exit 1
  fi
  
  if (( rotation_period < 1 || rotation_period > 365 )); then
    log_message "Rotation period must be between 1 and 365 days."
    exit 1
  fi
}

function delete_old_files {
  # Get the total size of all files
  total_size=$(du -sb "$Local_Mount_Point" | awk '{print $1}')

  # Get the total size of all files older than the rotation period
  old_files_size=$(find "$Local_Mount_Point" -type f -not -newermt "-$rotation_period days" -printf '%s\n' | awk '{total += $1} END {print total}')

  # List all files older than the rotation period and their sizes
  log_message "List of files older than $rotation_period days:"
  find "$Local_Mount_Point" -type f -not -newermt "-$rotation_period days" -printf '%s %p\n' | while read -r size file; do
    size="${size%" "}"  # Remove the space before the size value
    log_message "$file - $(($size/1024)) KB"
  done

  # Delete files older than the rotation period and count the number of files deleted
  num_files_deleted=$(find "$Local_Mount_Point" -depth -type f -not -newermt "-$rotation_period days" -delete -print | wc -l)

  # Verify that the number of files deleted
  if [ "$num_files_deleted" -eq 0 ]; then
    log_message "No files deleted from $Local_Mount_Point."
    return 0
  else
    log_message "Deleting files older than $rotation_period days from $Local_Mount_Point..."
	log_message "Deleted $num_files_deleted files from $Local_Mount_Point."
  fi

  # Get the total size of all files after deletion
  new_total_size=$(du -sb "$Local_Mount_Point" | awk '{print $1}')

  # Calculate the amount of space saved
  space_saved=$((total_size - new_total_size))

  # Verify that the space saved calculation is accurate
  if [ "$space_saved" -lt 0 ]; then
    log_message "Error: Space saved calculation is inaccurate. Expected positive value but got $space_saved."
    exit 1
  else
    # Calculate the amount of space saved in MB and GB
    space_saved_mb=$((space_saved / 1024**2))
    space_saved_gb=$((space_saved / 1024**3))

    # Check if space saved is greater than 1 GB, display in GB. Otherwise, display in MB
    if [ "$space_saved_gb" -gt 0 ]; then
      space_saved_bytes=$((space_saved * 1024**2))
      log_message "Deleted $num_files_deleted files from $Local_Mount_Point, saving $space_saved_gb GB of disk space."
    else
      space_saved_bytes=$((space_saved * 1024))
      log_message "Deleted $num_files_deleted files from $Local_Mount_Point, saving $space_saved_mb MB of disk space."
    fi
  fi
}

# Define a function to unmount the remote directory
function unmount_Remote_Directory {
  if mountpoint -q "$Local_Mount_Point"; then
    log_message "Unmounting remote directory $Remote_Dir from $Local_Mount_Point..."
    if sudo umount "$Local_Mount_Point"; then
      log_message "Unmounted remote directory $Remote_Dir from $Local_Mount_Point."
    else
      log_message "Error unmounting remote directory $Remote_Dir from $Local_Mount_Point."
      exit 1
    fi
  fi
}

# Function to handle errors
function handle_error {
  local error_code="$?"
  local error_message="$1"

  log_message "ERROR: $error_message (exit code $error_code)"
  exit "$error_code"
}

# Trap errors and call handle_error function
trap 'handle_error "Script aborted due to an error"' ERR

# Mount the remote directory
mount_Remote_Directory

# Call the function to set the Rotation Period
Rotation_Period "$1"

# Delete old files
delete_old_files "$rotation_period"

# Unmount the remote directory
unmount_Remote_Directory