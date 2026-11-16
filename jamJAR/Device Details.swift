//
//  Device Details.swift
//  jamJAR
//
//  Copyright © 2026 Jamf. All rights reserved.
//

// Imports
import Foundation
import SystemConfiguration

/// Check to see if a user in logged into the Mac we're running on.
///
/// - Returns:
///   Returns username if a user is logged in or "" if at the loginwindow.
///
func loggedInUser() -> String {
    // Verbose logging.
    log.verbose("\(#function.components(separatedBy: "(")[0])")
    // Get the name of the logged in user.
    let loggedInUser = SCDynamicStoreCopyConsoleUser(nil, nil, nil) as? String ?? nil
    // Verbose logging.
    log.verbose("\(#function.components(separatedBy: "(")[0]) - loggedInUser: \(String(describing: loggedInUser))")
    // If no-one or loginwindow is returned...
    if loggedInUser == "loginwindow" || loggedInUser == nil || loggedInUser == "" {
        // Return.
        return ""
    // Else if we have someone logged in...
    } else {
        // Return.
        return loggedInUser!
    }
}
