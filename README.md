# Adam's mr config.

This is my configuration for [mr](http://joeyh.name/code/mr/).
It won't work for anyone else, but I've published it because
it could be of interest / use to other mr users.  Certain parts
of it will be reusable, as detailed below.

## HOW IT WORKS

To set up a fresh `~adam` on a new machine, I simply download
[`bootstrap.sh`](https://github.com/aspiers/mr-config/blob/master/bootstrap.sh)
(e.g. via `wget`) and then run it - see the comments at the top
of the script for more details.

The configuration gets installed within `~/.config/mr`, and is a
combination of the following components:

* [`home-mrconfig`](https://github.com/aspiers/mr-config/tree/master/home-mrconfig) - gets pointed to by an ~/.mrconfig symlink; this is the root of the configuration hierarchy, and is deliberately kept lightweight since the meat of the configuration is handled via ...
* [`.mrconfig`](https://github.com/aspiers/mr-config/tree/master/.mrconfig) - uses [`library-loaders`](https://github.com/aspiers/mr-config/tree/master/library-loaders) to load all the components below:
* [`groups.d/`](https://github.com/aspiers/mr-config/tree/master/groups.d) - groups of `mr` repo definitions
* [`lib.d/`](https://github.com/aspiers/mr-config/tree/master/lib.d) which contains
    * various shell snippets which get auto-loaded in the context of `mr`'s `lib` parameter
    * definitions of various `mr` actions and other `mr` parameters
* [`sh.d/`](https://github.com/aspiers/mr-config/tree/master/sh.d) - various shell helper functions used by the files in `lib.d/`.  Parts of these could be reused by other people, e.g.:
    * [`sh.d/git`](https://github.com/aspiers/mr-config/tree/master/sh.d/git) - various generic `git`-related helper functions
    * [`sh.d/git-remotes`](https://github.com/aspiers/mr-config/tree/master/sh.d/git-remotes) - various helper functions relating to management of git remotes

Note that any file whose name begins `my-` is specific to me and will
not be useful to anyone else without modification.

## LICENSE

The software in this repository is free software: you can redistribute
it and/or modify it under the terms of the GNU General Public License
as published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This software is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
