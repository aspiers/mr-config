# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Overview

This repository contains a personal `mr` (myrepos) configuration system for managing multiple git repositories across machines. It uses a modular architecture with shell libraries and group definitions to organize repos by category.

## Architecture

### Core Structure

- `home-mrconfig` - Root config symlinked from `~/.mrconfig`
- `.mrconfig` - Main config that loads all components via `library-loaders`
- `library-loaders` - Functions to include files from lib.d/ and groups.d/
- `groups.d/` - Repository group definitions (numbered 00-99 by priority)
- `lib.d/` - mr actions and parameter definitions (auto-loaded into mr's lib context)
- `sh.d/` - Shell helper functions sourced by lib.d/ files

### Bootstrap Process

The `bootstrap.sh` script sets up a fresh home directory by:

1. Configuring SSH and git
2. Installing a custom mr fork from `~/.GIT/3rd-party/mr`
3. Bootstrapping home-mrconfig remotely
4. Installing GNU Stow
5. Using mr to checkout and stow all repositories

### Repository Groups

Groups are numbered files in `groups.d/` that define sets of repositories, e.g.:

- `00-boot` - Core tools (mr, stow, shell-env, git-config, ANTIFOLD)
- `05-basic` - Basic utilities (desktop-config, screenrc, gnupg)
- `10-moosehall` - Machine-specific configs
- `12-CLI` - Command-line tools
- `14-emacs` - Emacs configuration
- `26-AI` - AI-related tools (opencode, gemini-cli, claude-agents, beads)

and many others.

### Key Helper Functions (in `sh.d/`)

- `sh.d/git` - Generic git helpers (branch tracking, upstream management)
- `sh.d/git-remotes` - Automatic remote management for peer machines
- `sh.d/my-git*` - User-specific git configurations
- `sh.d/stow` - GNU Stow helpers for package management

Files prefixed with `my-` are user-specific and won't work without modification.

## Repository Definition Helper Functions

Repository definitions in `groups.d/` files use various helper functions in their `checkout`, `lib`, `remotes`, and `fixups` sections:

### Checkout/Clone Functions

- **`github_clone`** - Clone from user's GitHub fork (assumes you've forked the repo)
- **`git_clone_my_repo`** - Clone from adamspiers.org git server (personal repos)
- **`github_clone_ro_origin`** - Clone a GitHub repo (read-only, not forked)
- **`github_clone_rw_origin`** - Clone a GitHub repo with write access (e.g., wikis)
- **`gitlab_clone`** - Clone from GitLab
- **`savannah_ro_clone`** - Clone from GNU Savannah (read-only)

### Lib Context Helpers

Used to configure repository behavior before clone/checkout:

- **`set_git_origin_user <user>`** - Set the GitHub/GitLab user who owns the origin repo
- **`set_git_origin_name <name>`** - Set the origin repository name (if different from clone name)
- **`set_git_clone_name <name>`** - Set the name to use when cloning
- **`set_email <email>`** - Set the git user.email for this repo (overrides defaults)
- **`set_git_clone_remote <remote>`** - Set which remote name to use during clone (default: depends on service)

### Remote Management Functions

- **`auto_remotes`** - Automatically configure remotes based on repository type and service
  - Calls `auto_personal_remotes` and `auto_external_remotes`
  - Intelligently adds remotes for moosehall peer machines, github forks, etc.
- **`git_add_remotes "<list>"`** - Manually add remotes from a whitespace-separated list:
  ```
  remotes = git_add_remotes "
      origin  git@github.com:user/repo.git
      upstream  git://github.com/upstream/repo.git
  "
  ```
- **`git_add_remote <name> <url>`** - Add a single remote

### Fixup Functions

Run after checkout to configure the repository:

- **`git_config_email`** - Set git user.email based on `MR_EMAIL` (with smart defaults)
- **`setup_git_autocommit_and_annex_autosync`** - Enable auto-commit and git-annex auto-sync if configured
- **`ensure_symlink_exists <target> <link>`** - Create a symlink if it doesn't exist

### Skip Conditions

Used in `skip = ...` to conditionally skip repositories:

- **`default_skipper`** - Skip unless repo is in an active group or host property matches
- **`lazy`** - Skip by default unless explicitly requested with `mr -r`
- **`missing_exe <command>`** - Skip if the specified command is not available
- **`user_not_adam`** - Skip if current user is not 'adam'

## Common Operations

**Note:** When working from within a repository directory, you can run `mr <action>` directly. When working from elsewhere, use either:
- `mr -r <repo-name>` (requires being in `$HOME`)
- The `mr*` convenience commands from `mr-util` (work from any directory)

### mr-util Convenience Commands

These wrapper commands (from `~/.GIT/adamspiers.org/mr-util/bin/`) simplify repository operations:

```bash
mrco <repo> [<repo2> ...]   # Checkout one or more repos
mrup <repo> [<repo2> ...]   # Update repos
mrf <repo> [<repo2> ...]    # Run fixups
mrs <repo> [<repo2> ...]    # Check status
mrst <repo> [<repo2> ...]   # Stow repos
mrrest <repo> [<repo2> ...] # Restow repos
mrchk <repo> [<repo2> ...]  # Check upstream
```

**Examples:**
```bash
mrco Gittyup              # Checkout Gittyup from anywhere
mrf Gittyup               # Build and install Gittyup
mrco shell-env git-config # Checkout multiple repos at once
```

### Standard mr Commands

For all repositories or when in a repo directory:

```bash
mr status         # Check status of all repos
mr -s status      # Silent mode, only show changes
mr up             # Update all repos
mr remotes        # Set up remotes for all repos
mr stow           # Stow all stowable packages
mr fix            # Run fixups for all repos
```

For specific repos (must be run from `$HOME`):

```bash
mr -r <repo-name> checkout
mr -r <repo-name> update
mr -r <repo-name> fixups
mr -r <repo-name> status
```

## Package Installation Patterns

Repository contents can be installed into `$HOME` using different patterns depending on the type of package and complexity of build requirements.

### Pattern 1: Manual Symlink Installation (Non-Stowable)

**Use case:** Repositories that need specific symlinks created manually, not managed by GNU Stow.

**When to use:**
- Scripts or binaries that need to be symlinked to specific locations
- Plugins that need to be symlinked into another tool's directory
- When you want explicit control over symlink placement

**Configuration:**
```
[$HOME/.GIT/3rd-party/example]
checkout = github_clone
fixups =
    ensure_symlink_exists ~/bin/script-name $MR_REPO/script.sh
    ensure_symlink_exists ~/.tool/plugins/plugin-name $MR_REPO
```

**Key characteristics:**
- `stowable = true` is **NOT** set
- Use `ensure_symlink_exists <symlink-path> <target-path>` in fixups
- Manual control over each symlink
- Symlinks are NOT managed by GNU Stow

**Examples:** tpm (groups.d/12-CLI:102), sysz (groups.d/12-CLI:245)

### Pattern 2: Direct Repository Stowing (Default Stow Behavior)

**Use case:** Configuration repositories where the repo structure mirrors `$HOME`.

**When to use:**
- Config files and dotfiles (e.g., `.bashrc`, `.gitconfig`)
- Directory structures that should appear in `$HOME` (e.g., `.config/`, `bin/`)
- No build step required

**Configuration:**
```
[$HOME/.GIT/adamspiers.org/shell-env]
checkout = git_clone_my_repo
remotes = auto_remotes
stowable = true
```

**How it works:**
1. Repo is cloned (e.g., `~/.GIT/adamspiers.org/shell-env/`)
2. Stow creates symlink: `~/.STOW/shell-env -> ~/.GIT/adamspiers.org/shell-env`
3. Stow symlinks repo contents into `$HOME`:
   - `~/.bashrc -> ~/.GIT/adamspiers.org/shell-env/.bashrc`
   - `~/.config/foo -> ~/.GIT/adamspiers.org/shell-env/.config/foo`

**Key characteristics:**
- `stowable = true` set
- No `mr_init_stow_package` in lib section
- `STOW_PKG_TYPE=symlink` (default)
- Package path `~/.STOW/repo-name` is a symlink to the repo
- Stow automatically handles all symlinking

**Examples:** shell-env, git-config, desktop-config, emacs (groups.d/00-boot, groups.d/14-emacs)

### Pattern 3: Simple Compiled Binary Installation (Stowable)

**Use case:** Simple binaries that are built and installed directly to `$HOME`.

**When to use:**
- Go binaries with simple build process
- Single executable output
- Build installs directly to `~/bin/`

**Configuration:**
```
[$HOME/.GIT/3rd-party/goat]
checkout = github_clone
stowable = true
lib =
    set_git_origin_user bluesky-social
remotes = auto_remotes
fixups =
    make build
    mkdir -p ~/bin
    mv goat ~/bin/
```

**How it works:**
1. Repo is cloned
2. Fixups build the binary
3. Binary is moved/installed to `~/bin/goat`
4. Stow creates symlink: `~/.STOW/goat -> ~/.GIT/3rd-party/goat`
5. Stow manages the repo but binary is already in final location

**Key characteristics:**
- `stowable = true` set
- No `mr_init_stow_package` in lib section
- `STOW_PKG_TYPE=symlink` (default)
- Build output goes directly to `~/bin/` or similar
- Can use `ensure_symlink_exists` for additional symlinks (e.g., config files)

**Examples:** beads, vc, goat, beads_viewer (groups.d/26-AI, groups.d/60-social)

### Pattern 4: Complex Build to Stow Package Directory

**Use case:** Complex builds that install to a temporary directory, then stowed into `$HOME`.

**When to use:**
- Autotools-based builds (`./configure && make install`)
- Builds that install many files (binaries, libraries, man pages, etc.)
- When you want clean separation between build artifacts and `$HOME`

**Configuration:**
```
[$HOME/.GIT/3rd-party/git]
stowable = true
lib =
    mr_init_stow_package
    # Optional: export STOW_PKG_TYPE=directory (this is the default)
checkout = git_clone
fixups =
    set_stow_common_opts
    make configure
    ./configure --prefix=$STOW_PKG_PATH
    make install prefix=$STOW_PKG_PATH
    mr_restow_regardless
```

**How it works:**
1. Repo is cloned (e.g., `~/.GIT/3rd-party/git/`)
2. `mr_init_stow_package` sets `STOW_PKG_TYPE=directory` and `STOW_PKG_PATH=~/.STOW/git/`
3. Fixups build and install to `$STOW_PKG_PATH` (e.g., `~/.STOW/git/bin/git`)
4. `mr_restow_regardless` activates stowing
5. Stow symlinks package contents into `$HOME`:
   - `~/bin/git -> ~/.STOW/git/bin/git`
   - `~/share/man/man1/git.1 -> ~/.STOW/git/share/man/man1/git.1`

**Key characteristics:**
- `stowable = true` set
- `mr_init_stow_package` called in lib section
- `STOW_PKG_TYPE=directory` (set by `mr_init_stow_package`)
- `STOW_NO_AUTOMATIC_ACTIONS=yes` (prevents premature stowing)
- Build installs to `$STOW_PKG_PATH` (e.g., `~/.STOW/git/`)
- Call `mr_restow_regardless` at end of fixups
- **Do NOT use `ensure_symlink_exists`** - let stow handle all symlinking

**Examples:** git, tmux, screen, notmuch, msmtp (groups.d/27-git, groups.d/12-CLI, groups.d/25-mail)

### Pattern 5: Stow Package with Custom Source Path

**Use case:** When the stow package should point to a subdirectory of the repo, not the repo root.

**When to use:**
- Repo contains build artifacts that shouldn't be stowed
- Only a subdirectory of the repo should be stowed

**Configuration:**
```
[$HOME/org]
lib =
    export STOW_PKG_TYPE=symlink
    export STOW_SOURCE_PATH="$MR_REPO/.STOW"
    mr_init_stow_package
stowable = true
fixups =
    # ... setup code ...
```

**How it works:**
1. `STOW_SOURCE_PATH` overrides the default repo path
2. Stow symlink points to custom path: `~/.STOW/org -> ~/org/.STOW/`
3. Only contents of `.STOW/` subdirectory are stowed

**Key characteristics:**
- `STOW_PKG_TYPE=symlink` explicitly set
- `STOW_SOURCE_PATH` points to subdirectory
- Used for repos with mixed content

**Examples:** org (groups.d/23-PIM)

### STOW_PKG_TYPE Reference

The `STOW_PKG_TYPE` variable controls how the stow package is created:

- **`symlink`** (default without `mr_init_stow_package`):
  - Creates `~/.STOW/repo-name` as a symlink to the repo
  - Used for Patterns 2 and 3
  - Package path = symlink to `$MR_REPO` (or `$STOW_SOURCE_PATH` if set)

- **`directory`** (default with `mr_init_stow_package`):
  - Creates `~/.STOW/repo-name` as a real directory
  - Used for Pattern 4
  - Build installs files into this directory
  - Stow then symlinks directory contents into `$HOME`

## Key Conventions

- Repository paths often but not always follow pattern:
  `$HOME/.GIT/{adamspiers.org,3rd-party}/repo-name`
- Git email defaults configured per-group via `set_email` in lib context
- Repositories can be skipped based on conditions (lazy, missing deps, user, etc.)
- The `.autosync` file enables automatic git-annex syncing for certain repos
