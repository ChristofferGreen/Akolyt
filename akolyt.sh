#!/bin/bash

set -euo pipefail

# Global constants
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ASSETS_DIR="${SCRIPT_DIR}/assets"
FONT_PATH="${ASSETS_DIR}/Righteous-Regular.ttf"
PLATFORM_LOGO_PATH="${ASSETS_DIR}/platform_logo"
DEVELOPER_LOGO_PATH="${ASSETS_DIR}/developer_logo"
GAMEPAD_PATH="${ASSETS_DIR}/gamepad"
TMP_DIR="./tmp_$(date +%s)"
TMP_DOWNLOADED_IMAGES="${TMP_DIR}/downloaded"
TMP_RESIZED_IMAGES="${TMP_DIR}/resized"
TMP_PROCESSED_IMAGES="${TMP_DIR}/processed"
TMP_COMPOSITED_IMAGES="${TMP_DIR}/composited"
TMP_PDF="${TMP_DIR}/pdf"

# Global variables
# Should only be set early in main
# Should be invariant if doing multithreading
VERBOSE=false
DB_PATH="${ASSETS_DIR}/database.json"
THEME="default"

# Macros
is_empty() {
    [[ -z "$1" ]]
}

is_url() {
    case "$1" in
        http://*|https://*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

dir_exists() {
    [[ -d "$1" ]]
}

file_exists() {
    [[ -f "$1" ]]
}

# Helper functions
log() {
    if $VERBOSE; then
        echo "$1" >&2
    fi
}

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

get_extension() {
    local url="$1"
    basename "$url" | sed -E 's/.*\.([^.]+)$/.\1/'
}

cleanup() {
    if [ -d "$TMP_DIR" ]; then
        log "Cleaning up temporary files"
        rm -rf "$TMP_DIR"
    fi
}

check_required_utilities() {
    local -r required_utils="jq curl magick composite awk"
    local missing_utils=""

    for util in $required_utils; do
        if ! command -v "$util" > /dev/null 2>&1; then
            missing_utils="$missing_utils $util"
        fi
    done

    if ! is_empty "$missing_utils"; then
        echo "Error: The following required utilities are not installed:" >&2
        for util in $missing_utils; do
            echo "  - $util" >&2
        done
        echo "Please install these utilities and try again." >&2
        exit 1
    fi

    log "All required utilities are installed."
}

# Database functions
db_platform_property() {
    local platform="$1"
    local property="$2"
    jq -r --arg platform "$platform" --arg property "$property" \
        '.platforms[] | select(.name == $platform) | .[$property] // empty' "$DB_PATH"
}

db_game_property() {
    local -r platform="$1"
    local -r game="$2"
    local -r property="$3"

    jq -r --arg platform "$platform" \
          --arg game "$game" \
          --arg property "$property" '
        # Iterate through all games
        .games[] |
        # Select the game matching both name and platform
        select(.name == $game and .platform == $platform) |
        # Navigate the property path (handles nested properties)
        getpath($property | split("."))
    ' "$DB_PATH"
}
#front_cover=$(db_game_property "$platform" "$game" "assets.front")

db_game_developer() {
    local platform="$1"
    local game="$2"
    jq -r --arg platform "$platform" --arg name "$game" '.games[] | select(.platform == $platform and .name == $name) | .developer' "$DB_PATH"
}

db_game_year() {
    local platform="$1"
    local game="$2"
    jq -r --arg platform "$platform" --arg name "$game" '.games[] | select(.platform == $platform and .name == $name) | .year' "$DB_PATH"
}

db_game_players() {
    local platform="$1"
    local game="$2"
    jq -r --arg platform "$platform" --arg name "$game" '.games[] | select(.platform == $platform and .name == $name) | .players' "$DB_PATH"
}

db_game_blurb() {
    local platform="$1"
    local game="$2"
    jq -r --arg platform "$platform" --arg name "$game" '.games[] | select(.platform == $platform and .name == $name) | .blurb' "$DB_PATH"
}

db_platforms() {
    jq -r '.platforms[].name' "$DB_PATH"
}

db_games_by_platform() {
    local platform_name="$1"
    jq -r --arg platform "$platform_name" '.games[] | select(.platform == $platform) | .name' "$DB_PATH"
}

db_game_assets() {
    local platform="$1"
    local game="$2"
    jq -r --arg platform "$platform" --arg name "$game" '.games[] | select(.platform == $platform and .name == $name) | .assets' "$DB_PATH"
}

db_platform_resolution_width() {
    local platform="$1"
    jq -r --arg platform "$platform" '.platforms[] | select(.name == $platform) | .resolutionx // empty' "$DB_PATH"
}

db_platform_resolution_height() {
    local platform="$1"
    jq -r --arg platform "$platform" '.platforms[] | select(.name == $platform) | .resolutiony // empty' "$DB_PATH"
}


# Main functions
check_dirs_exists() {
	if ! dir_exists "${PLATFORM_LOGO_PATH}"; then
	    echo "Error: 'platform_logo' dir not found: ${PLATFORM_LOGO_PATH}"
	    exit 1
	fi
}

download_image() {
    local -r image_url="$1"
    local -r output_path="$2"
    
    # Create the parent directory if it doesn't exist
    local -r parent_dir=$(dirname "$output_path")
    mkdir -p "$parent_dir" || error_exit "Failed to create directory: ${parent_dir}"
	
    if ! curl --no-progress-meter -o "$output_path" "$image_url"; then
        error_exit "Failed to download image: ${image_url} to: ${output_path}."
    fi
}

resize_image() {
    local -r in_path="$1"
    local -r out_path="$2"
    local -r dims="$3"
    
    # Create the parent directory of the output path if it doesn't exist
    local -r parent_dir=$(dirname "$out_path")
    mkdir -p "$parent_dir" || error_exit "Failed to create directory: ${parent_dir}"
        
    if ! magick "${in_path}" -resize "${dims}" "${out_path}"; then
        error_exit "Failed to resize image: ${in_path} to: ${out_path} with dims: ${dims}"
    fi
}

download_resize_image() {
    local -r platform="$1"
    local -r game="$2"
    local -r type="$3"
    local -r image_url="$4"
    local -r dims="$5"
    
    local -r image_downloaded_path="${TMP_DOWNLOADED_IMAGES}/${platform}/${game}_${type}$(get_extension "$image_url")"
    
    if is_url "$image_url"; then
        log "            Downloading ${type} image to: $image_downloaded_path from: $image_url"
        download_image "$image_url" "$image_downloaded_path"
    else
        log "            Copying local ${type} image to: $image_downloaded_path from: $image_url"
        cp "$image_url" "$image_downloaded_path"
    fi
    
    local -r image_resized_path="${TMP_RESIZED_IMAGES}/${platform}/${game}_${type}_resized.png"
	log "            Resizing from: $image_downloaded_path to: $image_resized_path as: $dims"
    resize_image "$image_downloaded_path" "$image_resized_path" "${dims}"
	
	echo "$image_resized_path"
}

composite_images() {
    local -r in_overlay_path="$1"
    local -r in_back_path="$2"
    local -r out_path="$3"
    local -r gravity="$4"
    local -r geometry="$5"
    local -r transparency="${6:-1.0}"  # Default to 1.0 (fully opaque) if not provided
    
    # Create the parent directory of the output path if it doesn't exist
    local -r parent_dir=$(dirname "$out_path")
    mkdir -p "$parent_dir" || error_exit "Failed to create directory: ${parent_dir}"
    
    # Create a temporary image with adjusted transparency
    local temp_overlay="/tmp/temp_overlay_$(date +%s%N).png"
    
    if ! magick "$in_overlay_path" -alpha set -channel A -evaluate multiply "$transparency" +channel "$temp_overlay"; then
        error_exit "Failed to adjust transparency of overlay image: $in_overlay_path"
    fi
    
    if ! magick composite -gravity "$gravity" -geometry "$geometry" "$temp_overlay" "$in_back_path" "$out_path"; then
        rm -f "$temp_overlay"
        error_exit "Failed to composite image: $in_overlay_path on top of: $in_back_path to: $out_path"
    fi
    
    # Clean up the temporary file
    rm -f "$temp_overlay"
}

blur_brighten_image() {
    local -r in_path="$1"
    local -r out_path="$2"
    local -r blur="$3"
    local -r brightness="$4"
	
    # Create the parent directory of the output path if it doesn't exist
    local -r parent_dir=$(dirname "$out_path")
    mkdir -p "$parent_dir" || error_exit "Failed to create directory: ${parent_dir}"
	
	log "            Blurring and brightening: $in_path to $out_path"
	
    if ! magick "${in_path}" -blur "$blur" -brightness-contrast "$brightness" "$out_path"; then
        error_exit "Failed to blur and brighten image: $in_path"
    fi
}

composite_text() {
	local -r platform="$1"
	local -r background_path="$2"
	local -r text="$3"
	local -r dims="$4"
	local -r gravity="$5"
	local -r size="$6"
	local -r annotate="$7"
	
	local -r text_image_path="${TMP_COMPOSITED_IMAGES}/${platform}/${game}_text.png"
	if ! magick "${background_path}" -fill "${text_color}" -font "$FONT_PATH" -pointsize "$size" -gravity "$gravity" -annotate "$annotate" "$text" "${background_path}"; then
        error_exit "Failed to create text image: $text_image_path"
    fi
}

source themes/default.sh

create_cards() {
    local -r target_width="$1"
    local -r target_height="$2"

    for platform in $(db_platforms); do
        log "Parsing platform: $platform"
		while read -r game; do
			log "    Parsing game: $game"
			output_card_front "$platform" "$game" $target_width $target_height
			output_card_back "$platform" "$game" $target_width $target_height true
		done < <(db_games_by_platform "$platform")
	done
}

create_a4_card_montage() {
    local -r tile_config="3x3"
    local -r page_size="2480x3508" # A4 at 300 DPI
    local -r spacing_px=66
    local -r target_dpi=300
    local -r output_file="output.pdf"
    
    # Calculate target width and height in pixels for 55mm x 86mm at 300 DPI
    local -r target_width=$(awk "BEGIN {printf \"%.0f\", (55 * $target_dpi) / 25.4}")
    local -r target_height=$(awk "BEGIN {printf \"%.0f\", (86 * $target_dpi) / 25.4}")
    
    log "Creating montage: $output_file Image size: ${target_width}x${target_height} pixels"

	magick montage ${TMP_COMPOSITED_IMAGES}/**/*.* -tile $tile_config -geometry "${target_width}x${target_height}+${spacing_px}+${spacing_px}" -density $target_dpi -units PixelsPerInch -page $page_size "$output_file"

    if ! file_exists "$output_file"; then
        error_exit "Failed to create montage: $output_file"
    fi
}

create_tmp_folders() {
    mkdir -p "$TMP_DIR"
	mkdir -p "$TMP_DOWNLOADED_IMAGES"
	mkdir -p "$TMP_RESIZED_IMAGES"
	mkdir -p "$TMP_COMPOSITED_IMAGES"
	mkdir -p "$TMP_PDF"
}

load_theme() {
	if file_exists "themes/${THEME}.sh"; then
	    source "themes/${THEME}.sh"
	else
	    error_exit "Theme file not found: themes/${THEME}.sh"
	fi

	if ! declare -F output_card_front > /dev/null || ! declare -F output_card_back > /dev/null; then
	    error_exit "The theme file must define 'output_card_front' and 'output_card_back' functions"
	fi
}

main() {
	check_required_utilities

    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
			--theme)
			    if [[ -n "$2" ]]; then
			        THEME="$2"
			        shift 2
			    else
			        error_exit "Theme name is required after --theme"
			    fi
				;;
			*)
            shift
            ;;
        esac
    done
	
	load_theme

    check_dirs_exists
	create_tmp_folders

    #trap cleanup EXIT

    local -r card_width=576
    local -r card_height=900

    create_cards $card_width $card_height
	create_a4_card_montage

    log "Script completed successfully"
}

main "$@"