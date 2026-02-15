# Key Manager 🔑

Readme: [Português](README.ptbr.md)

<img src="https://github.com/user-attachments/assets/14bb0446-a6f2-49d4-9e4a-ed384365ab20" width="700">

![License](https://img.shields.io/github/license/sr00t3d/key_manager)
![Shell Script](https://img.shields.io/badge/shell-script-green)

Key Manager is a utility tool developed in Shell Script to simplify the management of SSH keys and credentials in Linux environments. It was designed for system administrators and programmers who need a fast and secure way to organize, execute, or deploy access keys.

## ✨ Features

- **SSH Key Management**: Addition, removal, and listing of public/private keys.
- **Automation**: Quick configuration of keys on remote servers.
- **Security**: File permission verification (chmod 600/700) to ensure key integrity.
- **Backup**: Built-in functions to save existing keys before any changes.
- **Intuitive Interface**: Interactive terminal menus to facilitate navigation.

## 📋 Prerequisites

- Linux-based Operating System (Ubuntu, Debian, CentOS, etc.).
- `bash` (version 4.0 or higher).
- `openssh-client` installed and configured.
- `ssh-keygen`, `ssh-copy-id`, `sshpass`, `ssh-keyscan`

## 🚀 Installation

To start using Key Manager, clone the repository and assign execution permissions to the main script:

1. Clone the repository
```bash
git clone https://github.com/sr00t3d/key_manager.git
```

2. Enter the folder

```bash
cd key_manager
```

3. Grant execution permission

```bash
chmod +x key_manager.sh
```

## 🛠️ How to Use

Run the script directly from the terminal:

```bash
./key_manager.sh
```
*Tip: Move the file to `/usr/local/bin` to make usage easier*

## Common Commands (Examples)

```bash
./key_manager.sh server_ip [-u] [-p password] [-P port] [-c] [-n key_name] [-q]
```

- `--add`:            Adds a new key to the SSH agent.
- `--list`:           Lists all keys managed by the system.
- `--deploy`:         Copies the public key to a remote server (automatic authorized_keys adjustment).
- `-server_ip`:       Destination server IP address (IPv4/IPv6)
- `-u`:               Update existing SSH key
- `-p` password:      Root user password for key copying
- `-P` port:          Custom SSH port (default: 22)
- `-c`:               Force copying the SSH key to the server
- `-n` key_name:      Custom SSH key file name (default: id_rsa)
- `-q`:               Silent mode for automation
- `-h`:               Show help message

## 🌟 Examples

**Usage with IPv4**

```bash
./key_manager.sh 192.168.1.100
```
**Using custom port and key**

```bash
./key_manager.sh 192.168.1.100 -P 2222 -n custom_key
```
**Force password update**

```bash
./key_manager.sh 192.168.1.100 -u -p mypassword -c
```

## 🛡️ Security

Always remember:
- **Never share your private keys**.
- Always use a strong passphrase when generating new keys.
- This script was created to facilitate management, but responsibility for credential security lies with the user.

## ⚠️ Legal Notice

> [!WARNING]
> This software is provided "as is". Always make sure to test first in a development environment. The author is not responsible for any misuse, legal consequences, or data impact caused by this tool.

## 📚 Detailed Tutorial

For a complete, step-by-step guide, check out my full article:

👉 [**Easily manage your SSH keys**](https://perciocastelo.com.br/blog/easy-manager-your-ssh-keys.html)

## License 📄

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for more details.

# License 📄
This project is licensed under the GNU General Public License v2.0
