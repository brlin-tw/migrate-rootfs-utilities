# migrate-rootfs-utilities

Utilities to help migrating user and system data to another rootfs.

<https://gitlab.com/brlin/migrate-rootfs-utilities>  
[![The GitLab CI pipeline status badge of the project's `main` branch](https://gitlab.com/brlin/migrate-rootfs-utilities/badges/main/pipeline.svg?ignore_skipped=true "Click here to check out the comprehensive status of the GitLab CI pipelines")](https://gitlab.com/brlin/migrate-rootfs-utilities/-/pipelines) [![GitHub Actions workflow status badge](https://github.com/brlin-tw/migrate-rootfs-utilities/actions/workflows/check-potential-problems.yml/badge.svg "GitHub Actions workflow status")](https://github.com/brlin-tw/migrate-rootfs-utilities/actions/workflows/check-potential-problems.yml) [![pre-commit enabled badge](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white "This project uses pre-commit to check potential problems")](https://pre-commit.com/) [![REUSE Specification compliance badge](https://api.reuse.software/badge/gitlab.com/brlin/migrate-rootfs-utilities "This project complies to the REUSE specification to decrease software licensing costs")](https://api.reuse.software/info/gitlab.com/brlin/migrate-rootfs-utilities)

## Prerequisites

The following prerequisites must be met before using the migration utilities:

* The following software are required to be installed on the system where the migration utilities are run:
    + GNU Bash  
      Used as the interpreter of the migration utilities.
    + GNU Core Utilities  
      For determining the script directory and plaintext data operations.
    + Rsync  
      Used for synchronizing files between the source and destination root filesystems.
        - The version 3.2.3 or above is required for supporting the `--mkpath` option.
    + The GNU C library(glibc)  
      For determining the user's home directory using the password database.
    + (Optional) OpenSSH  
      Used if the source or destination root filesystem is remote.
* You must have superuser(root) privileges to run the migration utilities.

## Usage

This product comprises of two utilities:

* [migrate-personal-data.sh](migrate-personal-data.sh): For migrating personal data files, including but not limited to documents and photos.
* [migrate-system-data.sh](migrate-system-data.sh): For migrating system data files, including but not limited to network settings and bluetooth pairing data.

Both utilities are required to be run as the superuser(root) and uses the same configuration file([config.sh.source](config.sh.source)).

Refer to the following instructions to use the product:

1. Download the release package from the [Releases](https://gitlab.com/brlin/migrate-rootfs-utilities/-/releases) page.
1. Extract the release package.
1. Refer to the [Configuration variables](#configuration-variables-that-can-change-the-migration-utilities-behaviors) section and edit the configuration file([config.sh.source](config.sh.source)) to suit your environment.
1. Run the migration utilities as the superuser(root) to migrate the data:

    ```bash
    sudo ./migrate-personal-data.sh
    sudo ./migrate-system-data.sh
    ```

## Configuration variables that can change the migration utilities' behaviors

The following configuration variables can change the migration utilities' behaviors:

### Common variables

The following configuration variables are used in both of the utilities:

#### DESTINATION_ROOTFS_SPEC

Specifies the Rsync specification of the destination root filesystem (could be a remote path).

Setting this configuration variable is mandatory.

#### SOURCE_ROOTFS_SPEC

Specifies the Rsync specification of the source root filesystem (could be a remote path).

**Default value:** `/` (The local root filesystem.)

### migrate-personal-data

The following configuration variables are only used in the migrate-personal-data utility:

#### DESTINATION_HOMEDIR_SPEC

Specifies the Rsync specification of the destination user home directory (could be a remote path).

**Default value:** `auto`(Automatically determine the path using the value of the DESTINATION_ROOTFS_SPEC configuration variable.)

#### SOURCE_HOMEDIR_SPEC

Specifies the Rsync specification of the source user home directory (could be a remote path).

**Default value:** `auto`(Automatically determine the path using password database.)

#### SOURCE_VBOX_VM_DIR

Specifies the path to the VirtualBox VMs directory in the source system.

If the path is relative, it is relative to the user's home directory(`SOURCE_HOMEDIR_SPEC`).

#### DESTINATION_DATAFS_SPEC

Specifies the Rsync specification of the destination user data file system (could be a remote path).

**Default value:** `auto`(Automatically determine the path using the value of the DESTINATION_ROOTFS_SPEC configuration variable.)

#### DESTINATION_VBOX_VM_DIR

Specifies the path to the VirtualBox VMs directory in the destination system.

If the path is relative, it is relative to the user's home directory(`DESTINATION_HOMEDIR_SPEC`).

#### ENABLE_SYNC_USER_DIRS

Whether to sync the user directories(e.g. Documents).

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_STEAM_LIBRARY

Whether to sync the user's Steam library.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_SSH_CONFIG_KEYS

Whether to sync the user's SSH configuration files an keys.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_DATAFS

Whether to sync the user's Data file system.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_GPG_CONFIG_KEYS

Whether to sync the GnuPG configurations and keys.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_FIREFOX_DATA

Whether to sync Firefox data.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_BASH_HISTORY

Whether to sync the Bash command history.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_GNOME_KEYRING

Whether to sync the GNOME keyring data.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_KDE_WALLET

Whether to sync the KDE Wallet data.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_USER_APPLICATIONS

Whether to sync the user local applications(in the non-standard Applications user directory).

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_KDE_CONNECT

Whether to sync the KDE Connect data.  This avoids re-pairing the paired devices.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

### migrate-system-data

The following configuration variables are only used in the migrate-system-data utility:

#### ENABLE_SYNC_WIREGUARD_CONFIG

Whether to sync the WireGuard configuration.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_UDP2RAW_INSTALLATION

Whether to sync the udp2raw installation.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_BLUETOOTHD_DATA

Whether to sync the data of the bluetooth daemon.  This avoids repairing the bluetooth devices.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_NETPLAN_CONFIG

Whether to sync the Netplan configuration files.  This avoids reconfiguring the network connections.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_FPRINTD_DATA

Whether to sync the fingerprint daemon data.  This avoids reconfiguring fingerprint recognition on the same system.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_UNMANAGED_APPS

Whether to sync the non-managed system-wide software installations(/opt).

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_MACHINE_OWNER_KEYS

Whether to sync the Machine Owner Keys(MOK) used for UEFI Secure Boot.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

#### ENABLE_SYNC_SSH_HOST_KEYS

Whether to sync the SSH host keys.

**Supported values:** `true`, `false`.  
**Default value:** `true`.

## References

The following materials are referenced during the development of this project:

* The rsync(1) manual page.  
  Explains the exit status code of the "Partial transfer due to vanished source files" error.
* [Where does Seahorse/GNOME keyring store its keyrings? - Ask Ubuntu](https://askubuntu.com/questions/96798/where-does-seahorse-gnome-keyring-store-its-keyrings)  
  Explains the path where GNOME keyring store its data.
* [KDE Wallet - ArchWiki](https://wiki.archlinux.org/title/KDE_Wallet)
  Explains the path where KDE Wallet store its data.

## Licensing

Unless otherwise noted([comment headers](https://reuse.software/spec-3.3/#comment-headers)/[REUSE.toml](https://reuse.software/spec-3.3/#reusetoml)), this product is licensed under [the 3.0 version of the GNU Affero General Public License](https://www.gnu.org/licenses/agpl-3.0.html), or any of its more recent versions of your preference.

This work complies to [the REUSE Specification](https://reuse.software/spec/), refer to the [REUSE - Make licensing easy for everyone](https://reuse.software/) website for info regarding the licensing of this product.
