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
# 3.0 - Hardcoded log path to match the jamJAR binary.
# 2.2 - Corrected "/Library/Preferences/com.jamf.jamJAR.plist", checks.
# 2.1 - Double quoted "${logFilePath}", to allow for spaces
# 2.0 - Rewritten in bash, to stop python prompts on macOS 12+
#
##########################################################################################

# Path to the jamJAR log file
logFilePath="/var/log/jamJAR.log"

# Return the last log entry as a Jamf EA result, or empty result if log is missing
if [ -f "${logFilePath}" ]
then
    # Output the last line of the log wrapped in Jamf EA result tags
    /bin/echo "<result>$(/usr/bin/tail -n -1 "${logFilePath}")</result>"
else
    # Log file not found; return an empty result
    /bin/echo "<result></result>"
fi
