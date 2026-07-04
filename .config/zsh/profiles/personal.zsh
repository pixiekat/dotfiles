# hyfetch, if exists, aliases
if [ -x "$(command -v hyfetch)" ]; then
    alias blahajfetch='hyfetch -p transgender'
    alias hy-effable-husbands='hyfetch -p nonbinary'
    alias ineffable-husbands='hy-effable-husbands'
    alias hyclexa='hyfetch -p bisexual'
    alias clexa-forever='hyclexa'
    alias team-free-will='hyfetch -p queer'
    alias destiel-will-never-die='hyfetch -p omnisexual'
    alias baby-its-klaine-outside='hyfetch -p rainbow'
fi

# does jellyfin exist?
if [ -x "$(command -v jellyfin)" ]; then
    alias jellystart='sudo systemctl start jellyfin'
    alias jellystop='sudo systemctl stop jellyfin'
    alias jellyrestart='sudo systemctl restart jellyfin'
    alias jellystatus='sudo systemctl status jellyfin'
fi

# Note: package-manager judgement moved to default.zsh so every profile
# (work included >:3) gets roasted, not just this one.
