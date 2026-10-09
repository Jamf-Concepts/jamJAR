//
//  notify.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation

/// Builds a `PendingNotificationArgs` value populated with the preference settings for the
/// given pending item type.
///
/// - Parameters:
///   - itemType: The type of pending item — `"install"` or `"uninstall"`.
///   - pendingItemsCount: The number of items currently pending, substituted into the
///       message body via the `%DISPLAYPENDING%` token.
///
/// - Returns:
///   A `PendingNotificationArgs` value configured with the message text, frequency, button,
///     and notification type for the given `itemType`.
///
func createNotificationArguments(itemType: String, pendingItemsCount: Int) -> PendingNotificationArgs {
    // Verbose logging.
    log.verbose("""
                \(#function.components(separatedBy: "(")[0]) - itemType: \(itemType), pendingItemsCount: \
                \(pendingItemsCount)
                """)
    // If we're to look for install items
    if itemType == "install" {
        return PendingNotificationArgs(
            notificationButton: PreferenceVariables.pendingInstallMessageLogoutButton,
            notificationButtonText: PreferenceVariables.pendingInstallMessageLogoutButtonText,
            notificationText: generateNotificationText(notificationBody: PreferenceVariables.pendingInstallMessage,
                                                        varDict: ["displayPending": String(pendingItemsCount)]),
            notificationType: PreferenceVariables.pendingInstallNotificationType,
            pendingMessage: PreferenceVariables.pendingInstallMessage,
            pendingMessageFrequency: PreferenceVariables.pendingInstallMessageFrequency,
            pendingNotify: PreferenceVariables.pendingInstallNotify
        )
    // Else we're to look for uninstall items
    } else {
        return PendingNotificationArgs(
            notificationButton: PreferenceVariables.pendingUninstallMessageLogoutButton,
            notificationButtonText: PreferenceVariables.pendingUninstallMessageLogoutButtonText,
            notificationText: generateNotificationText(notificationBody: PreferenceVariables.pendingUninstallMessage,
                                                        varDict: ["displayPending": String(pendingItemsCount)]),
            notificationType: PreferenceVariables.pendingUninstallNotificationType,
            pendingMessage: PreferenceVariables.pendingUninstallMessage,
            pendingMessageFrequency: PreferenceVariables.pendingUninstallMessageFrequency,
            pendingNotify: PreferenceVariables.pendingUninstallNotify
        )
    }
}

/// Generates the notification body text, replacing `%PLACEHOLDER%` tokens with their values.
///
/// Iterates over entries in `varDict` whose keys begin with `display`, uppercases each key,
/// and replaces the corresponding `%KEY%` placeholder in `notificationBody` with its value.
/// For example, the key `"displayVersion"` replaces `%DISPLAYVERSION%` in the body text.
///
/// - Parameters:
///   - notificationBody: The notification message template, optionally containing
///       `%DISPLAYNAME%` and `%DISPLAYVERSION%` placeholders.
///   - varDict: A dictionary of substitution variables. Only entries whose keys begin
///       with `"display"` are substituted.
///
/// - Returns:
///   The notification body string with all matching placeholders replaced.
///
func generateNotificationText(notificationBody: String, varDict: [String: String]) -> String {
    // Var declaration(s).
    var messageBody = notificationBody
    // For each entry in `varDict` that starts with display...
    for someVar in varDict where someVar.key.hasPrefix("display") {
        // Verbose logging.
        log.verbose("""
                    \(#function.components(separatedBy: "(")[0]) - \
                    replacingOccurrences(of: %\(someVar.key.uppercased())%, with: \(someVar.value)")
                    """)
        // Get the key, and turn upper case. Then replace the occurrences in the body.
        // For examples: replace %DISPLAYVERSION% with the value of varDict["displayVersion']
        messageBody = messageBody.replacingOccurrences(of: "%\(someVar.key.uppercased())%", with: someVar.value)
    }
    // Verbose logging.
    log.verbose("\(#function.components(separatedBy: "(")[0]) - messageBody: \(messageBody)")
    // Return.
    return messageBody
}

/// Notifies the logged-in user that a title has been successfully installed.
///
/// Does nothing if no user is logged in or if `installedNotify` is disabled. Logs a warning
/// if `displayName` or `displayVersion` are missing from `varDict`.
///
/// - Parameters:
///   - varDict: A dictionary containing at minimum `displayName`, `displayVersion`,
///       and `itemName` for the installed title.
///
func notifyInstalled(varDict: [String: String]) {
    // Get the username of the logged in user
    let loggedInUser = loggedInUser()
    // Check to see if at the loginwindow and we're to notify installed, before looking to notify
    if loggedInUser != "" && PreferenceVariables.installedNotify {
        // If varDict contains both displayName and displayVersion
        if varDict.keys.contains("displayName") && varDict.keys.contains("displayVersion") {
            // Generate the message body
            let notificationText = generateNotificationText(notificationBody: PreferenceVariables.installedMessage,
                                                            varDict: varDict)
            // Info logging.
            log.info("Notifying that \(varDict["displayName"]!) (\(varDict["displayVersion"]!)) has been installed...")
            // Notify that the title has been installed/updated.
            postNotification(notificationButton: false, notificationButtonText: "",
                             notificationText: notificationText, notificationType:
                                PreferenceVariables.installedNotificationType)
            // If there is an issue with the metadata for the title
        } else {
            // Log warning
            log.warning("""
                        Cannot notify that \(varDict["itemName"]!) has been installed, \
                        as either the display name or version are missing.
                        """)
        }
    // If we're logged in and we're not to notify, log we've installed an item
    } else if loggedInUser != "" && !PreferenceVariables.installedNotify {
        // Info logging.
        log.info("\(varDict["displayName"]!) (\(varDict["displayVersion"]!)) has been installed...")
    // If no-one is logged in
    } else {
        // Info logging.
        log.info("No-one logged in, \(varDict["displayName"]!) (\(varDict["displayVersion"]!)) has been installed.")
    }
}

/// Notifies the logged-in user that the installed version of a title is already up-to-date.
///
/// Only fires when triggered via Self Service (i.e. the `USER` environment variable is set
/// and is not `root`). Does nothing if `upToDateNotify` is disabled.
///
/// - Parameters:
///   - varDict: A dictionary containing at minimum `displayName` and `displayVersion`
///       for the title.
///
func notifyUpToDate(varDict: [String: String]) {
    // Get the username of the logged in user
    let loggedInUser = loggedInUser()
    // Check to see if at the loginwindow and we're to notify items are up-to-date, before looking to notify
    if loggedInUser != "" && PreferenceVariables.upToDateNotify {
        // If varDict contains both displayName and displayVersion
        if varDict.keys.contains("displayName") && varDict.keys.contains("displayVersion") {
            // Generate the message body
            let notificationText = generateNotificationText(notificationBody: PreferenceVariables.upToDateMessage,
                                                            varDict: varDict)
            // Info logging.
            log.info("Notifying that \(varDict["displayName"]!) is up-to-date...")
            // Notify that the title is up-to-date
            postNotification(notificationButton: false, notificationButtonText: "",
                             notificationText: notificationText, notificationType:
                                PreferenceVariables.upToDateNotificationType)
        }
    // If we're logged in and we're not to notify, log we're up-to-date
    } else if loggedInUser != "" && !PreferenceVariables.upToDateNotify {
        // Info logging.
        log.info("\(varDict["displayName"]!) is up-to-date...")
    }
}

/// Notifies the logged-in user that a title has been successfully uninstalled.
///
/// Does nothing if no user is logged in or if `uninstalledNotify` is disabled. Logs a warning
/// if `displayName` or `displayVersion` are missing from `varDict`.
///
/// - Parameters:
///     - varDict: A dictionary containing at minimum `displayName`, `displayVersion`,
///       and `itemName` for the uninstalled title.
///
func notifyUninstalled(varDict: [String: String]) {
    // Get the username of the logged in user
    let loggedInUser = loggedInUser()
    // Check to see if at the loginwindow and we're to notify uninstalled, before looking to notify
    if loggedInUser != "" && PreferenceVariables.uninstalledNotify {
        // If varDict contains both displayName and displayVersion
        if varDict.keys.contains("displayName") && varDict.keys.contains("displayVersion") {
            // Generate the message body
            let notificationText = generateNotificationText(notificationBody: PreferenceVariables.uninstalledMessage,
                                                            varDict: varDict)
            // Info logging.
            log.info("Notifying that \(varDict["displayName"]!) has been uninstalled...")
            // Notify that the title has been uninstalled.
            postNotification(notificationButton: false, notificationButtonText: "",
                             notificationText: notificationText, notificationType:
                                PreferenceVariables.uninstalledNotificationType)
            // If there is an issue with the metadata for the title
        } else {
            // Log warning
            log.warning("""
                        Cannot notify that \(varDict["itemName"]!) has been uninstalled, \
                        as either the display name or version are missing.
                        """)
        }
    // If we're logged in and we're not to notify, log we've uninstalled an item
    } else if loggedInUser != "" && !PreferenceVariables.uninstalledNotify {
        // Info logging.
        log.info("\(varDict["displayName"]!) has been uninstalled...")
    // If no-one is logged in
    } else {
        // Info logging.
        log.info("No-one logged in, \(varDict["displayName"]!) (\(varDict["displayVersion"]!)) has been uninstalled.")
    }
}

/// Delivers a notification via Notifier.app.
///
/// Builds the argument list for the Notifier binary and runs it synchronously. When
/// `notificationButton` is `true`, a logout button is appended whose label is
/// `notificationButtonText`.
///
/// - Parameters:
///     - notificationButton: Whether to include a logout action button in the notification.
///     - notificationButtonText: The label for the logout button (ignored when `notificationButton` is `false`).
///     - notificationText: The body text of the notification.
///     - notificationType: The notification style — `"banner"` or `"alert"`.
///
func postNotification(notificationButton: Bool, notificationButtonText: String, notificationText: String,
                      notificationType: String) {
    // Var declaration(s).
    var taskArguments = [String]()
    // If we're to add a button to the post
    if notificationButton {
        // Set arguments to the notification details
        taskArguments = ["--messageaction", "'" + GlobalVariables.managedSoftwareCenterPath + "'",
                         "--message", notificationText,
                         "--title", PreferenceVariables.notificationTitle,
                         "--type", notificationType,
                         "--messagebutton", notificationButtonText,
                         "--messagebuttonaction", "logout"]
    // If no button
    } else {
        // Set arguments to the notification details
        taskArguments = ["--messageaction", "'" + GlobalVariables.managedSoftwareCenterPath + "'",
                         "--message", notificationText,
                         "--title", PreferenceVariables.notificationTitle,
                         "--type", notificationType]
    }
    // If we have arguments
    if !taskArguments.isEmpty {
        // Set to the path to the Notifier.app
        let taskPath = PreferenceVariables.notifierBinaryPath
        // Run the task, ignoring returned data and exit status
        (_, _) = runTask(callMethod: "", logActions: true, taskPath: taskPath, taskArguments: taskArguments,
                         waitUntilExit: true)
    }
}

/// Removes a prior pending notification from Notification Center and clears the related preference keys.
///
/// Constructs the appropriate arguments for the Notifier binary to dismiss the previously posted
/// notification. The preference keys in `prefKeyArray` are then deleted from the user plist using
/// `CFPreferences`, and file ownership and permissions are reset if a user is logged in.
///
/// - Parameters:
///   - itemType: The type of managed item. Pass an empty string when running as the logged-in user.
///   - loggedInUser: The username of the currently logged-in user.
///   - displayArgs: The notification display arguments used to identify and dismiss the prior notification.
///   - prefKeyArray: An array of preference key names to delete from the user plist.
///   - userPlist: The path to the user's preference plist file.
func removePriorNotification(itemType: String, loggedInUser: String,
                             displayArgs: NotificationDisplayArgs,
                             prefKeyArray: [String], userPlist: String) {
    // If itemType has a value, we're being ran as root
    if itemType != "" {
        // Verbose logging.
        log.verbose("""
                    \(#function.components(separatedBy: "(")[0]) - loggedInUser: \(loggedInUser), \
                    notificationButton: \(displayArgs.notificationButton), notificationButtonText: \
                    \(displayArgs.notificationButtonText), notificationText: \(displayArgs.notificationText), \
                    notificationType: \(displayArgs.notificationType), prefKeyArray: \(prefKeyArray), \
                    userPlist: \(userPlist)
                    """)
    }
    // Var declaration(s).
    var taskArguments = [String]()
    // If the message had a button added to it post
    if displayArgs.notificationButton {
        // Set arguments to the notification details
        taskArguments = ["--messageaction", "'" + GlobalVariables.managedSoftwareCenterPath + "'",
                         "--message", displayArgs.notificationText,
                         "--remove", "prior",
                         "--title", PreferenceVariables.notificationTitle,
                         "--type", displayArgs.notificationType,
                         "--messagebutton", displayArgs.notificationButtonText,
                         "--messagebuttonaction", "logout"]
    // If no button
    } else {
        // Set arguments to the notification details
        taskArguments = ["--messageaction", "'" + GlobalVariables.managedSoftwareCenterPath + "'",
                         "--message", displayArgs.notificationText,
                         "--remove", "prior",
                         "--title", PreferenceVariables.notificationTitle,
                         "--type", displayArgs.notificationType]
    }
    // If we have arguments
    if !taskArguments.isEmpty {
        // Set to the path to the Notifier.app
        let taskPath = PreferenceVariables.notifierBinaryPath
        // Run the task, ignoring returned data and exit status
        (_, _) = runTask(callMethod: "", logActions: false, taskPath: taskPath, taskArguments: taskArguments,
                         waitUntilExit: true)
    }
    // If itemType has a value, we're being ran as root
    if itemType != "" {
        // Verbose logging.
        log.verbose("\(#function.components(separatedBy: "(")[0]) - prefKeyArray: \(prefKeyArray)")
    }
    // For each key in the prefKeyArray
    for prefKey in prefKeyArray {
        // If itemType has a value, we're being ran as root
        if itemType != "" {
            // Verbose logging.
            log.verbose("\(#function.components(separatedBy: "(")[0]) - Removing \(prefKey) from \(userPlist)")
        }
        // Remove the key
        CFPreferencesSetAppValue(prefKey as CFString, nil, userPlist as CFString)
    }
    // Write the preferences to disk
    CFPreferencesAppSynchronize(userPlist as CFString)
    // If we're logged in set the perms for the userPlist
    if loggedInUser != "" {
        // If itemType has a value, we're being ran as root
        if itemType != "" {
            // Verbose logging.
            log.verbose("""
                    \(#function.components(separatedBy: "(")[0]) - Setting  \(loggedInUser) as the owner of \
                    \(userPlist)
                    """)
        }
        // Set file to 700 perms, with the loggedInUser having rw
        try? FileManager.default.setAttributes([.ownerAccountName: loggedInUser, .posixPermissions: 0o700],
                                               ofItemAtPath: userPlist)
    }
}
