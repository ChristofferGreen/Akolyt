output_card_front() {
    local -r platform="$1"
    local -r game="$2"
    local -r target_width="$3"
    local -r target_height="$4"

	log "        Processing card front for: $game"
	log "l $platform $game $(db_game_property "$platform" "$game" "assets.front")"

	local -r front_image_resized_path="$(download_resize_image "$platform" "$game" "front" "$(db_game_property "$platform" "$game" "assets.front")" "${target_width}x${target_height}!")"	
	local -r front_image_developer_logo_resized_path="$(download_resize_image "$platform" "$game" "platform_logo" "${PLATFORM_LOGO_PATH}/${platform}.png" "x55")"
	
	local -r front_image_composited_path="${TMP_COMPOSITED_IMAGES}/${platform}/${game}_front.png"
	log "            Compositing developer logo $front_image_developer_logo_resized_path on top of front image: $front_image_resized_path to $front_image_composited_path"
	composite_images "$front_image_developer_logo_resized_path" "$front_image_resized_path" "$front_image_composited_path" "south" "+0+20"
	
    if ! file_exists "$front_image_composited_path"; then
        error_exit "Composited front file not created for image: $front_image_composited_path"
    fi
}

output_card_back() {
    local -r platform="$1"
    local -r game="$2"
    local -r target_width="$3"
    local -r target_height="$4"
    local -r scanlines="$5"

    local -r banner_height=120
    local -r screenshot_height=$(( (target_height - banner_height) / 2 ))
    local -r screenshot_and_banner_height=$(( banner_height + screenshot_height ))

    log "        Processing card back for: $game"
    
    # Start off by resizing images
    local -r banner_image_resized_path="$(download_resize_image "$platform" "$game" "banner" "$(db_game_property "$platform" "$game" "assets.banner")" "${target_width}x${banner_height}!")"
    local screenshot1_processed_path="$(download_resize_image "$platform" "$game" "screenshot1" "$(db_game_property "$platform" "$game" "assets.screenshot1")" "${target_width}x${screenshot_height}!")"
    local screenshot2_processed_path="$(download_resize_image "$platform" "$game" "screenshot2" "$(db_game_property "$platform" "$game" "assets.screenshot2")" "${target_width}x${screenshot_height}!")"
    if $scanlines; then
		:
    fi
    local -r game_logo_resized_path="$(download_resize_image "$platform" "$game" "logo" "$(db_game_property "$platform" "$game" "assets.logo")" "x$((banner_height * 75 / 100))")"
    
    # Process downloaded images
    local -r banner_image_processed_path="${TMP_PROCESSED_IMAGES}/${platform}/${game}_banner_processed.png"
    blur_brighten_image "$banner_image_resized_path" "$banner_image_processed_path" "0x5" "7x-10"
    
    # Create an empty image
    local -r back_image_path="${TMP_COMPOSITED_IMAGES}/${platform}/${game}_back.png"
    magick -size "${target_width}x${target_height}" xc:transparent -colorspace sRGB "PNG32:$back_image_path"
    
    # Gather data
    local -r mean_banner_brightness=$(magick "${banner_image_resized_path}" -resize 1x1! -format "%[mean]" info:)
    local -r text_color=$(awk -v brightness="$mean_banner_brightness" 'BEGIN {print (brightness > 32768) ? "black" : "white"}')
    
    local -r players=$(db_game_players "$platform" "$game")
    local player_text=""

    if [[ "$players" =~ ^[1-4]$ ]]; then
        player_text="\nPlayers:"
	else
        player_text="\nPlayers: $players"
    fi

    # Composite images into the empty image
    composite_images "$banner_image_processed_path" "$back_image_path" "$back_image_path" "north" "+0+0"
    composite_images "$game_logo_resized_path" "$back_image_path" "$back_image_path" "northeast" "+10+15"
    composite_text "$platform" "$back_image_path" "Developer:\nRelease Year: $(db_game_year "$platform" "$game")$player_text" "${target_width}x${banner_height}" "NorthWest" "20" "+10+20"
    composite_images "$screenshot1_processed_path" "$back_image_path" "$back_image_path" "north" "+0+$banner_height"
    composite_images "$screenshot2_processed_path" "$back_image_path" "$back_image_path" "north" "+0+$screenshot_and_banner_height"
    
    # Add TapTo logo
    local -r tapto_logo_resized_path="$(download_resize_image "$platform" "$game" "platform_logo" "${PLATFORM_LOGO_PATH}/tapto.png" "x45")"
    composite_images "${tapto_logo_resized_path}" "$back_image_path" "$back_image_path" "southeast" "+5+10" "0.8"
    
    # Add Developer Logo
    local -r developer_logo_resized_path="$(download_resize_image "$platform" "$game" "developer_logo" "${DEVELOPER_LOGO_PATH}/$(db_game_developer "$platform" "$game").png" "x20")"
    composite_images "${developer_logo_resized_path}" "$back_image_path" "$back_image_path" "northwest" "+115+23"

    # Add nbr players
    if [[ "$players" =~ ^[1-4]$ ]]; then
        local -r gamepad_resized_path="$(download_resize_image "$platform" "$game" "gamepad" "${GAMEPAD_PATH}/"$platform".png" "x40")"
        for ((i=0; i<players; i++)); do
            local offset=$((90 + i*45))  # Adjust the 45 value to change spacing between icons
            composite_images "${gamepad_resized_path}" "$back_image_path" "$back_image_path" "northwest" "+${offset}+65"
        done
    fi
    
    if ! file_exists "$back_image_path"; then
        error_exit "Composited back file not created for image: $back_image_path"
    fi
}