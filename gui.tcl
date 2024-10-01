package require Tk
package require json

# Global variables
set db_file ""
set db_data ""
set selected_game ""

# Function to load the database
proc load_database {} {
    global db_file db_data
    set types {
        {"JSON Files" {.json}}
        {"All files" * }
    }
    set db_file [tk_getOpenFile -filetypes $types]
    if {$db_file != ""} {
        set db_data [read_json_file $db_file]
        populate_listbox
        set selected_game ""
        clear_card_details
    }
}

# Function to read a JSON file
proc read_json_file {filename} {
    set f [open $filename]
    set data [read $f]
    close $f
    return [json::json2dict $data]
}

# Function to write to a JSON file
proc write_json_file {filename data} {
    set f [open $filename w]
    puts $f [json::write $data]
    close $f
}

# Function to populate the listbox
proc populate_listbox {} {
    global db_data
    .listbox delete 0 end
    foreach platform [dict keys $db_data.platforms] {
        .listbox insert end $platform
        foreach game $db_data.games {
            if {$game.platform == $platform} {
                .listbox insert end "  - $game.name"
            }
        }
    }
}

# Function to display card details
proc display_card_details {game_name} {
    global db_data selected_game
    set selected_game $game_name
    foreach game $db_data.games {
        if {$game.name == $game_name} {
            .entry_name delete 0 end
            .entry_name insert 0 $game.name
            .entry_developer delete 0 end
            .entry_developer insert 0 $game.developer
            .entry_year delete 0 end
            .entry_year insert 0 $game.year
            .entry_players delete 0 end
            .entry_players insert 0 $game.players
            .entry_front delete 0 end
            .entry_front insert 0 $game.assets.front
            .entry_banner delete 0 end
            .entry_banner insert 0 $game.assets.banner
            .entry_logo delete 0 end
            .entry_logo insert 0 $game.assets.logo
            .entry_screenshot1 delete 0 end
            .entry_screenshot1 insert 0 $game.assets.screenshot1
            .entry_screenshot2 delete 0 end
            .entry_screenshot2 insert 0 $game.assets.screenshot2
            .entry_blurb delete 0 end
            .entry_blurb insert 0 $game.blurb
            break
        }
    }
}

# Function to clear card details
proc clear_card_details {} {
    .entry_name delete 0 end
    .entry_developer delete 0 end
    .entry_year delete 0 end
    .entry_players delete 0 end
    .entry_front delete 0 end
    .entry_banner delete 0 end
    .entry_logo delete 0 end
    .entry_screenshot1 delete 0 end
    .entry_screenshot2 delete 0 end
    .entry_blurb delete 0 end
}

# Function to update card details
proc update_card_details {} {
    global db_data db_file selected_game
    if {$selected_game == ""} { return }
    foreach game $db_data.games {
        if {$game.name == $selected_game} {
            dict set game name [.entry_name get]
            dict set game developer [.entry_developer get]
            dict set game year [.entry_year get]
            dict set game players [.entry_players get]
            dict set game assets front [.entry_front get]
            dict set game assets banner [.entry_banner get]
            dict set game assets logo [.entry_logo get]
            dict set game assets screenshot1 [.entry_screenshot1 get]
            dict set game assets screenshot2 [.entry_screenshot2 get]
            dict set game blurb [.entry_blurb get]
            write_json_file $db_file $db_data
            break
        }
    }
}

# Create the main window
wm title . "Card Database Manager"

# Left frame with the listbox
frame .left
label .left.label -text "Games by Platform"
listbox .left.listbox -width 30 -height 20
pack .left.label -side top
pack .left.listbox -side top
pack .left -side left -fill y

# Middle frame with card details
frame .middle
label .middle.label_name -text "Name:"
entry .middle.entry_name -width 30
label .middle.label_developer -text "Developer:"
entry .middle.entry_developer -width 30
label .middle.label_year -text "Year:"
entry .middle.entry_year -width 30
label .middle.label_players -text "Players:"
entry .middle.entry_players -width 30
label .middle.label_front -text "Front Image URL:"
entry .middle.entry_front -width 30
label .middle.label_banner -text "Banner Image URL:"
entry .middle.entry_banner -width 30
label .middle.label_logo -text "Logo Image URL:"
entry .middle.entry_logo -width 30
label .middle.label_screenshot1 -text "Screenshot 1 URL:"
entry .middle.entry_screenshot1 -width 30
label .middle.label_screenshot2 -text "Screenshot 2 URL:"
entry .middle.entry_screenshot2 -width 30
label .middle.label_blurb -text "Blurb:"
entry .middle.entry_blurb -width 30
pack .middle.label_name .middle.entry_name -side top -fill x
pack .middle.label_developer .middle.entry_developer -side top -fill x
pack .middle.label_year .middle.entry_year -side top -fill x
pack .middle.label_players .middle.entry_players -side top -fill x
pack .middle.label_front .middle.entry_front -side top -fill x
pack .middle.label_banner .middle.entry_banner -side top -fill x
pack .middle.label_logo .middle.entry_logo -side top -fill x
pack .middle.label_screenshot1 .middle.entry_screenshot1 -side top -fill x
pack .middle.label_screenshot2 .middle.entry_screenshot2 -side top -fill x
pack .middle.label_blurb .middle.entry_blurb -side top -fill x
pack .middle -side left -fill both -expand 1

# Bottom frame with the "Load Database" button
frame .bottom
button .bottom.button -text "Load Database" -command load_database
pack .bottom.button -side left
pack .bottom -side bottom -fill x

# Bind listbox selection to display_card_details
.left.listbox bind <ButtonRelease-1> {
    set selection [.left.listbox curselection]
    if {$selection != ""} {
        set game_name [lindex [.left.listbox get 0 end] $selection]
        if {$selection != ""} {
            set game_name [string trimleft $game_name " -"]
            display_card_details $game_name
        }
    }
}

		Bind entry widget changes to update_card_details

		.middle.entry_name bind <KeyRelease> update_card_details
		.middle.entry_developer bind <KeyRelease> update_card_details
		.middle.entry_year bind <KeyRelease> update_card_details
		.middle.entry_players bind <KeyRelease> update_card_details
		.middle.entry_front bind <KeyRelease> update_card_details
		.middle.entry_banner bind <KeyRelease> update_card_details
		.middle.entry_logo bind <KeyRelease> update_card_details
		.middle.entry_screenshot1 bind <KeyRelease> update_card_details
		.middle.entry_screenshot2 bind <KeyRelease> update_card_details
		.middle.entry_blurb bind <KeyRelease> update_card_details
		