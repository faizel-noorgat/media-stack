#!/bin/bash

# Set variables
USER_NAME="faizel"  # Change this if needed
USER_ID=1000
GROUP_ID=1000

MOUNT_POINTS=(
    "/mnt/downloads"
    "/mnt/movies"
    "/mnt/series"
)

NFS_SERVER="192.168.1.12"  # Your actual NFS server IP
NFS_SHARES=(
    "/mnt/Loci201DataLake/Media/Downloads"
    "/mnt/Loci201DataLake/Media/Movies"
    "/mnt/Loci201DataLake/Media/Series"
)

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

echo "🔧 Ensuring user $USER_NAME has UID 1000..."

# Check if user exists, otherwise create it
if id "$USER_NAME" &>/dev/null; then
    echo "✅ User $USER_NAME already exists."
else
    echo "⚠️ User $USER_NAME not found. Creating user..."
    useradd -u $USER_ID -g $GROUP_ID -m -s /bin/bash $USER_NAME
    echo "✅ User $USER_NAME created with UID $USER_ID."
fi

# Ensure home folder permissions are correct
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME

echo "🔧 Creating mount directories..."
for MOUNT in "${MOUNT_POINTS[@]}"; do
    if [[ ! -d "$MOUNT" ]]; then
        mkdir -p "$MOUNT"
        echo "✅ Created $MOUNT"
    else
        echo "✅ $MOUNT already exists."
    fi
done

echo "🔧 Updating /etc/fstab for persistent mounts..."

# Backup fstab before modifying
cp /etc/fstab /etc/fstab.backup-$(date +%F-%T)

# Add NFS mounts to fstab if not already present
for i in "${!MOUNT_POINTS[@]}"; do
    if ! grep -qs "${MOUNT_POINTS[$i]}" /etc/fstab; then
        echo "$NFS_SERVER:${NFS_SHARES[$i]} ${MOUNT_POINTS[$i]} nfs defaults,_netdev 0 0" >> /etc/fstab
        echo "✅ Added ${MOUNT_POINTS[$i]} to fstab."
    else
        echo "✅ ${MOUNT_POINTS[$i]} already in fstab."
    fi
done

echo "🔧 Mounting all filesystems..."
mount -a

echo "🔧 Setting correct permissions..."
chown -R $USER_NAME:$USER_NAME /mnt/*
chmod -R 775 /mnt/*

echo "✅ All mounts and permissions are set! Reboot recommended."
