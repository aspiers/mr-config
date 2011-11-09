#!/bin/bash

set -e

git_host=adamspiers.org
git_local_hostname=arctic
git_user=adam
git_user_at_host=$git_user@$git_host
mr_upstream_repo="git@github.com:aspiers/kitenet-mr.git"

if ! which curl >&/dev/null; then
    echo "mr can't bootstrap without curl" >&2
    exit 1
fi

${EDITOR:-vi} ~/.zdotuser
${EDITOR:-vi} ~/.localhost-nickname

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
    echo "Wrote ~/.ssh/config:"
    echo
    cat ~/.ssh/config
fi

echo "Executing ssh -NMf $git_user_at_host"
ssh -NMf $git_user_at_host
echo

echo -n "Checking passwordless ssh works ... "
cmd="ssh -n -o PasswordAuthentication=no $git_user_at_host hostname 2>&1"
out="`$cmd`"
if [ "$out" != "$git_local_hostname" ]; then
    echo
    echo "$cmd returned [$out] not $git_local_hostname; aborting." >&2
    exit 1
else
    echo "yep - good!"
fi

dst=$HOME/.GIT/3rd-party
if [ -d $dst ]; then
    echo "$dst already exists; aborting" >&2
    exit 1
fi

mkdir -p $dst
echo "Retrieving upstream git repo for mr: $mr_upstream_repo"
git clone $mr_upstream_repo $dst/mr
ln -sf $dst/mr/mr ~/bin
echo '~/.config/mr/.mrconfig' > ~/.mrtrust

mr -t -i -v6 bootstrap http://adamspiers.org/.mrconfig

mr -v6 -i checkout

exit 0

# ~/bin probably doesn't exist yet, but it will be created early on
# in the below run, and various .cfg-post.d will rely on it being there.
export PATH=~/bin:$PATH

echo "Running mr -r cvs stow to set up .cvsrc ..."
mr -r cvs

echo "Running mr -r META shell-env to install lib/libhooks.sh ..."
mr -r META,shell-env
echo

echo "Running mr -r /ssh/ to retrieve all ssh config ..."
mr -r ssh,ssh.adam_spiers.sec
echo

if ! grep -q 'bootstrap.sh-magic-cookie' ~/.ssh/config; then
    echo "bootstrap.sh magic cookie missing from ~/.ssh/config; aborting!" >&2
    exit 1
fi

echo "Allowing mr to rebuild ssh config from scratch ..."
echo "rm ~/.ssh/config"
rm ~/.ssh/config
echo
echo "Running mr -r /ssh/ to build config ..."
mr -r /ssh/ #--dry-run

echo "Running mr -r ..."
mr -r #--dry-run
