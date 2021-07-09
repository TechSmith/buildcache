#!/bin/bash
# -*- mode: sh; tab-width: 2; indent-tabs-mode: nil; -*-
# ------------------------------------------------------------------------------
# Copyright (c) 2020 Marcus Geelnard
#
# This software is provided 'as-is', without any express or implied warranty. In
# no event will the authors be held liable for any damages arising from the use
# of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it freely,
# subject to the following restrictions:
#
#  1. The origin of this software must not be misrepresented; you must not claim
#     that you wrote the original software. If you use this software in a
#     product, an acknowledgment in the product documentation would be
#     appreciated but is not required.
#
#  2. Altered source versions must be plainly marked as such, and must not be
#     misrepresented as being the original software.
#
#  3. This notice may not be removed or altered from any source distribution.
# ------------------------------------------------------------------------------

# Note: This script is expected to be run from the build folder.

total_success=true

function run_test {
  LOCALLOCKS=$1
  TESTFILE=/tmp/bc_file_lock_stresstest_data-$$

  rm -f "$TESTFILE"

  test_type="network share safe locks"
  if [[ "$1" = "true" ]] ; then
    test_type="allow local locks"
  fi

  # Run four instances of the stresstest in parallel.
  echo "Starting four concurrent processes (${test_type})..."
  pids=""
  for _ in {1..4}; do
    base/file_lock_stresstest "$TESTFILE" "$LOCALLOCKS" &
    pids+=" $!"
  done

  # Wait for all processes to finish.
  got_error=false
  for p in $pids ; do
    if ! wait "$p" ; then
      got_error=true
    fi
  done

  # Get the result and delete the file.
  DATA=$(cat "$TESTFILE")
  rm -f "$TESTFILE"

  # Delete the lock file (if any).
  rm -f "${TESTFILE}.lock"

  # Did we have an error exit status from any of the processes?
  if $got_error ; then
    echo "*** FAIL: At least one of the processes failed."
    exit 1
  fi

  # Check the data file contents.
  EXPECTED_DATA="4000"
  if [[ "${DATA}" = "${EXPECTED_DATA}" ]] ; then
    echo "The test passed!"
  else
    echo "*** FAIL: The count should be ${EXPECTED_DATA}, but is ${DATA}."
    total_success=false
  fi
}

# Without local locks.
run_test false

# With local locks.
run_test true

# Check the test result.
if $total_success ; then
  echo "All tests passed!"
  exit 0
fi

echo "*** FAIL: At least one of the tests failed."
exit 1

