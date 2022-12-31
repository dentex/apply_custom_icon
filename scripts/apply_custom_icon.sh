#!/bin/bash

# Shell script for the nemo action `apply_custom_icon`
#
# Requires: xdotool zenity yad convert montage rsvg-convert
# On Linux Mint 21.1 Vera: `sudo apt install zenity yad graphicsmagick-imagemagick-compat librsvg2-bin`


######################
### INIT SOME VARS ###
######################

# Print a title
SCRIPT_TITLE=$(basename "$0")
echo -e "\n@@ $SCRIPT_TITLE @@"

# Store the base dir for future reference
parent_dir_name="$(basename "$(dirname "$1")")"
echo -e "\n-----------------------------\n   Parent directory:\n    $parent_dir_name \n-----------------------------"

# Make a local directory for custom icons, if not existing
ICONS_DIR="$HOME/.icons/apply_custom_icon_script"
mkdir -p $ICONS_DIR

# Define the base folder icon for compositions
base_folder_icon="$ICONS_DIR/_folder.png"

# Maximum number of sub directory levels to search for images
MAX_DEPTH=5
# Initial depth
DEPTH=0

# Zenity progress and its increment based on total dirs to process
pr=0
(( i_pr=100/$# ))


#########################
### DECLARE FUNCTIONS ###
#########################

choose_operation_type() {
  op1a="Montage (1st four images)"
  op1b="Montage (four random images)"
  op2a="1st image"
  op2b="Single random image"
  op3="Choose an image"
  op4="*Restore default*"
  op5="*Refresh base icon*"

  sel_op=$(zenity \
    --width 300 --height 300 --list --title "$SCRIPT_TITLE" \
    --text "Select operation" --radiolist \
    --column "" --column "" TRUE "$op1a" FALSE "$op1b" FALSE "$op2a" FALSE "$op2b" FALSE "$op3" FALSE "$op4" FALSE "$op5" --hide-header)

  # Exit if no selection made
  if [ -z "$sel_op" ]; then
    echo "exiting..." && exit 1
  else
    echo -e "\n-----------------------------\n   Selected operation:\n    $sel_op \n-----------------------------\n"
  fi
}


get_base_folder_icon() {
  ICONS_PATHS=( "/usr/share/icons" "/usr/local/share/icons" "/usr/share/pixmaps" "$HOME/.local/share/icons" "$HOME/.icons" )

  curr_icon_theme=$(gsettings get org.cinnamon.desktop.interface icon-theme)
  curr_icon_theme=${curr_icon_theme%\'}
  curr_icon_theme=${curr_icon_theme#\'}
  echo "=> Icon theme: $curr_icon_theme"


  for p in "${ICONS_PATHS[@]}"; do
    #echo "TESTING: $p"
    if ls $p 2> /dev/null | grep -q $curr_icon_theme; then
      curr_theme_path=$p
      echo "=> System path: $curr_theme_path"
      break
    fi
  done

  if [ -z $curr_theme_path ]; then
    echo "xx Unable to find the current icon-theme path"
    # Manual fallback
    folder_icon_path=$(yad --width 750 --height 750 \
                       --file --add-preview --filename=$HOME/$USER \
                       --file-filter="folder.svg folder.png" --title "Choose base folder icon")
    folder_icon_name=$(basename $folder_icon_path)
  else
    places_folder_paths_u=( $(grep -E '(\[places|places\])' "$curr_theme_path/$curr_icon_theme"/index.theme | \
                         grep -E '\[(256x256/places|places/256|places/scalable|128x128@2./places|places/128@2x|128x128/places|places/128)\]') )

    # Eventually put the 256x256 path as 1st to be checked                     
    IFS=$'\n'
    places_folder_paths=($(sort -r <<<"${places_folder_paths_u[*]}"))
    unset IFS
    echo "=> 'Places' folders: ${places_folder_paths[*]}"

    # Scan paths for the folder icon       
    for i in ${places_folder_paths[@]}; do
      i=${i%\]}
      i=${i#\[}

      places_folder_full_path="$curr_theme_path/$curr_icon_theme/$i"
      echo "-- testing $places_folder_full_path"

      folder_icon_name=$(ls $places_folder_full_path | grep -E '^folder(\.png|\.svg)')

      if [ -z $folder_icon_name ]; then
        echo "xx Folder icon not found for path '$i'"
      else
        folder_icon_path="$places_folder_full_path/$folder_icon_name"
        echo "=> Folder icon found: $folder_icon_path"
        break
      fi
    done
  fi
  
  # If SVG, convert in PNG
  if echo "$folder_icon_name" | grep -qi "svg"; then
    echo "-- Converting SVG to PNG"
    rsvg-convert -w 256 -h 256 "$folder_icon_path" -o "$base_folder_icon"
  else
    format=$(identify -format "%wx%h\n" "$folder_icon_path")
    # This should not happen...
    # ...because there's always at least a 256px PNG folder icon
    if [ "$format" != 256x256 ]; then
      echo "-- PNG is not 256x256: resizing...";
      convert -resize 256x256 "$folder_icon_path" "$base_folder_icon"
    else
      echo "-- Format and size OK, just copying"
      cp "$folder_icon_path" "$base_folder_icon"
    fi
  fi
  
  echo ""
}


create_tmp_emblem_op_1to4() {
  TMP_EMBLEM="$ICONS_DIR/EMBLEM_$(basename $1).png"
  
  echo $pr # Zenity percentage
  (( pr=pr+i_pr )) # Increment zenity progress for the next pass
  
  folder_name="$(basename "$i")"
  echo "$(echo "## $folder_name" | cut -c 1-35)..." # Zenity step text

  if [[ "$sel_op" == "$op1a" ]]; then
  
    # Montage (1st four images)
    while [ ${#TOT_IMAGES[@]} -eq 0 ]; do
      (( DEPTH++ ))
      readarray -d $'\0' TOT_IMAGES < <(find -L "$1" -maxdepth "$DEPTH" \( -iname '*.jp*g' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.tif*' \) -print0)
      
      echo "   testing depth $DEPTH"
      echo "   array items: ${#TOT_IMAGES[@]}"
      echo "   -"
      if [ $DEPTH -ge $MAX_DEPTH ]; then break; fi
    done
    
    IFS=$'\n'
    SORTED_IMAGES=($(sort <<<"${TOT_IMAGES[*]}"))
    declare -a TOP4_IMAGES=($(head -n4 <<<"${SORTED_IMAGES[*]}"))
    unset IFS
    DEPTH=0
    
    if [ ${#TOT_IMAGES[@]} -ne 0 ]; then
      montage_images TOP4_IMAGES
      TOT_IMAGES=( )
    else
      STOP=true
      echo "xx No images in $1"
    fi

  elif [[ "$sel_op" == "$op1b" ]]; then
  
    # Montage (four random images)
    while [ ${#TOT_IMAGES[@]} -eq 0 ]; do
      (( DEPTH++ ))
      readarray -d $'\0' TOT_IMAGES < <(find -L "$1" -maxdepth "$DEPTH" \( -iname '*.jp*g' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.tif*' \) -print0)
      
      echo "  testing depth $DEPTH"
      echo "  array items: ${#TOT_IMAGES[@]}"
      echo "  -"
      if [ $DEPTH -ge $MAX_DEPTH ]; then break; fi
    done
    
    IFS=$'\n'
    declare -a SHUF4_IMAGES=($(shuf -n4 <<<"${TOT_IMAGES[*]}"))
    unset IFS
    DEPTH=0
    
    if [ ${#TOT_IMAGES[@]} -ne 0 ]; then
      montage_images SHUF4_IMAGES
      TOT_IMAGES=( )
    else
      STOP=true
      echo "xx No images in $1"
    fi

  elif [[ "$sel_op" == "$op2a" ]]; then
  
    # 1st image
    while [ -z "$IMAGE" ]; do
      (( DEPTH++ ))
      IMAGE=$(find -L "$1" -maxdepth "$DEPTH" -iname '*.jp*g' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.tif*' | sort | head -n1)
      echo "  testing depth $DEPTH"
      echo "  image: $IMAGE"
      echo "  -"
      if [ $DEPTH -ge $MAX_DEPTH ]; then break; fi
    done
    
    DEPTH=0
    
    if [ -f "$IMAGE" ]; then
      convert "$IMAGE" -resize 160x90^ -gravity center -extent 160x90 "$TMP_EMBLEM"
      IMAGE=""
    else
      STOP=true
      echo "xx No images in $1"
    fi
    
  elif [[ "$sel_op" == "$op2b" ]]; then
  
    # Single random image
    while [ -z "$IMAGE" ]; do
      (( DEPTH++ ))
      IMAGE=$(find -L "$1" -maxdepth "$DEPTH" -iname '*.jp*g' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.tif*' | shuf -n1)
      echo "  testing depth $DEPTH"
      echo "  image: $IMAGE"
      echo "  -"
      if [ $DEPTH -ge $MAX_DEPTH ]; then break; fi
    done
    
    DEPTH=0
    
    if [ -f "$IMAGE" ]; then
      convert "$IMAGE" -resize 160x90^ -gravity center -extent 160x90 "$TMP_EMBLEM"
      IMAGE=""
    else
      STOP=true
      echo "xx No images in $1"
    fi

  fi
}


montage_images() {
  local -n arr=$1
  
  if [ ${#arr[@]} -eq 1 ]; then
    convert "${arr[0]}" -resize 160x90^ -gravity center -extent 160x90 "$TMP_EMBLEM"
  elif [ ${#arr[@]} -eq 2 ]; then
    montage -tile 2x1 -geometry 80x90+2+2 "${arr[@]}" "$TMP_EMBLEM"
  else
    # We have at least 4 images
    montage -tile 2x2 -geometry 80x45+2+2 "${arr[@]}" "$TMP_EMBLEM"
  fi
}


create_tmp_emblem_op_3() {
  IMAGE=$(yad --file --width 750 --height 750 --add-preview --mime-filter="Images | image/jpeg image/png image/tiff image/gif image/bmp" --filename="$1")
  
  TMP_EMBLEM="$ICONS_DIR/EMBLEM_$(basename $1).png"
  convert "$IMAGE" -resize 160x90^ -gravity center -extent 160x90 "$TMP_EMBLEM"
}


composite_custom_icon() {
  CUSTOM_ICON="$ICONS_DIR/ICON_$(basename $1).png"
  convert "$base_folder_icon" "$TMP_EMBLEM" -gravity Center -geometry +0+15 -composite "$CUSTOM_ICON"
}


apply_custom_icon() {
  gio set -t string "$1" metadata::custom-icon "file://$2"
}


update_custom_icon() {
  # Composite custom icon using the old emblem and the new base folder icon
  old_emblem="$ICONS_DIR/EMBLEM_$(basename $1).png"
  if [ -f "$old_emblem" ]; then
    CUSTOM_ICON="$ICONS_DIR/ICON_$(basename $1).png"
    convert "$base_folder_icon" "$old_emblem" -gravity Center -geometry +0+15 -composite "$CUSTOM_ICON"
    apply_custom_icon "$i" "$CUSTOM_ICON"
  else
    apply_custom_icon "$i" "$folder_icon_path"
  fi
}


refresh() {
  sleep 0.1 # Ugly, I know... but 1st xdotool command below often fails otherwise

  # Wait for the zenity dialog to close...
  # https://stackoverflow.com/a/41613532/1865860
  # ...and don't complain if there's already none
  tail --pid=$(pidof zenity) -f /dev/null 2> /dev/null

  # Re-gain window focus, if lost
  xdotool search --name "$parent_dir_name" windowactivate --sync

  # Reload nemo window pressing F5
  xdotool key F5
}


####################
### MAIN PROGRAM ###
####################

choose_operation_type

get_base_folder_icon


# Refresh base icon
if [[ "$sel_op" == "$op5" ]]; then
  # Show a progress dialog if more than 5 folders are selected
  if [ $# -gt 5 ]; then
    for i in "$@"; do

      update_custom_icon "$i"

    done | zenity --progress --auto-close --pulsate --no-cancel
  else
    for i in "$@"; do

      update_custom_icon "$i"

    done
  fi
  
# Restore default folder icon
elif [[ "$sel_op" == "$op4" ]]; then
  for i in "$@"; do

    apply_custom_icon "$i" "$folder_icon_path"
    rm -f "$ICONS_DIR/EMBLEM_$(basename $1).png" "$ICONS_DIR/ICON_$(basename $1).png"

  done # No progress here

# Choose image
elif [[ "$sel_op" == "$op3" ]]; then
  for i in "$@"; do

    create_tmp_emblem_op_3 "$i"
    composite_custom_icon "$i"
    apply_custom_icon "$i" "$CUSTOM_ICON"

  done # No progress here

# Montage and single images cases (op1a op1b op2a op2b)
else
  # Show a progress dialog if more than 2 folders are selected
  if [ $# -gt 2 ]; then
    for i in "$@"; do

      create_tmp_emblem_op_1to4 "$i"
      if [[ $STOP != true ]]; then
        composite_custom_icon "$i"
        apply_custom_icon "$i" "$CUSTOM_ICON"
      else
        STOP=false;
      fi

    done | tee >(zenity --progress --title="$SCRIPT_TITLE" --text="starting..." --percentage=0 --auto-close --auto-kill)
  else
    for i in "$@"; do

      create_tmp_emblem_op_1to4 "$i"
      if [[ $STOP != true ]]; then
        composite_custom_icon "$i"
        apply_custom_icon "$i" "$CUSTOM_ICON"
      else
        STOP=false;
      fi

    done
  fi
fi

refresh
