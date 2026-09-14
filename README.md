# Pixiekat's Dotfiles

Just my general dotfiles for personal use; feel free to clone and modify as you wish. :) 

## Firefox

`firefox/policies.json` is included to set some sensible search and privacy defaults, which are deliberately not included in the linking script. You can run `bin/pixiekat-dotfiles-restore-firefox-policies.json` to symlink it using sudo. I use firefox-nightly, so the path is hardlinked; edit it as you wish.

`.config/mozilla/user.js` has custom user prefs, which can be symlinked into whatever profile you have. Deliberately not included in the linking script either, you just need to symlink once. 