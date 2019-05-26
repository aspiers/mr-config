#!/bin/bash
#
# Bootstrap a new ~adam using mr.
#
# This essentially does the following steps:
#   - configures ssh
#   - configures git
#   - checks out and installs my hacked version of mr
#   - runs mr bootstrap on a remote copy of home-mrconfig
#   - uses mr to install GNU Stow
#   - uses mr to check out and fixup all repositories
#
# It is designed to be idempotent so can be re-run on failure.

set -e

git_host=git.adamspiers.org
git_local_hostname=coral
git_user=adam
git_user_at_host=$git_user@$git_host
# The following git clone strings require appropriate
# insteadOf to be set up.
# On a vanilla bootstrap, we may not have an ssh key with
# access to this URL:
#mr_upstream_repo="github:kitenet-mr.git"
# so instead get it from my server:
mr_upstream_repo="adamspiers.org:mr.git"
# N.B. this uses the URL rewrite set below

div () {
    echo
    echo "############################################################"
    echo
}

fatal () {
    echo "$*" >&2
    exit 1
}

mr_update_stow_fixups () {
    cd
    for pkg in "$@"; do
        echo "Retrieving $1 ..."
        # N.B. -i is omitted the first time, since the fixups are expected
        # to fail due to it not having been stowed yet.
        mr    -r "$pkg" up || :
        mr -i -r "$pkg" stow
        # fixups should now work after stowing
        mr -i -r "$pkg" fix
        echo
    done
}

# There's a whole bunch more we could check for here, but we don't
# because we want it to work for bare bones installs.
for prog in curl git ruby rake virtualenv make; do
    if ! which "$prog" >/dev/null 2>&1; then
	fatal "mr can't bootstrap without $prog"
    fi
done

[ -d ~/.stow ] && fatal "Rogue ~/.stow - delete it first."

cd

[ -e ~/.zdotuser           ] || ${EDITOR:-vi} ~/.zdotuser
[ -e ~/.localhost-nickname ] || ${EDITOR:-vi} ~/.localhost-nickname
if ! [ -e ~/.localhost-props ]; then
    cat <<EOF > ~/.localhost-props
# List of properties for this machine, which governs how mr manages
# the repositories on it, and how other custom scripts treat the machine.
#
# See ~/org/notes/localhost-props.org for documentation.

moosehall

#main-console
#laptop
openvpn-server
routine
SUSE
music
secure
EOF
    ${EDITOR:-vi} ~/.localhost-props
fi

echo "Setting ZDOTDIR to $HOME"
export ZDOTDIR=$HOME

if [ -z "$PERL5LIB" ]; then
    export PERL5LIB=$HOME/lib/perl5
else
    export PERL5LIB=$HOME/lib/perl5:$PERL5LIB
fi
echo "exported PERL5LIB=$PERL5LIB"

[ -d ~/.ssh ] || mkdir ~/.ssh
chmod 700 ~/.ssh

ssh_bootstrap_conf=$HOME/.ssh/config.d/00-BOOTSTRAP
if ! [ -f "$ssh_bootstrap_conf" ]; then
    echo "$ssh_bootstrap_conf does not exist."
    mkdir -p ~/.ssh/config.d
    cat <<EOF > $ssh_bootstrap_conf
Host $git_host
   ControlMaster auto

Host *
   ControlPath ~/.ssh/master-%r@%h:%p
EOF

    # Spoof a rebuild_config line so that rebuild_config will feel safe
    # replacing it.
    ( cat <<EOF; cat $ssh_bootstrap_conf ) > ~/.ssh/config
# Autogenerated from $0 via rebuild_config

EOF

    chmod 600 ~/.ssh/config
    echo "Wrote ~/.ssh/config:"
    echo "--------- 8< --------- 8< --------- 8< --------- 8< ---------"
    cat ~/.ssh/config
    echo "--------- 8< --------- 8< --------- 8< --------- 8< ---------"
    echo
fi

ssh_socket=$HOME/.ssh/master-${git_user_at_host}:22
if [ -S $ssh_socket ]; then
    echo "$ssh_socket already exists"
else
    echo "Executing ssh -NMf $git_user_at_host"
    ssh -NMf $git_user_at_host
    echo
fi

echo -n "Checking passwordless ssh works ... "
cmd="ssh -n -o PasswordAuthentication=no $git_user_at_host hostname 2>&1"
out="`$cmd`"
if [ "$out" != "$git_local_hostname" ]; then
    echo
    fatal "$cmd returned [$out] not $git_local_hostname; aborting."
else
    echo "yep - good!"
fi

div ############################################################

echo "Configuring git ..."
which git >&/dev/null || fatal "git not found on \$PATH; aborting."
git config --global url.ssh://$git_user_at_host/home/$git_user/.srv/git/.insteadof adamspiers.org:

div ############################################################

echo "Setting up ~/bin ..."
# Various .cfg-post.d rely on ~/bin being there.
if ! [ -d ~/bin ]; then
    mkdir ~/bin
fi
export PATH=$HOME/bin:$PATH

div ############################################################

third_party_git=$HOME/.GIT/3rd-party

mkdir -p $third_party_git
if [ -d $third_party_git/mr ]; then
    echo "Updating existing mr git repo ..."
    ( cd $third_party_git/mr && git pull -r )
else
    echo "Retrieving upstream git repo for mr: $mr_upstream_repo ..."
    git clone $mr_upstream_repo $third_party_git/mr
    ( cd $third_party_git/mr && git checkout master )
fi
ln -sf $third_party_git/mr/mr ~/bin

if ! [ -e ~/.mrtrust ]; then
    echo '~/.config/mr/.mrconfig' > ~/.mrtrust
fi

div ############################################################

echo "Setting up mr config ..."

if [ -e .mrconfig ]; then
    mr -r mr-config up
else
    mr -t -i bootstrap http://adamspiers.org/.mrconfig
fi

div ############################################################

up=$HOME/bin/up
unpack=$HOME/bin/unpack
# We need 'up' / 'unpack' installed first, so that the download
# plugin can unpack stow.
if [ -e $unpack ]; then
    echo "'unpack' utility already exists ..."
else
    echo "Downloading 'unpack' utility ..."
    curl -o $unpack https://raw.githubusercontent.com/aspiers/shell-env/master/bin/unpack
    chmod +x $unpack
fi

if [ -x $up ]; then
    echo "'up' utility already exists ..."
else
    ln -s unpack $up
fi

div ############################################################

# We need stow installed first, so that the other
# repos can stow themselves.
if which stow >&/dev/null; then
    echo "stow already installed"
else
    echo "Installing stow-release ..."
    mr -r stow-release checkout

    if ! which stow >&/dev/null; then
        echo "stow installation failed; aborting." >&2
        exit 1
    fi
fi

if [ -e $up -a ! -L $up ]; then
    echo "Removing temporary $up"
    rm $up
fi

div ############################################################

echo "Checking for files which distros are likely to provide ..."

for skelfile in \
    .profile .bashrc .bash_profile .inputrc .zshrc .emacs \
    .gnupg/{{pub,sec}ring,trustdb}.gpg
do
    if [ -e "$skelfile" -a ! -L "$skelfile" ]; then
        cat <<EOF >&2
Warning: $skelfile exists but is not a symlink.
This will cause conflicts when stowing shell-env.
Please correct now - launching a subshell ...

EOF
        $SHELL || fatal "Subshell failed; aborting."
    fi
done

div ############################################################

echo "Prevent accidental folding ASAP via ANTIFOLD ..."
mr -i -r ANTIFOLD up

div ############################################################

# shell-env is needed by mr-util for zrec

# Avoid Stow conflicts
rm -f $up $unpack

mr_update_stow_fixups shell-env

echo "Running mr fixups ..."
mr -i -r mr fixups

div ############################################################

# Check out some packages to bootstrap ssh config.  This will add
# extra stuff to the config but keep our ControlMaster / ControlPath
# bits so that passwordless ssh still works.

boot=( ssh ssh.adam_spiers.sec mr-util git-config )

mr_update_stow_fixups "${boot[@]}"

echo "Removing $ssh_bootstrap_conf and rebuilding ssh config ..."
rm $ssh_bootstrap_conf
~/.cfg-post.d/ssh

while ! [ -e ~/.ssh/id_rsa ]; do
    echo "No ssh private key found; create or copy one now, and exit shell when done ..."
    $SHELL
done

div ############################################################

echo "Installing other core dependencies ..."
mr_update_stow_fixups shell-env.adam_spiers.{pub,sec}

# Get moosehall-git-URL-rewriters.
mr_update_stow_fixups moosehall+shell-env
mr_update_stow_fixups git.adam_spiers.pub

mr_update_stow_fixups moosehall+ssh.{pub,sec}

div ############################################################

echo "Installing 05-basic ..."
mr_update_stow_fixups desktop-config screenrc git-annex.static
mr_update_stow_fixups gnupg{,.sec}

div ############################################################

echo "Bootstrapping emacs ..."
mr_update_stow_fixups emacs

div ############################################################

echo "Installing important stuff from 10-moosehall ..."
mr_update_stow_fixups moosehall+{xsession,watchlogs.pub,ldap.{pub,sec}}

div ############################################################

echo "Installing important stuff from 12-CLI ..."
mr_update_stow_fixups lftp fastdup xdiskusage weechat-config lnav lnav-formats

div ############################################################

echo "Installing important stuff from 20-Xorg ..."
mr_update_stow_fixups fonts solarized rxvt graphics audio watchlogs xkb

div ############################################################

echo "Running mr up for everything else ..."
# Ignore errors like for mr_update_stow_fixups
mr -s up

echo "Running mr stow for everything else ..."
mr -s -i stow

echo "Running mr fix for everything else ..."
mr -s -i fix

cat <<EOF

Now fix the above errors and also run:

  ( cd && mr remotes )
EOF
