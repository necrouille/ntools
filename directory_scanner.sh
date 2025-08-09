#!/bin/bash

# Parameters
working_dir="/downloads"
movies_dir="Movies"
series_dir="Series"
# Extensions to consider
media_ext="mp4|mkv|avi|mov" 

# Create the folders if they don't exist
[ ! -d "$working_dir/$movies_dir" ] && mkdir -p "$working_dir/$movies_dir"
[ ! -d "$working_dir/$series_dir" ] && mkdir -p "$working_dir/$series_dir"

# List all media files and ignore other files/folders
find "$working_dir" -type f -regextype posix-extended -regex ".*\.($media_ext)$" \
        -not -path "*/Apps/*" \
        -not -path "*/watch/*" \
        -not -path "*/rclone-mnt/*" \
        -not -path "*/OpenVPN/*" \
        -not -path "*/Series/*" \
        -not -path "*/Movies/*" \
        | while read -r file; do

    filename=$(basename "$file")
    dirname=$(dirname "$file" | sed -e "s|^$working_dir|..|g")

    echo $filename
done