//
//  Structures.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation

/// Global path constants, URLs, and bundle metadata used throughout the application.
///
struct GlobalVariables {
    // The application's bundle identifier.
    static let jamJARBundleId = String(describing: Bundle.main.object(forInfoDictionaryKey:
                                                                            "CFBundleIdentifier")!)
    // The application's current version string.
    static let jamJARVersion = String(describing: Bundle.main.object(forInfoDictionaryKey:
                                                                            "CFBundleShortVersionString")!)
    // Directory where collected log files are copied.
    static let collectedLogsDirectory = "/Users/Shared/jamJAR Logs/"
    // Path to Munki's install-at-logout trigger file.
    static let installAtLogoutFile = "/private/tmp/com.googlecode.munki.installatlogout"
    // Path to the Jamf binary.
    static let jamfBinaryPath = "/usr/local/jamf/bin/jamf"
    // Path to the jamJAR log file.
    static let logPath = "/var/log/jamJAR.log"
    // Path to Managed Software Center.
    static let managedSoftwareCenterPath = "/Applications/Managed Software Center.app"
}

/// Represents the contents of `/Library/Managed Installs/InstallInfo.plist`.
///
struct InstallInfoContent: Codable {
    // The managed install items pending installation.
    let managedInstalls: [ManagedInstalls]
    // Details of each managed install item.
    struct ManagedInstalls: Codable {
        // Munki/jamJAR name of the title.
        let name: String
    }
    // The removal items pending uninstallation.
    let removals: [Removals]
    // Details of each removal item.
    struct Removals: Codable {
        // Munki/jamJAR name of the title.
        let name: String
    }
    enum CodingKeys: String, CodingKey {
        case managedInstalls = "managed_installs"
        case removals
    }
}

/// Details of an item Munki attempted to install during this run.
///
struct InstallResults: Codable {
    // Display name of the title.
    let displayName: String?
    // Munki/jamJAR name of the title.
    let name: String?
    // Status, where 0 = installed.
    let status: Int?
    // Version of the title.
    let version: String?
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case name, status, version
    }
}

/// Parsed details extracted from a launchd plist file.
///
struct LaunchdPlistDetails {
    // The value of the plist's `Label` key.
    let label: String
    // The `KeepAlive.PathState` dictionary, mapping file paths to boolean keep-alive values.
    let pathState: [String: Bool]
    // The `LimitLoadToSessionType` array of session type strings.
    let sessionTypes: [String]
}

/// Details of a managed install entry from the report.
///
struct ManagedInstallEntry: Codable {
    // Display name of the title.
    let displayName: String?
    // Munki/jamJAR name of the title.
    let name: String?
    // Version of the title.
    let versionToInstall: String?
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case name
        case versionToInstall = "version_to_install"
    }
}

/// Represents the contents of `/Library/Managed Installs/ManagedInstallReport.plist`,
/// written by Munki after each run and read during postflight processing.
///
struct ManagedInstallReportContent: Codable {
    // Titles in `managed_installs` for which Munki found no newer version to install.
    let installedItems: [String]?
    // Details of items Munki attempted to install during this run.
    let installResults: [InstallResults]?
    // Titles present in the `managed_installs` array of the manifest.
    let managedInstalls: [ManagedInstallEntry]?
    // Titles in `managed_uninstalls` that Munki confirmed are no longer installed.
    let removedItems: [String]?
    // Details of items Munki attempted to uninstall during this run.
    let removalResults: [RemovalResults]?
    // Any warnings raised during the Munki run.
    let warnings: [String]?
    enum CodingKeys: String, CodingKey {
        case installedItems = "InstalledItems"
        case installResults = "InstallResults"
        case managedInstalls = "ManagedInstalls"
        case removedItems = "RemovedItems"
        case removalResults = "RemovalResults"
        case warnings = "Warnings"
    }
}

/// Reads and exposes all user-configurable preferences from the `ManagedInstalls`
/// preference domain, respecting any MDM-delivered configuration profiles.
///
struct MunkiVariables {
    // Read in Munki's preferences.
    static let munkiDefaults = UserDefaults(suiteName: "ManagedInstalls")
    // Path to Munki's `InstallInfo.plist`.
    static let installInfo = managedInstallDir + "InstallInfo.plist"
    // Path to the Managed Installs directory.
    static let managedInstallDir = munkiDefaults?.object(forKey:
                                                        "ManagedInstallDir") as? String ?? "/Library/Managed Installs/"
    // Path to Munki's `ManagedInstallReport.plist`.
    static let managedInstallReport = managedInstallDir + "ManagedInstallReport.plist"
    // Name of the to the Munki manifest.
    static let manifestName = munkiDefaults?.object(forKey: "LocalOnlyManifest") as? String ?? "jamJAR"
    // Path to the Munki manifest.
    static let manifestPath = managedInstallDir + "manifests/" + manifestName
}

/// Bundles the display arguments needed to post or remove a pending notification.
///
struct NotificationDisplayArgs {
    // Whether to include a logout action button.
    let notificationButton: Bool
    // The label for the logout button.
    let notificationButtonText: String
    // The body text of the notification.
    let notificationText: String
    // The notification display style.
    let notificationType: String
}

/// Arguments bundle passed to the pending notification logic, describing the message content,
/// type, frequency, and logout button configuration.
///
struct PendingNotificationArgs {
    // Whether to display a logout button alongside the notification.
    let notificationButton: Bool
    // Text for the logout button.
    let notificationButtonText: String
    // The composited notification message text.
    let notificationText: String
    // The notification type.
    let notificationType: String
    // The pending message.
    let pendingMessage: String
    // How frequently pending install notifications are posted.
    let pendingMessageFrequency: String
    // Whether to notify the user about pending items.
    let pendingNotify: Bool
}

/// Bundles the run-time state for a single pending notification processing pass.
///
struct PendingRunState {
    // The current count of pending items as a string.
    let pendingItemsCount: String
    // Whether user notifications should be posted for pending items.
    let postNotifications: Bool
    // The pending item count recorded during the previous run.
    let priorPendingCount: String
    // The notification message text recorded during the previous run.
    let priorPendingMessage: String
}

/// Reads and exposes all user-configurable preferences from the `com.jamf.jamJAR`
/// preference domain, respecting any MDM-delivered configuration profiles.
///
struct PreferenceVariables {
    // The shared `UserDefaults` instance used to read preference values.
    static let jamJARDefaults = UserDefaults.standard
    // Whether to force processing, bypassing normal deferral and termination checks.
    static let forceProcess = jamJARDefaults.object(forKey: "force_process") as? Bool ?? false
    // The title for all messages.
    static let notificationTitle = jamJARDefaults.object(forKey: "message_title") as? String ?? "jamJAR"
    // Whether to use Notifier for notificaitions or Management Action
    static let useNotifier = jamJARDefaults.object(forKey: "use_notifier") as? Bool ?? false
    // Path to the notifier application.
    static var notifierAppPath: String {
        // Notifier's path if `useNotifier` is true, Management Action if not.
        useNotifier ? "/Applications/Utilities/Notifier.app"
                    : "/Library/Application Support/JAMF/bin/Management Action.app"
    }
    // Path to the notifier binary.
    static var notifierBinaryPath: String {
        // Notifier's path if `useNotifier` is true, Management Action if not.
        notifierAppPath + (useNotifier ? "/Contents/MacOS/Notifier"
                                       : "/Contents/MacOS/Management Action")
    }
    // Whether verbose logging is enabled.
    static let verboseMode = jamJARDefaults.object(forKey: "verbose_mode") as? Bool ?? false
    // The "Install Messages" preference dictionary.
    static let installMessages = PreferenceVariables.jamJARDefaults.dictionary(forKey:
                                            "Install Messages") as Dictionary? ?? [String: Any]()
    // Installed message.
    static let installedMessage = PreferenceVariables.installMessages["installed_message"] as?
                                      String ?? "%DISPLAYNAME% %DISPLAYVERSION% has been installed."
    // Whether to notify the user when items have been installed.
    static let installedNotify = PreferenceVariables.installMessages["notify_installed"] as? Bool ?? true
    // The installed message type.
    static let installedNotificationType = PreferenceVariables.installMessages["installed_notification_type"]
                                             as? String ?? "banner"
    // The "Pending Install Messages" preference dictionary.
    static let pendingInstallMessages = PreferenceVariables.jamJARDefaults.dictionary(forKey:
                                             "Pending Install Messages") as Dictionary? ?? [String: Any]()
    // Pending install message.
    static let pendingInstallMessage = PreferenceVariables.pendingInstallMessages["pending_install_message"] as?
                                         String ?? """
                                                One or more items are pending installation. Click here for more \
                                                information or log out and the pending items will be installed.
                                                """
    // Frequency of which pending install messages are posted.
    static let pendingInstallMessageFrequency =
                 PreferenceVariables.pendingInstallMessages["pending_install_message_frequency"]
                   as? String ?? "every_run"
    // Whether to display a logout button when install items are pending.
    static let pendingInstallMessageLogoutButton =
                 PreferenceVariables.pendingInstallMessages["pending_logout_install_button"] as? Bool ?? true
    // Sets the text on the pending install logout button.
    static let pendingInstallMessageLogoutButtonText =
                PreferenceVariables.pendingInstallMessages["pending_logout_install_button_text"] as? String ?? "Logout"
    // Whether to notify the user about pending install items.
    static let pendingInstallNotify = PreferenceVariables.pendingInstallMessages["notify_pending_install"]
                                         as? Bool ?? true
    // The pending install message type.
    static let pendingInstallNotificationType =
                 PreferenceVariables.pendingInstallMessages["notify_pending_install_type"] as? String ?? "alert"
    // The "Pending Uninstall Messages" preference dictionary.
    static let pendingUninstallMessages = PreferenceVariables.jamJARDefaults.dictionary(forKey:
                                             "Pending Uninstall Messages") as Dictionary? ?? [String: Any]()
    // Pending uninstall message.
    static let pendingUninstallMessage = PreferenceVariables.pendingUninstallMessages["pending_uninstall_message"]
                                          as? String ?? """
                                            One or more items are pending uninstallation. Click here for more \
                                            information or log out and the pending items will be uninstalled.
                                            """
    // Frequency of which pending uninstall messages are posted.
    static let pendingUninstallMessageFrequency =
                 PreferenceVariables.pendingUninstallMessages["pending_uninstall_message_frequency"]
                   as? String ?? "every_run"
    // Whether to display a logout button when uninstall items are pending.
    static let pendingUninstallMessageLogoutButton =
                 PreferenceVariables.pendingUninstallMessages["pending_logout_uninstall_button"] as?  Bool ?? true
    // Sets the text displayed on the pending uninstall logout button.
    static let pendingUninstallMessageLogoutButtonText =
                 PreferenceVariables.pendingUninstallMessages["pending_logout_uninstall_button_text"]
                   as? String ?? "Logout"
    // Whether to notify the user about pending uninstall items.
    static let pendingUninstallNotify =
                 PreferenceVariables.pendingUninstallMessages["notify_pending_uninstall"] as? Bool ?? false
    // The pending uninstall message type.
    static let pendingUninstallNotificationType =
                 PreferenceVariables.pendingUninstallMessages["notify_pending_uninstall_type"] as? String ?? "alert"
    // The "Uninstall Messages" preference dictionary.
    static let uninstallMessages = PreferenceVariables.jamJARDefaults.dictionary(forKey: "Uninstall Messages")
                                     as Dictionary? ?? [String: Any]()
    // Uninstalled message.
    static let uninstalledMessage = PreferenceVariables.uninstallMessages["uninstalled_message"]
                                      as? String ?? "%DISPLAYNAME% has been uninstalled."
    // Whether to notify the user when items have been uninstalled.
    static let uninstalledNotify = PreferenceVariables.uninstallMessages["notify_uninstalled"]
                                     as? Bool ?? false
    // The uninstalled message type.
    static let uninstalledNotificationType = PreferenceVariables.uninstallMessages["uninstalled_notification_type"]
                                                as? String ?? "banner"
    // The "Up-to-date Messages" preference dictionary.
    static let upToDateMessages = PreferenceVariables.jamJARDefaults.dictionary(forKey: "Up-to-date Messages")
                                     as Dictionary? ?? [String: Any]()
    // Up-to-date message.
    static let upToDateMessage = PreferenceVariables.upToDateMessages["notify_up_to_date_message"]
                                      as? String ?? "The latest version of %DISPLAYNAME% is installed."
    // Whether to notify the user when items are already up-to-date after a Self Service install attempt.
    static let upToDateNotify = PreferenceVariables.upToDateMessages["notify_up_to_date"]
                                     as? Bool ?? true
    // The up-to-date message type.
    static let upToDateNotificationType = PreferenceVariables.upToDateMessages["up_to_date_notification_type"]
                                                as? String ?? "banner"
}

/// Launchd items and package receipts identified for removal during uninstall.
///
struct RemovalArrays {
    // Launch Agent plist paths matching the removal prefixes.
    let launchAgentPlists: [String]
    // Launch Daemon plist paths matching the removal prefixes.
    let launchDaemonPlists: [String]
    // Package receipt identifiers matching the removal prefixes.
    let pkgReceipts: [String]
}

/// Details of an item Munki attempted to uninstall during this run.
///
struct RemovalResults: Codable {
    // Display name of the title.
    let displayName: String?
    // Munki/jamJAR name of the title.
    let name: String?
    // Status, where 0 = installed.
    let status: Int?
    // Version of the title.
    let version: String?
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case name, status, version
    }
}
