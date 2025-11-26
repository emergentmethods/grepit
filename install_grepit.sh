#!/bin/bash

# Install fzf if not already installed
if ! command -v fzf &> /dev/null; then
    echo "Installing fzf..."
    sudo apt update
    sudo apt install -y fzf
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
    while IFS= read -r cmd; do
        # Skip empty lines
        [ -z "$cmd" ] && continue
        # Add timestamp and append to grepit history
        echo "$IMPORT_TIMESTAMP | $cmd" >> "$GREPIT_HISTORY"
    done < "$HOME/.bash_history"

    echo "Migrated $(wc -l < "$GREPIT_HISTORY") commands from bash history"
elif [ -f "$GREPIT_HISTORY" ]; then
    echo "Grepit history already exists, skipping migration"
fi

# Define the history capture function
history_capture="
# Grepit centralized history configuration
GREPIT_HISTORY_FILE=\"\$HOME/.cache/grepit/history\"
GREPIT_LAST_CMD=\"\"

# Function to append command to centralized history
_grepit_save_command() {
    local last_cmd
    last_cmd=\$(HISTTIMEFORMAT= history 1 | sed 's/^[ ]*[0-9]*[ ]*//')

    # Skip if command is empty, starts with space, or is the same as last command
    if [ -n \"\$last_cmd\" ] && [ \"\$last_cmd\" != \"\$GREPIT_LAST_CMD\" ] && [[ ! \"\$last_cmd\" =~ ^[[:space:]] ]]; then
        # Use flock to safely append to history file from multiple terminals
        (
            flock -x 200
            echo \"\$(date '+%Y-%m-%d %H:%M:%S') | \$last_cmd\" >> \"\$GREPIT_HISTORY_FILE\"
        ) 200>\"\$GREPIT_HISTORY_FILE.lock\"
        GREPIT_LAST_CMD=\"\$last_cmd\"
    fi
}

# Add to PROMPT_COMMAND to capture every command
if [[ ! \"\$PROMPT_COMMAND\" =~ _grepit_save_command ]]; then
    PROMPT_COMMAND=\"_grepit_save_command\${PROMPT_COMMAND:+;\$PROMPT_COMMAND}\"
fi
"

# Define the updated grepit function with centralized history
grepit_function="
grepit() {
    local search_term=\"\$1\"
    local cmd
    local GREPIT_HISTORY_FILE=\"\$HOME/.cache/grepit/history\"

    # Create history file if it doesn't exist
    touch \"\$GREPIT_HISTORY_FILE\"

    if [ -n \"\$search_term\" ]; then
        cmd=\$(tac \"\$GREPIT_HISTORY_FILE\" | sed 's/^[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\} | //' | awk '!seen[\$0]++' | grep \"\$search_term\" | fzf --height=100% --layout=reverse --border --prompt=\"Select command to run: \" --no-preview)
    else
        cmd=\$(tac \"\$GREPIT_HISTORY_FILE\" | sed 's/^[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\} | //' | awk '!seen[\$0]++' | fzf --height=100% --layout=reverse --border --prompt=\"Select command to run: \" --no-preview)
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

# Add the history capture to .bashrc if it's not already present
if ! grep -q "_grepit_save_command" ~/.bashrc; then
    echo "Adding grepit history capture to ~/.bashrc..."
    echo "$history_capture" >> ~/.bashrc
else
    echo "grepit history capture is already in ~/.bashrc"
fi

# Add the grepit function to .bashrc if it's not already present
if ! grep -q "grepit()" ~/.bashrc; then
    echo "Adding grepit function to ~/.bashrc..."
    echo "$grepit_function" >> ~/.bashrc
else
    echo "grepit function is already in ~/.bashrc"
fi

# Source the .bashrc file to apply changes
echo "Sourcing ~/.bashrc..."
source ~/.bashrc

echo ""
echo "Setup complete!"
echo "Centralized history location: ~/.cache/grepit/history"
echo ""
echo "Usage:"
echo "  grepit              - Browse all commands"
echo "  grepit <term>       - Search for specific commands"
