#!/bin/bash

set -e

git_host=git.adamspiers.org
git_local_hostname=arctic
git_user=adam
git_user_at_host=$git_user@$git_host
mr_upstream_repo="git@github.com:aspiers/kitenet-mr.git"

div () {
    echo
    echo "############################################################"
    echo
}

fatal () {
    echo "$*" >&2
    exit 1
}

which curl >/dev/null 2>&1 || fatal "mr can't bootstrap without curl"
[ -d ~/.stow ] && fatal "Rogue ~/.stow - delete it first."

cd

[ -e ~/.zdotuser           ] || ${EDITOR:-vi} ~/.zdotuser
[ -e ~/.localhost-nickname ] || ${EDITOR:-vi} ~/.localhost-nickname

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

if ! [ -f "$HOME/.ssh/config" ]; then
    echo "~/.ssh/config does not exist."
    cat <<EOF > ~/.ssh/config
# bootstrap.sh-magic-cookie <- indicates can be automatically removed by bootstrap.sh
Host $git_host
   ControlMaster auto

Host *
   ControlPath ~/.ssh/master-%r@%h:%p
EOF
    chmod 600 ~/.ssh/config
    echo "Wrote ~/.ssh/config:"
    echo
    cat ~/.ssh/config
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

which git >&/dev/null || fatal "git not found on \$PATH; aborting."
git config url.ssh://$git_host/home/$git_user/.insteadof $git_local_hostname:

div ############################################################

third_party_git=$HOME/.GIT/3rd-party

mkdir -p $third_party_git
if [ -d $third_party_git/mr ]; then
    echo "Updating existing mr git repo"
    ( cd $third_party_git/mr && git pull -r )
else
    echo "Retrieving upstream git repo for mr: $mr_upstream_repo"
    git clone $mr_upstream_repo $third_party_git/mr
    ( cd $third_party_git/mr && git checkout master )
fi
ln -sf $third_party_git/mr/mr ~/bin
echo '~/.config/mr/.mrconfig' > ~/.mrtrust

div ############################################################

# Various .cfg-post.d rely on ~/bin being there.
if ! [ -d ~/bin ]; then
    mkdir ~/bin
fi
export PATH=$HOME/bin:$PATH

if [ -e .mrconfig ]; then
    mr -r mr-config up
else
    mr -t -i bootstrap http://adamspiers.org/.mrconfig
fi

div ############################################################

# We need stow installed first, so that the other
# repos can stow themselves.
mr -r stow-release checkout

if [ -d ~/.cfg ]; then
    touch ~/.cfg/.stow
    export MR_STOW_OVER=.
fi

div ############################################################

# cfgctl is needed early on for lib/libhooks.sh, and possibly other
# things too.
mr -r cfgctl up

echo "Retrieving shell-env and ssh config ..."
mr -i -r shell-env,ssh,ssh.adam_spiers.sec up
echo

div ############################################################

if ! grep -q 'bootstrap.sh-magic-cookie' ~/.ssh/config; then
    echo "bootstrap.sh magic cookie missing from ~/.ssh/config"
    if ! head -n1 ~/.ssh/config | grep -q 'Autogenerated'; then
        fatal "~/.ssh/config wasn't autogenerated; aborting."
    fi
fi

echo "Allowing mr to rebuild ssh config from scratch ..."
echo "rm ~/.ssh/config"
rm ~/.ssh/config
echo
echo "Running mr -r ssh fixups to build config ..."
mr -i -r ssh fixups

div ############################################################

echo "Running mr checkout ..."
mr -s -i up

cat <<EOF

Now fix the above errors and also run:

  ( cd && mr remotes )
EOF
