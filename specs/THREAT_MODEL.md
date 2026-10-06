# Threat Model & Kerckhoffs Security Posture

## 1. Adversary Definition

We define our threat actor as an **Autonomous Adversary** ($\mathcal{A}$) operating from within the guest execution environment.

### Capabilities of $\mathcal{A}$:
1. **Full White-Box Knowledge:** $\mathcal{A}$ has complete access to the source code of the guest kernel, the host VMM daemon, all network proxy configs, seccomp filters, and build scripts.
2. **Root Execution inside Guest:** $\mathcal{A}$ can execute arbitrary machine code with `UID 0` (`root`) inside the guest environment.
3. **Exploit Crafting:** $\mathcal{A}$ can trigger known or zero-day vulnerabilities in the guest operating system, guest kernel modules, and virtual device drivers.
4. **Adaptive Behavioral Strategy:** If powered by an LLM or autonomous agent, $\mathcal{A}$ can iteratively analyze error messages, test boundaries, and formulate novel multi-stage breakout chains.

---

## 2. Security Invariants (What Must Never Be Compromised)

| Invariant | Description | Enforcement Mechanism |
| :--- | :--- | :--- |
| **$I_1$: Host Integrity** | $\mathcal{A}$ cannot execute code on the host operating system. | Hardware virtualization boundary (Intel VT-x / AMD-V via KVM) + Memory-safe Rust VMM. |
| **$I_2$: State Non-Persistence** | Changes made by $\mathcal{A}$ in session $S_i$ do not persist to session $S_{i+1}$. | Ephemeral Copy-on-Write snapshots; memory and disk deltas discarded in RAM (`tmpfs`). |
| **$I_3$: Zero Host Exfiltration** | $\mathcal{A}$ cannot read host filesystem files, environment variables, or metadata services. | Absence of shared filesystem mounts (`9p`/`virtiofs` disabled by default; isolated vsock only). |
| **$I_4$: Network Containment** | $\mathcal{A}$ cannot establish unauthorized external TCP/UDP connections. | Guest network interface bound to isolated TAP device routed strictly through an egress allowlist proxy. |

---

## 3. Defense-in-Depth Boundary Analysis

```text
[Guest Process]
       │
       ▼
[Guest Kernel] (Can be completely owned by adversary)
       │
       ▼  (Hardware Hypercall / VM-Exit)
┌────────────────────────────────────────────────────────┐
│  HARDWARE BOUNDARY (CPU VT-x / AMD-V)                  │
└────────────────────────────────────────────────────────┘
       │
       ▼
[VMM Process] (Firecracker: Memory-Safe Rust, stripped devices)
       │
       ▼  (Host Syscall Filter)
┌────────────────────────────────────────────────────────┐
│  SECCOMP-BPF & CGROUPS V2 (Host Kernel Shield)        │
└────────────────────────────────────────────────────────┘
       │
       ▼
[Host Linux Kernel & Filesystem]
```

### Why Standard Docker Fails:
Docker relies on namespaces (`clone(CLONE_NEWPID | CLONE_NEWNS...)`). The syscall execution path never leaves the host kernel. A single privilege-escalation bug or namespace traversal bug in the host kernel compromises the entire server.

### Why Ironclad Agent Sandbox Succeeds:
Even if $\mathcal{A}$ replaces the guest kernel with a crafted rootkit, a VM-Exit traps the execution back into the VMM. To break out to the host, $\mathcal{A}$ must find a remote code execution exploit in Firecracker's minimal Rust device emulation code. The VMM is itself constrained by a host Seccomp-BPF policy, preventing it from executing shells or opening sensitive files on the host.
