# Remote Workspaces PoC

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