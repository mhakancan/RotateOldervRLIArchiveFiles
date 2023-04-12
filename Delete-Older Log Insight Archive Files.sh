#!/bin/bash

# Set the remote host and directory path
REMOTE_HOST="root@192.168.233.16"
REMOTE_DIR="/mnt/nfs_shares/vrli-archive/"

# Set the local mount point path
LOCAL_MOUNT_POINT="/mnt/vrli-archive/"

# Mount remote filesystem using SSH key for authentication
sshfs $REMOTE_HOST:$REMOTE_DIR $LOCAL_DIR

# Mount the remote directory over SSH using sshfs
sshfs "$REMOTE_HOST:$REMOTE_DIR" "$LOCAL_MOUNT_POINT"

# Check if the mount point directory exists
if [ -d "$LOCAL_MOUNT_POINT" ]; then
  # List all files on the mount point
  ls -la "$LOCAL_MOUNT_POINT"

  # Delete files older than 15 days and count the number of files deleted
  num_files_deleted=$(find "$LOCAL_MOUNT_POINT" -type f -mtime +15 -depth -exec rm {} \; -print | wc -l)

  # Print success message if files were deleted
  if [ "$num_files_deleted" -gt 0 ]; then
    echo "Files older than 15 days have been deleted from $LOCAL_MOUNT_POINT"
  fi

  # Unmount the remote directory
  umount "$LOCAL_MOUNT_POINT"
else
  # Print error message
  echo "Mount point directory $LOCAL_MOUNT_POINT does not exist."
fi
