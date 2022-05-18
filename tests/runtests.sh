#!/bin/bash
ROOT="$(pyenv root)"
MODE="single"
NODEPS=0
PREFIX_ALL="test_pyteomics_"
PREFIX_SINGLE="test_pyteomics_single_"
CLEAN=0
declare -A exitcodes

for i in "$@" ; do
    if [[ "$i" == "--all" ]] ; then
        MODE="all"
    fi
    if [[ "$i" == "--clean" ]] ; then
        CLEAN=1
    fi
    if [[ "$i" == "--no-deps" ]] ; then
        NODEPS=1
    fi
done

if [[ $MODE == "all" ]] ; then
    echo "Installing Python versions..."
    xargs -a python-versions.txt -I{} pyenv install -s {}
    echo "Creating environments..."
    while read pv; do
        if [[ $CLEAN == 1 ]] || [ ! -d "${ROOT}/versions/${PREFIX_ALL}${pv}" ]; then
            pyenv virtualenv -f "$pv" "${PREFIX_ALL}${pv}"
        fi
    done < python-versions.txt
    if [[ $NODEPS == 0 ]] ; then
        echo "Installing dependencies..."
        while read pv; do
            eval "${ROOT}/versions/${PREFIX_ALL}${pv}/bin/pip" install -U pip wheel
            eval "${ROOT}/versions/${PREFIX_ALL}${pv}/bin/pip" install -r ../test-requirements.txt
            eval "${ROOT}/versions/${PREFIX_ALL}${pv}/bin/pip" install -U ..
        done < python-versions.txt
    fi
    echo "Running tests..."
    find . -name 'test_*.py' -print | while read f; do
        while read pv; do
            echo "${ROOT}/versions/${PREFIX_ALL}${pv}/bin/python" "$f"
            eval "${ROOT}/versions/${PREFIX_ALL}${pv}/bin/python" "$f"
            exitcodes["$f + py${pv}"]=$?
        done < python-versions.txt
    done
    if [[ $CLEAN == 1 ]] ; then
        echo "Deleting environments..."
        xargs -a python-versions.txt -I{} echo pyenv virtualenv-delete -f "${PREFIX_ALL}"{}
    fi
else
    for f; do
        if [ -f "$f" ]; then
            fname="$f"
        elif [ -f "test_${f}.py" ]; then
            fname="test_${f}.py"
        else
            continue
        fi
        while read pv; do
            if [[ $CLEAN == 1 ]] || [ ! -d "${ROOT}/versions/${PREFIX_SINGLE}${pv}" ]; then
                echo "Creating environment..."
                pyenv virtualenv -f "$pv" "${PREFIX_SINGLE}${pv}"
            fi

            if [[ $NODEPS == 0 ]] ; then
                echo "Installing dependencies..."
                eval "${ROOT}/versions/${PREFIX_SINGLE}${pv}/bin/pip" install -U pip wheel
                eval "${ROOT}/versions/${PREFIX_SINGLE}${pv}/bin/pip" install -r ../test-requirements.txt
                eval "${ROOT}/versions/${PREFIX_SINGLE}${pv}/bin/pip" install -U ..
            fi
            echo "Running test..."
            echo "Executing ${ROOT}/versions/${PREFIX_SINGLE}${pv}/bin/python ${fname}"
            eval "${ROOT}/versions/${PREFIX_SINGLE}${pv}/bin/python" "${fname}"
            exitcodes["$f + py${pv}"]=$?
            if [[ $CLEAN == 1 ]] ; then
                echo "Deleting environment..."
                echo pyenv virtualenv-delete -f "${PREFIX_SINGLE}${pv}"
                eval pyenv virtualenv-delete -f "${PREFIX_SINGLE}${pv}"
            fi
        done < python-versions.txt
    done
fi

total=0
for key in "${!exitcodes[@]}"; do
    if [[ "${exitcodes[$key]}" != 0 ]] ; then
        (( total++ ))
        echo "ERROR: $key => exit code ${exitcodes[$key]}"
    fi
done

if [[ $total == 0 ]] ; then
    echo "All tests complete, there were no errors."
else
    echo "All tests complete, there were ${total} errors (see above)."
fi
