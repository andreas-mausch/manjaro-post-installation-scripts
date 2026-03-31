# Mozilla User Preferences
# Privacy-Handbuch, medium strenge user.js (vom 15.07.2024)
# Download: https://www.privacy-handbuch.de/handbuch_21u.htm

#####################
# Minimale Parameter
#####################

user_pref("app.normandy.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.disk_cache_ssl", false);
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.messaging-system.whatsNewPanel.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.system.topsites", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
user_pref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("browser.pagethumbnails.capturing_disabled", true);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.region.update.enabled", false);
user_pref("browser.region.network.url", "");
user_pref("browser.search.update", false);
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.sessionstore.privacy_level", 2);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.startup.page", 0);
user_pref("browser.tabs.crashReporting.sendReport", false);
user_pref("browser.tabs.firefox-view", false);
user_pref("browser.topsites.contile.enabled", false);
user_pref("browser.uitour.enabled", false);
user_pref("browser.uitour.url", "");
user_pref("browser.urlbar.trimURLs", false);
user_pref("browser.urlbar.groupLabels.enabled", false);
user_pref("browser.urlbar.suggest.openpage", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.quicksuggest.enabled", false);
user_pref("browser.urlbar.quicksuggest.dataCollection.enabled", false);
user_pref("browser.urlbar.quicksuggest.showedOnboardingDialog", true);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.vpn_promo.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("dom.private-attribution.submission.enabled", false);
user_pref("dom.security.https_first", true);
user_pref("dom.vibrator.max_vibrate_ms", 0);
user_pref("extensions.getAddons.cache.enabled", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("extensions.ui.lastCategory", "addons://list/extension");
user_pref("extensions.pocket.enabled", false);
user_pref("extensions.quarantinedDomains.enabled", false);
user_pref("extensions.systemAddon.update.enabled", false);
user_pref("extensions.webextensions.restrictedDomains", "");
user_pref("layout.css.font-visibility", 1);
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("media.peerconnection.ice.no_host", true);
user_pref("network.connectivity-service.enabled", false);
user_pref("network.cookie.cookieBehavior", 5);
user_pref("network.http.referer.XOriginPolicy", 1);
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);
user_pref("network.IDN_show_punycode", true);
user_pref("network.manage-offline-status", false);
user_pref("network.trr.default_provider_uri", "https://doh.ffmuc.net/dns-query");
user_pref("permissions.isolateBy.userContext", true);
user_pref("places.history.enabled", false);
user_pref("privacy.clearOnShutdown.offlineApps", true);
user_pref("privacy.cpd.offlineApps", true);
user_pref("privacy.cpd.passwords", true);
user_pref("privacy.donottrackheader.enabled", false);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.history.custom", true);
user_pref("privacy.query_stripping.enabled", true);
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.trackingprotection.enabled", false);
user_pref("privacy.userContext.enabled", true);
user_pref("privacy.userContext.ui.enabled", true);
user_pref("security.insecure_connection_text.enabled", true);
user_pref("security.insecure_connection_text.pbmode.enabled", true);
user_pref("services.settings.server", "https://s.%.c.invalid/v1");
user_pref("signon.autofillForms", false);
user_pref("signon.formlessCapture.enabled", false);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("ui.use_standins_for_native_colors", true);
user_pref("webgl.enable-debug-renderer-info", false);

user_pref("security.ssl.require_safe_negotiation", true);
user_pref("security.ssl.treat_unsafe_negotiation_as_broken", true);

#####################
# Moderate Parameter
#####################

user_pref("browser.formfill.enable", false);
user_pref("browser.safebrowsing.downloads.remote.url", " ");
user_pref("browser.safebrowsing.downloads.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.downloads.remote.enabled", false);
user_pref("browser.safebrowsing.downloads.remote.block_dangerous", false);
user_pref("browser.safebrowsing.downloads.remote.block_dangerous_host", false);
user_pref("browser.safebrowsing.downloads.remote.block_potentially_unwanted", false);
user_pref("browser.safebrowsing.downloads.remote.block_uncommon", false);
user_pref("browser.safebrowsing.blockedURIs.enabled", false);
user_pref("browser.safebrowsing.provider.google.gethashURL", "");
user_pref("browser.safebrowsing.provider.google.updateURL", "");
user_pref("browser.safebrowsing.provider.google4.gethashURL", "");
user_pref("browser.safebrowsing.provider.google4.updateURL", "");
user_pref("browser.safebrowsing.provider.mozilla.gethashURL", "");
user_pref("browser.safebrowsing.provider.mozilla.updateURL", "");
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_send_http_background_request", false);
user_pref("extensions.blocklist.enabled", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("extensions.formautofill.heuristics.enabled", false);
user_pref("extensions.screenshots.disabled", true);
user_pref("font.blacklist.underline_offset", "");
user_pref("network.captive-portal-service.enabled", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.altsvc.enabled", false);
user_pref("network.http.altsvc.oe", false);
user_pref("security.cert_pinning.enforcement_level", 2);
user_pref("security.certerrors.mitm.auto_enable_enterprise_roots", false);
user_pref("ui.systemUsesDarkTheme", 0);
user_pref("webgl.disable-fail-if-major-performance-caveat", true);

// temporär RESET auf Default
user_pref("browser.display.use_document_fonts", 1);

##########################
# Medium strenge Parameter
##########################

user_pref("dom.push.enabled", false);
user_pref("identity.fxaccounts.enabled", false);
user_pref("javascript.options.baselinejit", false);
user_pref("javascript.options.ion", false);
user_pref("javascript.options.native_regexp", false);
user_pref("media.autoplay.default", 5);
user_pref("media.autoplay.blocking_policy", 2);
user_pref("media.eme.enabled", false);
user_pref("media.gmp-gmpopenh264.enabled", false);
user_pref("media.gmp-gmpopenh264.autoupdate", false);
user_pref("media.gmp-gmpopenh264.provider.enabled", false);
user_pref("media.gmp-gmpopenh264.visible", false);
user_pref("media.gmp-manager.url", "data:text/plain,");
user_pref("media.gmp-manager.url.override", "data:text/plain,");
user_pref("pdfjs.enableScripting", false);
user_pref("signon.rememberSignons", false);

user_pref("_user.js.prhdb", "medium_15072024");


####################
# Strenge Parameter (hier deaktiviert)
####################

// user_pref("browser.chrome.site_icons", false);
// user_pref("browser.display.use_document_fonts", 0);
// user_pref("browser.eme.ui.enabled", false);
// user_pref("browser.sessionstore.max_tabs_undo", 0);
// user_pref("browser.sessionstore.max_windows_undo", 0);
// user_pref("dom.event.clipboardevents.enabled", false);
// user_pref("gfx.direct2d.disabled", true);
// user_pref("gfx.downloadable_fonts.enabled", false);
// user_pref("gfx.font_rendering.opentype_svg.enabled", false);
// user_pref("gfx.font_rendering.graphite.enabled", false);
// user_pref("layout.css.font-loading-api.enabled", false);
// user_pref("media.hardware-video-decoding.enabled", false);
// user_pref("pdfjs.disabled", true);
// user_pref("privacy.clearOnShutdown.siteSettings", true);
// user_pref("privacy.cpd.siteSettings", true);
// user_pref("svg.disabled", true);



