#!/bin/bash

# Install fzf if not already installed
if ! command -v fzf &> /dev/null; then
    echo "Installing fzf..."
    if command -v brew &> /dev/null; then
        brew install fzf
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y fzf
    else
        echo "No supported package manager found (brew or apt-get)."
        echo "On macOS, install Homebrew first: https://brew.sh"
        echo "Then re-run this script, or install fzf manually: https://github.com/junegunn/fzf#installation"
        exit 1
    fi
else
    echo "fzf is already installed."
fi

# Create the centralized grepit cache directory
GREPIT_DIR="$HOME/.cache/grepit"
GREPIT_HISTORY="$GREPIT_DIR/history"
mkdir -p "$GREPIT_DIR"
echo "Created grepit directory at $GREPIT_DIR"

# Migrate existing bash history to grepit format
if [ -f "$HOME/.bash_history" ] && [ ! -f "$GREPIT_HISTORY" ]; then
    echo "Migrating existing bash history to grepit..."
    IMPORT_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Read bash history and convert to grepit format
    # Skip timestamp comments (lines starting with #) from HISTTIMEFORMAT
    while IFS= read -r cmd; do
        # Skip empty lines and timestamp comments
        [ -z "$cmd" ] && continue
        [[ "$cmd" =~ ^#[0-9]+$ ]] && continue
        # Add timestamp and append to grepit history
        echo "$IMPORT_TIMESTAMP | $cmd" >> "$GREPIT_HISTORY"
    done < "$HOME/.bash_history"

    echo "Migrated $(wc -l < "$GREPIT_HISTORY") commands from bash history"
elif [ -f "$GREPIT_HISTORY" ]; then
    echo "Grepit history already exists, skipping migration"
fi

# Define the bash history capture function
bash_history_capture="
# Grepit centralized history configuration (bash)
GREPIT_HISTORY_FILE=\"\$HOME/.cache/grepit/history\"

# Function to append command to centralized history
_grepit_save_command() {
    local last_cmd
    # Get last command, strip number and any timestamp from HISTTIMEFORMAT
    last_cmd=\$(HISTTIMEFORMAT= history 1 | sed -e 's/^[ ]*[0-9]*[ ]*//' -e 's/^[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\} //')

    # Skip if command is empty or starts with space
    if [ -n \"\$last_cmd\" ] && [[ ! \"\$last_cmd\" =~ ^[[:space:]] ]]; then
        # Use a mkdir-based lock to safely append to history file from multiple terminals
        # (portable across Linux and macOS, unlike flock which isn't built into macOS)
        local lockdir=\"\$GREPIT_HISTORY_FILE.lockdir\"
        while ! mkdir \"\$lockdir\" 2>/dev/null; do sleep 0.01; done
        # Compare against the file's actual last entry (not an in-memory variable) so
        # dedup stays correct across re-sourcing this file and across multiple terminals
        local prev_cmd
        prev_cmd=\$(tail -n 1 \"\$GREPIT_HISTORY_FILE\" 2>/dev/null | cut -d'|' -f2- | sed 's/^ //')
        if [ \"\$last_cmd\" != \"\$prev_cmd\" ]; then
            echo \"\$(date '+%Y-%m-%d %H:%M:%S') | \$last_cmd\" >> \"\$GREPIT_HISTORY_FILE\"
        fi
        rmdir \"\$lockdir\"
    fi
}

# Add to PROMPT_COMMAND to capture every command
if [[ ! \"\$PROMPT_COMMAND\" =~ _grepit_save_command ]]; then
    PROMPT_COMMAND=\"_grepit_save_command\${PROMPT_COMMAND:+;\$PROMPT_COMMAND}\"
fi
"

# Define the bash grepit function with centralized history
bash_grepit_function="
grepit() {
    local search_term=\"\$1\"
    local cmd
    local reverse_cmd
    local GREPIT_HISTORY_FILE=\"\$HOME/.cache/grepit/history\"

    # Create history file if it doesn't exist
    touch \"\$GREPIT_HISTORY_FILE\"

    # tac is GNU coreutils only; macOS/BSD ships tail -r instead.
    # Use an array (not a string) so this works under zsh too, which
    # doesn't word-split unquoted variables the way bash does.
    if command -v tac >/dev/null 2>&1; then
        reverse_cmd=(tac)
    else
        reverse_cmd=(tail -r)
    fi

    if [ -n \"\$search_term\" ]; then
        cmd=\$(\"\${reverse_cmd[@]}\" \"\$GREPIT_HISTORY_FILE\" | cut -d'|' -f2- | sed 's/^ //' | awk '!seen[\$0]++' | grep \"\$search_term\" | fzf --height=100% --layout=reverse --border --prompt=\"Select command to run: \" --no-preview)
    else
        cmd=\$(\"\${reverse_cmd[@]}\" \"\$GREPIT_HISTORY_FILE\" | cut -d'|' -f2- | sed 's/^ //' | awk '!seen[\$0]++' | fzf --height=100% --layout=reverse --border --prompt=\"Select command to run: \" --no-preview)
    fi

    if [ -n \"\$cmd\" ]; then
        echo \"Running: \$cmd\"
        # Add the selected command to the shell history
        history -s \"\$cmd\"
        eval \"\$cmd\"
    else
        echo \"No command selected.\"
    fi
}
"

# Define the zsh history capture function (macOS default shell since Catalina)
zsh_history_capture="
# Grepit centralized history configuration (zsh)
GREPIT_HISTORY_FILE=\"\$HOME/.cache/grepit/history\"

# Function to append command to centralized history
_grepit_save_command() {
    local last_cmd
    last_cmd=\"\$(fc -ln -1)\"

    # Skip if command is empty or starts with space
    if [ -n \"\$last_cmd\" ] && [[ ! \"\$last_cmd\" =~ ^[[:space:]] ]]; then
        # Use a mkdir-based lock to safely append to history file from multiple terminals
        local lockdir=\"\$GREPIT_HISTORY_FILE.lockdir\"
        while ! mkdir \"\$lockdir\" 2>/dev/null; do sleep 0.01; done
        # Compare against the file's actual last entry (not an in-memory variable) so
        # dedup stays correct across re-sourcing this file and across multiple terminals
        local prev_cmd
        prev_cmd=\$(tail -n 1 \"\$GREPIT_HISTORY_FILE\" 2>/dev/null | cut -d'|' -f2- | sed 's/^ //')
        if [ \"\$last_cmd\" != \"\$prev_cmd\" ]; then
            echo \"\$(date '+%Y-%m-%d %H:%M:%S') | \$last_cmd\" >> \"\$GREPIT_HISTORY_FILE\"
        fi
        rmdir \"\$lockdir\"
    fi
}

# Add to precmd_functions to capture every command (zsh's equivalent of PROMPT_COMMAND)
if (( ! \${precmd_functions[(Ie)_grepit_save_command]} )); then
    precmd_functions+=(_grepit_save_command)
fi
"

# Define the zsh grepit function with centralized history
zsh_grepit_function="
grepit() {
    local search_term=\"\$1\"
    local cmd
    local reverse_cmd
    local GREPIT_HISTORY_FILE=\"\$HOME/.cache/grepit/history\"

    # Create history file if it doesn't exist
    touch \"\$GREPIT_HISTORY_FILE\"

    # tac is GNU coreutils only; macOS/BSD ships tail -r instead.
    # Use an array (not a string) so this works under zsh too, which
    # doesn't word-split unquoted variables the way bash does.
    if command -v tac >/dev/null 2>&1; then
        reverse_cmd=(tac)
    else
        reverse_cmd=(tail -r)
    fi

    if [ -n \"\$search_term\" ]; then
        cmd=\$(\"\${reverse_cmd[@]}\" \"\$GREPIT_HISTORY_FILE\" | cut -d'|' -f2- | sed 's/^ //' | awk '!seen[\$0]++' | grep \"\$search_term\" | fzf --height=100% --layout=reverse --border --prompt=\"Select command to run: \" --no-preview)
    else
        cmd=\$(\"\${reverse_cmd[@]}\" \"\$GREPIT_HISTORY_FILE\" | cut -d'|' -f2- | sed 's/^ //' | awk '!seen[\$0]++' | fzf --height=100% --layout=reverse --border --prompt=\"Select command to run: \" --no-preview)
    fi

    if [ -n \"\$cmd\" ]; then
        echo \"Running: \$cmd\"
        # Add the selected command to the shell history
        print -s \"\$cmd\"
        eval \"\$cmd\"
    else
        echo \"No command selected.\"
    fi
}
"

# Wire grepit into whichever shells are actually present on this system,
# so it works regardless of whether bash or zsh (macOS default) is in use.
if command -v bash &> /dev/null; then
    touch ~/.bashrc

    if ! grep -q "_grepit_save_command" ~/.bashrc; then
        echo "Adding grepit history capture to ~/.bashrc..."
        echo "$bash_history_capture" >> ~/.bashrc
    else
        echo "grepit history capture is already in ~/.bashrc"
    fi

    if ! grep -q "grepit()" ~/.bashrc; then
        echo "Adding grepit function to ~/.bashrc..."
        echo "$bash_grepit_function" >> ~/.bashrc
    else
        echo "grepit function is already in ~/.bashrc"
    fi

    # macOS Terminal starts a login shell, which reads ~/.bash_profile instead of
    # ~/.bashrc. Make sure ~/.bashrc actually gets loaded in that case.
    touch ~/.bash_profile
    if ! grep -q '\.bashrc' ~/.bash_profile; then
        echo "Configuring ~/.bash_profile to source ~/.bashrc..."
        printf '\nif [ -f ~/.bashrc ]; then\n    source ~/.bashrc\nfi\n' >> ~/.bash_profile
    fi
fi

if command -v zsh &> /dev/null; then
    touch ~/.zshrc

    if ! grep -q "_grepit_save_command" ~/.zshrc; then
        echo "Adding grepit history capture to ~/.zshrc..."
        echo "$zsh_history_capture" >> ~/.zshrc
    else
        echo "grepit history capture is already in ~/.zshrc"
    fi

    if ! grep -q "grepit()" ~/.zshrc; then
        echo "Adding grepit function to ~/.zshrc..."
        echo "$zsh_grepit_function" >> ~/.zshrc
    else
        echo "grepit function is already in ~/.zshrc"
    fi
fi

echo ""
echo "Setup complete!"
echo "Centralized history location: ~/.cache/grepit/history"
echo ""
echo "Usage:"
echo "  grepit              - Browse all commands"
echo "  grepit <term>       - Search for specific commands"
echo ""
echo "Restart your terminal (or run 'source ~/.bashrc' / 'source ~/.zshrc') to start using grepit."
