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
    if [ "$ACTION" == "rpm" ]; then
        if System_checkEnvironment; then
            if ! which rpm > /dev/null; then
                echo "rpm not found, try: apt install rpm"
                exit 1
            fi

            System_definitions
            System_cleanup

            System_systemFilesSetup

            System_redhatFilesSetup
            System_rpmCreate
            System_cleanup

            echo "Created /tmp/$rpmPackage"
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
        if ! grep -q 'Debian GNU/Linux 11 (bullseye)' /etc/os-release; then
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
        rpmPackageVer=$(awk -F'-' '{print $1}' DEBIAN-PKG/deb.release)
        rpmPackageRel=$(awk -F'-' '{print $2}' DEBIAN-PKG/deb.release)
    else
        echo "Error: deb.release missing."
        echo "Usage: bash RH/make-rh-release.sh --action rpm"
        exit 1
    fi

    shortName="mta"
    debArch="all"
    rpmArch="noarch"
    debCurrentGitCommit=$(git log --pretty=oneline | head -1 | awk '{print $1}')

    projectName="automation-interface-mta"
    workingFolder="/tmp"
    workingFolderPath="${workingFolder}/${projectName}-${rpmPackageVer}"

    rpmPackage=${projectName}-${rpmPackageVer}-${rpmPackageRel}.${rpmArch}.rpm
    mainSpec=${projectName}.spec
}


function System_cleanup()
{   
    # List of the directories to be deleted.
    rmDirs="$workingFolderPath"
    for dir in $rmDirs; do
        if [ -d "$dir" ]; then
            rm -fR "$dir"
        fi
    done
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


function System_redhatFilesSetup()
{
    # Create the rpmbuild tree in $workingFolder.
    # The path must be passed to rpmbuild with the --define "_topdir <path>" option
    rpmDirs="RPMS BUILD SOURCES SPECS SRPMS BUILDROOT/${projectName}-${rpmPackageVer}-${rpmPackageRel}.x86_64"
    for dir in $rpmDirs; do
        mkdir -p "${workingFolder}/rpmbuild/$dir"
    done

    # Copy spec files to build the rpm package.
    cp RH-PKG/REDHAT/*.spec ${workingFolder}/rpmbuild/SPECS

    # Set version, release, source tar in the main spec file. 
    sed -i "s/RH_VERSION/$rpmPackageVer/g" ${workingFolder}/rpmbuild/SPECS/${mainSpec}
    sed -i "s/RH_RELEASE/$rpmPackageRel/g" ${workingFolder}/rpmbuild/SPECS/${mainSpec}
    sed -i "s/RPM_SOURCE/${projectName}.tar/g" ${workingFolder}/rpmbuild/SPECS/${mainSpec}

    # Create the source tar file for the rpm.
    cd $workingFolder
    tar pcf ${projectName}.tar ${projectName}-${rpmPackageVer}
    mv ${projectName}.tar ${workingFolder}/rpmbuild/SOURCES
    cd -

    # Build the file specs section. List files only, not directories.
    echo "%files" > ${workingFolder}/rpmbuild/SPECS/files.spec
    tar tf ${workingFolder}/rpmbuild/SOURCES/${projectName}.tar | grep -Ev '/$' | sed "s#${projectName}-${rpmPackageVer}##g" >> ${workingFolder}/rpmbuild/SPECS/files.spec
}


function System_rpmCreate()
{
    rpmbuild --define "_topdir ${workingFolder}/rpmbuild" -ba ${workingFolder}/rpmbuild/SPECS/${mainSpec}
    mv ${workingFolder}/rpmbuild/RPMS/${rpmArch}/${rpmPackage} /tmp
    rm -fr ${workingFolder}/rpmbuild
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
    echo "Missing parameters. Use --action rpm."
else
    System "system"
    $system_run
fi

exit 0
