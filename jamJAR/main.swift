//
// main.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation

// Setup logging.
setupLogging()

// Pass the arguments.
// Array of arguments passed to the executable, with the first argument dropped as it is always the executable itself.
let passedArgs = Array(CommandLine.arguments.dropFirst())

// If no args passed...
if passedArgs.isEmpty {
    // Show help.
    print(JamJAR.helpMessage())
    // Exit.
    exit(1)
// If args are passed...
} else {
    // Parse the arguments.
    let parsedResult = JamJAR.parseOrExit(passedArgs)
    // If we're not looking to process pending items or get the version...
    if !parsedResult.version && !parsedResult.commands.processPending {
        // Sets the `force_process` key as needed.
        forceCheck(parsedResult: parsedResult)
        // Sets the `verbose_mode` key as needed.
        verboseCheck(parsedResult: parsedResult)
    }
    // If `--add-to-installs` was passed...
    if !parsedResult.commands.addToInstalls.isEmpty {
        // Exit if not running as root.
        rootCheck(passedArg: "--add-to-installs")
        // Add the title to an installs array...
        modifyManifest(actionType: "add", sectionName: "managed_installs",
                       titleName: parsedResult.commands.addToInstalls)
    // If `--add-to-uninstalls` was passed...
    } else if !parsedResult.commands.addToUninstalls.isEmpty {
        // Exit if not running as root.
        rootCheck(passedArg: "--add-to-uninstalls")
        // Add the title to `managed_uninstalls`.
        modifyManifest(actionType: "add", sectionName: "managed_uninstalls",
                       titleName: parsedResult.commands.addToUninstalls)
    // If `--postflight` was passed...
    } else if parsedResult.commands.postflight {
        // Exit if not running as root.
        rootCheck(passedArg: "--postflight")
        // Run function.
        postflight(parsedResult: parsedResult)
    // If `--process-pending` was passed...
    } else if parsedResult.commands.processPending {
        // Run function.
        processPending(itemType: "", managedItemsArray: [], postNotifications: true)
    // If `--remove-from-installs` was passed...
    } else if !parsedResult.commands.removeFromInstalls.isEmpty {
        // Exit if not running as root.
        rootCheck(passedArg: "--remove-from-installs")
        // Remove the title from `managed_installs`.
        modifyManifest(actionType: "remove", sectionName: "managed_installs",
                       titleName: parsedResult.commands.removeFromInstalls)
    // If `--remove-from-uninstalls` was passed...
    } else if !parsedResult.commands.removeFromUninstalls.isEmpty {
        // Exit if not running as root.
        rootCheck(passedArg: "--remove-from-uninstalls")
        // Remove the title from `managed_uninstalls`.
        modifyManifest(actionType: "remove", sectionName: "managed_uninstalls",
                       titleName: parsedResult.commands.removeFromUninstalls)
    // If `--collect-logs` was passed...
    } else if parsedResult.collectLogs {
        // Exit if not running as root.
        rootCheck(passedArg: "--collect-logs")
        // Run function.
        collectLogs()
    // If `--reset` was passed...
    } else if parsedResult.reset {
        // Exit if not running as root.
        rootCheck(passedArg: "--reset")
        // Run function.
        reset(parsedResult: parsedResult)
    // If `--version` was passed...
    } else if parsedResult.version {
        // Print the jamJAR's version.
        print("\(GlobalVariables.jamJARVersion)")
        // Exit.
        exit(0)
    // If we've not been passed any other options...
    } else {
        // Show help.
        print(JamJAR.helpMessage())
        // Exit.
        exit(1)
    }
}

/// Exits with status `1` if the current process is not running as root.
///
/// - Parameters:
///   - passedArg: The argument name that triggered the check, used in the error message.
///
func rootCheck(passedArg: String) {
    // If we're not root...
    if NSUserName() != "root" {
        // Print error.
        print("The argument: \(passedArg), requires root privileges.")
        // Exit with exitcode 1.
        exit(1)
    }
}

/// Sets or clears the `force_process` preference key based on the `--force` flag and the
/// current `force_process` preference value.
///
/// - Parameters:
///   - parsedResult: The parsed `jamJAR` command arguments, used to read `globalFlags.force`.
///
func forceCheck(parsedResult: JamJAR) {
    // If we're to force the process...
    if parsedResult.globalFlags.force || PreferenceVariables.forceProcess {
        // Set the `force_process` key to `true`.
        toggleOption(enableOption: true, optionName: "force_process")
    // If we're not forcing...
    } else {
        // Delete the `force_process` key.
        toggleOption(enableOption: false, optionName: "force_process")
    }
}

/// Sets the SwiftyBeaver log level and writes the `verbose_mode` preference key based on
/// the `--verbose` flag and the current `verbose_mode` preference value.
///
/// - Parameters:
///   - parsedResult: The parsed `jamJAR` command arguments, used to read `globalFlags.verbose`.
///
func verboseCheck(parsedResult: JamJAR) {
    // If `verbose mode` is to be enabled...
    if parsedResult.globalFlags.verbose || PreferenceVariables.verboseMode {
        // Only log we're enabling verbose mode if running as root, due to rights to the log file...
        if NSUserName() == "root" {
            // Set the logging level to verbose.
            fileLog.minLevel = .verbose
            toggleOption(enableOption: true, optionName: "verbose_mode")
        }
    // If we're not logging verbose...
    } else {
        // Set the logging level to: info.
        fileLog.minLevel = .info
        // Delete `verbose_mode` key.
        toggleOption(enableOption: false, optionName: "verbose_mode")
    }
}

// Starts the main run loop, keeping the process alive for async operations such as network
// requests to complete. Without this, the CLI would exit before async callbacks fire.
// See: https://developer.apple.com/forums/thread/713085
//
dispatchMain()
