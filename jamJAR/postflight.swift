//
//  postflight.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation

/// Runs all postflight processing after a Munki run completes.
///
/// Reads the manifest and `ManagedInstallReport.plist`, processes install and removal results,
/// sends user notifications, updates the manifest, manages the logout-trigger file, clears
/// preference keys, logs a final status line for the Jamf Extension Attribute, and optionally
/// runs `jamf recon` if anything was installed or uninstalled. Exits with status `0`.
///
/// - Parameters:
///   - parsedResult: The parsed `jamJAR` command arguments.
///
func postflight(parsedResult: JamJAR) {
    // Print to stdout.
    print("For jamJAR logs, please see: \(GlobalVariables.logPath).")
    // Info logging.
    log.info("jamJAR - \(GlobalVariables.jamJARVersion) - Running postflight...")
    // Var declaration(s).
    var itemsDict = ["installedItems": 0, "removedItems": 0]
    var runRecon = false
    // Look for items within the manifest.
    var (managedInstallsArray, managedUninstallsArray) = processManifest(asUser: false)
    // Process ManagedInstallReport.
    let managedInstallReportContent = processManagedInstallReport()
    // Info logging.
    log.info("Processing run data...")
    // Process the content, notifying if items have been installed or pending etc.
    processManagedInstallReportContent(itemsDict: &itemsDict,
                                       managedInstallsArray: &managedInstallsArray,
                                       managedInstallReportContent: managedInstallReportContent,
                                       managedUninstallsArray: &managedUninstallsArray)
    // Info logging.
    log.info("Processing warnings...")
    // If there are any warnings items...
    if managedInstallReportContent.warnings != nil {
        // Process the items that generated warnings...
        processWarnings(managedInstallReportContent: managedInstallReportContent,
                        managedInstallsArray: &managedInstallsArray,
                        managedUninstallsArray: &managedUninstallsArray)
    }
    // Update the manifest.
    (_, _) = updateManifest(managedInstallsArray: managedInstallsArray, managedUninstallsArray: managedUninstallsArray)
    // Info logging.
    log.info("Processing pending...")
    // Process `InstallInfo`.
    let (pendingInstalls, pendingUninstalls) = processInstallInfo()
    // Check for pending installs and notifying as applicable and noting details to clear as needed.
    processPending(itemType: "install", managedItemsArray: pendingInstalls, postNotifications: true)
    // Check for pending uninstalls and notifying as applicable and noting details to clear as needed.
    processPending(itemType: "uninstall", managedItemsArray: pendingUninstalls, postNotifications: true)
    // Create or delete the pending file as needed.
    createOrDeleteTriggerFile(managedInstallsArray: managedInstallsArray,
                              managedUninstallsArray: managedUninstallsArray)
    // If anything has been installed or uninstalled...
    if itemsDict["installedItems"] != 0 || itemsDict["removedItems"] != 0 {
        // Info logging.
        log.info("Will run a recon as items have been installed/uninstalled...")
        // Set `runRecon` to true.
        runRecon = true
    }
    // Delete `verbose_mode` key
    toggleOption(enableOption: false, optionName: "verbose_mode")
    // Delete the `force_process` key
    toggleOption(enableOption: false, optionName: "force_process")
    // Info logging.
    log.info("jamJAR - \(GlobalVariables.jamJARVersion) - Completed running postflight.")
    // Log final status message for the Extension Attribute.
    log.info("""
             \(itemsDict["installedItems"] ?? 0) installed, \(itemsDict["removedItems"] ?? 0) uninstalled, \
             \(managedInstallsArray.count) installs pending, \(managedUninstallsArray.count) uninstalls pending
             """)
    // If anything has been installed or uninstalled...
    if runRecon {
        // Run a recon, discarding output.
        (_, _) = runTask(callMethod: "", logActions: false, taskPath: GlobalVariables.jamfBinaryPath,
                         taskArguments: ["recon"], waitUntilExit: true)
    }
    // Exit.
    exit(0)
}

/// Creates or deletes the Munki install-at-logout trigger file based on whether any items
/// remain pending.
///
/// If both arrays are empty the trigger file is deleted (if it exists). If either array is
/// non-empty the trigger file is created (if it does not already exist). Warnings are logged
/// if either operation fails.
///
/// - Parameters:
///   - managedInstallsArray: Titles currently pending installation.
///   - managedUninstallsArray: Titles currently pending uninstallation.
///
func createOrDeleteTriggerFile(managedInstallsArray: [String], managedUninstallsArray: [String]) {
    // If we have nothing pending...
    if managedInstallsArray.isEmpty && managedUninstallsArray.isEmpty {
        // If the trigger file exists...
        if FileManager.default.fileExists(atPath: GlobalVariables.installAtLogoutFile) {
            do {
                // Try to delete the trigger file...
                try FileManager.default.removeItem(atPath: GlobalVariables.installAtLogoutFile)
                // Info logging.
                log.info("Deleted logout install trigger file as nothing pending")
            // If removing the file fails...
            } catch {
                // Log warning.
                log.warning("Failed to delete: \(GlobalVariables.installAtLogoutFile)")
            }
        }
    // If we have something pending...
    } else {
        // If the trigger file does not exist...
        if !FileManager.default.fileExists(atPath: GlobalVariables.installAtLogoutFile) {
            // Try to create the trigger file...
            if FileManager.default.createFile(atPath: GlobalVariables.installAtLogoutFile,
                                              contents: nil, attributes: nil) {
                // Info logging.
                log.info("Created logout install trigger file")
            // If creating the file fails...
            } else {
                // Log warning.
                log.warning("Failed to create: \(GlobalVariables.installAtLogoutFile)")
            }
        }
    }
}

/// Parses `InstallInfo.plist` and returns the lists of titles pending installation and removal.
///
/// Logs a warning and returns empty arrays if the file is missing or cannot be decoded.
///
/// - Returns:
///   A tuple of `(pendingInstalls, pendingUninstalls)` — arrays of Munki title name strings.
///
func processInstallInfo() -> ([String], [String]) {
    // Verbose logging.
    log.verbose("\(#function.components(separatedBy: "(")[0])")
    // Var declaration(s).
    var pendingInstalls = [String]()
    var pendingUninstalls = [String]()
    // If we can find `InstallInfo` and the expected location.
    if FileManager.default.fileExists(atPath: MunkiVariables.installInfo) {
        // Read in the file
        do {
            // Try to parse the file...
            let installInfoData = try? Data(contentsOf:
                                                     URL(fileURLWithPath: MunkiVariables.installInfo))
            // Try to decode using the `installInfoDetails` struct.
            let installInfoContent = try PropertyListDecoder().decode(InstallInfoContent.self,
                                                                               from: installInfoData!)
            // For each title we have in `managed_installs`.
            for someTitle in installInfoContent.managedInstalls {
                // Append to the `pendingInstalls` array.
                pendingInstalls.append(someTitle.name)
            }
            // For each title we have in removals.
            for someTitle in installInfoContent.removals {
                // Append the name to the `pendingUninstalls` array.
                pendingUninstalls.append(someTitle.name)
            }
            // Return the contents of the `installInfo`, as per the `installInfoDetails` struct.
            return (pendingInstalls, pendingUninstalls)
        // Error if an issue...
        } catch {
            // Warning logging.
            log.warning("Parsing \(MunkiVariables.installInfo) failed with error: \(error).")
        }
    // If` installInfo` missing....
    } else {
        // Warning logging.
        log.warning("Cannot locate: \(MunkiVariables.installInfo).")
    }
    // Verbose logging.
    log.verbose("""
                \(#function.components(separatedBy: "(")[0]) - pendingInstalls: \(pendingInstalls), pendingUninstalls: \
                \(pendingUninstalls)
                """)
    // Return.
    return (pendingInstalls, pendingUninstalls)
}

/// Parses `ManagedInstallReport.plist` and returns its decoded contents.
///
/// Logs a warning and returns an empty `ManagedInstallReportContent` if the file is missing
/// or cannot be decoded.
///
/// - Returns:
///   A `ManagedInstallReportContent` value populated from the plist, or an empty instance
///   if the file cannot be read.
///
func processManagedInstallReport() -> ManagedInstallReportContent {
    // Verbose logging.
    log.verbose("\(#function.components(separatedBy: "(")[0])")
    // If we can find ManagedInstallReport and the expected location
    if FileManager.default.fileExists(atPath: MunkiVariables.managedInstallReport) {
        // Read in the file
        do {
            // Try to parse the file
            let managedInstallReportData = try? Data(contentsOf:
                                                     URL(fileURLWithPath: MunkiVariables.managedInstallReport))
            // Try to decode using the ManagedInstallReportDetails struct
            let managedInstallReportContent = try PropertyListDecoder().decode(ManagedInstallReportContent.self,
                                                                               from: managedInstallReportData!)
            // Verbose logging.
            log.verbose("""
                        \(#function.components(separatedBy: "(")[0]) - managedInstallReportContent: \
                        \(managedInstallReportContent)
                        """)
            // Return the contents of the ManagedInstallReport, as per the ManagedInstallReportDetails struct
            return managedInstallReportContent
        // Error if an issue
        } catch {
            // Log a warning, if we cannot process the ManagedInstallReport
            log.warning("Parsing \(MunkiVariables.managedInstallReport) failed with error: \(error).")
        }
    // If the ManagedInstallReport missing
    } else {
        log.warning("Cannot locate: \(MunkiVariables.managedInstallReport).")
    }
    // Set managedInstallReportContent to an empty version
    let managedInstallReportContent = ManagedInstallReportContent(installedItems: [], installResults: [],
                                                                  managedInstalls: [], removedItems: [],
                                                                  removalResults: [], warnings: [])
    // Verbose logging.
    log.verbose("""
                \(#function.components(separatedBy: "(")[0]) - managedInstallReportContent: \
                \(managedInstallReportContent)
                """)
    // Return an empty version of managedInstallReportContent
    return managedInstallReportContent
}

/// Processes the decoded `ManagedInstallReport` content, updating the manifest arrays and
/// sending install/uninstall/up-to-date notifications as appropriate.
///
/// Iterates over `InstalledItems`, `RemovedItems`, `InstallResults`, and `RemovalResults`,
/// removing completed titles from the pending arrays and incrementing the install/removal
/// counters in `itemsDict`.
///
/// - Parameters:
///     - itemsDict: Running counts of installed and removed items; incremented in place.
///     - managedInstallsArray: Titles pending installation; completed titles are removed in place.
///     - managedInstallReportContent: The decoded report from `ManagedInstallReport.plist`.
///     - managedUninstallsArray: Titles pending uninstallation; completed titles are removed in place.
///
func processManagedInstallReportContent(itemsDict: inout [String: Int],
                                        managedInstallsArray: inout [String],
                                        managedInstallReportContent: ManagedInstallReportContent,
                                        managedUninstallsArray: inout [String]) {
    // If we have any items within `InstalledItems`.
    if managedInstallReportContent.installedItems != nil {
        // For each title within `InstalledItems`.
        for titleName in managedInstallReportContent.installedItems! {
            // Remove title from `managed_installs` (if exists).
            managedInstallsArray.removeAll { $0 == titleName }
            // Info logging.
            log.info("Latest version of: \(titleName) installed. Removing from installs.")
            // Get the the USER key from the env, if not nil nor root then we should be running via Self Service.
            if ProcessInfo().environment["USER"] != nil && ProcessInfo().environment["USER"] != "root" {
                // If we match `titleName`, get additional details for `titleName` from the `ManagedInstalls` array.
                for someTitle in managedInstallReportContent.managedInstalls!.enumerated()
                where someTitle.element.name == titleName {
                        // Notify we're up to date.
                        notifyUpToDate(varDict: ["displayName": someTitle.element.displayName ?? "",
                                                 "displayVersion": someTitle.element.versionToInstall ?? "",
                                                 "itemName": someTitle.element.name!])
                }
            }
        }
    }
    // If we have any items within `RemovedItems`.
    if managedInstallReportContent.removedItems != nil {
        // For each title within `RemovedItems`.
        for titleName in managedInstallReportContent.removedItems! {
            // Remove title from `managed_uninstalls` (if exists).
            managedUninstallsArray.removeAll { $0 == titleName }
            // Info logging.
            log.info("Cannot find: \(titleName) installed. Removing from uninstalls.")
        }
    }
    // If we installed any items in this run, they will be in `InstallResults`.
    if managedInstallReportContent.installResults != nil {
        // For each title within `InstallResults`.
        for titleName in managedInstallReportContent.installResults!.enumerated() {
            // Remove title from `managed_installs` (if exists).
            managedInstallsArray.removeAll { $0 == titleName.element.name! }
            // Notify the user that the item has been installed.
            notifyInstalled(varDict: ["displayName": titleName.element.displayName ?? "",
                                      "displayVersion": titleName.element.version ?? "",
                                      "itemName": titleName.element.name!])
            // Up `installedItems` count.
            itemsDict["installedItems"]! += 1
        }
    }
    // If we uninstalled any items in this run, they will be in `RemovalResults`.
    if managedInstallReportContent.removalResults != nil {
        // For each title within `RemovalResults`.
        for titleName in managedInstallReportContent.removalResults!.enumerated() {
            // Remove title from `managed_uninstalls` (if exists).
            managedUninstallsArray.removeAll { $0 == titleName.element.name! }
            // Notify the user that the item has been uninstalled.
            notifyUninstalled(varDict: ["displayName": titleName.element.displayName ?? "",
                                        "displayVersion": titleName.element.version ?? "",
                                        "itemName": titleName.element.name!])
            // Up `removedItems` count.
            itemsDict["removedItems"]! += 1
        }
    }
}

/// Scans `ManagedInstallReport` warnings for known patterns and removes affected titles from
/// the pending install and uninstall arrays.
///
/// Matches each pending title against the `Warnings` array using two regex patterns:
/// architecture rejection and "no pkginfo found". Any matched title is removed from both
/// arrays and its warning is logged.
///
/// - Parameters:
///     - managedInstallReportContent: The decoded report containing the `Warnings` array.
///     - managedInstallsArray: Titles pending installation; warned titles are removed in place.
///     - managedUninstallsArray: Titles pending uninstallation; warned titles are removed in place.
///
func processWarnings(managedInstallReportContent: ManagedInstallReportContent,
                     managedInstallsArray: inout [String],
                     managedUninstallsArray: inout [String]) {
    // Let declarations for regex patterns.
    let architectureWarning = try? NSRegularExpression(pattern: """
                                                                Rejected item .*?, version .*? with supported \
                                                                architectures: .*?
                                                                """)
    let notFoundWarning = try? NSRegularExpression(pattern: """
                                                            Could not process item (.*?) for (.*?). No \
                                                            pkginfo found in catalogs: (.*?)
                                                            """)
    let regexPatterns = [architectureWarning, notFoundWarning]
    // Var declaration(s).
    var warningItems = [String: String]()
    // If `managedInstallsArray` has content...
    if !managedInstallsArray.isEmpty {
        // For each entry in the `managedInstallsArray`...
        for managedInstall in managedInstallsArray {
            // If we have a match, get the 1st matches index...
            if let indexMatch = managedInstallReportContent.warnings?.firstIndex(where: {$0.contains(managedInstall)}) {
                // Set warning message.
                let warningMessage = managedInstallReportContent.warnings?[indexMatch] ?? ""
                // For each regex pattern, if the regex patterns match a warning for a title.
                for regexPattern in regexPatterns where ((regexPattern?.matches(in: warningMessage,
                                                                                range: NSRange(location: 0,
                                                                                length: warningMessage.utf16.count)
                                                                                ).first) != nil) == true {
                    // Add the titles name and it's warning to `warningItems`.
                    warningItems[managedInstall] = warningMessage
                }
            }
        }
    }
    // If `managedUninstallsArray` has content.
    if !managedUninstallsArray.isEmpty {
        // For each entry in the `managedUninstallsArray`.
        for managedUninstall in managedUninstallsArray {
            // If we have a match, get the 1st matches index...
            if let indexMatch = managedInstallReportContent.warnings?.firstIndex(where:
                                                                                {$0.contains(managedUninstall)}) {
                // Set warning message.
                let warningMessage = managedInstallReportContent.warnings?[indexMatch] ?? ""
                // For each regex pattern, if the regex patterns match a warning for a title.
                for regexPattern in regexPatterns where ((regexPattern?.matches(in: warningMessage,
                                                                                    range: NSRange(location: 0,
                                                                                    length: warningMessage.utf16.count)
                                                                                    ).first) != nil) == true {
                    // Add the titles name and it's warning to `warningItems`.
                    warningItems[managedUninstall] = warningMessage
                }
            }
        }
    }
    // For any item in `warningItems`.
    for (warningItem, warningMessage) in warningItems {
        // Remove title from `managed_installs` (if exists).
        managedInstallsArray.removeAll { $0 == warningItem }
        // Remove warningItem from `managed_uninstalls` (if exists).
        managedUninstallsArray.removeAll { $0 == warningItem }
        // Info logging.
        log.info("""
                 Removed \"\(warningItem)\" due to it raising the warning: \
                 \(warningMessage.replacingOccurrences(of: "\n", with: ""))
                 """)
    }
}
