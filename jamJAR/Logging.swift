//
//  Logging.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation
import SwiftyBeaver

// Create a SwiftyBeaver logger object.
let log = SwiftyBeaver.self
// Create a file destination object.
let fileLog = FileDestination()

/// Gathers Jamf and Munki log files into a single directory for easy retrieval.
///
/// Deletes any existing copy of `collectedLogsDirectory`, recreates it with group `staff` and
/// permissions `777`, then copies the following logs into it:
/// - `/Library/Managed Installs/Logs/ManagedSoftwareUpdate.log`
/// - `/var/log/install.log`
/// - `/var/log/jamf.log`
/// - `/var/log/jamJAR.log`
///
/// Exits with status `0` on success, or `1` if the directory cannot be created or a file
/// cannot be copied.
///
func collectLogs() {
    // Print to stdout
    print("Collecting logs...")
    // Array of log files to collect
    let logFiles = ["/Library/Managed Installs/Logs/ManagedSoftwareUpdate.log", "/var/log/install.log",
                    "/var/log/jamf.log", "/var/log/jamJAR.log"]
    // Boolean if `GlobalVariables.collectedLogsDirectory`, exists
    if FileManager.default.fileExists(atPath: GlobalVariables.collectedLogsDirectory) {
        // Do..
        do {
            // Delete the directory
            try FileManager.default.removeItem(atPath: GlobalVariables.collectedLogsDirectory)
            // Print to stdout
            print("Successfully deleted: \(GlobalVariables.collectedLogsDirectory).")
        // If we fail to delete the directory
        } catch {
            // Print error
            print("ERROR: Failed to delete: \(GlobalVariables.collectedLogsDirectory).")
            // Exit
            exit(1)
        }
    }
    // Do...
    do {
        // Try to create `GlobalVariables.collectedLogsDirectory`
        try FileManager.default.createDirectory(atPath: GlobalVariables.collectedLogsDirectory,
                                                 withIntermediateDirectories: false,
                                                 attributes: [FileAttributeKey.groupOwnerAccountName: "staff",
                                                              FileAttributeKey.posixPermissions: 0o777])
        // Print to stdout
        print("Successfully created: \(GlobalVariables.collectedLogsDirectory).")
    // If we fail to create the directory
    } catch {
        // Print error
        print("ERROR: Failed to create: \(GlobalVariables.collectedLogsDirectory).")
        // Exit
        exit(1)
    }
    // For each entry in `logFiles`, where the file exists
    for logFile in logFiles where FileManager.default.fileExists(atPath: logFile) {
        // Get the logs name from the path
        let logFileName = logFile.split(separator: "/").last ?? ""
        // If we have a file name
        if logFileName != "" {
            // Path to copy the log to
            let logFilePath = GlobalVariables.collectedLogsDirectory + "/" + logFileName
            // Do..
            do {
                // Try to copy the logfile to `GlobalVariables.collectedLogsDirectory`
                try FileManager.default.copyItem(atPath: logFile,
                                                 toPath: logFilePath)
                // Set the files permissions to 777
                try FileManager.default.setAttributes([FileAttributeKey.posixPermissions: 0o777],
                                                      ofItemAtPath: logFilePath)
                // Print to stdout
                print("Successfully copied: \(logFile), to: \(GlobalVariables.collectedLogsDirectory).")
            // If fail to copy the log file
            } catch {
                // Print error
                print("ERROR: Failed to copy: \(logFile), to: \(GlobalVariables.collectedLogsDirectory).")
                // Exit
                exit(1)
            }
        }
    }
    // Print to stdout.
    print("Logs have been copied to: \(GlobalVariables.collectedLogsDirectory).")
    // Exit
    exit(0)
}

/// Configures the SwiftyBeaver file destination and attaches it to the logger.
///
/// Must be called once at startup, before any logging takes place.
///
func setupLogging() {
    // Set the datetime format.
    fileLog.format = "$Dyyyy-MM-dd HH:mm:ss Z$d ~ $L: $M"
    // Disable asynchronous logging.
    fileLog.asynchronously = false
    // Set log file path.
    fileLog.logFileURL = URL(fileURLWithPath: String(GlobalVariables.logPath))
    // Add the file destination to the logging object.
    log.addDestination(fileLog)
}

/// Routes a log message to stdout or the SwiftyBeaver log file depending on how the tool was invoked.
///
/// When `callMethod` is `"arg"` or `"user"`, messages are printed to stdout with a timestamp.
/// Otherwise they are written to the log file via SwiftyBeaver at the appropriate level.
///
/// - Parameters:
///   - callMethod: How the binary was invoked — `"arg"`, `"user"`, or `""`.
///   - logLevel: The severity level — `"VERBOSE"`, `"INFO"`, `"WARNING"`, or `"ERROR"`.
///   - logMessage: The message to log.
///
func toggleLogging(callMethod: String, logLevel: String, logMessage: String) {
    // Var declaration(s).
    var timeStampNow = String()
    // If we're invoked via arg or by the user...
    if callMethod == "arg" || callMethod == "user" {
        // Create a DateFormatter object.
        let dateFormatter = DateFormatter()
        // Set date format.
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        // Get date and time for now.
        let dateNow = NSDate()
        // Set `timeStampNow` to the current date and time in the wanted format.
        timeStampNow = dateFormatter.string(from: dateNow as Date)
    }
    // If we're invoked via arg and are to log VERBOSE messages...
    if callMethod == "arg" && logLevel == "VERBOSE" && fileLog.minLevel == .verbose {
        // Print verbose messages to stdout.
        print(timeStampNow + " VERBOSE: " + logMessage)
    // If we're invoked via arg and not verbose as well...
    } else if callMethod == "arg" && logLevel != "VERBOSE" {
        // Print info messages to stdout.
        print(timeStampNow + " " + logLevel + ": " + logMessage)
    }
    // If we've been invoked by the user, post to stdout only...
    if callMethod == "user" {
        // Print info messages to stdout.
        print(timeStampNow + " " + logLevel + ": " + logMessage)
    // If we're not invoked via arg, and are to log VERBOSE messages...
    } else if callMethod != "arg" && logLevel == "VERBOSE" && fileLog.minLevel == .verbose {
        // Verbose logging.
        log.verbose(logMessage)
    // If we're not invoked via arg, and not verbose as well...
    } else if callMethod != "arg" && logLevel != "VERBOSE" {
        // If we're to log as an error.
        if logLevel == "ERROR" {
            // Log error
            log.error(logMessage)
        }
        // If we're to log as info.
        if logLevel == "INFO" {
            // Log info
            log.info(logMessage)
        }
        // If we're to log as a warning.
        if logLevel == "WARNING" {
            // Log warning
            log.warning(logMessage)
        }
    }
}
