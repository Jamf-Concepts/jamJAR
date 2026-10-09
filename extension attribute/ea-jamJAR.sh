#!/bin/bash
#
##########################################################################################
#
# In accessing and using this Product, you confirm that you accept the terms of our
# Product Licence in full and agree to comply with the terms of such Licence.
#
# https://resources.jamf.com/documents/products/documentation/software-license-and-services-agreement.pdf
#
##########################################################################################
#
# DESCRIPTION
# Returns the last line of the jamJAR log file
#
##########################################################################################
#
# CHANGE LOG
# 2.2 - Corrected "/Library/Preferences/com.jamf.jamJAR.plist", checks. 
# 2.1 - Double quoted "${logFilePath}", to allow for spaces
# 2.0 - Rewritten in bash, to stop python prompts on macOS 12+
#
##########################################################################################

# Read log path from local user preferences (lower precedence than managed prefs)
if [ -f "/Library/Preferences/com.jamf.jamJAR.plist" ]
then
    # Read the log directory path from the local plist; suppress stderr if the key is absent
    logDir=$(/usr/bin/defaults read "/Library/Preferences/com.jamf.jamJAR.plist" log_file_dir 2> /dev/null)
    # Read the log file name from the local plist; suppress stderr if the key is absent
    logFileName=$(/usr/bin/defaults read "/Library/Preferences/com.jamf.jamJAR.plist" log_file_name 2> /dev/null)
fi

# Managed preferences override local preferences when both exist
if [ -f "/Library/Managed Preferences/com.jamf.jamJAR.plist" ]
then
    # Read the log directory path from the managed plist; suppress stderr if the key is absent
    logDir=$(/usr/bin/defaults read "/Library/Managed Preferences/com.jamf.jamJAR.plist" log_file_dir 2> /dev/null)
    # Read the log file name from the managed plist; suppress stderr if the key is absent
    logFileName=$(/usr/bin/defaults read "/Library/Managed Preferences/com.jamf.jamJAR.plist" log_file_name 2> /dev/null)
fi

# Fall back to default log directory if not set by either plist
if [ -z "${logDir-unset}" ]
then
    # Default log directory
    logDir="/var/log/"
fi

# Fall back to default log file name if not set by either plist
if [ -z "${logFileName-unset}" ]
then
    # Default log file name
    logFileName="jamJAR"
fi

# Build the full log file path, ensuring a single slash between dir and filename
if [[ "${logDir}" == */ ]]
then
    # logDir already has a trailing slash
    logFilePath="${logDir}""${logFileName}"".log"
else
    # logDir lacks a trailing slash, so insert one
    logFilePath="${logDir}""/""${logFileName}"".log"
fi

# Return the last log entry as a Jamf EA result, or empty result if log is missing
if [ -f "${logFilePath}" ]
then
    # Output the last line of the log wrapped in Jamf EA result tags
    /bin/echo "<result>$(/usr/bin/tail -n -1 "${logFilePath}")</result>"
else
    # Log file not found; return an empty result
    /bin/echo "<result></result>"
fi