#!/bin/bash

# Variables based on seedbox folders
# Here : all files are downloaded in /downloads and 2 folders : Movies and Series have been created below the same folder
SOURCE_DIR="/downloads"
FILM_DIR="Movies"
SERIE_DIR="Series"

# Create the folders if they don't exist
[ ! -d "$SOURCE_DIR/$FILM_DIR" ] && mkdir -p "$SOURCE_DIR/$FILM_DIR"
[ ! -d "$SOURCE_DIR/$SERIE_DIR" ] && mkdir -p "$SOURCE_DIR/$SERIE_DIR"

# Extensions to consider
MEDIA_EXT="mp4|mkv|avi|mov"

# List all media files and ignore other files/folders
find "$SOURCE_DIR" -type f -regextype posix-extended -regex ".*\.($MEDIA_EXT)$" \
        -not -path "*/Apps/*" \
        -not -path "*/watch/*" \
        -not -path "*/rclone-mnt/*" \
        -not -path "*/OpenVPN/*" \
        -not -path "*/Series/*" \
        -not -path "*/Movies/*" \
        | while read -r file; do
  # For each file, check of it is a serie, if not it is a movie
  # Detection process :
  # - Check if the file is a serie : if it contains S[0-9]{1,2}E[0-9]{1,2} or [0-9]{1,2}x[0-9]{1,2}
  # - If not, it is a movie

  filename=$(basename "$file")
  dirname=$(dirname "$file" | sed -e "s|^$SOURCE_DIR|..|g")

  # Series detection patterns:
  # - S01E12 : S followed by 1-2 digits (season) + E followed by 1-3 digits (episode)
  # - 1x12 : 1-2 digits (season) + x + 1-3 digits (episode)
  # - Season 1 : "Season" + optional space + 1-2 digits (season)
  # - Saison 1 : "Saison" + optional space + 1-2 digits (season)
  if echo "$filename" | grep -Eiq 'S[0-9]{1,2}E[0-9]{1,3}|[0-9]{1,2}x[0-9]{1,3}|Season[._ ][0-9]{1,2}|Saison[._ ][0-9]{1,2}|VOL[0-9]{1,2}|Vol[._ ][0-9]{1,2}|vol[._ ][0-9]{1,2}|Volume[._ ][0-9]{1,2}|volume[._ ][0-9]{1,2}|- [0-9]{1,2} '; then
    # Serie section
    
    if echo "$filename" | grep -Eiq '[sS][0-9]{1,2}'; then
      # Reset dirname
      series_name=$(echo "$filename" | sed -E 's/[._ ][sS][0-9]{1,2}.*$//i' | sed -e 's/ /\./g')
      [ ! -d "$SOURCE_DIR/$SERIE_DIR/$series_name" ] && mkdir "$SOURCE_DIR/$SERIE_DIR/$series_name"
      dirname=$(dirname "$file" | sed -e "s|^$SOURCE_DIR|../..|g")
      # Set src and target for symlink
      src_file="$dirname/$filename"
      target="$SERIE_DIR/$series_name/$filename"
      # Check if the symlink file already exists in the target directory
      if [ ! -e "$SOURCE_DIR/$SERIE_DIR/$series_name/$filename" ]; then
        # If not, create a symlink to the source file
        ln -s "$src_file" "$target"
      fi

    elif echo "$filename" | grep -Eiq '[0-9]{1,2}x[0-9]{1,3}'; then
      # Reset dirname
      if echo "$dirname" | grep -Eiq 'titans'; then
        series_name="L'attaque.des.titans"
      elif echo "$dirname" | grep -Eiq '[Ss][._ ]*[0-9]{1,2}'; then
        series_name=$(echo "$dirname" | sed -E 's/[._ ][sS][0-9]{1,2}.*$//i' | sed -e 's/^..\///g' | sed -e 's/ /\./g')
      fi
      [ ! -d "$SOURCE_DIR/$SERIE_DIR/$series_name" ] && mkdir "$SOURCE_DIR/$SERIE_DIR/$series_name"
      dirname=$(dirname "$file" | sed -e "s|^$SOURCE_DIR|../..|g")
      # Set src and target for symlink
      src_file="$dirname/$filename"
      target="$SERIE_DIR/$series_name/$filename"
      # Check if the symlink file already exists in the target directory
      if [ ! -e "$SOURCE_DIR/$SERIE_DIR/$series_name/$filename" ]; then
        # If not, create a symlink to the source file
        ln -s "$src_file" "$target"
      fi

    elif echo "$filename" | grep -Eiq 'VOL[0-9]{1,2}'; then
      # Reset dirname
      if echo "$dirname" | grep -Eiq 'titans'; then
        series_name=$(echo "$dirname" | sed -E 's/[._ ][Ss]aison[._ ][0-9]{1,2}.*$//i' | sed -e 's|../||g' | sed -e 's/ /\./g')
      elif echo "$dirname" | grep -Eiq 'VOL[._ ]*[0-9]{1,2}'; then
        series_name=$(echo "$dirname" | sed -E 's/[._ ]VOL[0-9]{1,2}.*$//i' | sed -e 's|../||g' | sed -e 's/ /\./g')
      elif echo "$dirname" | grep -Eiq 'Saison[ ]*[0-9]{1,2}'; then
        series_name=$(echo "$dirname" | sed -E 's/[._ ][Ss]aison[._ ][0-9]{1,2}.*$//i' | sed -e 's|../||g' | sed -e 's/ /\./g')
      fi
      dirname=$(dirname "$file" | sed -e "s|^$SOURCE_DIR|../..|g")
      [ ! -d "$SOURCE_DIR/$SERIE_DIR/$series_name" ] && mkdir "$SOURCE_DIR/$SERIE_DIR/$series_name"
      # Set src and target for symlink
      src_file="$dirname/$filename"
      target="$SERIE_DIR/$series_name/$filename"
      # Check if the symlink file already exists in the target directory
      if [ ! -e "$SOURCE_DIR/$SERIE_DIR/$series_name/$filename" ]; then
        # If not, create a symlink to the source file
        ln -s "$src_file" "$target"
      fi

    elif echo "$filename" | grep -Eiq '[0-9]{1,2} '; then
      # Specific use case : Check if folder exist and if there is more than 2 media files into the folder to confirm the serie
      if [ $(find $(dirname "$file") -maxdepth 1 -type f -regextype posix-extended -regex ".*\.($MEDIA_EXT)$" ! -regex ".*\.($IGNORE_EXT)$" -not -path "*/\($IGNORE_DIR\)/*" | wc -l) -gt 2 ]; then
        # At least to media files so, it's a serie
        series_name=$(dirname "$file" | sed -e "s|^$SOURCE_DIR/||g" | sed -E 's/[._][ ]-[ ][0-9]{1,2} .*$//i' | sed -e 's/ /\./g')
        [ ! -d "$SOURCE_DIR/$SERIE_DIR/$series_name" ] && mkdir "$SOURCE_DIR/$SERIE_DIR/$series_name"

        # Set src and target for symlink
        dirname=$(dirname "$file" | sed -e "s|^$SOURCE_DIR|../..|g")
        src_file="$dirname/$filename"
        target="$SERIE_DIR/$series_name/$filename"

        # Check if the symlink file already exists in the target directory
        if [ ! -e "$SOURCE_DIR/$SERIE_DIR/$series_name/$filename" ]; then
          # If not, create a symlink to the source file
          ln -s "$src_file" "$target"
        fi
      else
        # not a serie but movie
        # Set src and target for symlink    
        src_file="$dirname/$filename"
        target="$FILM_DIR/$filename"

        # Check if the symlink file already exists in the target directory
        if [ ! -e "$target" ]; then
          # If not, create a symlink to the source file
          ln -s "$src_file" "$target"
        fi
      fi
    else
      echo "unknown filter"
    fi
    
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

# Clean broken symlinks in both directories
#for dir in "$FILM_DIR" "$SERIE_DIR"; do
#    find "$dir" -type l | while read -r symlink; do
#        if [ ! -e "$(readlink "$symlink")" ]; then
#            rm "$symlink"
#        fi
#    done
#done

# Remove empty directories under SERIE_DIR
find "$SERIE_DIR" -type d -empty -not -path "$SERIE_DIR" | while read -r empty_dir; do
    rmdir "$empty_dir"
done
