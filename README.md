# Project Code Dump Utility

A lightweight Bash utility for creating consistent project code dumps with optional archiving and integrity checks.  
Designed to keep your workspace clean and maintain incremental archives over time.

---

## Features

- 📄 **Generate dumps** of project source files into a single timestamped `.md` file.  
- 🔐 **Integrity checks**: SHA256 hash is generated and tracked in `checksums_index.txt`.  
- 📦 **Archiving**: Combine multiple dumps into a single `.zip` bundle for easier storage.  
- 🧹 **Incremental cleanup**: Old dumps and checksums are removed once archived.  
- ⚡ **Simple CLI flags** for flexible operation.  

---

## Usage

Make the script executable first:

```bash
chmod +x dump_script.sh

Create a new dump

./dump_script.sh -y

This will:

Collect all tracked files

Save them into *_all_code_dump_<timestamp>.md

Generate a .sha256 checksum and append it to checksums_index.txt



---

Archive older dumps

./dump_script.sh --archive

This will:

Collect all previous dumps (*_all_code_dump_*.md)

Bundle them into a single .zip file under archives/

Clean up the older dumps + checksums from the workspace


Each archive is timestamped (dumps_bundle_<timestamp>.zip) so you can keep multiple archives over time.


---

Example Workflow

1. Create dumps daily or weekly:

./dump_script.sh -y


2. When the dump files grow, archive them:

./dump_script.sh --archive


3. Extract an archive:

unzip archives/dumps_bundle_<timestamp>.zip




---

Repo Hygiene

This repo includes a .gitignore to exclude:

Generated dumps

Archives

Checksums

Python caches, venvs, IDE files



---

License

MIT License — feel free to use, modify, and share.
