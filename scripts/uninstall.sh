#!/usr/bin/env bash
#
# zsh-sage uninstaller
#

set -euo pipefail

SAGE_HOME="$HOME/.zsh-sage"
PLUGIN_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-sage"

echo "=== zsh-sage uninstaller ==="
echo ""

# Remove oh-my-zsh symlink
if [[ -L "$PLUGIN_DIR" ]]; then
    rm "$PLUGIN_DIR"
    echo "Removed plugin symlink: $PLUGIN_DIR"
fi

# Ask about data
read -p "Remove command history database at $SAGE_HOME? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$SAGE_HOME"
    echo "Removed $SAGE_HOME"
else
    echo "Kept $SAGE_HOME"
fi

echo ""
echo "Don't forget to remove 'zsh-sage' from plugins in your ~/.zshrc"
echo "=== Uninstall complete ==="
