user_pref("browser.aboutConfig.showWarning", false);
user_pref("signon.rememberSignons", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.pinned", []);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.search.widget.inNavBar", true);
user_pref("privacy.donottrackheader.enabled", true);
user_pref("geo.enabled", false);
user_pref("media.videocontrols.picture-in-picture.enabled", false);
user_pref("browser.bookmarks.editDialog.showForNewBookmarks", false);
user_pref("extensions.pocket.enabled", false);
user_pref("browser.compactmode.show", false);
user_pref("browser.uidensitys", 1);
user_pref("browser.tabs.firefox-view", false);
user_pref("browser.tabs.inTitlebar", 1);

user_pref("dom.security.https_first", true);
user_pref("dom.security.https_first_schemeless", true);

// Do not connect to detectportal.firefox.com
user_pref("network.captive-portal-service.enabled", false);

// Disable OCSP (certificate validation check)
// [0=do not check; 1=check all (default); 2=check EVSSL Certs only]
user_pref("security.OCSP.enabled", 0);

// Disable PPA (Privacy Preserving Attribution)
user_pref("dom.private-attribution.submission.enabled", false);

// Don't save addresses
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.addresses.capture.enabled", false);
