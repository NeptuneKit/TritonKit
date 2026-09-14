/*
Ported from https://github.com/MobAI-App/simslim
profiles.go and features.go at commit f3b979ecd913f56904a9b6100cad1f84fe01d228

MIT License

Copyright (c) 2026 Interlap

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import Foundation

struct SimulatorResourceServiceCategory: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let description: String
    let downside: String
    /// Upstream iOS 26.5 clean-boot median; workload-dependent and not additive.
    let approxMemoryMB: Int
    let labels: [String]
}

struct SimulatorResourceServiceFeature: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let labels: [String]
}

enum SimulatorResourceCatalogError: Error, Equatable {
    case unknownCategory(String)
    case unknownLabel(String)
    case unknownFeature(String)
}

enum SimulatorResourceCatalog {
    static let sourceCommit = "f3b979ecd913f56904a9b6100cad1f84fe01d228"
    static let sourceURL = "https://github.com/MobAI-App/simslim"
    static let alwaysEnabledLabels: Set<String> = ["com.apple.sharingd"]
    static let alwaysEnabledReasons = ["com.apple.sharingd": "Required for system share sheets."]
    static let categories: [SimulatorResourceServiceCategory] = [
        .init(id: "widgets", name: "Widgets & Wallpaper",
              description: "Home and lock screen posters, widgets, and Live Activities.",
              downside: "Home and Lock Screen widgets, wallpaper posters, and Live Activities stop updating.",
              approxMemoryMB: 675, labels: [
                  "com.apple.PosterBoard",
                  "com.apple.chronod",
                  "com.apple.liveactivitiesd",
              ]),
        .init(id: "siri", name: "Siri & Intelligence",
              description: "Siri, Apple Intelligence, speech, and on-device ML model services.",
              downside: "Siri, speech features, and Apple Intelligence services are unavailable.",
              approxMemoryMB: 265, labels: [
                  "com.apple.assistantd",
                  "com.apple.assistant_cdmd",
                  "com.apple.assistant_service",
                  "com.apple.siriactionsd",
                  "com.apple.siriinferenced",
                  "com.apple.siriknowledged",
                  "com.apple.sirittsd",
                  "com.apple.siri.context.service",
                  "com.apple.siri.acousticsignature",
                  "com.apple.corespeechd",
                  "com.apple.voiced",
                  "com.apple.voicebankingd",
                  "com.apple.speechmodeltrainingd",
                  "com.apple.intelligenceplatformd",
                  "com.apple.intelligencecontextd",
                  "com.apple.intelligenceflowd",
                  "com.apple.intelligencetasksd",
                  "com.apple.generativeexperiencesd",
                  "com.apple.knowledgeconstructiond",
                  "com.apple.naturallanguaged",
                  "com.apple.textunderstandingd",
                  "com.apple.modelcatalogd",
                  "com.apple.modelmanagerd",
                  "com.apple.mlhostd",
                  "com.apple.mlruntimed",
                  "com.apple.suggestd",
                  "com.apple.parsecd",
                  "com.apple.parsec-fbf",
                  "com.apple.proactiveeventtrackerd",
              ]),
        .init(id: "search", name: "Spotlight & Search",
              description: "On-device Spotlight and in-Settings search services.",
              downside: "Spotlight and Settings search return no results.",
              approxMemoryMB: 50, labels: [
                  "com.apple.searchd",
                  "com.apple.searchtoold",
                  "com.apple.spotlightknowledged",
                  "com.apple.spotlightknowledged.updater",
                  "com.apple.corespotlightservice",
              ]),
        .init(id: "icloud", name: "iCloud & Apple Account",
              description: "iCloud sync, Apple Account, keychain, and backup services.",
              downside: "iCloud sync, Apple Account, Keychain, and backup workflows will not work.",
              approxMemoryMB: 100, labels: [
                  "com.apple.appleaccountd",
                  "com.apple.appleaccounttransparencyd",
                  "com.apple.appleidsetupd",
                  "com.apple.akd",
                  "com.apple.amsaccountsd",
                  "com.apple.amsengagementd",
                  "com.apple.amsondevicestoraged",
                  "com.apple.cloudd",
                  "com.apple.cloudphotod",
                  "com.apple.ckdiscretionaryd",
                  "com.apple.cloudsettingssyncagent",
                  "com.apple.bird",
                  "com.apple.syncdefaultsd",
                  "com.apple.cdpd",
                  "com.apple.sosd",
                  "com.apple.SecureBackupDaemon",
                  "com.apple.TrustedPeersHelper",
                  "com.apple.protectedcloudstorage.protectedcloudkeysyncing",
                  "com.apple.icloudmailagent",
                  "com.apple.icloudsubscriptionoptimizerd",
                  "com.apple.communicationtrustd",
              ]),
        .init(id: "store", name: "App Store, Push & Media",
              description: "App Store, push notification, StoreKit, and media services.",
              downside: "Remote push notifications and StoreKit or App Store testing will not work.",
              approxMemoryMB: 80, labels: [
                  "com.apple.appstored",
                  "com.apple.appstorecomponentsd",
                  "com.apple.apsd",
                  "com.apple.itunescloudd",
                  "com.apple.itunesstored",
                  "com.apple.storekitd",
                  "com.apple.amsaccountsd",
                  "com.apple.amsengagementd",
                  "com.apple.amsondevicestoraged",
                  "com.apple.passd",
                  "com.apple.financed",
                  "com.apple.videosubscriptionsd",
                  "com.apple.assetsubscriptiond",
                  "com.apple.musicd",
              ]),
        .init(id: "pim", name: "Mail, Calendar & Contacts",
              description: "Mail, Calendar, Contacts, Reminders, and related sync services.",
              downside: "Contacts, Calendar, Reminders, and Mail-backed pickers or sync may fail.",
              approxMemoryMB: 80, labels: [
                  "com.apple.email.maild",
                  "com.apple.exchangesyncd",
                  "com.apple.dataaccess.dataaccessd",
                  "com.apple.calaccessd",
                  "com.apple.remindd",
                  "com.apple.contactsd",
                  "com.apple.contacts.postersyncd",
                  "com.apple.peopled",
              ]),
        .init(id: "web", name: "Safari Sync & Web Services",
              description: "Safari sync, web push, privacy, and universal-link services.",
              downside: "Universal links and Safari sync or background web services will not work.",
              approxMemoryMB: 50, labels: [
                  "com.apple.SafariBookmarksSyncAgent",
                  "com.apple.Safari.History",
                  "com.apple.Safari.passwordbreachd",
                  "com.apple.Safari.SafeBrowsing.Service",
                  "com.apple.safarifetcherd",
                  "com.apple.WebBookmarks.webbookmarksd",
                  "com.apple.webkit.adattributiond",
                  "com.apple.webkit.webpushd",
                  "com.apple.webprivacyd",
                  "com.apple.swcd",
              ]),
        .init(id: "family", name: "Family & Screen Time",
              description: "Family Sharing, Screen Time, and usage tracking.",
              downside: "Family Sharing, Screen Time, and usage tracking stop working.",
              approxMemoryMB: 65, labels: [
                  "com.apple.familycircled",
                  "com.apple.FamilyControlsAgent",
                  "com.apple.familynotification",
                  "com.apple.askpermissiond",
                  "com.apple.asktod",
                  "com.apple.ScreenTimeAgent",
                  "com.apple.ScreenTimeSettingsAgent",
                  "com.apple.UsageTrackingAgent",
              ]),
        .init(id: "health", name: "Health, Home & Fitness",
              description: "HealthKit, HomeKit, and Fitness services.",
              downside: "HealthKit, HomeKit, and Fitness integrations will not work.",
              approxMemoryMB: 135, labels: [
                  "com.apple.healthd",
                  "com.apple.healthappd",
                  "com.apple.healthcontentd",
                  "com.apple.healtheventsd",
                  "com.apple.healthrecordsd",
                  "com.apple.finhealthd",
                  "com.apple.homed",
                  "com.apple.homeeventsd",
                  "com.apple.fitcore",
                  "com.apple.fitcore.session",
                  "com.apple.fitnesscoachingd",
                  "com.apple.fitnessintelligenced",
                  "com.apple.activityawardsd",
                  "com.apple.activitysharingd",
              ]),
        .init(id: "photos", name: "Photos & Media Analysis",
              description: "Photos library, photo analysis, and media analysis services.",
              downside: "Photo picker, Photos-library workflows, and media analysis may fail.",
              approxMemoryMB: 60, labels: [
                  "com.apple.photoanalysisd",
                  "com.apple.photosface",
                  "com.apple.mediaanalysisd",
                  "com.apple.mediaanalysisd.service",
                  "com.apple.mediastream.mstreamd",
                  "com.apple.medialibraryd",
                  "com.apple.assetsd",
                  "com.apple.assetsd.nebulad",
              ]),
        .init(id: "apps", name: "News, Weather, Maps & Games",
              description: "News, Weather, Maps, Tips, and game services.",
              downside: "News, Weather, Maps background data, and game-controller services are unavailable.",
              approxMemoryMB: 90, labels: [
                  "com.apple.newsd",
                  "com.apple.weatherd",
                  "com.apple.Maps.mapssyncd",
                  "com.apple.Maps.mapspushd",
                  "com.apple.Maps.geocorrectiond",
                  "com.apple.maps.destinationd",
                  "com.apple.MapKit.SnapshotService",
                  "com.apple.jetpackassetd",
                  "com.apple.tipsd",
                  "com.apple.gamed",
                  "com.apple.gamesaved",
                  "com.apple.GameController.gamecontrollerd",
              ]),
        .init(id: "messaging", name: "Messaging & FaceTime",
              description: "iMessage, FaceTime, call, and identity services.",
              downside: "iMessage, FaceTime, and related identity services will not work.",
              approxMemoryMB: 60, labels: [
                  "com.apple.identityservicesd",
                  "com.apple.ids_simd",
                  "com.apple.imautomatichistorydeletionagent",
                  "com.apple.imcore.imtransferagent",
                  "com.apple.imdpersistence.IMDPersistenceAgent",
                  "com.apple.facetimemessagestored",
                  "com.apple.telephonyutilities.callservicesd",
              ]),
        .init(id: "connectivity", name: "Sharing & Device Connectivity",
              description: "AirDrop, Continuity, CarPlay, Watch, and Find My services.",
              downside: "AirDrop, Continuity, CarPlay, Watch, and Find My connectivity will not work.",
              approxMemoryMB: 65, labels: [
                  "com.apple.rapportd",
                  "com.apple.companiond",
                  "com.apple.carkitd",
                  "com.apple.wcd",
                  "com.apple.tvremoted",
                  "com.apple.avatarsd",
                  "com.apple.stickersd",
                  "com.apple.sociallayerd",
                  "com.apple.announced",
                  "com.apple.navd",
                  "com.apple.findmy.findmylocated",
              ]),
        .init(id: "telemetry", name: "Ads, Diagnostics & Telemetry",
              description: "DeviceCheck, ad privacy, analytics, diagnostics, and feedback services.",
              downside: "DeviceCheck plus analytics, diagnostics, and feedback services are unavailable.",
              approxMemoryMB: 105, labels: [
                  "com.apple.ap.adprivacyd",
                  "com.apple.ap.promotedcontentd",
                  "com.apple.diagnosticextensionsd",
                  "com.apple.feedbackd",
                  "com.apple.rtcreportingd",
                  "com.apple.securityuploadd",
                  "com.apple.geoanalyticsd",
                  "com.apple.triald",
                  "com.apple.followupd",
                  "com.apple.purplebuddy.budd",
                  "com.apple.devicecheckd",
              ]),
        .init(id: "other", name: "Other Background Services",
              description: "Wallet, business services, assets, and miscellaneous background daemons.",
              downside: "Wallet, merchant, business, asset, and miscellaneous background services are unavailable.",
              approxMemoryMB: 195, labels: [
                  "com.apple.financed",
                  "com.apple.passd",
                  "com.apple.merchantd",
                  "com.apple.coreidvd",
                  "com.apple.businessservicesd",
                  "com.apple.deviceaccessd",
                  "com.apple.replicatord",
                  "com.apple.linkd",
                  "com.apple.ind",
                  "com.apple.storagedatad",
                  "com.apple.StatusKitAgent",
                  "com.apple.countryd",
                  "com.apple.mobileassetd",
                  "com.apple.managedconfiguration.passcodenagd",
              ]),
    ]

    static let features: [SimulatorResourceServiceFeature] = [
        .init(id: "push", name: "Push notifications", labels: ["com.apple.apsd"]),
        .init(id: "storekit", name: "StoreKit / in-app purchase", labels: ["com.apple.storekitd", "com.apple.itunesstored", "com.apple.amsaccountsd", "com.apple.amsengagementd", "com.apple.amsondevicestoraged", "com.apple.passd", "com.apple.financed"]),
        .init(id: "app-store", name: "App Store", labels: ["com.apple.appstored", "com.apple.itunesstored"]),
        .init(id: "universal-links", name: "Universal links / associated domains", labels: ["com.apple.swcd"]),
        .init(id: "spotlight", name: "Spotlight & Settings search", labels: ["com.apple.searchd", "com.apple.searchtoold"]),
        .init(id: "siri", name: "Siri & speech", labels: ["com.apple.assistantd", "com.apple.corespeechd"]),
        .init(id: "icloud", name: "iCloud sync", labels: ["com.apple.cloudd"]),
        .init(id: "keychain-sync", name: "iCloud Keychain", labels: ["com.apple.akd"]),
        .init(id: "contacts", name: "Contacts", labels: ["com.apple.contactsd"]),
        .init(id: "calendar", name: "Calendar", labels: ["com.apple.calaccessd"]),
        .init(id: "reminders", name: "Reminders", labels: ["com.apple.remindd"]),
        .init(id: "mail", name: "Mail", labels: ["com.apple.email.maild"]),
        .init(id: "photos", name: "Photos library & analysis", labels: ["com.apple.assetsd", "com.apple.photoanalysisd"]),
        .init(id: "health", name: "HealthKit", labels: ["com.apple.healthd"]),
        .init(id: "homekit", name: "HomeKit", labels: ["com.apple.homed"]),
        .init(id: "imessage", name: "iMessage & FaceTime", labels: ["com.apple.identityservicesd"]),
        .init(id: "widgets", name: "Widgets & Live Activities", labels: ["com.apple.chronod", "com.apple.liveactivitiesd"]),
        .init(id: "wallet", name: "Wallet & passes", labels: ["com.apple.passd"]),
        .init(id: "maps", name: "Maps background services", labels: ["com.apple.Maps.mapssyncd"]),
        .init(id: "weather", name: "Weather", labels: ["com.apple.weatherd"]),
        .init(id: "news", name: "News", labels: ["com.apple.newsd"]),
        .init(id: "game-center", name: "Game Center", labels: ["com.apple.gamed"]),
        .init(id: "find-my", name: "Find My", labels: ["com.apple.findmy.findmylocated"]),
        .init(id: "screen-time", name: "Screen Time", labels: ["com.apple.ScreenTimeAgent"]),
    ]

    static let slimmableLabels = Set(categories.flatMap(\.labels))
    static let managedLabels = slimmableLabels.union(alwaysEnabledLabels)

    static func resolveFeatures(_ ids: [String]) throws -> [SimulatorResourceServiceFeature] {
        try ids.map { id in
            guard let feature = features.first(where: { $0.id == id }) else {
                throw SimulatorResourceCatalogError.unknownFeature(id)
            }
            return feature
        }
    }

    /// A kept category wins for shared labels, matching upstream profile semantics.
    static func desired(exceptCategories: Set<String> = [], keep: Set<String> = []) throws -> Set<String> {
        for id in exceptCategories.sorted() where !categories.contains(where: { $0.id == id }) {
            throw SimulatorResourceCatalogError.unknownCategory(id)
        }
        for label in keep.sorted() where !managedLabels.contains(label) {
            throw SimulatorResourceCatalogError.unknownLabel(label)
        }
        let excepted = Set(categories.filter { exceptCategories.contains($0.id) }.flatMap(\.labels))
        return slimmableLabels.subtracting(excepted).subtracting(keep)
    }

    /// Never changes a non-managed label, even if it appears in desired.
    static func delta(current: Set<String>, desired: Set<String>) -> (disable: [String], enable: [String]) {
        let safeDesired = desired.intersection(slimmableLabels)
        return (safeDesired.subtracting(current).sorted(),
                current.intersection(managedLabels).subtracting(safeDesired).sorted())
    }
}
