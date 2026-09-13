// ~/.../dotfiles/firefox/user.js
// Read at startup, never rewritten by Firefox — safe to version-control.

// Merino / Firefox Suggest — separate from the search-suggestions checkbox
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.merino.enabled", false);
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.quicksuggest.online.enabled", false);
user_pref("browser.urlbar.showSearchSuggestionsFirst", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.quickactions", false);
user_pref("browser.urlbar.suggest.quicksuggest.all",	false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.recentsearches", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.sports", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.suggest.trending", false);
user_pref("browser.urlbar.suggest.weather", false);
user_pref("browser.urlbar.suggest.yelp", false);
user_pref("browser.urlbar.suggest.yelpRealtime", false);
user_pref("services.sync.prefs.sync-seen.browser.urlbar.showSearchSuggestionsFirst", true);
user_pref("services.sync.prefs.sync-seen.browser.urlbar.suggest.engines", true);
user_pref("services.sync.prefs.sync-seen.browser.urlbar.suggest.searches", true);
user_pref("services.sync.prefs.sync-seen.browser.urlbar.suggest.topsites", true);
user_pref("services.sync.prefs.sync.browser.urlbar.suggest.topsites", true);

// ── AI features off ──────────────────────────────────────────────
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.page", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("extensions.ml.enabled", false);
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("browser.tabs.groups.smart.userEnabled", false);
user_pref("browser.translations.enable", false);
// browser.ai.control.* = "blocked" are string values, not booleans:
user_pref("browser.ai.control.default", "blocked");

// ── Telemetry / studies / suggest ────────────────────────────────
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("nimbus.rollouts.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("browser.urlbar.suggest.quicksuggest.all", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.suggest.quickactions", false);
user_pref("browser.urlbar.showSearchSuggestionsFirst", false);

// ── New tab page stripped ────────────────────────────────────────
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);

// ── Privacy / tracking ───────────────────────────────────────────
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("privacy.query_stripping.enabled", true);
user_pref("privacy.query_stripping.enabled.pbmode", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.emailtracking.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.annotate_channels.strict_list.enabled", true);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation", true);

// ── HTTPS-only ───────────────────────────────────────────────────
user_pref("dom.security.https_only_mode", false);
user_pref("dom.security.https_only_mode_pbm", false);

// ── Passwords handled by 1Password, not Firefox ──────────────────
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
user_pref("signon.generation.enabled", false);

// ── UI / behaviour ───────────────────────────────────────────────
user_pref("intl.accept_languages", "en-gb,en");
user_pref("browser.download.useDownloadDir", false);   // always ask where
user_pref("browser.toolbars.bookmarks.visibility", "always");
user_pref("sidebar.verticalTabs", true);
user_pref("browser.startup.page", 3);                  // restore session
user_pref("media.eme.enabled", true);
user_pref("general.autoScroll", true);

user_pref("network.trr.mode", 5);  // 5 = explicitly off
