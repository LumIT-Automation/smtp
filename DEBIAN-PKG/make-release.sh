#!/bin/bash

set -e

function System()
{
    base=$FUNCNAME
    this=$1

    # Declare methods.
    for method in $(compgen -A function)
    do
        export ${method/#$base\_/$this\_}="${method} ${this}"
    done

    # Properties list.
    ACTION="$ACTION"
}

# ##################################################################################################################################################
# Public
# ##################################################################################################################################################

#
# Void System_run().
#
function System_run()
{
    if [ "$ACTION" == "deb" ]; then
        if System_checkEnvironment; then
            System_definitions
            System_cleanup

            System_systemFilesSetup
            System_debianFilesSetup
            System_debCreate
            System_cleanup

            echo "Created /tmp/$projectName.deb"
        else
            echo "A Debian 11 (Bullseye) operating system is required for the deb-ification. Aborting."
            exit 1
        fi
    else
        exit 1
    fi
}

# ##################################################################################################################################################
# Private static
# ##################################################################################################################################################

function System_checkEnvironment()
{
    if [ -f /etc/os-release ]; then
        if ! grep -q 'bullseye' /etc/os-release; then
            return 1
        fi
    else
        return 1
    fi

    return 0
}


function System_definitions()
{
    declare -g debPackageRelease
    declare -g debCurrentGitCommit

    declare -g projectName
    declare -g workingFolder
    declare -g workingFolderPath

    if [ -f DEBIAN-PKG/deb.release ]; then
        # Get program version from the release file.
        debPackageRelease=$(echo $(cat DEBIAN-PKG/deb.release))
    else
        echo "Error: deb.release missing."
        echo "Usage: bash DEBIAN-PKG/make-release.sh --action deb"
        exit 1
    fi

    debCurrentGitCommit=$(git log --pretty=oneline | head -1 | awk '{print $1}')

    projectName="automation-interface-mta_${debPackageRelease}_all"
    workingFolder="/tmp"
    workingFolderPath="${workingFolder}/${projectName}"
}


function System_cleanup()
{
    if [ -n "$workingFolderPath" ]; then
        if [ -d "$workingFolderPath" ]; then
            rm -fR "$workingFolderPath"
        fi
    fi
}


function System_systemFilesSetup()
{
    # Create a new working folder and populate it.
    mkdir $workingFolderPath

    # Setting up system files.
    cp -R etc $workingFolderPath
    cp -R usr $workingFolderPath



    # Forcing standard permissions (755 for folders, 644 for files, owned by root:root.
    chown -R root:root $workingFolderPath
    find $workingFolderPath -type d -exec chmod 755 {} \;
    find $workingFolderPath -type f -exec chmod 644 {} \;
    chmod +x $workingFolderPath/usr/bin/postfix-setup.sh
    chmod +x $workingFolderPath/usr/bin/mail-test.sh
}


function System_debianFilesSetup()
{
    # Setting up all the files needed to build the package (DEBIAN folder).
    cp -R DEBIAN-PKG/DEBIAN $workingFolderPath

    sed -i "s/^Version:.*/Version:\ $debPackageRelease/g" $workingFolderPath/DEBIAN/control
    sed -i "s/GITCOMMIT/$debCurrentGitCommit/g" $workingFolderPath/DEBIAN/control

    [ -f $workingFolderPath/DEBIAN/preinst ] && chmod +x $workingFolderPath/DEBIAN/preinst
    [ -f $workingFolderPath/DEBIAN/postinst ] && chmod +x $workingFolderPath/DEBIAN/postinst
    [ -f $workingFolderPath/DEBIAN/prerm ] && chmod +x $workingFolderPath/DEBIAN/prerm
    [ -f $workingFolderPath/DEBIAN/postrm ] && chmod +x $workingFolderPath/DEBIAN/postrm
}


function System_debCreate()
{
    cd $workingFolder
    dpkg-deb --build $projectName
}

# ##################################################################################################################################################
# Main
# ##################################################################################################################################################

ACTION=""

# Must be run as root.
ID=$(id -u)
if [ $ID -ne 0 ]; then
    echo "This script needs super cow powers."
    exit 1
fi

# Parse user input.
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --action)
            ACTION="$2"
            shift
            shift
            ;;

        *)
            shift
            ;;
    esac
done

if [ -z "$ACTION" ]; then
    echo "Missing parameters. Use --action deb."
else
    System "system"
    $system_run
fi

exit 0
