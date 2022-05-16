#!/bin/bash

. 
#installing required dependencies

check_packages() {

	IFS=" "
	echo "[DBG] PKG_DEPS: $PKG_DEPS"

	local PKG_DEPPIES=$(echo $PKG_DEPS | sed 's/\"//g')
	echo "[DBG] PKG_DEPS: $PKG_DEPPIES"

	for element in "$PKG_DEPPIES"; do
		echo "[DEBUGGA] Checking if $element is installed"
		if ! dpkg-query -s $element; then 
			echo "[WRN] Package $element is not installed. Starting installation"
			return 1
		fi
	done
	return 0

}

install_dependencies() {

	if check_packages; then
		echo "[INF] All required packages are installed"
	else
		echo ""
		local PKG_DEPPIES=$(echo $PKG_DEPS | sed 's/\"//g')
		echo "[DEBUGGA] Attempting to install $PKG_DEPPIES"
		if sudo /usr/bin/apt-get install -y $PKG_DEPPIES ; then
			echo ""
			echo "[INF] Packages were installed successfully"
		else
			echo "[ERR] can\'t install required packages. Please, check your package manager"
			echo "Aborting"
			exit 1
		fi
	fi
	return 0

}


#. prod_build/general/install_dependencies
. prod_build/general/pre-build.sh #VERSIONS and git
export_variables "prod_build/general/conf/*"
export_variables "prod_build/linux/debian/conf/*"

install_dependencies

VERSION_STRING=$(echo $VERSION_FORMAT | sed "s/\"//g" ) #Removing quotes
VERSION_ENTRIES=$(echo $VERSION_ENTRIES | sed "s/\"//g" )
extract_version_number
[ -e prod_build/linux/debian/essentials/changelog ] && last_version_string=$(cat prod_build/linux/debian/essentials/changelog | head -n 1 | cut -d '(' -f2 | cut -d ')' -f1)



#if [ -z "$last_version_string"]; then 
#	echo "Changelog won't be modified"
#	exit 1;
#fi

### ideally, we need to ask whether changelog needs to be updated or not
### is it correct? And if not, we just need to exit from this conditional construction
### not quite. See, there is always a changelog in git. (git log). We need to maintain debian/changelog on projects not built with cmake, 
### cause information from this changelog (version) is used to write package metadata. And we had messed up for a long time because of desyncing. 
### This is a solution. We modify the changelog only if there are updates and not on build servers. And of course if it's not cmake-based build project.
### let's keep those comments here for a while

if [[ $ONBUILDSERVER == 0 ]]; then  
	echo "[WRN] on build platform. Version won't be changed" # okay, so this echo wont be outputted as the condition is not true

elif [ ! -e debian/changelog ]; then  ### I guess this what's supposed to be added in order to solve the issue with the changelog?+
	echo "[INF] Debian changelog does not exist. Nothing to be done there." #I supposed it should look somehow like that.
#makes sense
elif [ "$last_version_string" == "$VERSION_STRING" ]; then
	echo "[INF] Version $last_version_string is equal to $VERSION_STRING. Nothing to change"
else
	echo "[INF] editing the changelog"
	text=$(extract_gitlog_text)
	IFS=$'\n'
	for textline in $text; do
		dch -v $VERSION_STRING $textline
	done
	branch=$(git branch | grep "*" | cut -c 3- )
	case branch in
		"master" ) branch="stable";;
		"develop" ) branch="testing";;
	esac
	dch -r --distribution "$branch" --force-distribution ignored
	controlfile_version=$(cat prod_build/linux/debian/essentials/control | grep "Standards" | cut -d ' ' -f2) #Add to control info.
	sed -i "s/$controlfile_version/$VERSION_STRING/" prod_build/linux/debian/essentials/control
	export UPDVER=1
fi

exit 0

## Maybe we do have the version required? Then we don't need to build it again. CHECK IT THERE!
