//
//  processPending.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation

/// Processes pending managed software items, routing logic to run either as root or as the logged-in user.
///
/// When called as root (non-empty `itemType`), retrieves notification arguments, reads prior pending
/// state from the user plist, and delegates to ``processAsRoot``.
/// When called as the user (empty `itemType`), delegates to ``processAsUser(loggedInUser:userPlist:)`` and exits.
///
/// - Parameters:
///   - itemType: The type of managed item (`"install"` or `"uninstall"`). Pass an empty string when running as the
///               logged-in user.
///   - managedItemsArray: Array of managed item names currently pending.
///   - postNotifications: Whether user notifications should be posted for pending items.
///
func processPending(itemType: String, managedItemsArray: [String], postNotifications: Bool) {
    // If `itemType` has a value, we're being ran as root...
    if itemType != "" {
        // Verbose logging.
        log.verbose("""
                \(#function.components(separatedBy: "(")[0]) - itemType: \(itemType), managedItemsArray: \
                \(managedItemsArray), postNotifications: \(postNotifications)
                """)
    }
    // Get the username of the logged in user.
    let loggedInUser = loggedInUser()
    // Get users path to the plist within the users account.
    let userPlist = URL(fileURLWithPath: NSHomeDirectoryForUser(loggedInUser) ??
                            NSHomeDirectory()).appendingPathComponent("Library/Preferences/" +
                                                GlobalVariables.jamJARBundleId + ".plist").path
    // If `itemType` has a value, we're being ran as root...
    if itemType != "" {
        // Creates notificationArgs object
        let notificationArgs = createNotificationArguments(itemType: itemType,
                                                           pendingItemsCount: managedItemsArray.count)
        // Read values from the user plist...
        let (priorPendingCount, priorPendingMessage) = readUserPlist(userPlist: userPlist, itemType: itemType)
        // Verbose logging.
        log.verbose("""
                    \(#function.components(separatedBy: "(")[0]) - priorPendingCount: \(priorPendingCount), \
                    priorPendingMessage: \(priorPendingMessage)
                    """)
        // Process pending as root.
        processAsRoot(itemType: itemType, loggedInUser: loggedInUser, notificationArgs: notificationArgs,
                      runState: PendingRunState(pendingItemsCount: String(managedItemsArray.count),
                                               postNotifications: postNotifications,
                                               priorPendingCount: priorPendingCount,
                                               priorPendingMessage: priorPendingMessage),
                      userPlist: userPlist)
    // With no value it's being ran as the user...
    } else {
        // Process pending as the user.
        processAsUser(loggedInUser: loggedInUser, userPlist: userPlist)
        // Exit
        exit(0)
    }
}

/// Processes pending managed software items when running as root.
///
/// Evaluates whether a notification should be posted based on the notification frequency setting and
/// whether the pending item count has changed since the last run. If no items are pending but a prior
/// notification exists, it is removed via ``removePriorNotification``.
///
/// - Parameters:
///   - itemType: The type of managed item (`"install"` or `"uninstall"`).
///   - loggedInUser: The username of the currently logged-in user.
///   - notificationArgs: A ``PendingNotificationArgs`` object containing notification configuration.
///   - runState: The run-time state for this pending processing pass.
///   - userPlist: The path to the user's preference plist file.
///
func processAsRoot(itemType: String, loggedInUser: String, notificationArgs: PendingNotificationArgs,
                   runState: PendingRunState, userPlist: String) {
    // Verbose logging.
    log.verbose("""
                \(#function.components(separatedBy: "(")[0]) - itemType: \(itemType), loggedInUser: \(loggedInUser), \
                pendingItemsCount: \(runState.pendingItemsCount), notificationArgs: \(notificationArgs), \
                postNotifications: \(runState.postNotifications), priorPendingCount: \(runState.priorPendingCount), \
                priorPendingMessage: \(runState.priorPendingMessage), userPlist: \(userPlist), \
                PreferenceVariables.forceProcess: \(PreferenceVariables.forceProcess)
                """)
    // If we're logged in, we're to notify about pending items, we have pending items, and we're not forcing
    if loggedInUser != "" && runState.postNotifications && notificationArgs.pendingNotify &&
        runState.pendingItemsCount != "0" && !PreferenceVariables.forceProcess {
        // Verbose logging.
        log.verbose("\(#function.components(separatedBy: "(")[0]) - items are pending and we're logged in")
        // If we're to notify every run OR we're to notify on change and there has been a change since the last run
        if notificationArgs.pendingMessageFrequency == "every_run" ||
           (notificationArgs.pendingMessageFrequency == "on_change" &&
            runState.pendingItemsCount != runState.priorPendingCount) {
            // Info logging.
            log.info("Notifying that items are pending " + itemType + "ation...")
            // Sleep for a few to not spam notification center
            sleep(5)
            // Notify that items are pending
            postNotification(notificationButton: notificationArgs.notificationButton,
                             notificationButtonText: notificationArgs.notificationButtonText,
                             notificationText: notificationArgs.notificationText,
                             notificationType: notificationArgs.notificationType)
            // Info logging.
            log.info("Writing pending details to: \(userPlist)")
            // Write pending item count to check next run, using defaults more consistent than CFPreferences for user 
            // preferences when root
            (_, _) = runTask(callMethod: "", logActions: true, taskPath: "/usr/bin/defaults",
                             taskArguments: ["write", userPlist, "prior_pending_" + itemType + "_count",
                                             "-int", String(describing: runState.pendingItemsCount)],
                             waitUntilExit: true)
            // Write pending message to check next run, using defaults more consistent than CFPreferences for user
            // preferences when root
            (_, _) = runTask(callMethod: "", logActions: true, taskPath: "/usr/bin/defaults",
                             taskArguments: ["write", userPlist, "prior_pending_" + itemType + "_message",
                                             "-string", notificationArgs.notificationText], waitUntilExit: true)
            // Write the preferences to disk, using defaults more consistent than CFPreferences for user preferences
            // when root
            (_, _) = runTask(callMethod: "", logActions: true, taskPath: "/usr/bin/defaults",
                             taskArguments: ["read", userPlist], waitUntilExit: true)
            // Set file to 700 perms, with the loggedInUser having rw
            try? FileManager.default.setAttributes([.ownerAccountName: loggedInUser, .posixPermissions: 0o700],
                                                   ofItemAtPath: userPlist)
        // If we don't meet the prior criteria
        } else {
            // Verbose logging.
            log.verbose("\(#function.components(separatedBy: "(")[0]) - notifying criteria not met")
        }
    // If logged in and we're to notify about pending items, but have none.. clear message from notification center
    } else if loggedInUser != "" && notificationArgs.pendingNotify && runState.pendingItemsCount == "0" {
        // Verbose logging.
        log.verbose("\(#function.components(separatedBy: "(")[0]) - no pending \(itemType)s and we're logged in.")
        // If we have notified the logged in user of pending items
        if runState.priorPendingMessage != "" {
            // Remove prior pending message (if applicable) and logged in as the same used that was notified before
            removePriorNotification(itemType: itemType, loggedInUser: loggedInUser,
                                    displayArgs: NotificationDisplayArgs(
                                        notificationButton: notificationArgs.notificationButton,
                                        notificationButtonText: notificationArgs.notificationButtonText,
                                        notificationText: runState.priorPendingMessage,
                                        notificationType: notificationArgs.notificationType),
                                    prefKeyArray: ["prior_pending_" + itemType + "_message",
                                                   "prior_pending_" + itemType + "_count"],
                                    userPlist: userPlist)
        }
    }
}

/// Processes pending managed software items when running as the logged-in user.
///
/// Reads prior pending install and uninstall state from the user plist. If items that were previously
/// pending are no longer pending, any prior notifications are removed via ``removePriorNotification``.
///
/// - Parameters:
///   - loggedInUser: The username of the currently logged-in user.
///   - userPlist: The path to the user's preference plist file.
///
func processAsUser(loggedInUser: String, userPlist: String) {
    // Get pending install details from the user plist
    let (priorInstallPendingCount, priorInstallMessage) = readUserPlist(userPlist: userPlist, itemType: "install")
    // Info logging.
    toggleLogging(callMethod: "user", logLevel: "INFO", logMessage: """
                     Prior pending install count: \(priorInstallPendingCount), prior pending install message: \
                     \(priorInstallMessage)
                     """)
    // Get pending install details from the user plist
    let (priorUninstallPendingCount, priorUninstallMessage) = readUserPlist(userPlist: userPlist, itemType: "uninstall")
    // Info logging.
    toggleLogging(callMethod: "user", logLevel: "INFO", logMessage: """
                    Prior pending uninstall count: \(priorUninstallPendingCount), \
                    prior pending uninstall message: \(priorUninstallMessage)
                    """)
    // Look for items within the manifest
    let (managedInstallsArray, managedUninstallsArray) = processManifest(asUser: true)
    // If we have no pending installs, but did when the user was last logged in & we're to notify of pending installs
    if managedInstallsArray.isEmpty && priorInstallPendingCount != "0" && PreferenceVariables.pendingInstallNotify {
        // Info logging.
        toggleLogging(callMethod: "user", logLevel: "INFO", logMessage: "Clearing pending installs from: \(userPlist)")
        // Info logging.
        toggleLogging(callMethod: "user", logLevel: "INFO", logMessage: "Prior text: \(priorInstallMessage)")
        // If we have prior notificationText
        if priorInstallMessage != "" {
            // Info logging.
            toggleLogging(callMethod: "user", logLevel: "INFO", logMessage: "Removing the prior notification...")
            // Remove prior pending message (if applicable) and logged in as the same used that was notified before
            removePriorNotification(itemType: "", loggedInUser: loggedInUser,
                                    displayArgs: NotificationDisplayArgs(
                                        notificationButton: PreferenceVariables.pendingInstallMessageLogoutButton,
                                        notificationButtonText:
                                            PreferenceVariables.pendingInstallMessageLogoutButtonText,
                                        notificationText: priorInstallMessage,
                                        notificationType: PreferenceVariables.pendingInstallNotificationType),
                                    prefKeyArray: ["prior_pending_install_message", "prior_pending_install_count"],
                                    userPlist: userPlist)
        }
    }
    // If we have no pending uninstalls, but did when the user was last logged in & we're to notify of pending installs
    if managedUninstallsArray.isEmpty && priorUninstallPendingCount != "0" &&
        PreferenceVariables.pendingUninstallNotify {
        // Info logging.
        toggleLogging(callMethod: "user", logLevel: "INFO", logMessage:
                        "Clearing pending uninstalls from: \(userPlist)")
        // Info logging.
        toggleLogging(callMethod: "user", logLevel: "INFO", logMessage:
                        "Prior notification text: \(priorUninstallMessage)")
        // If we have prior notificationText
        if priorUninstallMessage != "" {
            // Info logging.
            toggleLogging(callMethod: "user", logLevel: "INFO", logMessage: "Removing the prior notification...")
            // Remove prior pending message (if applicable) and logged in as the same used that was notified before
            removePriorNotification(itemType: "", loggedInUser: loggedInUser,
                                    displayArgs: NotificationDisplayArgs(
                                        notificationButton: PreferenceVariables.pendingUninstallMessageLogoutButton,
                                        notificationButtonText:
                                            PreferenceVariables.pendingUninstallMessageLogoutButtonText,
                                        notificationText: priorUninstallMessage,
                                        notificationType: PreferenceVariables.pendingUninstallNotificationType),
                                    prefKeyArray: ["prior_pending_uninstall_message",
                                                   "prior_pending_uninstall_count"],
                                    userPlist: userPlist)
        }
    }
}

/// Returns the prior pending item count and notification message stored in the user's preference plist.
///
/// Reads two preference keys — `prior_pending_{itemType}_count` and `prior_pending_{itemType}_message` —
/// using `/usr/bin/defaults`. If the plist does not exist or the keys are absent, default values
/// (`"0"` and `""`) are returned.
///
/// - Parameters:
///   - userPlist: The path to the user's preference plist file.
///   - itemType: The type of managed item (`"install"` or `"uninstall"`).
///
/// - Returns:
///   A tuple of `(priorPendingCount, priorPendingMessage)`.
///
func readUserPlist(userPlist: String, itemType: String) -> (String, String) {
    // Var declaration(s).
    var keyDefined = Bool()
    var keyValue = String()
    var priorPendingCount = String()
    var priorPendingMessage = String()
    // If userPlist exists
    if FileManager.default.fileExists(atPath: userPlist) {
        // Use defaults to read look for preference key
        (keyValue, keyDefined) = runTask(callMethod: "", logActions: false, taskPath: "/usr/bin/defaults",
                                         taskArguments: ["read", userPlist, "prior_pending_" + itemType + "_count"],
                                         waitUntilExit: true)
        // If the prior_pending_install_count is defined, set priorPendingCount
        if keyDefined == true {
            // Set priorPendingCount to keyValue
            priorPendingCount = keyValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // If prior_pending_install_count is not defined
        } else {
            // Set priorPendingCount to keyValue
            priorPendingCount = "0"
        }
        // Use defaults to read look for preference key
        (keyValue, keyDefined) = runTask(callMethod: "", logActions: false, taskPath: "/usr/bin/defaults",
                                         taskArguments: ["read", userPlist, "prior_pending_" + itemType + "_message"],
                                         waitUntilExit: true)
        // If the prior_pending_install_message is defined, set priorPendingMessage
        if keyDefined == true {
            // Set priorPendingCount to keyValue as string
            priorPendingMessage = keyValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // If prior_pending_install_count is not defined
        } else {
            // Set priorPendingMessage to an empty string
            priorPendingMessage = ""
        }
    // If userPlist is missing, return default values
    } else {
        // Set priorPendingCount to 0
        priorPendingCount = "0"
        // Set priorPendingMessage to an empty string
        priorPendingMessage = ""
    }
    // Return the keys value
    return (priorPendingCount, priorPendingMessage)
}
