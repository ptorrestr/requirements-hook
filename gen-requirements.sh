#!/usr/bin/env bash
# Script to generate requirements.txt automatically whenever a change is found in
# Pipfile.lock

show_help() {
    cat << EOF
Usage: ${0##*/} [-h] [-d] PIPLOCK_FILE
Generate the requirements file from the Pipfile.lock file

  -h                        Display this help
  -d                        Generate developement requirement file also
EOF
}

generate_requirements() {
    #1 Pipfile.lock
    #2 requirements.txt
    PIPLOCK_FILE=$1
    REQUIREMENTS_FILE=$2
    test_file=$(mktemp)
    # check default environment
    jq -r '.default
        | to_entries[]
        | .key + .value.version' \
    $PIPLOCK_FILE > $test_file
    if diff $REQUIREMENTS_FILE $test_file > /dev/null 2>&1; then
        echo "$REQUIREMENTS_FILE is updated"
    else
        echo "$REQUIREMENTS_FILE needs to be updated"
        cp $test_file $REQUIREMENTS_FILE
        REQUIREMENTS_FILE_NEEDS_UPDATE=1
    fi
}

generate_requirements_dev() {
    #1 Pipfile.lock
    #2 requirements.txt
    #3 requirements-dev.txt
    PIPLOCK_FILE=$1
    REQUIREMENTS_FILE=$2
    REQUIREMENTS_DEV_FILE=$3
    test_file_dev=$(mktemp)
    # check develop environment. We actually need to check both!
    jq -r '.default
        | to_entries[]
        | .key + .value.version' \
    $PIPLOCK_FILE > $test_file_dev
    jq -r '.develop
        | to_entries[]
        | .key + .value.version' \
    $PIPLOCK_FILE >> $test_file_dev
    if diff $REQUIREMENTS_DEV_FILE $test_file_dev > /dev/null 2>&1; then
        echo "$REQUIREMENTS_DEV_FILE is updated"
    else
        echo "$REQUIREMENTS_DEV_FILE needs to be updated"
        cp $test_file_dev $REQUIREMENTS_DEV_FILE
        REQUIREMENTS_DEV_FILE_NEEDS_UPDATE=1
    fi
}

SUCCESS=0
FAIL=1
SKIP=2

check_command() {
  #1 command
  echo -n "Checking command $1... "
  ( hash $1 2>/dev/null ) ||\
    (echo "ERROR: Command $1 is not available" 1>&2 &&\
    return $FAIL )
}

failed() {
  echo "Failed"
  echo "---> Execution failed:"
  cat .err
  rm .err
  exit 1
}

skipped() {
  echo "Skipped"
  rm .err
}

success() {
  echo "Ok"
  rm .err
}

check_task() {
  "$@" 2> .err
  result_proc=$?
  (test "$result_proc" -eq $SUCCESS && success )\
    || (test "$result_proc" -eq $SKIP && skipped )\
    || failed;
}


# Read input
make_dev=0
while getopts "hd" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        d)
            make_dev=1
            ;;
        *)
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"   # Discard the options and sentinel --

# handle non-option arguments
if [[ $# -ne 1 ]]; then
    show_help
    exit 1
fi
piplock_path=$1
requirements_path="$(dirname "$piplock_path")"
requirements_path="$requirements_path/requirements.txt"

check_task check_command jq
check_task check_command diff


generate_requirements $piplock_path $requirements_path

if [[ $make_dev -eq 1 ]]; then
    parentdir="$(dirname "$requirements_path")"
    requirements_dev_file="${requirements_path##*/}"
    filename="${requirements_dev_file%.*}"
    extension="${requirements_dev_file##*.}"
    requirements_dev_path="$parentdir/$filename-dev.$extension"
    generate_requirements_dev $piplock_path $requirements_path $requirements_dev_path
fi

if [[ ! -z "${REQUIREMENTS_FILE_NEEDS_UPDATE}" ]] || [[ ! -z "${REQUIREMENTS_DEV_FILE_NEEDS_UPDATE}" ]]; then
    exit 1
fi