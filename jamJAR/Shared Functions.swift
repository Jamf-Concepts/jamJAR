//
//  Shared Functions.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation

/// Deletes the item at the given path. Silently does nothing if the item does not exist.
///
/// - Parameters:
///     - itemPath: The path to the item to delete.
///
func deleteItem(itemPath: String) {
    // If the item exists...
    if FileManager.default.fileExists(atPath: itemPath) {
        // Try to delete the item.
        try? FileManager.default.removeItem(atPath: itemPath)
    }
}

/// Finds items at the supplied directory whose filenames begin with one of the given prefixes.
///
/// - Parameters:
///     - itemDir: The directory to search.
///     - itemPrefixes: The filename prefixes to match against.
///
/// - Returns:
///     An array of full paths for every item in `itemDir` whose name starts with a prefix
///     found in `itemPrefixes`. Returns an empty array if the directory is unreadable or
///     no matches are found.
///
func findItems(itemDir: String, itemPrefixes: [String]) -> [String] {
    // Convert to a var as function variables are constants.
    var tempItemArray = [String]()
    // Get the contents of the supplied directory.
    let dirContents: [String]? = try? FileManager.default.contentsOfDirectory(atPath: itemDir)
    // If we found any items...
    if dirContents != nil {
        // For each found item...
        for foundItem in dirContents! {
            // For each prefix...
            for itemPrefix in itemPrefixes where foundItem.hasPrefix(itemPrefix) {
               // Add to `itemArray`.
                tempItemArray.append(itemDir + foundItem)
            }
        }
    }
    // Return.
    return tempItemArray
}

/// Returns the `managed_installs` and `managed_uninstalls` arrays from the jamJAR manifest.
///
/// Reads the arrays from the manifest via ``processManifest(asUser:)``.
///
/// - Parameters:
///   - asUser: Pass `true` when running as the logged-in user to suppress verbose logging.
///
/// - Returns:
///   A tuple containing `managedInstallsArray` and `managedUninstallsArray`, each being an
///   array of Munki title name strings.
///
func getInstallsArrays(asUser: Bool) -> (managedInstallsArray: [String], managedUninstallsArray: [String]) {
    // If we're not running as a user...
    if !asUser {
        // Verbose logging.
        log.verbose("\(#function.components(separatedBy: "(")[0])")
    }
    // Get the manifest `managed_install` and `managed_uninstall` arrays...
    let (managedInstallsArray, managedUninstallsArray) = processManifest(asUser: false)
    // If we're not running as a user...
    if !asUser {
        // Verbose logging.
        log.verbose("""
                    \(#function.components(separatedBy: "(")[0]) - managedInstallsArray: \(managedInstallsArray), \
                    managedUninstallsArray: \(managedUninstallsArray)
                    """)
    }
    // Return
    return (managedInstallsArray, managedUninstallsArray)
}

/// Resets the passed preference domain, and deletes the plist if found.
///
/// - Parameters:
///   - prefDomain: The `prefDomain` to clear and delete.
///
func resetPreferenceDomain(prefDomain: String) {
    // Var declaration(s).
    let plistPath = "/Library/Preferences/" + prefDomain + ".plist"
    // Verbose logging.
    toggleLogging(callMethod: "", logLevel: "VERBOSE", logMessage:
                    "\(#function.components(separatedBy: "(")[0]) - plistPath: \(plistPath)")
    // Reset file
    (_, _) = runTask(callMethod: "", logActions: true, taskPath: "/usr/bin/defaults",
                     taskArguments: ["delete", plistPath], waitUntilExit: true)
    // Write the preferences to disk, using defaults more consistent than CFPreferences for timing
    (_, _) = runTask(callMethod: "", logActions: true, taskPath: "/usr/bin/defaults",
                     taskArguments: ["read", plistPath], waitUntilExit: true)
    // Delete the file
    deleteItem(itemPath: "/Library/Preferences/" + prefDomain + ".plist")
    // Info logging.
    toggleLogging(callMethod: "arg", logLevel: "INFO",
                  logMessage: "Deleted: /Library/Preferences/" + prefDomain + ".plist")
}

/// Triggers a Munki run via `managedsoftwareupdate`.
///
/// When `PreferenceVariables.forceProcess` is `true`, runs `--checkonly` first to populate the
/// install list, then immediately fires `--installonly` without waiting. Otherwise, runs with
/// the standard `--auto --munkistatusoutput` flags without waiting.
///
func runMunki() {
    // If we're forcing...
    if PreferenceVariables.forceProcess {
        // Cache value for `verboseMode`.. to set as needed for second run
        let verboseMode = PreferenceVariables.verboseMode
        // Run checkonly.
        (_, _) = runTask(callMethod: "", logActions: false, taskPath: "/usr/local/munki/managedsoftwareupdate",
                         taskArguments: ["--checkonly"], waitUntilExit: true)
        // Toggles verbose mode
        toggleOption(enableOption: verboseMode, optionName: "verbose_mode")
        // Install all items, including pending.. ignoring if running etc
        (_, _) = runTask(callMethod: "", logActions: false, taskPath: "/usr/local/munki/managedsoftwareupdate",
                         taskArguments: ["--installonly"], waitUntilExit: false)
    // If we're not forcing...
    } else {
        // Run Munki.
        (_, _) = runTask(callMethod: "", logActions: false, taskPath: "/usr/local/munki/managedsoftwareupdate",
                         taskArguments: ["--auto", "--munkistatusoutput"], waitUntilExit: false)
    }
}

/// Runs a shell task and optionally waits for it to complete.
///
/// - Parameters:
///   - callMethod: How the binary was invoked — `"arg"`, `"user"`, or `""`.
///   - logActions: Whether to emit verbose log entries for the task lifecycle.
///   - taskPath: The path to the binary to execute.
///   - taskArguments: The arguments to pass to the binary.
///   - waitUntilExit: Whether to block until the task finishes before returning.
///
/// - Returns:
///   A tuple containing:
///   - The combined stdout/stderr output of the command, or `""` if not waiting.
///   - `true` if the task exited with status `0`; always `false` when not waiting.
///
func runTask(callMethod: String, logActions: Bool, taskPath: String, taskArguments: [String], waitUntilExit: Bool) ->
                 (String, Bool) {
    // If we're to log...
    if logActions == true {
        // Verbose logging.
        toggleLogging(callMethod: callMethod, logLevel: "VERBOSE", logMessage: """
                      \(#function.components(separatedBy: "(")[0]) - taskPath: \(taskPath), taskArguments: \
                      \(taskArguments), waitUntilExit: \(waitUntilExit)
                      """)
    }
    // Create a Task object.
    let task = Process()
    // Set the Task object's `executableURL` to binary we want to call,
    task.executableURL = URL(fileURLWithPath: taskPath)
    // Set the Task object's arguments.
    task.arguments = taskArguments
    // Create a pipe.
    let outPipe = Pipe()
    // Set the pipe to be used for stdout.
    task.standardOutput = outPipe
    // Set the pipe to be used for stderr.
    task.standardError = outPipe
    // Run the task.
    try? task.run()
    // If we're to wait until the task exits...
    if waitUntilExit {
        // Var declaration(s).
        var successfulExit = false
        // If we're to log...
        if logActions == true {
            // Verbose logging.
            toggleLogging(callMethod: callMethod, logLevel: "VERBOSE", logMessage: """
                          \(#function.components(separatedBy: "(")[0]) - waiting for task
                          """)
        }
        // Wait until task exits...
        task.waitUntilExit()
        // Get output.
        let outdata = outPipe.fileHandleForReading.readDataToEndOfFile()
        // Convert to string.
        let cmdOut = String(decoding: outdata, as: UTF8.self)
        // If we're to log...
        if logActions == true {
            // Verbose logging.
            toggleLogging(callMethod: callMethod, logLevel: "VERBOSE", logMessage: """
                          \(#function.components(separatedBy: "(")[0]) - cmdOut: \
                          \(cmdOut.replacingOccurrences(of: "\n", with: "")), taskPath: \(taskPath), \
                          taskArguments: \(taskArguments)
                          """)
        }
        // If the exit code from the task is: 0...
        if task.terminationStatus == 0 {
            // Set `successfulExit` to: true.
            successfulExit = true
        }
        // If we're to log...
        if logActions == true {
            // Verbose logging.
            toggleLogging(callMethod: callMethod, logLevel: "VERBOSE", logMessage: """
                          \(#function.components(separatedBy: "(")[0]) - successfulExit: \(successfulExit)
                          """)
        }
        // Return.
        return (cmdOut, successfulExit)
    }
    // If we're to log...
    if logActions == true {
        // Verbose logging.
        toggleLogging(callMethod: callMethod, logLevel: "VERBOSE", logMessage: """
                      \(#function.components(separatedBy: "(")[0]) - not waiting for task
                      """)
    }
    // Get output
    let outdata = outPipe.fileHandleForReading.readDataToEndOfFile()
    // Convert to string.
    let cmdOut = String(decoding: outdata, as: UTF8.self)
    // Return.
    return (cmdOut, false)
}

/// Sets or removes a boolean key in the `com.jamf.jamJAR` preference domain.
///
/// - Parameters:
///   - enableOption: Pass `true` to set the key to `true`, or `false` to delete the key entirely.
///   - optionName: The preference key name to toggle (e.g. `verbose_mode`).
///
func toggleOption(enableOption: Bool, optionName: String) {
    // Var declaration(s).
    var optionValue: Bool = false
    // Verbose logging.
    log.verbose("""
                \(#function.components(separatedBy: "(")[0]) - enableOption: \(enableOption), \
                optionName: \(optionName)
                """)
    // If we're toggling: `force_process`...
    if optionName == "force_process" {
        // Get the value of `force_process`.
        optionValue = PreferenceVariables.forceProcess
    // Otherwise toggle `verbose_mode`...
    } else {
        // Get the value of `force_process`.
        optionValue = PreferenceVariables.verboseMode
    }
    // If we're to enable a disabled option, and vice versa...
    if enableOption != optionValue {
        // If we're to enable the option...
        if enableOption {
            // Set the`optionName` key in the preference domain.
            CFPreferencesSetValue(optionName as CFString, true as CFBoolean,
                                  GlobalVariables.jamJARBundleId as CFString, kCFPreferencesAnyUser,
                                  kCFPreferencesAnyHost)
            // Verbose logging.
            toggleLogging(callMethod: "", logLevel: "VERBOSE", logMessage:
                            "\(#function.components(separatedBy: "(")[0]) - \(optionName) has been enabled...")
        // If we're to disable the option...
        } else {
            // Delete the `optionName` key.
            CFPreferencesSetValue(optionName as CFString, nil, GlobalVariables.jamJARBundleId as CFString,
                                  kCFPreferencesAnyUser, kCFPreferencesAnyHost)
            // Verbose logging.
            toggleLogging(callMethod: "", logLevel: "VERBOSE", logMessage:
                            "\(#function.components(separatedBy: "(")[0]) - \(optionName) has been disabled...")
        }
        // Write the preferences to disk.
        CFPreferencesSynchronize(GlobalVariables.jamJARBundleId as CFString, kCFPreferencesAnyUser,
                                 kCFPreferencesAnyHost)
    // If we already have the option set as required...
    } else {
        // Verbose logging.
        toggleLogging(callMethod: "", logLevel: "VERBOSE", logMessage: """
                      \(#function.components(separatedBy: "(")[0]) - No change needed for: \(optionName), it is \
                      already set to: \(enableOption)...
                      """)
    }
}
