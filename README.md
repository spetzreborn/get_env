get_env
=======

## Program for downloading and managing of dotfiles and environmental settings

### Features and design goals
* #### Simple
One program file, one configuration file and one working directory.

* #### Uses git
Use github or own git-repository for environment files.

* #### No need for root
Will work on your shell on your friends server.

* #### Renameable - May use multiple get_env
The program is interchangeable in name, just rename the program file.
You can even have multiple get_env with different names and different configurations.

### Manifest
The repository has a `manifest` in its root for all hosts, and optionally
`HOSTS/<hostname>/manifest` for a specific host.

```bash
# Space-separated list of directories to create.
dirsToCreate="$HOME/.local/bin $HOME/.config/foo"
# Copy files: "dir_in_repo destination_dir files..."
files2copy[0]="dotfiles $HOME .bashrc .vimrc"
# Symlink files instead of copying: "dir_in_repo destination_dir files..."
files2link[0]="bin $HOME/.local/bin backup.sh deploy.sh"
```

Use double quotes, so `$HOME` is expanded. Destination directories must be absolute
paths, `~` is not expanded either.

Links point to the synced copy of the repository in the working directory, so they
are kept up to date on every run. A regular file in the way is backed up before it is
replaced by a link. Don't edit linked files in place, the next run overwrites them.
Links that are removed from the manifest are not removed. Use `files2copy` for
dotfiles like `.bashrc`, changes in linked files are not detected.

### Header in copied files
Put a comment line with `%%GET_ENV%%` in a file in the repository, and it is replaced
with a header when the file is copied, so you can see that it is handled by get_env:

```bash
#!/bin/bash
# %%GET_ENV%%
```
becomes
```bash
#!/bin/bash
# %%GET_ENV%%
# %%GET_ENV%% This file is handled by get_env. Local changes will be lost.
# %%GET_ENV%% Source: dotfiles (branch master): bin/backup.sh
# %%GET_ENV%% Put on disk: 2026-10-06 14:02:11 by get_env on myhost
# %%GET_ENV%% git revision: 3c244b1
# %%GET_ENV%%
```
Any comment style works, the characters before (and after) the keyword are kept,
e.g. `" %%GET_ENV%%` in .vimrc or `<!-- %%GET_ENV%% -->` in HTML. Only the first such
line is replaced. Header lines are ignored when comparing, so a file is not updated
just because the timestamp differs. Files without the keyword are copied as is.
Linked files (`files2link`) get no header.
