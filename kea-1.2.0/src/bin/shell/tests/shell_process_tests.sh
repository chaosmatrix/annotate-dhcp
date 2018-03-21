# Copyright (C) 2017 Internet Systems Consortium, Inc. ("ISC")
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Path to the temporary configuration file.
CFG_FILE=/home/wlodek/dev/releases/120_3/src/bin/shell/tests/test_config.json
# Path to the Control Agent log file.
LOG_FILE=/home/wlodek/dev/releases/120_3/src/bin/shell/tests/test.log
# Expected version
EXPECTED_VERSION="1.2.0"

# Control Agent configuration to be stored in the configuration file.
# todo: use actual configuration once we support it.
CONFIG="{
    \"Control-agent\":
    {
        \"http-host\": \"127.0.0.1\",
        \"http-port\": 8081
    },
    \"Logging\":
    {
        \"loggers\": [
        {
            \"name\": \"kea-ctrl-agent\",
            \"output_options\": [
                {
                    \"output\": \"$LOG_FILE\"
                }
            ],
            \"severity\": \"DEBUG\"
        }
        ]
    }
}"

# In these tests we need to use two binaries: Control Agent and Kea shell.
# Using bin and bin_path would be confusing, so we omit defining bin
# and bin_path on purpose.
ca_bin="kea-ctrl-agent"
ca_bin_path=/home/wlodek/dev/releases/120_3/src/bin/agent

shell_bin="kea-shell"
shell_bin_path=/home/wlodek/dev/releases/120_3/src/bin/shell

tmpfile_path=/home/wlodek/dev/releases/120_3/src/bin/shell/tests

# Import common test library.
. /home/wlodek/dev/releases/120_3/src/lib/testutils/dhcp_test_lib.sh

# This test verifies that Control Agent is shut down gracefully when it
# receives a SIGINT or SIGTERM signal.
shell_command_test() {
    test_name=${1}  # Test name
    cmd=${2}        # Command to be sent
    exp_rsp=${3}    # Expected response
    params=${4}     # Any extra parameters

    # Setup phase: start CA.

    # Log the start of the test and print test name.
    test_start ${test_name}
    
    # Remove any dangling CA instances and remove log files.
    cleanup

    # Create new configuration file.
    create_config "${CONFIG}"

    # Instruct Control Agent to log to the specific file.
    set_logger
    # Start Control Agent.
    start_kea ${ca_bin_path}/${ca_bin}
    # Wait up to 20s for Control Agent to start.
    wait_for_kea 20
    if [ ${_WAIT_FOR_KEA} -eq 0 ]; then
        printf "ERROR: timeout waiting for Control Agent to start.\n"
        clean_exit 1
    fi

    # Check if it is still running. It could have terminated (e.g. as a result
    # of configuration failure).
    get_pid ${ca_bin}
    if [ ${_GET_PIDS_NUM} -ne 1 ]; then
        printf "ERROR: expected one Control Agent process to be started.\
 Found %d processes started.\n" ${_GET_PIDS_NUM}
        clean_exit 1
    fi

    # Check in the log file, how many times server has been configured.
    # It should be just once on startup.
    get_reconfigs
    if [ ${_GET_RECONFIGS} -ne 1 ]; then
        printf "ERROR: server been configured ${_GET_RECONFIGS} time(s),\
 but exactly 1 was expected.\n"
        clean_exit 1
    else
        printf "Server successfully configured.\n"
    fi

    # Main test phase: send command, check response.
    tmp="echo \"${params}\" | ${shell_bin_path}/${shell_bin} --host \
 127.0.0.1 --port 8081 ${cmd} > ${tmpfile_path}/shell-stdout.txt"
    echo "Executing kea-shell ($tmp)"
    
    echo "${params}" | ${shell_bin_path}/${shell_bin} --host 127.0.0.1 \
 --port 8081 ${cmd} > ${tmpfile_path}/shell-stdout.txt

    # Check the exit code
    shell_exit_code=$?
    if [ ${shell_exit_code} -ne 0 ]; then
        echo "ERROR:" \
        "kea-shell returned ${shell_exit_code} exit code,  expected 0."
    else
        echo "kea-shell returned ${shell_exit_code} exit code as expected."
    fi

    # Now check the response
    rm -f ${tmpfile_path}/shell-expected.txt
    echo ${exp_rsp} > ${tmpfile_path}/shell-expected.txt
    diff ${tmpfile_path}/shell-stdout.txt ${tmpfile_path}/shell-expected.txt
    diff_code=$?
    if [ ${diff_code} -ne 0 ]; then
        echo "ERROR:" \
        "content returned is different than expected." \
        "See ${tmpfile_path}/shell-*.txt"
        echo "EXPECTED:"
        cat ${tmpfile_path}/shell-expected.txt
        echo "ACTUAL RESULT:"
        cat ${tmpfile_path}/shell-stdout.txt
        clean_exit 1
    else
        echo "Content returned by kea-shell meets expectation."
        rm ${tmpfile_path}/shell-*.txt
    fi
    # Main test phase ends.

    # Cleanup phase: shutdown CA
    # Send SIGTERM signal to Control Agent
    send_signal 15 ${ca_bin}

    # Now wait for process to log that it is exiting.
    wait_for_message 10 "DCTL_SHUTDOWN" 1
    if [ ${_WAIT_FOR_MESSAGE} -eq 0 ]; then
        printf "ERROR: Control Agent did not log shutdown.\n"
        clean_exit 1
    fi

    # Make sure the server is down.
    wait_for_server_down 5 ${ca_bin}
    assert_eq 1 ${_WAIT_FOR_SERVER_DOWN} \
        "Expected wait_for_server_down return %d, returned %d"

    test_finish 0
}

# This test verifies that the binary is reporting its version properly.
version_test() {
    test_name=${1}  # Test name

    # Log the start of the test and print test name.
    test_start ${test_name}

    # Remove dangling Kea instances and remove log files.
    cleanup

    REPORTED_VERSION="`${shell_bin_path}/${shell_bin} -v`"

    if test "${REPORTED_VERSION}" == "${EXPECTED_VERSION}"; then
        test_finish 0
    else
        echo "ERROR:" \
        "Expected version ${EXPECTED_VERSION}, got ${REPORTED_VERSION}"
        test_finish 1
    fi
}

version_test "shell.version"
shell_command_test "shell.list-commands" "list-commands" \
    "[ { \"arguments\": [ \"build-report\", \"config-get\", \"config-test\", \"config-write\", \"list-commands\", \"shutdown\", \"version-get\" ], \"result\": 0 } ]" ""
shell_command_test "shell.bogus" "give-me-a-beer" \
    "[ { \"result\": 2, \"text\": \"'give-me-a-beer' command not supported.\" } ]" ""
shell_command_test "shell.empty-config-test" "config-test" \
    "[ { \"result\": 1, \"text\": \"Missing mandatory 'arguments' parameter.\" } ]" ""
shell_command_test "shell.no-app-config-test" "config-test" \
    "[ { \"result\": 1, \"text\": \"Missing mandatory 'Control-agent' parameter.\" } ]" \
    "\"FooBar\": { }"
shell_command_test "shell.no-map-config-test" "config-test" \
    "[ { \"result\": 1, \"text\": \"'Control-agent' parameter expected to be a map.\" } ]" \
    "\"Control-agent\": [ ]"
shell_command_test "shell.bad-value-config-test" "config-test" \
    "[ { \"result\": 2, \"text\": \"out of range value (80000) specified for parameter 'http-port' (<string>:1:76)\" } ]" \
    "\"Control-agent\": { \"http-port\": 80000 }"