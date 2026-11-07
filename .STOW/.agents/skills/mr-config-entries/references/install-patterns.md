# Installing repository contents under $HOME

Paths such as `groups.d/26-AI` are relative to `~/.config/mr`.

## Never install outside $HOME

**Fixups must never install into `/usr/local` (or anywhere else outside
`$HOME`) unless it is genuinely unavoidable.** Everything mr manages belongs
under `$HOME`, typically `~/bin/` or a stow package in `~/.STOW/`, so that:

- no fixup needs `sudo`, and `mr fix` can run unattended
- the whole installation is per-user and reproducible on any machine
- nothing mr owns can collide with distro-packaged files

Upstream build scripts frequently disagree, hardcoding `/usr/local/bin` or
probing for passwordless sudo. Redirect them, in descending order of
preference:

1. **Use the upstream override** if one exists: a `--prefix`, `PREFIX=`,
   `DESTDIR=`, or an install-directory environment variable.
2. **Run only the sub-steps you need**, skipping the upstream "install
   globally" step, then create the symlink yourself with
   `ensure_symlink_exists ~/bin/<name> "$MR_REPO/path/to/script"`. Inline the
   sub-steps rather than calling the aggregate script that appends the global
   install.
3. **Patch a temporary copy** of the installer with `sed` when it offers no
   override at all, and `grep -Fq` both before and after to assert the pattern
   matched. A silently-failed `sed` would otherwise install to the wrong place.

Whichever route you take, leave a comment saying why, so the next reader does
not "simplify" it back to the upstream one-liner.

**Examples:** orca (`groups.d/26-AI`, route 2). sussurro (`groups.d/20-Xorg`)
sidesteps the upstream installer entirely by building from source with
`make build` and copying into `~/bin/`.

## Choosing a pattern

Repository contents can be installed into `$HOME` using different patterns depending on the type of package and complexity of build requirements.

## Pattern 1: Manual Symlink Installation (Non-Stowable)

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

## Pattern 2: Direct Repository Stowing (Default Stow Behavior)

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

## Pattern 3: Simple Compiled Binary Installation (Stowable)

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

## Pattern 4: Complex Build to Stow Package Directory

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

## Pattern 5: Stow Package with Custom Source Path

**Use case:** When the stow package should point to a subdirectory of the repo, not the repo root.

**When to use:**
- Repo contains build artifacts that shouldn't be stowed
- Only a subdirectory of the repo should be stowed

**Configuration:**
```
[.config/mr.sec]
name = mr-config.sec
stowable = true
lib =
    export STOW_PKG_TYPE=symlink
    export STOW_SOURCE_PATH="$MR_REPO/.STOW"
    mr_init_stow_package
```

**How it works:**
1. `STOW_SOURCE_PATH` overrides the default repo path
2. Stow symlink points to custom path: `~/.STOW/mr-config.sec -> ~/.config/mr.sec/.STOW/`
3. Only contents of `.STOW/` subdirectory are stowed

**Key characteristics:**
- `STOW_PKG_TYPE=symlink` explicitly set
- `STOW_SOURCE_PATH` points to subdirectory
- Used for repos with mixed content

**Examples:** mr-config.sec (home-mrconfig)

## STOW_PKG_TYPE Reference

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

