//
//  ArgParser.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import ArgumentParser
import Foundation

/// The root `ParsableCommand` for jamJAR.
///
/// Defines the top-level flags (`--collect-logs`, `--reset`, `--version`, `--uninstall`) and
/// groups user-facing commands and global flags into `Commands` and `GlobalFlags` respectively.
///
struct JamJAR: ParsableCommand {
    /// Create the command configuration.
    static let configuration = CommandConfiguration(
        /// Overview text.
        abstract: "jamJAR - \(GlobalVariables.jamJARVersion)", usage: "", helpNames: [.long]
    )
    @OptionGroup(title: "Commands")
    var commands: Commands
    @OptionGroup(title: "Global Flags")
    var globalFlags: GlobalFlags
    /// Collects logs.
    @Flag(help: """
                Creates: /Users/Shared/jamJAR Logs/, and copies log files to that directory. Useful for \
                troubleshooting.

                """)
    var collectLogs: Bool = false
    /// Resets jamJAR.
    @Flag(help: """
                Resets any locally created jamJAR and Munki items, such as plists and cached items. These will be \
                regenerated (as applicable), with the next jamJAR run. Useful for troubleshooting.

                """)
    var reset: Bool = false
    /// Prints version information.
    @Flag(help: """
                Displays jamJAR's version only.

                """)
    var version: Bool = false
}

/// User-facing commands for jamJAR.
///
/// Groups the options that interact with the Munki manifest (`--add-to-installs`,
/// `--remove-from-installs`, `--add-to-uninstalls`, `--remove-from-uninstalls`) and
/// the hidden flags used internally by the postflight script (`--postflight`, `--process-pending`).
///
struct Commands: ParsableArguments {
    /// Adds the passed title to the `managed_installs` array of the jamJAR manifest.
    @Option(help: """
                  Adds the supplied title to jamJAR's installs list.

                  """)
    var addToInstalls: String = ""
    /// Removes the passed title to the `managed_installs` array of the jamJAR manifest.
    @Option(help: """
                  Removes the supplied title from jamJAR's installs list.

                  """)
    var removeFromInstalls: String = ""
    /// Adds the passed title to the `managed_uninstalls` array of the jamJAR manifest.
    @Option(help: """
                  Adds the supplied title to jamJAR's uninstalls list.

                  """)
    var addToUninstalls: String = ""
    /// Removes the passed title to the `managed_uninstalls` array of the jamJAR manifest
    @Option(help: """
                  Removes the supplied title from jamJAR's uninstalls list.

                  """)
    var removeFromUninstalls: String = ""
    /// Triggers the `postflight` function.
    @Flag(help: .hidden)
    var postflight: Bool = false
    /// Triggers the `processPending` function.
    @Flag(help: .hidden)
    var processPending: Bool = false
}

/// Global modifier flags that can be combined with any `Commands` option.
///
/// These flags alter the behaviour of the selected command: `--force` bypasses the usual
/// precondition checks, and `--verbose` enables detailed logging to `/var/log/jamJAR.log`.
///
struct GlobalFlags: ParsableArguments {
    /// Forces the selected option.
    @Flag(help: """
                Forces action to be taken. Such forcing installation or uninstallation of all pending items without \
                waiting for them to be terminated prior.

                """)
    var force: Bool = false
    /// Enables verbose logging.
    @Flag(help: """
                Enables verbose logging of actions to /var/log/jamJAR.log.

                """)
    var verbose: Bool = false
}
