//
//  Manifest.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation

/// Adds or removes a title from the `managed_installs` or `managed_uninstalls` array in the
/// jamJAR manifest, then triggers a Munki run if anything remains pending.
///
/// After updating the manifest, calls `processPending` to refresh any outstanding notification
/// state, then calls `runMunki() if either array is non-empty. Exits with status `0`.
///
/// - Parameters:
///   - actionType: The operation to perform — `"add"` to append the title, or `"remove"` to
///       delete all occurrences of it.
///   - sectionName: The manifest key to modify — `"managed_installs"` or
///       `"managed_uninstalls"`.
///   - titleName: The Munki title name to add or remove.
///
func modifyManifest(actionType: String, sectionName: String, titleName: String) {
    // Var declaration(s).
    var modificationMessage = String()
    // Print to stdout.
    print("For jamJAR logs, please see: \(GlobalVariables.logPath).")
    // Verbose logging.
    log.verbose("""
                \(#function.components(separatedBy: "(")[0]) - actionType: \(actionType), \
                sectionName: \(sectionName), titleName: \(titleName)
                """)
    // Info logging.
    log.info("jamJAR - \(GlobalVariables.jamJARVersion) - Modifying manifest...")
    // Look for the installs arrays within the manifest.
    var (managedInstallsArray, managedUninstallsArray) = getInstallsArrays(asUser: false)
    // If we're to modify `managed_installs`...
    if sectionName == "managed_installs" {
        // If we're to add
        if actionType == "add" {
            // Add `titleName` to `managed_installs`.
            managedInstallsArray.append(titleName)
            // Set `modificationMessage`.
            modificationMessage = "Added \(titleName) to installs, installs now contains:"
        }
        // If we're to remove...
        if actionType == "remove" {
            // Remove any occurrences of `titleName` within `managed_installs`
            managedInstallsArray.removeAll { $0 == titleName }
            // Set `modificationMessage`
            modificationMessage = "Removed \(titleName) from installs, installs now contains:"
        }
    }
    // If we're to modify `managed_uninstalls`...
    if sectionName == "managed_uninstalls" {
        // If we're to add
        if actionType == "add" {
            // Add `titleName` to `managed_uninstalls`.
            managedUninstallsArray.append(titleName)
            // Set `modificationMessage`.
            modificationMessage = "Added \(titleName) to uninstalls, uninstalls now contains:"
        }
        // If we're to remove...
        if actionType == "remove" {
            // Remove any occurrences of `titleName` within `managed_uninstalls`...
            managedUninstallsArray.removeAll { $0 == titleName }
            // Set `modificationMessage`
            modificationMessage = "Removed \(titleName) from uninstalls, uninstalls now contains:"
        }
    }
    // Update the manifest.
    (managedInstallsArray, managedUninstallsArray) = updateManifest(managedInstallsArray: managedInstallsArray,
                                                                    managedUninstallsArray: managedUninstallsArray)
    // If we've modified `managed_installs`...
    if sectionName == "managed_installs" {
        // Info logging.
        log.info("\(modificationMessage) \(managedInstallsArray)")
        // Check for pending installs and notifying as applicable, noting details to clear as needed.
        processPending(itemType: "install", managedItemsArray: managedInstallsArray, postNotifications: false)
    }
    // If we've modified `managed_uninstalls`...
    if sectionName == "managed_uninstalls" {
        // Info logging.
        log.info("\(modificationMessage) \(managedUninstallsArray)")
        // Check for pending uninstalls and notifying as applicable, noting details to clear as needed.
        processPending(itemType: "uninstall", managedItemsArray: managedUninstallsArray, postNotifications: false)
    }
    // If we have anything within `managed_installs` or `managed_uninstalls`...
    if managedInstallsArray != [] || managedUninstallsArray != [] {
        // Run munki.
        runMunki()
    // If nothing pending...
    } else {
        // Log final status message for the Extension Attribute.
        log.info("0 installed, 0 uninstalled, 0 installs pending, 0 uninstalls pending")
    }
    // Exit.
    exit(0)
}

/// Reads the jamJAR manifest and returns the current installs and uninstalls arrays.
///
/// If the manifest plist does not exist, empty arrays are returned for both lists.
///
/// - Parameters:
///   - asUser: Pass `true` when called in a user-facing context to suppress verbose logging.
///
/// - Returns:
///   A tuple containing:
///     - `managedInstallsArray`: Titles currently in the `"managed_installs"` key.
///     - `managedUninstallsArray`: Titles currently in the `"managed_uninstalls"` key.
///
func processManifest(asUser: Bool) -> (managedInstallsArray: [String], managedUninstallsArray: [String]) {
    // If we're not running as a user...
    if !asUser {
        // Verbose logging.
        log.verbose("\(#function.components(separatedBy: "(")[0])")
    }
    // If the file exists...
    if FileManager.default.fileExists(atPath: MunkiVariables.manifestPath) {
        // Read in `managed_installs`.
        let managedInstallsArray = CFPreferencesCopyAppValue("managed_installs" as CFString,
                                                             MunkiVariables.manifestPath as CFString)
                                   as? [String] ?? []
        // Read in `managed_uninstalls`.
        let managedUninstallsArray = CFPreferencesCopyAppValue("managed_uninstalls" as CFString,
                                                                MunkiVariables.manifestPath as CFString)
                                     as? [String] ?? []
        // If we're not running as a user...
        if !asUser {
            // Verbose logging.
            log.verbose("""
                        \(#function.components(separatedBy: "(")[0]) - \
                        managedInstallsArray: \(managedInstallsArray), \
                        managedUninstallsArray: \(managedUninstallsArray)
                        """)
        }
        // Return.
        return (managedInstallsArray, managedUninstallsArray)
    // If the file is missing...
    } else {
        // If we're not running as a user...
        if !asUser {
            // Verbose logging.
            log.verbose("\(#function.components(separatedBy: "(")[0]) - manifest missing, returning empty arrays")
        }
        // Return.
        return ([], [])
    }
}

/// Writes deduplicated installs and uninstalls arrays to the jamJAR manifest plist.
///
/// Converts each input array to a `Set` to remove duplicates before writing. If an array is
/// empty, the corresponding key (`managed_installs` or `managed_uninstalls`) is removed from
/// the manifest. Sets the manifest file permissions to `755` after writing.
///
/// - Parameters:
///   - managedInstallsArray: Titles to write to the `managed_installs` key.
///   - managedUninstallsArray: Titles to write to the `managed_uninstalls` key.
///
/// - Returns:
///   A tuple of the deduplicated `(installsArray, uninstallsArray) as written.
///
func updateManifest(managedInstallsArray: [String], managedUninstallsArray: [String]) -> ([String], [String]) {
    // Verbose logging.
    log.verbose("""
                \(#function.components(separatedBy: "(")[0]) - managedInstallsArray: \(managedInstallsArray), \
                managedUninstallsArray: \(managedUninstallsArray)
                """)
    // Convert managedInstallsArray to a set, removing duplicates... then an ordered array.
    let installsArray = Array(Set(managedInstallsArray)).sorted()
    // Verbose logging.
    log.verbose("\(#function.components(separatedBy: "(")[0]) - installsArray: \(installsArray)")
    // If we have items in the installsArray
    if !installsArray.isEmpty {
        // Set managed_installs
        CFPreferencesSetAppValue("managed_installs" as CFString,
                                 installsArray as CFPropertyList,
                                 MunkiVariables.manifestPath as CFString)
    // If we have no items in the installsArray
    } else {
        // Remove managed_installs
        CFPreferencesSetAppValue("managed_installs" as CFString, nil, MunkiVariables.manifestPath as CFString)
    }
    // Convert managedInstallsArray to a set, removing duplicates... then an ordered array.
    let uninstallsArray = Array(Set(managedUninstallsArray)).sorted()
    // Verbose logging.
    log.verbose("\(#function.components(separatedBy: "(")[0]) - uninstallsArray: \(uninstallsArray)")
    // If we have items in the uninstallsArray
    if !uninstallsArray.isEmpty {
        // Set managed_uninstalls
        CFPreferencesSetAppValue("managed_uninstalls" as CFString,
                                 uninstallsArray as CFPropertyList,
                                 MunkiVariables.manifestPath as CFString)
    // If we have no items in the uninstallsArray
    } else {
        // Remove managed_uninstalls
        CFPreferencesSetAppValue("managed_uninstalls" as CFString, nil,
                                 MunkiVariables.manifestPath as CFString)
    }
    // Write the preferences to disk
    CFPreferencesAppSynchronize(MunkiVariables.manifestPath as CFString)
    // Set file to 755 perms
    try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                           ofItemAtPath: MunkiVariables.manifestPath)
    // Verbose logging.
    log.verbose("""
                \(#function.components(separatedBy: "(")[0]) - installsArray: \(installsArray), uninstallsArray: \
                \(uninstallsArray)
                """)
    // Return.
    return (installsArray, uninstallsArray)
}
