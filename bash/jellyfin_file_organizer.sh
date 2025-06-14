#!/bin/bash

# Variables based on seedbox folders
# Here : all files are downloaded in /downloads and 2 folders : Movies and Shows have been created below the same folder
SOURCE_DIR="/downloads"
FILM_DIR="${SOURCE_DIR}/Movies"
SERIE_DIR="${SOURCE_DIR}/Shows"

# Create the folders if they don't exist
[ ! -d "$FILM_DIR" ] && mkdir -p "$FILM_DIR"
[ ! -d "$SERIE_DIR" ] && mkdir -p "$SERIE_DIR"

# Extensions to consider
MEDIA_EXT="mp4|mkv|avi|mov"
IGNORE_EXT="meta|nfo"
SRT_EXT="srt"

# Directories to ignore
IGNORE_DIR="Apps|rclone-mnt|watch|OpenVPN|Shows|Movies"

# Function to normalize series name
normalize_series_name() {
    local name="$1"
    # Convert to lowercase
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    # Replace dots, underscores, and multiple spaces with single space
    name=$(echo "$name" | sed -E 's/[._]+/ /g' | sed -E 's/[[:space:]]+/ /g')
    # Trim leading and trailing spaces
    name=$(echo "$name" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    echo "$name"
}

# Function to extract season and episode numbers
extract_season_episode() {
    local filename="$1"
    local season=""
    local episode=""
    
    # Try S01E02 format
    if [[ "$filename" =~ S([0-9]{1,2})E([0-9]{1,3}) ]]; then
        season="${BASH_REMATCH[1]}"
        episode="${BASH_REMATCH[2]}"
    # Try 1x02 format
    elif [[ "$filename" =~ ([0-9]{1,2})x([0-9]{1,3}) ]]; then
        season="${BASH_REMATCH[1]}"
        episode="${BASH_REMATCH[2]}"
    fi
    
    # Pad season and episode numbers with zeros
    season=$(printf "%02d" "$season")
    episode=$(printf "%02d" "$episode")
    
    echo "$season:$episode"
}

# List all media files and ignore other files/folders
find "$SOURCE_DIR" -type f -regextype posix-extended -regex ".*\.($MEDIA_EXT)$" ! -regex ".*\.($IGNORE_EXT)$" -not -path "*/\($IGNORE_DIR\)/*" | while read -r file; do
  # For each file, check of it is a serie, if not it is a movie
  # Detection process :
  # - Check if the file is a serie : if it contains S[0-9]{1,2}E[0-9]{1,2} or [0-9]{1,2}x[0-9]{1,2}
  # - If not, it is a movie

  filename=$(basename "$file")
  dirname=$(dirname "$file" | sed -e "s|^$SOURCE_DIR|../|g")

  # Series detection patterns:
  # - S01E12 : S followed by 1-2 digits (season) + E followed by 1-3 digits (episode)
  # - 1x12 : 1-2 digits (season) + x + 1-3 digits (episode)
  # - Season 1 : "Season" + optional space + 1-2 digits (season)
  # - Saison 1 : "Saison" + optional space + 1-2 digits (season)
  if echo "$filename" | grep -Eiq 'S[0-9]{1,2}E[0-9]{1,3}|[0-9]{1,2}x[0-9]{1,3}|Season[ ]*[0-9]{1,2}|Saison[ ]*[0-9]{1,2}'; then
    # Serie section
    
    # Extract series name from path or filename
    series_name=""
    if [[ "$dirname" != "$SOURCE_DIR" ]]; then
        # Try to get series name from directory
        series_name=$(basename "$dirname")
    else
        # Extract from filename (remove season/episode info)
        series_name=$(echo "$filename" | sed -E 's/[._]S[0-9]{1,2}E[0-9]{1,3}.*$//i' | sed -E 's/[._][0-9]{1,2}x[0-9]{1,3}.*$//i')
    fi
    
    # Normalize series name
    normalized_name=$(normalize_series_name "$series_name")
    
    # Extract season and episode
    season_episode=$(extract_season_episode "$filename")
    season=$(echo "$season_episode" | cut -d':' -f1)
    episode=$(echo "$season_episode" | cut -d':' -f2)
    
    # Create series directory if it doesn't exist
    series_dir="${SERIE_DIR}/${normalized_name}"
    [ ! -d "$series_dir" ] && mkdir -p "$series_dir"
    
    # Create season directory if it doesn't exist
    season_dir="${series_dir}/Season_${season}"
    [ ! -d "$season_dir" ] && mkdir -p "$season_dir"
    
    # Create symlink for the episode
    target="${season_dir}/${normalized_name}_S${season}E${episode}.${filename##*.}"
    if [ ! -e "$target" ]; then
        ln -s "$file" "$target"
    fi
    
    # Store in temporary file for later processing
    echo "$normalized_name|$season|$episode|$file" >> "$TEMP_SERIES"
  else
    # Movie section

    # Set src and target for symlink    
    src_file="$dirname/$filename"
    target="$FILM_DIR/$filename"

    # Check if the symlink file already exists in the target directory
    if [ ! -e "$target" ]; then
      # If not, create a symlink to the source file
      ln -s "$src_file" "$target"
    fi
  fi

done

# Remove the temporary files
rm -f "$TEMP_MOVIES" "$TEMP_SERIES"

# Clean broken symlinks in both directories
for dir in "$FILM_DIR" "$SERIE_DIR"; do
    find "$dir" -type l | while read -r symlink; do
        if [ ! -e "$(readlink "$symlink")" ]; then
            rm "$symlink"
        fi
    done
done

# Remove empty directories under SERIE_DIR
find "$SERIE_DIR" -type d -empty -not -path "$SERIE_DIR" | while read -r empty_dir; do
    rmdir "$empty_dir"
done
