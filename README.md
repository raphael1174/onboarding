Onboarding bootstrap for Debian/Ubuntu

Files:
- bootstrap.sh: Minimal root-run script that installs Ansible and runs the included Ansible playbook.
- ansible/playbook.yml: Playbook that installs packages, deploys simple dotfiles, and can optionally install Docker.

Usage:
1. Copy the repository to the target machine.
2. Run as root from a non-root user (so SUDO_USER is set):
   sudo ./bootstrap.sh [--docker]

Options:
- --docker: installs Docker, Docker CLI, and docker-compose-plugin and adds the target user to the docker group.

Notes:
- The script detects a latest OpenTofu release asset via GitHub API and supplies the URL to the playbook. If not found, the playbook skips OpenTofu installation.
 - The script detects a latest OpenTofu release asset via GitHub API and supplies the URL to the playbook. If not found, the playbook will try to automatically select a matching linux asset for the host architecture.
- The playbook installs common packages via apt; if some packages aren't available in the OS repositories, you may need to enable additional repos or install those tools by other means.
- After the playbook completes, the target user may need to log out and log back in for group membership changes (docker, fuse) to apply.

Restic secure env and systemd integration
- Instead of embedding secrets in the playbook, pass restic_repository and restic_password as extra-vars or environment variables. The playbook will write /etc/restic/env with mode 0600 and the systemd service references this EnvironmentFile. Example:
  sudo restic_repository="s3:s3.amazonaws.com/bucket" restic_password="supersecret" ./bootstrap.sh

OpenTofu auto-detection
- If bootstrap.sh cannot determine an OpenTofu asset, the playbook queries GitHub and attempts to select an asset matching the host architecture (e.g. amd64, arm64). You can also explicitly pass opentofu_url via the environment to bootstrap.sh.


Passing an SSH public key to be deployed:
- You can pass an ssh public key to the playbook by setting the environment variable when invoking the bootstrap script, for example:
  sudo ssh_pub_key="ssh-rsa AAAA... user@example" ./bootstrap.sh

Testing locally in Docker (optional):
- If you have Docker available, there's a simple smoke-test script that starts an Ubuntu container and runs the bootstrap in it. Make it executable and run it from the repo root:
  chmod +x test/run_in_docker.sh
  ./test/run_in_docker.sh
