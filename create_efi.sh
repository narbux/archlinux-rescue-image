#!/usr/bin/env bash

set -euo pipefail

if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root!"
    exit 1
fi

if [ "$(find mkosi.output -maxdepth 0 -empty 2>/dev/null)" ]; then
    echo "Mkosi.output is empty. Skipping removal."
else
    echo "Cleaning mkosi.output directory."
    rm mkosi.output/*
fi

echo "Creating image"
mkosi build

echo "Removing old image from ESP"
if compgen -G "/efi/EFI/Linux/archlinux-rescue*" > /dev/null; then
    rm /efi/EFI/Linux/archlinux-rescue*
    echo "Removed old image."
else
    echo "No matching files on ESP found. Skipping removal."
fi

# Define the partition and file
partition="/dev/nvme0n1p1"
file="mkosi.output/archlinux-rescue_$(date --utc +%Y%m%d).efi"

# Get the size of the file in bytes
file_size=$(stat -c %s "$file" 2>/dev/null)

# Check if the file exists and its size is valid
if [ -z "$file_size" ] || [ "$file_size" -le 0 ]; then
    echo "Error: File '$file' does not exist or is empty."
    exit 1
fi

# Get the available free space on the partition in bytes
free_space=$(df -B1 "$partition" | awk 'NR==2 {print $4}')

# Check if the partition has enough free space
if [ "$free_space" -lt "$file_size" ]; then
    echo "Error: Not enough free space on $partition to store $file."
    echo "Required: $((file_size / 1024 / 1024)) MB, Available: $((free_space / 1024 / 1024)) MB"
    exit 1
else
    echo "Success: Enough free space on $partition to store $file."
    echo "Required: $((file_size / 1024 / 1024)) MB, Available: $((free_space / 1024 / 1024)) MB"
    echo "Installing image"
    install -m644 -t /efi/EFI/Linux mkosi.output/*.efi
fi

echo "Signing image"
sbctl sign /efi/EFI/Linux/archlinux-rescue*
