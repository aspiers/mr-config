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

**Note:** The `-r <repo>` option is only needed when running commands from outside the repository directory. When already in a repo directory, omit `-r` to operate on the current repo.

### Checking repository status

```bash
mr status         # Check status of all repos
mr -s status      # Silent mode, only show changes
mr -r <repo> status  # Check specific repo (from any location)
```

### Updating repositories

```bash
mr up             # Update all repos
mr -r <repo> up   # Update specific repo (from any location)
```

### Managing remotes

```bash
mr remotes        # Set up remotes for all repos
mr -r <repo> remotes  # Set up remotes for specific repo (from any location)
```

### Stowing packages

```bash
mr stow           # Stow all stowable packages
mr -r <repo> stow # Stow specific package (from any location)
```

### Running fixups (post-checkout setup)

```bash
mr fix            # Run fixups for all repos
mr -r <repo> fix  # Run fixups for specific repo (from any location)
```

## Key Conventions

- Repository paths often but not always follow pattern:
  `$HOME/.GIT/{adamspiers.org,3rd-party}/repo-name`
- Stowable repos use GNU Stow to symlink files into `$HOME`
- Git email defaults configured per-group via `set_email` in lib context
- Repositories can be skipped based on conditions (lazy, missing deps, user, etc.)
- The `.autosync` file enables automatic git-annex syncing for certain repos
