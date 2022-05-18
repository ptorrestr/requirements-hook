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

show_unknown_format() {
    cat << EOF
Unknown input file format. Currently, only "Pipenv.lock" and "poetry.lock" are
supported.
EOF
}

is_pipenv() {
    # Check if the input file is a Pipfile.lock
    #1 Input file
    FILE=$1
    if [ "${FILE##*/}" = "Pipfile.lock" ]; then
        true
    else
        false
    fi
}

is_poetry() {
    # Check if the input file is a poetry.lock file
    #1 Input file
    FILE=$1
    if [ "${FILE##*/}" = "poetry.lock" ]; then
        true
    else
        false
    fi
}

get_deps_base() {
    # Generate dependencies from Pipfile.lock that are standard
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
     # Generate dependencies from Pipfile.lock that are git repos
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
    # Generate dependencies from Pipfile.lock that are files
    PIPLOCK_FILE=$1 #1 Pipfile.lock
    OUTPUT_FILE=$2  #2 Output file
    ENV=$3          #3 Environment
    jq -r --arg v "$ENV" '.[$v]
        | to_entries[]
        | select(.value.file != null)
        | .key + " @ " + .value.file' \
        $PIPLOCK_FILE > $OUTPUT_FILE
}

generate_requirements_pipenv() {
    # Generate requirements using pipenv
    #1 Pipenv.lock file
    #2 temporal requirments.txt file
    #3 type (either default or develop)
    PIPLOCK_FILE=$1
    OUTPUT_TEMP_FILE=$2
    TYPES=$3

    new_requirements_file=$(mktemp)
    # check default environment
    for type in $TYPES
    do
        # check for standard requirements
        test_file_1=$(mktemp)
        get_deps_base $PIPLOCK_FILE $test_file_1 $type
        # check for git+ssh and add them to the end
        test_file_2=$(mktemp)
        get_deps_git $PIPLOCK_FILE $test_file_2 $type
        # check for files and add them to the end
        test_file_3=$(mktemp)
        get_deps_file $PIPLOCK_FILE $test_file_3 $type
        # create new version
        cat $test_file_1 $test_file_2 $test_file_3 | sort -u >> $new_requirements_file
    done

    cat $new_requirements_file | sort -u >> $OUTPUT_TEMP_FILE    
}

generate_requirements_poetry() {
    # Generate requirements using poetry
    #1 poetry.lock file
    #2 temporal requirments.txt file
    #3 type (either default or develop)
    LOCK_FILE=$1
    OUTPUT_TEMP_FILE=$2
    TYPES=$3

    new_requirements_file=$(mktemp)
    for type in $TYPES
    do
        echo "$type"
        python poetry.py $LOCK_FILE $type >> $new_requirements_file
    done

    cat $new_requirements_file | sort -u >> $OUTPUT_TEMP_FILE    
}

generate_requirements() {
    #1 Pipfile.lock
    #2 requirements.txt
    PIPLOCK_FILE=$1
    REQUIREMENTS_FILE=$2
    new_requirements_file=$(mktemp)
    if is_pipenv $PIPLOCK_FILE; then
        generate_requirements_pipenv $PIPLOCK_FILE $new_requirements_file default
    elif is_poetry $PIPLOCK_FILE; then
        generate_requirements_poetry $PIPLOCK_FILE $new_requirements_file default
    else
        show_unknown_format
        exit 2
    fi

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
    new_requirements_file=$(mktemp)

    if is_pipenv $PIPLOCK_FILE; then
        generate_requirements_pipenv $PIPLOCK_FILE $new_requirements_file "default develop"
    elif is_poetry $PIPLOCK_FILE; then
        generate_requirements_poetry $PIPLOCK_FILE $new_requirements_file "default develop"
    else
        show_unknown_format
        exit 2
    fi

    # validate diff
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

check_file() {
    #1 file
    echo -n "Checking input file $1..."
    test -f $1 ||\
        ( echo "ERROR: File $1 was not found" 1>&2 &&\
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

check_task check_file $piplock_path
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