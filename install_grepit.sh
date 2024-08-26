#!/bin/bash

# Install fzf if not already installed
if ! command -v fzf &> /dev/null; then
    echo "Installing fzf..."
    sudo apt update
    sudo apt install -y fzf
else
    echo "fzf is already installed."
fi

# Define the updated grepit function with history recording
grepit_function="
grepit() {
    local search_term=\"\$1\"
    local cmd

    if [ -n \"\$search_term\" ]; then
        cmd=\$(history | tac | grep \"\$search_term\" | fzf --height=100% --layout=reverse --border --prompt=\"Select command to run: \" --no-preview | sed 's/^[ ]*[0-9]*[ ]*//')
    else
        cmd=\$(history | tac | fzf --height=100% --layout=reverse --border --prompt=\"Select command to run: \" --no-preview | sed 's/^[ ]*[0-9]*[ ]*//')
    fi

    if [ -n \"\$cmd\" ]; then
        echo \"Running: \$cmd\"
        # Add the selected command to the history
        history -s \"\$cmd\"
        eval \"\$cmd\"
    else
        echo \"No command selected.\"
    fi
}
"

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

echo "Setup complete."
