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

get_deps_base() {
    PIPLOCK_FILE=$1 #1 Pipfile.lock
    OUTPUT_FILE=$2  #2 Output file
    ENV=$3          #3 Environment
    jq -r --arg v "$ENV" '.[$v]
        | to_entries[]
        | select(.value.version != null and .value.file == null )
        | .key + .value.version' \
        $PIPLOCK_FILE > $OUTPUT_FILE
}

get_deps_git() {
    PIPLOCK_FILE=$1 #1 Pipfile.lock
    OUTPUT_FILE=$2  #2 Output file
    ENV=$3          #3 Environment
    jq -r --arg v "$ENV" '.[$v]
        | to_entries[]
        | select(.value.git != null)
        | "-e git+"+.value.git+"@"+.value.ref+"#egg="+.key' \
        $PIPLOCK_FILE > $OUTPUT_FILE
}

get_deps_file() {
    PIPLOCK_FILE=$1 #1 Pipfile.lock
    OUTPUT_FILE=$2  #2 Output file
    ENV=$3          #3 Environment
    jq -r --arg v "$ENV" '.[$v]
        | to_entries[]
        | select(.value.file != null)
        | .key + " @ " + .value.file' \
        $PIPLOCK_FILE > $OUTPUT_FILE
}

generate_requirements() {
    #1 Pipfile.lock
    #2 requirements.txt
    PIPLOCK_FILE=$1
    REQUIREMENTS_FILE=$2
    # check default environment
    test_file_1=$(mktemp)
    get_deps_base $PIPLOCK_FILE $test_file_1 default
    # check for git+ssh and add them to the end
    test_file_2=$(mktemp)
    get_deps_git $PIPLOCK_FILE $test_file_2 default
    # check for git+ssh and add them to the end
    test_file_3=$(mktemp)
    get_deps_file $PIPLOCK_FILE $test_file_3 default
    # create new version
    new_requirements_file=$(mktemp)
    cat $test_file_1 $test_file_2 $test_file_3 | sort -u > $new_requirements_file
    # validate diff
    if diff $REQUIREMENTS_FILE $new_requirements_file > /dev/null 2>&1; then
        echo "$REQUIREMENTS_FILE is updated"
    else
        echo "$REQUIREMENTS_FILE needs to be updated"
        cp $new_requirements_file $REQUIREMENTS_FILE
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
    # check default environment
    test_file_1=$(mktemp)
    get_deps_base $PIPLOCK_FILE $test_file_1 default
    # check for git+ssh and add them to the end
    test_file_2=$(mktemp)
    get_deps_git $PIPLOCK_FILE $test_file_2 default
    # check for file
    test_file_3=$(mktemp)
    get_deps_file $PIPLOCK_FILE $test_file_3 default
    # now, develop
    test_file_4=$(mktemp)
    get_deps_base $PIPLOCK_FILE $test_file_4 develop
    # check for develop git+ssh
    test_file_5=$(mktemp)
    get_deps_git $PIPLOCK_FILE $test_file_5 develop
    # check for file
    test_file_6=$(mktemp)
    get_deps_file $PIPLOCK_FILE $test_file_6 develop
    # create new version
    new_requirements_file=$(mktemp)
    cat $test_file_1 $test_file_2 $test_file_3 $test_file_4 $test_file_5 $test_file_6 \
        | sort -u > $new_requirements_file
    if diff $REQUIREMENTS_DEV_FILE $new_requirements_file > /dev/null 2>&1; then
        echo "$REQUIREMENTS_DEV_FILE is updated"
    else
        echo "$REQUIREMENTS_DEV_FILE needs to be updated"
        cp $new_requirements_file $REQUIREMENTS_DEV_FILE
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