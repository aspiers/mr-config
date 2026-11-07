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
- `.STOW/` - Stow package for mr-config itself (agent skills), linked into `$HOME`

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

## Adding or Changing Repository Entries

Before adding, changing or reviewing an entry in `groups.d/` or
`home-mrconfig`, including forking an upstream repository, load the
`mr-config-entries` skill. It covers entry shapes, the helper functions,
installing under `$HOME` and the stow patterns. Its source is in
`.STOW/.agents/skills/mr-config-entries/`; mr stows it into
`~/.agents/skills/`, so it loads from any repository.

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
mr describe       # Print "- name<TAB>path<TAB>description" per repo
mrdesc <repo>     # Print one repo's description, cached by mr-recache
```

For specific repos (must be run from `$HOME`):

```bash
mr -r <repo-name> checkout
mr -r <repo-name> update
mr -r <repo-name> fixups
mr -r <repo-name> status
```

## Key Conventions

- Repository paths often but not always follow pattern:
  `$HOME/.GIT/{adamspiers.org,3rd-party}/repo-name`
- Git email defaults configured per-group via `set_email` in lib context
- Repositories can be skipped based on conditions (lazy, missing deps, user, etc.)
- The `.autosync` file enables automatic git-annex syncing for certain repos
