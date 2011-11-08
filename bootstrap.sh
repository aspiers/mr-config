#!/bin/bash

if ! which curl >&/dev/null; then
    echo "mr can't bootstrap without curl" >&2
    exit 1
fi

dst=$HOME/.GIT/3rd-party
[ -d $dst ] || mkdir -p $dst

git clone git@github.com:aspiers/kitenet-mr.git $dst/mr
ln -s $dst/mr/mr ~/bin

mr -t bootstrap http://adamspiers.org/.mrconfig
cd
mr stow
