# mr helper functions

Helpers available in the `checkout`, `lib`, `remotes`, `fixups` and `skip`
sections of an entry. They are defined in `~/.config/mr/sh.d/` and
`~/.config/mr/lib.d/`; read the source when behaviour matters.

## Checkout/Clone Functions

- **`github_clone`** - Clone from user's GitHub fork (assumes you've forked the repo)
- **`git_clone_my_repo`** - Clone from adamspiers.org git server (personal repos)
- **`github_clone_ro_origin`** - Clone a GitHub repo (read-only, not forked)
- **`github_clone_rw_origin`** - Clone a GitHub repo with write access (e.g., wikis)
- **`gitlab_clone`** - Clone from GitLab
- **`savannah_ro_clone`** - Clone from GNU Savannah (read-only)

## Lib Context Helpers

Used to configure repository behavior before clone/checkout:

- **`set_git_origin_user <user>`** - Set the GitHub/GitLab user who owns the origin repo
- **`set_git_origin_name <name>`** - Set the origin repository name (if different from clone name)
- **`set_git_clone_name <name>`** - Set the name to use when cloning
- **`set_email <email>`** - Set the git user.email for this repo (overrides defaults)
- **`set_description <text>`** - Record the repo's one-line purpose, printed by `mr describe`. Every repo under `~/.GIT/adamspiers.org` and every top-level repo in `~` needs one; third-party clones don't
- **`set_git_clone_remote <remote>`** - Set which remote name to use during clone (default: depends on service)

## Remote Management Functions

- **`auto_remotes`** - Automatically configure remotes based on repository type and service
  - Calls `auto_personal_remotes` and `auto_external_remotes`
  - Intelligently adds remotes for moosehall peer machines, github forks, etc.
- **`github_readwrite_remote <remote> [<username> [<reponame>]]`** - Add a GitHub remote with read/write (SSH) access; username defaults to remote name
- **`github_readonly_remote <remote> [<username> [<reponame>]]`** - Add a GitHub remote with read-only access; username defaults to remote name
- **`git_add_remotes "<list>"`** - Manually add remotes from a whitespace-separated list:
  ```
  remotes = git_add_remotes "
      origin  git@github.com:user/repo.git
      upstream  git://github.com/upstream/repo.git
  "
  ```
- **`git_add_remote <name> <url>`** - Add a single remote

## Fixup Functions

Run after checkout to configure the repository:

- **`git_config_email`** - Set git user.email based on `MR_EMAIL` (with smart defaults)
- **`setup_git_autocommit_and_annex_autosync`** - Enable auto-commit and git-annex auto-sync if configured
- **`ensure_symlink_exists <target> <link>`** - Create a symlink if it doesn't exist

## Skip Conditions

Used in `skip = ...` to conditionally skip repositories:

- **`default_skipper`** - Skip unless repo is in an active group or host property matches
- **`lazy`** - Skip by default unless explicitly requested with `mr -r`
- **`missing_exe <command>`** - Skip if the specified command is not available
- **`user_not_adam`** - Skip if current user is not 'adam'

