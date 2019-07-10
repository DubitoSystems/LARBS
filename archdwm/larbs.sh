#!/bin/sh
# Luke's Auto Rice Boostrapping Script (LARBS)
# by Luke Smith <luke@lukesmith.xyz>
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

while getopts ":a:r:b:p:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -b: Dotfiles branch (master is assumed otherwise)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
	b) repobranch=${OPTARG} ;;
	p) progsfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

# DEFAULTS:
[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/ghomasHudson/dotfiles.git" && repobranch="archdwm"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/ghomasHudson/LARBS/master/archdwm/progs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"
[ -z "$repobranch" ] && repobranch="master"

### FUNCTIONS ###

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
	dialog --title "Welcome!" --msgbox "Welcome to the Auto-Rice Bootstrapping Script!\\n\\nThis script will automatically install a fully-featured dwm Arch Linux desktop, which I use as my main machine.\\n\\n-Luke" 10 60
	}

getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
        done ;}

getuser() { \
	name=$(dialog --inputbox "First, please enter the name for your main user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit;}

getcredentialsforgit() { \
	# Prompts user for username an password to github.
	glogin=$(dialog --inputbox "If there are any private repositories in your progs.csv, please provide GitHub credentials for Git Clone\\nOtherwise just confirm without any input" 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	gpass1=$(dialog --no-cancel --passwordbox "Enter a password for GitHub profile." 10 60 3>&1 1>&2 2>&3 3>&1)
	gpass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$gpass1" = "$gpass2" ]; do
		unset gpass2
		gpass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		gpass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

installorupdate() { \
    dialog --colors --title "Install or just Update" --yes-label "Update" --no-label "Install" --yesno "Pick whether you want the script to Install from fresh or update the packages on an existing system" 14 70
    }
usercheck() { \
	! (id -u "$name" >/dev/null) 2>&1 ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. We can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nThis script will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that the script will change $name's password to the one you just gave." 14 70
	}

preinstallmsg() { \
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
	}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

refreshkeys() { \
	pacman --noconfirm -Sy archlinux-keyring
	}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#LARBS/d" /etc/sudoers
	echo "$* #LARBS" >> /etc/sudoers ;}

manualinstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[ -f "/usr/bin/$1" ] || (
	echo "Installing \"$1\", an AUR helper..."
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz
	cd "$1" &&
	sudo -u "$name" makepkg --noconfirm -si
	cd /tmp || return) ;}

maininstall() { # Installs all needed programs from main repo.
	echo "Installing \`$1\` ($n of $total). $1 $2"
	pacman --noconfirm --needed -S "$1"
	}

gitmakeinstall() {
	mkdir -p $reposdir
	chown $name $reposdir
	echo "Installing \`$(basename "$1")\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2"
	pathtorepo="$reposdir""$(basename $1)"
        if [ ! -d "$pathtorepo" ]; then
            expect -c "
                spawn sudo -u $name git -C \"$reposdir\" clone --depth 1 \"$1\"
                expect \"Username*\"
                send \"$glogin\r\"
                expect \"Password*\"
                send \"$gpass1\r\"
                expect eof
                "
        fi
        cd $pathtorepo
	make
	make install
	cd /tmp || return ;}

aurinstall() { \
	echo "Installing \`$1\` ($n of $total) from the AUR. $1 $2"
	echo "$aurinstalled" | grep "^$1$"
	sudo -u "$name" $aurhelper -S --noconfirm "$1"
	}

pipinstall() { \
	echo "Installing the Python package \`$1\` ($n of $total). $1 $2"
	command -v pip || pacman -S --noconfirm --needed python-pip
	yes | pip install "$1"
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qm | awk '{print $1}')
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"") maininstall "$program" "$comment" ;;
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;}

putgitrepo() { # Downlods a gitrepo $1 and places the files in $2 only overwriting conflicts
	echo "Downloading and installing config files..."
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2" && chown -R "$name:wheel" "$2"
	chown -R "$name:wheel" "$dir"
 	expect -c "
		spawn sudo -u \"$name\" git clone -b $branch --depth 1 \"$1\" \"$dir/gitrepo\"
		expect \"Username*\"
		send \"$glogin\r\"
		expect \"Password*\"
		send \"$gpass1\r\"
		expect eof
		"
	sudo -u "$name" cp -rfT "$dir/gitrepo" "$2"
	}

serviceinit() { for service in "$@"; do
	echo "Enabling \"$service\"..."
	systemctl enable "$service"
	systemctl start "$service"
	done ;}

systembeepoff() {
	echo "Getting rid of that retarded error beep sound..."
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

resetpulse() { dialog --infobox "Reseting Pulseaudio..." 4 50
	killall pulseaudio
	sudo -n "$name" pulseaudio --start ;}

finalize(){ \
	echo "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1)."
	echo "Done"
	}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
pacman -Syu --noconfirm --needed dialog expect ||  error "Are you sure you're running this as the root user? Are you sure you're using an Arch-based distro? ;-) Are you sure you have an internet connection? Are you sure your Arch keyring is updated?"

# Welcome user.
welcomemsg || error "User exited."



#Check whether to install or just update existing.
update=1
installorupdate || update=0

if [ $update -eq 0 ]; then
    # **Full install**

    # Get and verify username and password.
    getuserandpass || error "User exited"

    # Give warning if user already exists.
    usercheck || error "User exited."

    # Get cretentials for private git repos
    getcredentialsforgit || error "User exited."

    # Last chance for user to back out before install.
    preinstallmsg || error "User exited."

    ### The rest of the script requires no user input.
    adduserandpass || error "Error adding username and/or password."
    reposdir="/home/$name/Repos/"

    # Refresh Arch keyrings.
    refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually."

    dialog --title "LARBS Installation" --infobox "Installing \`basedevel\` , \`git\` and \`expect\` for installing other software." 5 70
    pacman --noconfirm --needed -S base-devel git expect
    [ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

    # Allow user to run sudo without password. Since AUR programs must be installed
    # in a fakeroot environment, this is required for all builds with AUR.
    newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

    # Make pacman and yay colorful and adds eye candy on the progress bar because why not.
    grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color/Color/" /etc/pacman.conf
    grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

    # Use all cores for compilation.
    sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

    manualinstall $aurhelper || error "Failed to install AUR helper."

else
    getuser || error "User exited."
fi


# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the dotfiles in the user's home directory
if [ $update -eq 0 ]; then
    putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
    rm -f "/home/$name/README.md" "/home/$name/LICENSE"

    # Install the LARBS Firefox profile in ~/.mozilla/firefox/
    putgitrepo "https://github.com/LukeSmithxyz/mozillarbs.git" "/home/$name/.mozilla/firefox"

    # Pulseaudio, if/when initially installed, often needs a restart to work immediately.
    [ -f /usr/bin/pulseaudio ] && resetpulse
fi

# Enable services here.
serviceinit cronie sshd

# Most important command! Get rid of the beep!
systembeepoff

#Set the uk keymap for X11
localectl set-x11-keymap gb

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newperms "%wheel ALL=(ALL) ALL #LARBS
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm"

# Last message! Install complete!
finalize
