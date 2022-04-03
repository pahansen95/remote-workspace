# Remote Workspaces PoC

## QuickStart

```bash
# Create a git project to maintain all your remote workspaces
declare \
	gitops_dir="${HOME}/Documents/Repositories/homelab-gitops/"
mkdir -p "${gitops_dir}"
cd "${gitops_dir}"
git init .

# Export ENV Vars
export KUBECONFIG="${gitops_dir}/.cache/kubeconfig"
# See the values.yaml file for the registry in use
export CONTAINER_REGISTRY_USERNAME="..."
export CONTAINER_REGISTRY_PASSWORD="..."
export USER_SSH_KEY="${HOME}/.ssh/dev"
export USER_SSH_PUB_KEY="${HOME}/.ssh/dev.pub"

# Build Up a Remote Workspace
remote-workspace.sh --log-level info \
	up \
		"git@gitlab.com:pahansen95/eap-proxy.git"

# Tear Down a Remote Workspace (Doesn't Delete Workspace Data)
remote-workspace.sh --log-level info \
	down \
		"git@gitlab.com:pahansen95/eap-proxy.git"
```

## Goal

PoC to build remote Ephemeral (Dev, Ops, etc...) Workspaces in a Kubernetes cluster.

## Requirements

- Invoked locally
- Runs in a Kubernetes Cluster
- Workspace Folder Persistent, Everything else Ephemeral
  - Workspace Folder built from Commit of project
- Remote Connection via VSCode
- Loads Secrets (Git, SSH, etc...) from local machine

## Design

- A Remote Container Exists that serves as the working environment.
  - VsCode Extensions
- (Future State) A set of Network Addressable Services
- A PV that holds the workspace folder & is mounted at the designated workspace path.
  - Originally created from a Commit SHA
- A Client side CLI tool that is used to build up & tear down the workspace.
- Client Side VsCode connects to the Remote Container
