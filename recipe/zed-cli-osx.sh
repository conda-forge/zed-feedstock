# XXX(lucascolley): should this be robust to the user moving `Zed.app`?
exec "$(dirname "$0")/../lib/zed/zed-cli" --zed="$HOME/Applications/Zed.app" "$@"
