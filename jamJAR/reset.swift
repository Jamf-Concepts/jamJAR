//
//  reset.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation

/// Performs a full reset of jamJAR, restoring all settings and caches to their defaults.
///
/// Clears the Munki manifest, removes pending install and uninstall notifications, empties the
/// Managed Installs directory, resets preference domains for both jamJAR and Munki, deletes
/// per-user preference plists, clears root's Managed Installs plist, and removes log files. Exits
/// with code `0` on completion.
///
/// - Parameters:
///   - parsedResult: The parsed command-line arguments.
///
func reset(parsedResult: JamJAR) {
    // Info logging.
    toggleLogging(callMethod: "arg", logLevel: "INFO", logMessage:
            "jamJAR - \(GlobalVariables.jamJARVersion) - Resetting...")
    // If we have a manifest
    if FileManager.default.fileExists(atPath: MunkiVariables.manifestPath) {
        // Reset the manifest
        (_, _) = updateManifest(managedInstallsArray: [], managedUninstallsArray: [])
    }
    // Remove prior install pending notifications
    processPending(itemType: "install", managedItemsArray: [], postNotifications: false)
    // Remove prior uninstall pending notifications
    processPending(itemType: "uninstall", managedItemsArray: [], postNotifications: false)
    // Check that /Library/Managed Installs/ exists
    if FileManager.default.fileExists(atPath: MunkiVariables.managedInstallDir) {
        // Get the contents of the supplied directory
        let dirContents: [String]? = try? FileManager.default.contentsOfDirectory(atPath:
                                                                                    MunkiVariables.managedInstallDir)
        // If we found any items
        if dirContents != [] {
            // Info logging.
            toggleLogging(callMethod: "arg", logLevel: "INFO", logMessage:
                            "Emptying: \(MunkiVariables.managedInstallDir)")
            // For each found item
            for foundItem in dirContents! {
                // Delete the item
                deleteItem(itemPath: MunkiVariables.managedInstallDir + "/" + foundItem)
            }
            // Info logging.
            toggleLogging(callMethod: "arg", logLevel: "INFO", logMessage:
                            "Emptied: \(MunkiVariables.managedInstallDir)")
        }
    }
    // Resets the main preferences
    resetPreferenceDomain(prefDomain: GlobalVariables.jamJARBundleId)
    // Resets munki's main preferences
    resetPreferenceDomain(prefDomain: "ManagedInstalls")
    // Looks for user dirs
    let userDirs = try? FileManager.default.contentsOfDirectory(atPath: "/Users/")
    // If we have located some items
    for userDir in userDirs!.sorted() {
        // Path to the user plist
        let userPlist = "/Users/" + userDir + "/Library/Preferences/" + GlobalVariables.jamJARBundleId + ".plist"
        // Delete the file
        deleteItem(itemPath: userPlist)
    }
    // Create a list of misc items to delete
    let fileList = [GlobalVariables.logPath]
    // For each entry in fileList, that exists
    for filePath in fileList where FileManager.default.fileExists(atPath: filePath) {
        // Delete the file
        deleteItem(itemPath: filePath)
        // Info logging.
        toggleLogging(callMethod: "arg", logLevel: "INFO", logMessage: "Deleted: \(filePath)")
    }
    // Info logging.
    toggleLogging(callMethod: "arg", logLevel: "INFO", logMessage: "Reset complete.")
    // Exit
    exit(0)
}
