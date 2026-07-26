#!/bin/sh
# IceWM theme hover support. Final, ugly comments added.

# The five button images IceWM looks for in a theme directory.
BUTTON_NAMES='close maximize minimize restore menuButton'

# Find where pixel rows start in an XPM file. Structure (1-indexed lines):
#line 1:  /* XPM */
#2:  static char * name_xpm[] = {
#3:  "WIDTH HEIGHT NUM_COLORS C", header
#4+: "key  c COLOR", ... N palette entries, may span lines
#then:    "pixelrow1", ... "pixelrowH", exactly HEIGHT pixel rows
#last:    };
# The palette has exactly NUM_COLORS entries but they can be spread across multiple lines, with several entries per line separated by '","'. This counts them to know where the pix data begins.
find_line_where_pixel_data_begins() {
    xpm_file="$1"
    # Line 3 = header, 3rd word = number of palette colors.
    number_of_palette_entries=$(
        sed -n '3p' "$xpm_file" | tr -d '"' | cut -d' ' -f3
    )
    # Try to avoid broken XPMs, if empty treat as zero.
    [ -z "$number_of_palette_entries" ] && number_of_palette_entries=0

    current_line_number=3
    palette_entries_found=0
    entry_separator='","'

    # Walk lines 4..EOF, counting palette entries until we have em all.
    while [ "$palette_entries_found" -lt "$number_of_palette_entries" ] \
          && read -r current_line_text; do

        current_line_number=$((current_line_number + 1))

        # Count entries on this line by stripping , separators. Each removal is +1 entry found.
        entries_on_this_line=1
        remaining_text="$current_line_text"
        while :; do
            text_after_stripping="${remaining_text#*$entry_separator}"
            [ "$text_after_stripping" = "$remaining_text" ] && break
            remaining_text="$text_after_stripping"
            entries_on_this_line=$((entries_on_this_line + 1))
        done

        palette_entries_found=$((palette_entries_found + entries_on_this_line))
    done <<EOF
$(sed -n '4,$p' "$xpm_file")
EOF

    # Return the first line after the last palette line (= where pixels start).
    echo $((current_line_number + 1))
}

# Create an *O.xpm hover image from an *A.xpm active image An *A.xpm button is vertically split: top half = normal look, bottom half = "pressed" look. The *O.xpm hover image needs the pressed look on BOTH halves (so the button appears highlighted on hover).
# We just take the bottom half and write it twice lol. This also renames the C variable from *A_xpm to *O_xpm. Output goes to stdout, the caller redirects it.
create_hover_button_from_active() {
    active_button_file="$1"
    # Height is the 2nd word on line 3 of the XPM header.
    image_height=$(
        sed -n '3p' "$active_button_file" | tr -d '"' | cut -d' ' -f2
    )
    first_pixel_data_line=$(find_line_where_pixel_data_begins "$active_button_file")
    half_the_button_height=$((image_height / 2))
    last_pixel_data_line=$((first_pixel_data_line + image_height - 1))
    # Build the new variable name, closeA to closeO, menuButtonA to menuButtonO
    hover_variable_name=$(
        basename "$active_button_file" .xpm | sed 's/A$/O/'
    )

    # Part 1, header (lines 1..just before pixel data), with the C variable renamed.
    sed -n "1,$((first_pixel_data_line - 1))p" "$active_button_file" \
        | sed "s/static char \*.*=/static char *${hover_variable_name}_xpm[] =/"

    # Part 2-3, the pressed (bottom) half of the pixels, written twice.
    sed -n "${first_pixel_data_line},${last_pixel_data_line}p" "$active_button_file" \
        | tail -n "$half_the_button_height"
    sed -n "${first_pixel_data_line},${last_pixel_data_line}p" "$active_button_file" \
        | tail -n "$half_the_button_height"

    # Part 4, footer (everything after the pixel rows is usually just "};").
    sed -n "$((last_pixel_data_line + 1)),\$p" "$active_button_file"
}

# This makes sure default.theme has "RolloverButtonsSupported=1". AFAIK there is only three possible starting situations:
#"RolloverButtonsSupported=1" already exists, nothing to do
#"RolloverButtonsSupported=0" exists, so, flip it to 1
#No "rollover" line at all, if this happens, we insert it
# We write to a TMP file and swap it in.
enable_rollover_in_theme_config() {
    theme_config_file="$1"
    temporary_file="${theme_config_file}.tmp"

    # status: 0=not seen, 1=found =1, 2=changed =0-1, 3=inserted before Look=
    status=0

    # IFS= prevents stripping spaces, -r keeps backslashes literal
    # || [ -n "$line" ] catches the last line if it lacks a trailing newline.
    while IFS= read -r line || [ -n "$line" ]; do
        case $line in
            # A: already enabled, no changes needed.
            *RolloverButtonsSupported=1*)
                status=1; printf '%s\n' "$line" ;;
            # B: disabled -> change to enabled.
            *RolloverButtonsSupported=0*)
                status=2; printf '%s\n' 'RolloverButtonsSupported=1' ;;
            # If there is no setting yet (C), insert it.
            *Look=*)
                if [ "$status" = 0 ]; then
                    printf '%s\n' 'RolloverButtonsSupported=1'
                    status=3
                fi
                printf '%s\n' "$line"
                ;;
            # All other lines pass unchanged.
            *) printf '%s\n' "$line" ;;
        esac
    done < "$theme_config_file" > "$temporary_file"

    case $status in
        1) rm -f "$temporary_file"; return 1 ;;  # was already correct?
        2|3) mv "$temporary_file" "$theme_config_file"; return 0 ;;
        *)  # State C with no Look= either, prepend to the file.
            printf '%s\n' 'RolloverButtonsSupported=1' \
                | cat - "$theme_config_file" > "$temporary_file"
            mv "$temporary_file" "$theme_config_file"
            return 0 ;;
    esac
}

# Process one theme directory, create *O.xpm files and fix default.theme.
add_hover_support_to_a_single_theme() {
    theme_directory="$1"
    [ -d "$theme_directory" ] || return

    theme_config_file="$theme_directory/default.theme"
    [ -f "$theme_config_file" ] || { echo "  SKIP: no default.theme"; return; }

    number_of_images_created=0
    for button_name in $BUTTON_NAMES; do
        active_button_file="$theme_directory/${button_name}A.xpm"
        hover_button_file="$theme_directory/${button_name}O.xpm"
        [ -f "$active_button_file" ] || continue
        create_hover_button_from_active "$active_button_file" > "$hover_button_file"
        number_of_images_created=$((number_of_images_created + 1))
    done

    rollover_was_modified=0
    enable_rollover_in_theme_config "$theme_config_file" && rollover_was_modified=1

    theme_name=$(basename "$theme_directory")
    echo "  ${theme_name}: ${number_of_images_created} O images created," \
         " RolloverButtonsSupported=${rollover_was_modified}"
}

# Handle command-line arguments
if [ $# -lt 1 ]; then
    echo "Usage: sh icewm_hover_final.sh <theme_directory> [theme_directory ...]"
    exit 1
fi

for given_path in "$@"; do
    if [ -d "$given_path" ] && [ -f "$given_path/default.theme" ]; then
        add_hover_support_to_a_single_theme "$given_path"
    else
        # Treat as folder of theme subdirectories (~/.icewm/themes/*).
        for possible_theme_dir in "$given_path"/*; do
            [ -d "$possible_theme_dir" ] \
                && add_hover_support_to_a_single_theme "$possible_theme_dir"
        done
    fi
done
