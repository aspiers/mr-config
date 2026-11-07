---
name: mr-config-entries
description: Adds, changes or reviews repository entries in Adam's mr (myrepos) config, the groups.d files and home-mrconfig under ~/.config/mr, including forking an upstream GitHub repository, registering it and checking it out with mrco. Use when asked to fork, track, clone, register or "add to mr" a repository, before starting work on an upstream project that has no checkout under ~/.GIT/3rd-party yet, or when editing an entry's checkout, remotes, lib, skip or fixups sections, such as making mr build or install a repository.
---

# mr-config entries

Entries live in `~/.config/mr` (mr-config, public on GitHub). Entries for
private repositories go in `~/.config/mr.sec` instead, with the same
helpers.
Read `~/.config/mr/AGENTS.md` for how the config is put together, and
check `git status` there before editing.

## Writing an entry

- Pick the `groups.d` file by topic (`26-AI`, `12-CLI`, `20-Xorg` and so
  on), put the entry next to related ones, and copy the shape of the
  entries around it. A file's `[DEFAULT]` section, where it has one, sets
  `set_email` for all its entries.
- Checkouts usually live at `~/.GIT/adamspiers.org/<name>` (Adam's own)
  or `~/.GIT/3rd-party/<name>` (everyone else's).
- Every repository under `~/.GIT/adamspiers.org`, and every top-level one
  in `~`, needs `set_description "<one-line purpose>"` in `lib`; `mr
  describe` prints it. Third-party clones don't need one.
- Add `skip = lazy` (often `lazy || default_skipper`) when the repository
  shouldn't be cloned on every machine by a bare `mr checkout`. `mrco`
  still checks out a lazy repository.
- Fixups must install under `$HOME`, never `/usr/local`, so `mr fix` runs
  without `sudo`. Before writing build or install fixups, read
  [references/install-patterns.md](references/install-patterns.md): it
  covers redirecting upstream installers and the five stow patterns.
- [references/helpers.md](references/helpers.md) lists the clone, `lib`,
  remote, fixup and skip helpers. Read it when an entry needs more than
  the shapes below.

## Adam's own repository

```
[$HOME/.GIT/adamspiers.org/<name>]
lib = set_description "<one-line purpose>"
checkout = git_clone_my_repo
remotes = auto_remotes
```

## Fork of an upstream GitHub repository

1. Check it isn't already registered (`grep -rn '/<name>\]'
   ~/.config/mr/groups.d`) or checked out under `~/.GIT/3rd-party`.
2. Fork it with `gh repo fork <owner>/<name> --clone=false`. If the fork
   already exists, carry on. If `gh` says its token is invalid, ask the
   user to run `! gh auth login -h github.com`.
3. Add the entry:
   ```
   [$HOME/.GIT/3rd-party/<name>]
   checkout = github_clone
   remotes =
       auto_remotes
       github_readwrite_remote aspiers
   lib =
       set_git_origin_user <owner>
   ```
   `github_clone` clones the fork as remote `github`, and `auto_remotes`
   adds the upstream as `origin`. `github_readwrite_remote aspiers` sets
   `remote.pushDefault`, so a plain `git push` goes to the fork, never
   upstream. If GitHub gave the fork a different name, add both
   `set_git_clone_name <fork-name>` and `set_git_origin_name <name>`;
   otherwise `origin` points at a repository named after the fork.
4. A comment above the entry saying why it was forked helps later readers.

To track a repository without forking it, existing entries use `checkout =
github_clone_ro_origin` with `remotes = auto_remotes`.

## Checking out and verifying

```bash
mrco <name>
git -C <path> remote -v
git -C <path> config remote.pushDefault
mrf <name>    # only if the entry has fixups
```

For a fork, confirm `origin` is `<owner>/<name>` and the push default is
the `aspiers` fork.

## Committing

Commit the entry on its own in `~/.config/mr`, with a message shaped like
`<group file>: add <name> fork` and a body saying why. mr-config is
public, so keep private details out of the entry, its comments and the
message.
