# HelloHap board migration package

This folder is generated from the current board.

Packages:

- `hellohap-runtime-migration-20260610-extra-haps-v3.tar.gz`
  - OpenClaw runtime, shell bridge, current agent identities/workspaces, signing material, and all HAP build directories.
  - Also includes `hellohap-migration/haps/entry-default-signed.hap` and `hellohap-migration/haps/inputmethod-2in1-V1.0.4.hap`; the runtime installer installs both automatically.
  - Excludes OpenClaw session transcripts, task history, and logs.
- `hellohap-buildenv-migration-20260610-v2.tar.gz`
  - Docker command binaries and the `openclaw-linux-env:portable` image archive.
  - Needed when the target board must rebuild/sign HAPs locally.

Basic restore on a new board:

```sh
cd /
tar -xzf /data/local/tmp/hellohap-runtime-migration-20260610-extra-haps-v3.tar.gz
sh /data/local/tmp/hellohap-migration/install_runtime_on_new_board.sh
```

Optional build environment restore:

```sh
cd /
tar -xzf /data/local/tmp/hellohap-buildenv-migration-20260610-v2.tar.gz
sh /data/local/tmp/hellohap-migration/install_buildenv_on_new_board.sh
```

Notes:

- The runtime package contains credentials/signing material from the source board. Treat it as sensitive.
- The package keeps agent identity and workspace files, but intentionally removes conversation/session records.
- If `/system/bin` is read-only on the target board, the installer will keep using `/data/local/tmp/bin/openclaw-ctl`; copy the files from `/data/local/tmp/hellohap-migration/system-bin/` manually only if the system partition is writable.
- Ports used by the runtime are `7681` for shell-bridge and `18800` for OpenClaw gateway.
