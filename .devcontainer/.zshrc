# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
  git
  z
  fzf
  extract
  copypath
  sudo
  zsh-autosuggestions
  zsh-syntax-highlighting
  colored-man-pages
  history-substring-search
  command-not-found
)

source $ZSH/oh-my-zsh.sh

# Recover cleanly when a terminal UI exits without disabling mouse reporting.
# Otherwise mouse movement/clicks arrive at zsh as visible escape-sequence input.
_gpu_workspace_reset_mouse_tracking() {
  [[ -t 1 ]] || return
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1005l\e[?1006l\e[?1015l' > /dev/tty 2>/dev/null
}

autoload -Uz add-zsh-hook
add-zsh-hook -d precmd _gpu_workspace_reset_mouse_tracking 2>/dev/null
add-zsh-hook precmd _gpu_workspace_reset_mouse_tracking
_gpu_workspace_reset_mouse_tracking
