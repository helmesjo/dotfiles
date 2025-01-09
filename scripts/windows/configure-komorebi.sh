setx KOMOREBI_CONFIG_HOME "$(cygpath -m "$HOME/.config/komorebi/")"
setx WHKD_CONFIG_HOME "$(cygpath -m "$HOME/.config/whkd/")"

komorebic stop --whkd --bar
komorebic start --whkd --bar
