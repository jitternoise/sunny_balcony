# Flash Flood — Store Release Checklist

Step-by-step path from "the game works on my laptop" to "it is live on Google
Play and the App Store". Written 2026-09-10 against the requirements in force
that day; both stores change rules yearly, so re-check the dated items before
each new release. Sources are at the bottom.

Flash Flood is **offline, free, has no accounts, no ads, no analytics, no
networking**. That makes most of the privacy paperwork trivial, but the
paperwork still has to be filed. Where the answer would change if you added
ads or a paid tier, the item says so.

Legend: `[ ]` to do · **⏱** something with a waiting period, start it early ·
**💻** needs the Mac · **📱** needs a physical device.

---

## 0. Start the slow things first ⏱

These have waiting periods you cannot shorten. Kick them off before any of
the build work.

- [ ] **Google Play developer account** — one-time US$25. Personal accounts
      created after 2023-11-13 need a **12-tester, 14-day closed test** before
      Google grants production access (see §6). Identity verification with a
      government ID is now mandatory for every new personal account, and
      Google is extending developer verification to *all* app installs on
      certified Android devices, so this is not skippable.
- [ ] **Apple Developer Program** — US$99/year. Individual enrolment takes
      roughly 1-2 days; an Organization needs a **D-U-N-S number** (free, but
      up to ~4 weeks to issue) and 1-2 weeks of Apple verification.
- [ ] **Decide individual vs organization on both stores, and use the same
      answer on both.** An individual's legal name appears on the listing.
      A business name needs a registered business and a D-U-N-S on both
      sides. Changing later means a new account and a migration.
- [ ] **Recruit the 12 Android testers** now if the Play account is personal.
      They must stay opted in *continuously* for 14 days; a tester who drops
      out resets the clock for that seat. Friends with Android phones,
      a Discord, or one of the tester-exchange communities.
- [ ] **Get hold of hardware** 📱: at least one Android phone (ideally one
      with a camera cutout, one older/cheaper one) and one iPhone. A Mac is
      required for the iOS build and upload 💻; nothing else can do it.
- [ ] **Name and trademark check.** Search both stores for "Flash Flood" and
      close variants, then USPTO/EUIPO. Apple assigns a name to one app per
      locale and settles disputes by trademark. If the name is taken, the
      rename touches `config/name` in `project.godot`, which is also the key
      for `user://`, so do it before any tester has a save.
- [ ] **Reserve the App Store name** by creating the App Store Connect record
      as soon as the Apple account is live. The Play listing name is not
      reserved until publication.

## 1. Legal and identity paperwork (no code)

- [ ] **Privacy policy, hosted at a public URL.** Both stores require one for
      every app, even one that collects nothing. It should say: no data
      collected, no data shared, saves stay on the device, no third-party
      SDKs. A static page on GitHub Pages or the game's site is enough. The
      URL goes into Play's Data safety section and App Store Connect's App
      Privacy.
- [ ] **Support URL / contact email** shown on both listings. Apple requires
      a support URL. Play shows the developer email publicly and it must be
      monitored.
- [ ] **EU Digital Services Act trader status** — Apple requires every
      account to declare it, and non-declared apps are removed from the EU
      storefront. A free hobby game with no monetisation can usually declare
      *non-trader*. Anything monetised (ads, paid, IAP) makes you a trader
      and Apple then **publishes your address, phone and email** on the
      listing; a PO box and a dedicated number are the usual answer. Play has
      its own DSA declaration in the Console.
- [ ] **Agreements.** Accept the Apple Developer Program License Agreement
      and the Play Developer Distribution Agreement. Only sign the Apple
      *Paid Apps* agreement and set up Play's merchant account if the game
      will ever be paid or sell IAP; tax forms and banking details come with
      those.
- [ ] **Asset licensing audit.** For every font, sprite, sound (there is
      none yet) and the 15 character concepts in `characters/`: who owns it,
      under what licence, and does the licence allow commercial distribution
      and require attribution. Write a `THIRD_PARTY_NOTICES` file and
      surface it in an in-game credits screen if any licence requires it.
      Godot's own MIT licence asks for attribution in distributed builds;
      an "Made with Godot" credit line covers it.
- [ ] **Age rating expectations.** Both questionnaires will land this at
      Play *Everyone* / PEGI 3 and Apple *4+*. Fire and flood are hazards to
      route, not violence, but answer the "violent themes" question
      honestly. Apple's new tiers are 4+ / 9+ / 13+ / 16+ / 18+.
- [ ] **Decide whether the app is "made for kids".** Play's *Designed for
      Families* and Apple's *Kids Category* bring extra rules (no
      third-party analytics, parental gates, stricter review). A 4+ rating
      does **not** force you into them. Recommendation: do not opt in.

## 2. Decide what actually ships (project scope)

Both reviews reject anything that looks unfinished (Apple guideline 4.2).
Settle these before the first build; each is a scope decision, not a bug.

- [ ] **Level 68 is unwinnable** (`handheld-audit.md` finding 33). This is a
      hard blocker: a reviewer or the first player who reaches it will
      report the game as broken. Fix or replace the level and re-verify
      `level-solutions.md` and `level-min-times.md` for it.
- [ ] **The 11 wall-placement solutions in `level-solutions.md`** are stale
      docs, not shipping content, but re-verify the 11 levels are winnable
      with the 2-wide Wall by hand or by updating the solution book. Run
      `verify_solutions.gd` and record the result.
- [ ] **Story layer** (`story-bible.md`) and **characters** are not in the
      engine. Either ship without them and say nothing about them in the
      listing, or schedule them for a later update. Do not screenshot art
      that is not in the build; Apple rejects for misleading metadata.
- [ ] **Audio.** There is none. A silent game passes review, but reviewers
      and players notice. At minimum decide; if you ship silent, make sure
      nothing in the UI implies a mute toggle.
- [ ] **A way out of every screen.** Reviewers try Back on Android and swipe
      gestures on iOS. Confirm the system Back button never closes the app
      from a popup or from Level Select, and that iOS gesture-bar swipes
      do not hit the bottom of the inventory bar (safe-area work from
      2026-09-08 should cover it; verify on device).
- [ ] **First-run experience.** The reviewer plays for a few minutes. The
      five tutorial levels are the pitch; make sure they open on first
      launch with no dead ends.
- [ ] **Versioning scheme.** Pick semantic `version/name` (e.g. `1.0.0`) and
      a monotonically increasing integer `version/code` for Android; iOS
      needs `CFBundleShortVersionString` plus a build number that only ever
      goes up. Record where these live in the export presets.

## 3. Android build

Godot 4.6 export prerequisites (from the official docs): **OpenJDK 17**,
Android SDK Platform-Tools 35+, Build-Tools 35.0.1, Platform 35, command-line
tools, CMake 3.10.2, NDK r28b, and the matching Godot export templates.

- [ ] Install the SDK/NDK/JDK and point *Editor Settings → Export → Android*
      at them. Download the 4.6 export templates.
- [ ] **Create the release keystore** with `keytool` (RSA 2048, validity
      10000 days). Keystore and key passwords must currently be identical
      for Godot. **Back it up in two places** (password manager + offline).
      Losing it is survivable only because of Play App Signing, but a
      leaked one is not.
- [ ] Add an Android export preset. Settings to set deliberately:
  - [ ] Package unique name, e.g. `com.<you>.flashflood`. Reverse-domain of
        a domain you control. Cannot be changed after first upload.
  - [ ] `version/code` and `version/name` per §2.
  - [ ] **Target SDK ≥ 36.** From 2026-08-31 Google Play rejects new apps
        and updates targeting below Android 16 (API 36). Do not trust the
        preset default; set it. Min SDK: Godot's default (24) is fine.
  - [ ] Architectures: arm64-v8a required by Play; keep armeabi-v7a only if
        you want the tiny old-device tail. Drop x86/x86_64.
  - [ ] Export format **AAB**, not APK. Play does not accept APKs for new
        apps. Enable *Gradle build* (AAB requires it).
  - [ ] **Uncheck "Export With Debug".** The single most common cause of
        "Play refuses my upload".
  - [ ] Release keystore path, user (alias), password filled in.
  - [ ] Screen orientation locked to portrait; immersive mode as intended.
  - [ ] Permissions: **none**. Godot adds INTERNET only if you tick it.
        An offline game with an INTERNET permission draws questions in the
        Data safety review.
  - [ ] Icons: 512² launcher icon plus adaptive foreground/background
        (432² each). Godot generates the density set from these.
  - [ ] **Exclude `res://tests/` and `res://tools/`** via the export
        filter (they read files outside `res://`, per `open-items.md`).
  - [ ] Texture compression: decide ETC2/ASTC vs lossless per
        `open-items.md` item 3. Flat-colour, hard-edged art is the worst
        case for block compression; measure before committing.
- [ ] **16 KB page size.** Play requires it for apps targeting API 35+.
      Godot ≥ 4.5's Android templates comply; nothing to do unless you add
      a native plugin, in which case it must ship 16 KB-aligned `.so` files.
- [ ] Build the AAB. Install via `bundletool` or an internal-testing upload
      on a real phone 📱, not just the editor's one-click deploy.
- [ ] Commit `export_presets.cfg`? It is gitignored because it holds the
      keystore path and password. Keep it that way; document the settings
      here instead, or keep a `.example` copy with secrets stripped.

## 4. iOS build 💻

- [ ] Mac with **Xcode 26 or later**. Since 2026-04-28 App Store Connect
      only accepts builds made with the iOS 26 SDK. Older Xcode uploads are
      rejected outright.
- [ ] In the Apple developer portal: register the **Bundle ID**
      (`com.<you>.flashflood`, matching Android for sanity), and let Xcode
      manage signing (automatic signing with the team's distribution
      certificate and an App Store provisioning profile).
- [ ] Add an iOS export preset in Godot. Required: **App Store Team ID**
      and **Bundle Identifier** (export errors without them). Also set
      version/build numbers, portrait-only orientation, the icon set
      (1024² source, no alpha), launch screen colour/image, and the same
      `tests/`/`tools/` exclusion as Android.
- [ ] **Renderer decision** (`open-items.md` item 1): the project uses
      `gl_compatibility`, which reaches Metal through ANGLE on iOS. Test it
      on a real iPhone 📱 first thing. If it misbehaves, switch the mobile
      renderer to *Mobile* (Metal) and re-run the snapshot net; that is a
      project-level change.
- [ ] **Export compliance.** The game uses no encryption and no networking.
      Set `ITSAppUsesNonExemptEncryption = NO` in the exported Info.plist
      (Godot's export options expose it as an additional plist entry) so
      every upload does not stall on the export-compliance question.
- [ ] **Privacy manifest.** Godot's iOS template ships a
      `PrivacyInfo.xcprivacy` declaring its required-reason API usage
      (file timestamps, user defaults). Confirm it is present in the
      exported Xcode project; Apple rejects uploads without approved
      reasons.
- [ ] Open the `.xcodeproj`, select *Any iOS Device*, **Product → Archive**,
      then *Distribute App → App Store Connect → Upload*. Fix any signing
      or asset-catalogue warnings the validator raises.
- [ ] Note that Godot cannot export for the iOS Simulator; all testing is on
      hardware or via TestFlight.

## 5. On-device verification 📱 (both platforms)

The standing caveat in `CLAUDE.md`: nothing has ever run on a GPU. Everything
below is about closing that gap; the headless suites cannot.

- [ ] Run through all five tutorials and at least levels 1, 22 (the 505-cell
      one), 63 (geyser-fed Hydro), a `grid_style = "flat"` level, and the
      jamboree budget level.
- [ ] **Safe-area insets** on a device with a cutout and a gesture bar
      (`open-items.md` item 5). Check the HUD, the Level Select header, and
      the board's top/bottom margins. If the inset arrives a frame late, the
      documented fix is a re-apply on `NOTIFICATION_APPLICATION_RESUMED`.
- [ ] **Sprite-sheet bleed and tile seams** (`open-items.md` item 4): look
      for a sliver of the wrong animation frame at tile edges and hairline
      seams between adjacent water cells at fractional `Hex.SIZE`.
- [ ] **Redraw cost** (`open-items.md` item 6): leave a level open for ten
      minutes; watch battery/thermals and frame pacing. Gate terrain
      animation to `started` if it is expensive.
- [ ] Multi-touch: second finger on the board must not place a block
      (the `VerifyMultiTouch` suite models this; confirm for real).
- [ ] Background/foreground: suspend mid-simulation, return, confirm the
      beat clock resumes sanely and the save is intact. Kill the app
      mid-save; confirm the `.bak` recovery path works.
- [ ] Rotation locked, status bar behaviour, and no letterboxing at 19.5:9,
      20:9 and 4:3-ish (tablet) aspect ratios.
- [ ] Cold-start time and install size. Note both for the listing decision
      on tablets (Play asks for tablet screenshots if you say it supports
      them; you can restrict to phones).
- [ ] Android system Back from every screen; iOS home-swipe from every
      screen.
- [ ] Battery and memory over a 30-minute session on the weakest device.

## 6. Google Play Console

Order matters: the Console blocks the release until every *Dashboard* task
shows a tick.

- [ ] Create the app: name, default language, *Game*, free. **Free cannot be
      changed to paid later**; the reverse is allowed.
- [ ] **Play App Signing** is automatic for new apps (Google-generated
      upload/signing keys, now "quantum-ready hybrid signing"). Record the
      SHA-256 of your upload key from *App integrity* and confirm it
      matches `keytool -list`.
- [ ] **Store listing**: short description (≤80 chars), full description
      (≤4000), app icon **512×512 32-bit PNG ≤1 MB** (Play now applies its
      own 30% corner radius; supply a full-bleed square), **feature graphic
      1024×500 JPEG/24-bit PNG, no alpha** (optional but used for featuring),
      **≥2 phone screenshots** (1080×1920 recommended, 320-3840 px per side,
      max 2:1, no alpha, up to 8). Tablet 7"/10" sets only if you declare
      tablet support. Category *Puzzle*, tags, contact email, privacy
      policy URL.
- [ ] **App content** section, all of it:
  - [ ] Privacy policy URL
  - [ ] Ads declaration: *no ads*
  - [ ] App access: *all functionality available without special access*
  - [ ] Content rating (IARC questionnaire) → expect Everyone/PEGI 3
  - [ ] Target audience and content: choose 13+ (or all ages if you
        accept the Families policy). Do not tick "appeals to children"
        unless you intend to join Designed for Families.
  - [ ] News app: no. COVID app: no. Government app: no.
  - [ ] **Data safety**: no data collected, no data shared. Must agree with
        the privacy policy and with what the binary does (no INTERNET
        permission helps here).
  - [ ] Financial features: none. Health: none.
  - [ ] Advertising ID: not used.
- [ ] Upload the AAB to **Internal testing** first. Read the **pre-launch
      report** (Google runs it on ~10 real devices and flags crashes,
      accessibility, and 16 KB issues).
- [ ] **Closed testing** (personal accounts created after 2023-11-13):
      create a closed track, add the 12+ testers by email or Google Group,
      keep the release live and the testers opted in for **14 continuous
      days**, then **apply for production access** from the Dashboard and
      answer Google's questionnaire about what you tested and learned.
      Expect ~7 days for Google's decision.
- [ ] Countries/regions: pick all, or exclude specific ones. Note that
      once the DSA and developer-verification rules apply, EU and
      Brazil/Indonesia/Singapore/Thailand distribution depends on verified
      developer status.
- [ ] Production release: write release notes, choose a **staged rollout**
      (e.g. 20% → 100%) so a bad build reaches few people, submit. Review
      is usually hours to a few days; first apps take longer.

## 7. App Store Connect

- [ ] Create the app record (reserves the name): platform iOS, name (≤30
      chars), primary language, bundle ID, SKU, *Full* user access.
- [ ] **App Information**: subtitle (≤30), primary category *Games* with
      subcategory *Puzzle*, secondary optional, content rights ("does not
      contain third-party content" unless it does), **age rating
      questionnaire** (the 2025 version with the new in-app controls,
      capabilities, medical, and violence questions; expect 4+), privacy
      policy URL.
- [ ] **App Privacy**: "Data Not Collected". Publishes as the empty
      nutrition label.
- [ ] **Pricing and Availability**: Free, all territories (or a subset).
      Pre-orders optional.
- [ ] **Version page**: screenshots — **6.9" iPhone set is required**
      (1320×2868 or 1290×2796 portrait; Apple scales down for smaller
      phones), up to 10. **13" iPad set is required if the app runs on
      iPad**; if you ship iPhone-only, set *Devices* accordingly in Xcode
      so no iPad set is demanded. Promotional text (≤170, editable without
      review), description (≤4000), keywords (≤100 chars, comma-separated),
      support URL (required), marketing URL, copyright line, version
      string, release notes.
- [ ] **App Review Information**: contact name/phone/email, notes for the
      reviewer ("offline single-player puzzle; no account needed; first
      five levels are a tutorial; a full-game save is not required"). No
      sign-in, so no demo account.
- [ ] Attach the uploaded build; confirm the export-compliance question is
      already answered by the plist key.
- [ ] **TestFlight** first: internal testers (your team, immediate) and
      optionally external testers (needs a light Beta App Review). Run at
      least one TestFlight round on a device that did not build it.
- [ ] Choose **manual release** so you control launch day, then *Submit for
      Review*. Typical review is 24-48 h; a first submission can take
      longer. Common first-submission rejections: crash on launch on the
      reviewer's device, guideline 4.2 (looks unfinished), misleading
      screenshots, missing support URL.
- [ ] If rejected, reply in Resolution Center; most first rejections are
      one exchange.

## 8. Launch day and after

- [ ] Release both stores the same day (Apple: press *Release*; Play: the
      staged rollout goes live on submit approval).
- [ ] Tag the commit that built the release (`v1.0.0`) and record the exact
      export settings and Godot version in `dev-progress.md`.
- [ ] Watch **Play Console → Android vitals** (crashes, ANRs) and **App
      Store Connect → Crashes** for the first week. Both are free and need
      no SDK in the app.
- [ ] Reply to reviews on both stores; Play weights responsiveness.
- [ ] **Calendar reminders** for the yearly rules: Play raises the target
      API level each August (extensions to November on request); Apple
      raises the minimum SDK/Xcode each spring after the WWDC release.
      Budget one maintenance update a year purely for those.
- [ ] Renew the Apple membership yearly or the app is pulled.
- [ ] Keep the keystore backups current and the Play/Apple account recovery
      details (phone, 2FA) working.

---

## Sources (checked 2026-09-10)

**Google Play**
- [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878) — API 36 for new apps/updates from 2026-08-31; extension to 2026-11-01.
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465) — 12 testers, 14 days.
- [Everything about the 12 testers requirement (community guide)](https://support.google.com/googleplay/android-developer/community-guide/255621488/everything-about-the-12-testers-requirement)
- [Android developer verification rollout (Android Developers Blog, 2026-03)](https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html)
- [Required information to create a Play Console developer account](https://support.google.com/googleplay/android-developer/answer/13628312)
- [Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Content rating requirements (IARC)](https://support.google.com/googleplay/android-developer/answer/9859655)
- [Preview assets: icon, feature graphic, screenshots](https://support.google.com/googleplay/android-developer/answer/9866151)
- [Use Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Pre-launch reports](https://support.google.com/googleplay/android-developer/answer/9842757)
- [16 KB page size and Godot (forum)](https://forum.godotengine.org/t/google-console-16kb-memory-size-page-requirements-nov-1-2025-deadline/124764)

**Apple**
- [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) — Xcode 26 / iOS 26 SDK since 2026-04-28; age-rating update since 2026-01-31; DSA trader status.
- [Updated age ratings in App Store Connect](https://developer.apple.com/news/?id=ks775ehf)
- [Manage EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple Developer Program enrollment](https://developer.apple.com/programs/enroll/)
- [App Store screenshot sizes 2026](https://aso.dev/app-store-connect/screenshots/)
- [ITSAppUsesNonExemptEncryption explained](https://orbitkit.io/blog/app-store-export-compliance-encryption/)
- [App Store rejections guide (RevenueCat)](https://www.revenuecat.com/blog/growth/the-ultimate-guide-to-app-store-rejections)

**Godot**
- [Exporting for Android (4.6 docs)](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)
- [Exporting for iOS (4.6 docs)](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_ios.html)
- [Distributing from Xcode to App Store Connect (Peanuts Code)](https://www.peanuts-code.com/en/tutorials/gd0023_distribute_app_from_xcode/)
