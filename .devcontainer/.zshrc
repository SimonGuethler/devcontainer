# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
  git
  git-lfs
  z
  fzf
  tmux
  extract
  copypath
  sudo
  colored-man-pages
  history-substring-search
  zsh-syntax-highlighting
  deja
)

# history: explicit settings (append + shared + no dups; 1M entries)
setopt append_history
setopt share_history
setopt hist_ignore_dups
setopt hist_expire_dups_first
setopt hist_find_no_dups
setopt hist_reduce_blanks
setopt inc_append_history
setopt no_beep
HISTSIZE=1000000
SAVEHIST=1000000

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
