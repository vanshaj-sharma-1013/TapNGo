# Setting up ads and "Remove Ads" in Tap N Go

The game code is finished: `ads.gd` decides when ads show, `ads_admob.gd` talks to AdMob,
`store.gd` / `store_billing.gd` handle the purchase. They stay inactive (stubs) until you
install the two Godot plugins below. Until then the editor/debug build grants rewards at once.

Until the plugins are installed, the editor shows parse errors for `ads_admob.gd` and
`store_billing.gd` (they name plugin classes). That is expected and harmless: the game only
loads those files when the plugins exist.

## 1. AdMob account and app
1. Create an AdMob account at admob.google.com and add the app (Android). You get an
   **App ID** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`).
2. Create **three ad units** inside that app:
   - Rewarded
   - Interstitial
   - Rewarded interstitial
3. Paste the three unit ids into `LIVE` in `ads_config.gd`. Leave `USE_TEST_ADS := true` while
   developing. Set it to `false` only for the release build. Never tap your own live ads.
4. In AdMob, add `app-ads.txt` hosting later if you publish a developer website (optional).

## 2. Install the AdMob plugin (Poing Studios)
1. Godot: Project > Install Android Build Template (once).
2. Tools > AdMob Download Manager > Android > pick the latest version (or download the
   `poing-godot-admob-android` zip for your Godot version from
   github.com/poingstudios/godot-admob-plugin releases).
3. Files end up in `res://addons/admob/`. Open `res://addons/admob/android/config.gd` and set
   `APPLICATION_ID` to your AdMob **App ID** (the test App ID
   `ca-app-pub-3940256099942544~3347511713` works for testing).
4. Project > Project Settings > Plugins: enable the AdMob plugin.
5. Project > Export > Android: enable **Use Gradle Build**, and tick the `Admob` plugin in the
   plugin list. Permission `INTERNET` and `ACCESS_NETWORK_STATE` should be on.
6. Run on a real Android phone (ads do not run in the editor or on desktop).

Check the plugin's current docs (poingstudios.github.io/godot-admob-plugin) if a class name
differs from `ads_admob.gd`; that file is the only one to adjust.

## 3. Test it
- With `USE_TEST_ADS := true` you should see "Test Ad" banners labelled by Google.
- Crash in Endless: the three revives should show a rewarded ad, then a rewarded interstitial,
  then two ads in a row.
- Fail one level 3 times, tap Restart: an interstitial shows before the level reloads.
- A 10-minute session without any ad, then Menu: an interstitial shows.

## 4. Remove Ads purchase (Google Play Billing)
1. In Google Play Console create the app (or an internal test track release) and upload at
   least one build with billing permission.
2. Monetize > In-app products > Create product:
   - Product ID: **`remove_ads`** (must match `PRODUCT_REMOVE_ADS` in `store.gd`)
   - Type: one-time (non-consumable). Set the price (for example $1.99). Activate it.
3. Install the **GodotGooglePlayBilling** plugin (github.com/godotengine/godot-google-play-billing,
   master branch for Godot 4.2+): copy to `res://addons/GodotGooglePlayBilling/`, enable it in
   Project Settings > Plugins, and enable **Use Gradle Build** in the Android export.
4. Add yourself under Play Console > Settings > License testing so test purchases are free.
5. Test only on a device installed from an internal/closed test track (a sideloaded debug APK
   cannot buy).
The price shown in the shop is Google's real, localised price; `$1.99` is only a fallback.

## 5. Before you ship
- Google Play: complete the **Data safety** form and declare that the app uses ads
  (Advertising ID).
- Add a consent flow where required (EU/UK users need Google's User Messaging Platform;
  AdMob > Privacy & messaging). The Poing plugin includes UMP support, see its docs.
- Because the audience is 13+ (not child-directed), normal AdMob settings are fine. If you
  ever target under-13s, tell me: ad formats and networks change.
- Switch `USE_TEST_ADS` to `false` and rebuild.
- Cloud Run backend does not know about coins. Coins are local only (see below).

## Notes
- Coins live in `user://save.json` on the device, so a determined player can edit them. That is
  fine for cosmetics, but it is the reason coins should not be turned into real money (see the
  summary). If a cash-out is ever built, coins would have to be earned and stored on the server.
