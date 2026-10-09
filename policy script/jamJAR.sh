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
# jamJAR policy script.
#
##########################################################################################
#
# CHANGE LOG
# 3.0 - Migrated to bash and updated for jamJAR 2.0.
#
##########################################################################################

##########################################################################################
################################### Global Variables #####################################
##########################################################################################

# Path to jamJAR's binary
JAMJAR_BINARY="/usr/local/munki/jamJAR"

# Path to jamJAR's log
JAMJAR_LOG="/var/log/jamJAR.log"

# This scripts Version
SCRIPT_VERSION="3.1"

##########################################################################################
#################################### Start functions #####################################
##########################################################################################


# Validates prerequisites: must run as root, binary must exist, and at least one of $4-$7 must be set.
setup()
{
    # Make sure we're root, exiting if not.
    if [[ "$(/usr/bin/id -u)" -ne 0 ]]
    then
        # ERROR notification.
        /bin/echo "ERROR: This script must be run as root, exiting..." 1>&2
        # Exit.
        exit 1
    fi

    # Make sure that the jamJAR binary exists, exiting if not.
    if [[ ! -f "${JAMJAR_BINARY}" ]]
    then
        # ERROR notification.
        /bin/echo "ERROR: ${JAMJAR_BINARY} not found, exiting..." 1>&2
        # Exit.
        exit 1
    fi

    # Check that we have a value assigned to at least one of the variables: $4 - $7,
    # exiting if not.
    if [[ -z "$4$5$6$7" ]]
    then
        # ERROR notification.
        /bin/echo "ERROR: Nothing assigned to \$4 - \$7, exiting..." 1>&2
        # Exit.
        exit 1
    fi
}


# Entry point: reads script parameters ($4-$10) and dispatches each to processParameter() with the appropriate flags.
main()
{
    # Var declarations.
    local force_action=""
    local verbose_mode=""

    # Progress notification
    /bin/echo "Running jamJAR policy script: ${SCRIPT_VERSION}"

    # If the script parameter `$8`, has been set...
    if [[ -n "${8}" ]]
    then
        # Set `force_action` to: `true.`
        force_action="true"
    fi

    # If the script parameter `$9`, has been set...
    if [[ -n "${9}" ]]
    then
        # Set `verbose_mode` to: `true.`
        verbose_mode="true"
    fi

    # If the script parameter `$4`, has been set...
    if [[ -n "${4}" ]]
    then
        # Process the parameters content.
        processParameter "${4}" "--add-to-installs" "${force_action}" "${verbose_mode}"
    fi

    # If the script parameter `$5`, has been set...
    if [[ -n "${5}" ]]
    then
        # Process the parameters content.
        processParameter "${5}" "--remove-from-installs" "${force_action}" "${verbose_mode}"
    fi

    # If the script parameter `$6`, has been set...
    if [[ -n "${6}" ]]
    then
        # Process the parameters content.
        processParameter "${6}" "--add-to-uninstalls" "${force_action}" "${verbose_mode}"
    fi

    # If the script parameter `$7`, has been set...
    if [[ -n "${7}" ]]
    then
        # Process the parameters content.
        processParameter "${7}" "--remove-from-uninstalls" "${force_action}" "${verbose_mode}"
    fi
}


# Splits a comma-delimited parameter value into individual titles and calls the jamJAR binary for each,
# appending --force, --enforce-updates (1.6+), or --verbose flags as configured. Exits non-zero on any failure.
processParameter()
{
    # Var declarations.
    local jamJAR_version
    local -a cli_command
    local force_action="${3}"
    local jau_action="${2}"
    local parameter_value="${1}"
    local -a passed_titles
    local return_code=0
    local run_errors=''
    local tail_pid
    local verbose_mode="${5}"

    # Attempt to retrieve the version of `JAMJAR_BINARY`.
    jamJAR_version="$("${JAMJAR_BINARY}" --version 2>&1)"

    # If the version could not be retrieved, exit with an error.
    if [[ -z "${jamJAR_version}" ]]
    then
        # ERROR notification.
        /bin/echo "ERROR: Failed to retrieve version from ${JAMJAR_BINARY}, exiting..." 1>&2
        # Exit.
        exit 1
    fi

    # Set `,` as the field separator.
    local IFS=","

    # Convert `parameter_value` to an array, splitting on `,`.
    read -r -a passed_titles <<< "${parameter_value}"

    # Ensure `JAMJAR_LOG` exists so `tail -f` has a file to follow, as the binary itself creates the file on first run.
    /usr/bin/touch "${JAMJAR_LOG}"

    # For each title in `passed_titles`...
    for passed_title in "${passed_titles[@]}"
    do
        # Create the base command to call `JAMJAR_BINARY`.
        cli_command=("${JAMJAR_BINARY}" "${jau_action}" "${passed_title}")
        # If we're to force the action...
        if [[ -n "${force_action}" ]]
        then
            # Append the `--force` flag.
            cli_command+=("--force")
        fi
        # If we're to enable verbose mode.
        if [[ -n "${verbose_mode}" ]]
        then
            # Append the `--verbose` flag.
            cli_command+=("--verbose")
        fi
        # Tail `JAMJAR_LOG` and background the process.
        /usr/bin/tail -f "${JAMJAR_LOG}" &
        # Store the PID of the backgrounded tail process immediately.
        tail_pid=$!
        # Issue the command to the `JAMJAR_BINARY`.
        "${cli_command[@]}"
        # Get the commands return code.
        return_code=$?
        # Ask the backgrounded tail process to quit.
        /bin/kill -TERM "${tail_pid}"
        # If the run encountered an issue...
        if [[ "${return_code}" -ne 0 ]]
        then
            # Set `run_errors`.
            run_errors="true"
        fi
    done

    # If `run_errors` has been set.
    if [[ -n "${run_errors}" ]]
    then
        # Error notification.
        /bin/echo "jamJAR encountered one or more errors, please review: ${JAMJAR_LOG}, for more information."
        # Exit with the same code.
        exit "${return_code}"
    # If no errors were encountered.
    else
        # Error notification.
        /bin/echo "jamJAR ran successfully."
        # Exit
        exit 0
    fi
}

##########################################################################################
#################################### End functions #######################################
##########################################################################################

setup "${@}"
main "${@}"
