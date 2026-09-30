# PEDE — Portable Ephemeral Development Environments

> **Portable • Isolated • On-Demand • Zero Global Pollution**

**PEDE (Portable Ephemeral Development Environments)** is an automation system built with **Windows Batch + PowerShell**, designed to provide **portable, isolated, and temporary** development environments without installing runtimes, compilers, or toolchains directly into Windows.

Instead of installing tools system-wide, each toolchain is packaged in a `master.7z` archive. When an environment is launched, PEDE extracts it into a hidden `.env` workspace, configures environment variables for the current `cmd.exe` session, and provides cleanup operations when the session ends.

---

# 1. Highlights

- **Zero Global Pollution** — does not intentionally modify the global `PATH`, Registry, `AppData`, or `USERPROFILE`.
- **On-Demand Extraction** — toolchains are extracted only when needed.
- **Ephemeral Workspace** — the active environment lives in `.env` and can be removed completely.
- **Session-Scoped Environment** — variables such as `PATH`, `HOME`, `GOROOT`, and `GOPATH` are configured for the isolated shell.
- **Manifest Tracking** — tracks files using size, `mtime`, and MD5 when applicable.
- **Smart Cleanup** — supports keeping the workspace, removing original files while preserving changes, deleting everything, or repacking useful changes into the archive.
- **Portable Archives** — toolchains are distributed as archives rather than system-wide installations.
- **Cross-Environment Support** — supports Bun, Git, Go, Linux/WSL, Node.js, Python, Rust, Svelte, and W64DevKit.
- **Lightweight Toolchain Strategy** — Rust can use a reduced W64DevKit toolchain with unnecessary GNU components removed.

---

# 2. Project Overview

PEDE follows this model:

```text
Archive
   │
   ▼
Extract on demand
   │
   ▼
.env workspace
   │
   ▼
Session-scoped environment
   │
   ▼
Isolated development shell
   │
   ▼
User changes
   │
   ▼
Cleanup / Preserve / Repack
```

This README reflects the architecture and behavior documented by the current PEDE specification and does not assume undocumented features.

---

# 3. Architecture

Every PEDE environment follows the same lifecycle:

```text
┌──────────────────────────┐
│ Run Launch Script        │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Check .env               │
└────────────┬─────────────┘
             │
       .env exists?
        ┌────┴────┐
       YES        NO
        │          │
        │          ▼
        │   ┌──────────────────────┐
        │   │ Extract master.7z    │
        │   │ Build .manifest      │
        │   │ Create temp PS1      │
        │   └──────────┬───────────┘
        │              │
        └──────┬───────┘
               ▼
┌──────────────────────────────┐
│ Configure isolated variables │
│ PATH / HOME / GOROOT / ...   │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ Launch isolated CMD shell    │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ Development work             │
│ cargo / go / bun / python... │
└──────────────┬───────────────┘
               │
             exit
               │
               ▼
┌──────────────────────────────┐
│ Cleanup menu                 │
│                              │
│ [0] Keep                     │
│ [1] Delete origin, keep edit │
│ [2] Delete all               │
│ [3] Repack + delete          │
└──────────────────────────────┘
```

PEDE uses `.manifest` to distinguish original files from new or modified files. The manifest is generated with PowerShell, and long-path handling uses the `\\?\` prefix to work around the traditional Windows `MAX_PATH` limit.

---

# 4. Supported Environments

| Environment | Entry Script | Main Executable / Target | Isolation / Configuration |
|---|---|---|---|
| **Bun** | `bun_start.bat` | `.env\bun.exe` | Sets `BUN_INSTALL=.env`; adds `.env` and `.env\bin` to `PATH` |
| **Git** | `git_start.bat` | `.env\cmd\git.exe` | Isolates `HOME`, `XDG_CONFIG_HOME`, and `.gitconfig` |
| **Go** | `golang_start.bat` | `.env\bin\go.exe` | Configures `GOROOT`, `GOPATH`, `GOCACHE`; disables telemetry |
| **Linux / WSL** | `linux_start.bat` | WSL distro `LinuxBase` | Uses `wsl --import`; supports package overlay |
| **Node.js** | `nodejs_start.bat` | `.env\node.exe` | Redirects npm prefix, cache, and `.npmrc` |
| **Python** | `python_start.bat` | `.env\python.exe` | Uses a no-GUI Python distribution; provides `pip.bat` / `pip3.bat` wrappers |
| **Rust** | `rust_start.bat` | `.env\.cargo\bin\cargo.exe` | Integrates lightweight W64DevKit MinGW GCC |
| **Svelte** | `svelte_start.bat` | `.env\package.json` | Uses Bun as the supporting runtime |
| **W64DevKit** | `w64devkit_start.bat` | `.env\bin\gcc.exe` | Standalone MinGW-w64 C/C++ environment |

---

# 5. Directory Structure

```text
COMPILER/
├── _Bin/
│   ├── bun_start.bat
│   ├── git_start.bat
│   ├── golang_start.bat
│   ├── linux_start.bat
│   ├── nodejs_start.bat
│   ├── python_start.bat
│   ├── rust_start.bat
│   ├── svelte_start.bat
│   └── w64devkit_start.bat
│
├── Bun/
│   ├── master.7z
│   └── bun_start.bat
│
├── Git/
│   ├── master.7z
│   └── git_start.bat
│
├── GoLang/
│   ├── master.7z
│   └── golang_start.bat
│
├── Linux/
│   ├── master.7z
│   ├── pkg.7z
│   └── linux_start.bat
│
├── NodeJS/
│   ├── master.7z
│   └── nodejs_start.bat
│
├── Python/
│   ├── master.7z
│   └── python_start.bat
│
├── Rust/
│   ├── master.7z
│   └── rust_start.bat
│
├── Svelte/
│   ├── master.7z
│   └── svelte_start.bat
│
└── W64DevKit/
    ├── master.7z
    └── w64devkit_start.bat
```

`_Bin\` is the centralized quick-launch directory. Cross-dependent environments such as Rust and Svelte rely on this relative structure to resolve related archives and toolchains.

---

# 6. Requirements

## 6.1 Operating System

- Windows 10 64-bit
- Windows 11 64-bit

## 6.2 7-Zip

PEDE requires 7-Zip at:

```text
C:\Program Files\7-Zip\7z.exe
```

## 6.3 PowerShell

PEDE uses the standard Windows PowerShell environment.

Some scripts use:

```powershell
-ExecutionPolicy Bypass
```

## 6.4 WSL

WSL is required **only for the Linux environment**.

Enable:

```text
Windows Subsystem for Linux
```

---

# 7. Installation / Setup

PEDE is not designed around system-wide runtime installation.

1. Prepare the `COMPILER/` directory.
2. Place each `master.7z` archive in the correct environment directory.
3. Place the corresponding `.bat` launcher beside the archive.
4. Optionally place quick-launch shortcuts in `_Bin/`.
5. For Linux, prepare WSL and the Linux `master.7z`; `pkg.7z` is an optional package overlay.

Once the directory layout is correct, PEDE does not require the compiler/runtime to be registered in the global Windows `PATH`.

---

# 8. Usage

## 8.1 Launch an Environment

Example:

```bat
_Bin\python_start.bat
```

Other launchers follow the same pattern:

```bat
_Bin\linux_start.bat
```

```bat
Python\python_start.bat
```

```bat
git_start.bat
```

If `.env` does not exist:

```text
master.7z
    │
    ├── Extract
    ▼
.env/
    │
    └── .manifest
```

---

## 8.2 Work Inside the Isolated Shell

Once the isolated Command Prompt opens, toolchain commands can be used normally:

```bat
python --version
pip --version

go version

cargo --version

bun --version
```

Environment variables are configured for the isolated shell rather than being installed into the global Windows environment.

---

## 8.3 Exit

When finished:

```bat
exit
```

PEDE displays:

```text
====================================
 [0] Keep
 [1] Delete origin (keep changes)
 [2] Delete all
 [3] Save to archive + Delete
====================================
Choose (0-3):
```

---

# 9. Cleanup System

## `[0] Keep`

Keeps `.env` intact.

Useful when:

- you will continue using the same toolchain;
- you want faster startup next time;
- you do not want to extract the archive again.

---

## `[1] Delete origin (keep changes)`

> **Note:** This option is currently **unavailable for Linux**.

PEDE compares the current workspace with `.manifest`.

```text
Original file + unchanged
        ↓
      DELETE

Original file + modified
        ↓
       KEEP

New file
        ↓
       KEEP
```

Comparison uses file size, `mtime`, and MD5 when applicable.

The intended result is to remove original toolchain files while preserving files created or modified by the user.

---

## `[2] Delete all`

Deletes:

```text
.env/
```

Use it to:

- free disk space;
- return the workspace to a clean state;
- make the next launch extract again from `master.7z`.

---

## `[3] Save to archive + Delete`

Workflow:

```text
.env
 │
 ├── Remove temporary/cache data
 │
 ├── Pack useful changes
 │
 ▼
master.7z
 │
 └── Delete .env
```

This option stores useful changes back into the archive before deleting the workspace.

**Back up `master.7z` before using this option.**

---

# 10. Manifest System

The manifest is a core component of PEDE's smart cleanup mechanism.

Tracked information includes:

- file size;
- modification time (`mtime`);
- MD5 hash when applicable.

During processing, PEDE creates temporary PowerShell scripts in:

```text
%TEMP%
```

Examples:

```text
_m<RANDOM>.ps1
_c<RANDOM>.ps1
```

These scripts are used to create manifests and compare workspace state.

PEDE also uses:

```text
\\?\
```

for long-path handling.

---

# 11. Toolchain Optimization

## 11.1 Rust + W64DevKit

The Rust environment uses W64DevKit MinGW GCC as a supporting toolchain.

To reduce footprint, components such as the following may be removed:

```text
g++
gfortran
gdb
C++ headers
Fortran libraries
```

The goal is to keep the required GNU Rust support while reducing environment size.

## 11.2 Svelte + Bun

The Svelte environment uses Bun as its supporting runtime.

The Svelte environment resolves Bun through the project's relative directory structure.

---

# 12. Git Configuration

The Git environment uses placeholder identity values:

```bat
git config --global user.name "EXAMPLE_NAME"
git config --global user.email "EXAMPLE_EMAIL@DOMAIN.COM"
```

**Do not use the example identity for a real repository.**

Check the active configuration:

```bat
git config --global user.name
git config --global user.email
```

---

# 13. Security & Cleanup Notice

> [!WARNING]
> PEDE creates temporary PowerShell scripts in `%TEMP%` while generating manifests and performing cleanup operations.

After use:

- inspect `%TEMP%` for PEDE-generated temporary scripts;
- remove temporary scripts that are no longer required;
- do not keep manually added temporary `PATH` entries pointing to `%TEMP%` or `.env`;
- make sure the isolated session has ended.

This helps reduce temporary file accumulation and unintended temporary environment configuration.

---

# 14. Antivirus / Windows Defender

PEDE may:

- extract unsigned local binaries;
- create temporary PowerShell scripts;
- create and delete files through Batch;
- interact with `gcc.exe`, `rust-lld.exe`, and other linker/toolchain binaries.

Because of this behavior, Windows Defender or another antivirus product **may report a false positive**.

If a legitimate file is incorrectly quarantined, the current specification suggests adding the project root to the Windows Defender exclusion list.

Only do this after verifying the project's and toolchain's source and integrity.

---

# 15. Recommended Workflow

```text
┌─────────────────────────┐
│ 1. Start environment    │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 2. Extract if required  │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 3. Work in isolated CMD │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 4. Save source changes  │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 5. exit                 │
└────────────┬────────────┘
             ▼
      ┌──────┴──────┐
      │ Cleanup     │
      └──────┬──────┘
             │
      ┌──────┼───────────────┐
      ▼      ▼       ▼       ▼
     [0]    [1]     [2]     [3]
    Keep   Clean   Reset   Repack
```

| Situation | Option |
|---|---|
| Continue using the toolchain | `[0] Keep` |
| Keep changes while removing original files | `[1] Delete origin` |
| Completely remove the workspace | `[2] Delete all` |
| Save changes into the archive | `[3] Save to archive + Delete` |

---

# 16. Design Philosophy

PEDE is built around five principles:

### 1. Portable

Toolchains are packaged as archives and organized inside a project directory.

### 2. Ephemeral

`.env` is not intended to be a permanent installation. It can be created and removed as needed.

### 3. Isolated

Environment variables are configured for the active session rather than relying on global Windows configuration.

### 4. Reproducible

`master.7z` acts as the original toolchain archive, while `.manifest` provides the basis for identifying workspace changes.

### 5. Resource-Aware

Toolchains can be stripped of unnecessary components to reduce disk footprint, especially in Rust/W64DevKit environments.

---

# 17. Troubleshooting

## `.env` is not created

Check that:

```text
master.7z
```

exists in the correct environment directory.

Example:

```text
Python/
├── master.7z
└── python_start.bat
```

---

## `7z.exe` cannot be found

Verify:

```text
C:\Program Files\7-Zip\7z.exe
```

If 7-Zip is installed elsewhere, the current script may fail when it relies on the documented path. The project should be obtained from its source and extracted into the expected location.

---

## Linux environment does not start

Check:

```bat
wsl --status
```

Make sure WSL is enabled.

Verify:

```text
Linux/
├── master.7z
├── pkg.7z
└── linux_start.bat
```

`pkg.7z` is an optional package overlay intended to provide a large portion of the command set when the base Ubuntu/Linux environment is otherwise minimal.

`master.7z` is the base Linux distribution archive.

---

## Git identity is incorrect

Check:

```bat
git config --global user.name
git config --global user.email
```

Do not use:

```text
EXAMPLE_NAME
EXAMPLE_EMAIL@DOMAIN.COM
```

for a real repository.

---

## Workspace uses too much disk space

Use:

```text
[2] Delete all
```

to remove `.env`.

When you need to preserve user-created or modified files while removing unchanged original files, use:

```text
[1] Delete origin (keep changes)
```

This option is currently unavailable for Linux.

---

# 18. Operational Rules

Recommended operating rules:

1. Always exit the shell with:
   ```bat
   exit
   ```
2. Check `%TEMP%` periodically.
3. Do not leave temporary `PATH` entries pointing to `.env` or `%TEMP%` after the session ends.
4. Back up `master.7z` before using `[3]`.
5. Use `[1]` when preserving changes is required.
6. Use `[2]` when a complete workspace reset is required.
7. Never commit a real repository using the example Git identity.
8. Only add antivirus exclusions after verifying that the project and toolchain are trusted.

---

# 19. Quick Reference

```text
PEDE
│
├── Archives
│   └── master.7z
│
├── Runtime Workspace
│   └── .env/
│
├── Metadata
│   └── .manifest
│
├── Launcher
│   └── *_start.bat
│
├── Temporary Automation
│   └── %TEMP%\*_*.ps1
│
└── Cleanup
    ├── [0] Keep
    ├── [1] Delete origin / Keep changes
    ├── [2] Delete all
    └── [3] Save to archive / Delete
```

### Supported toolchains

```text
Bun
Git
Go
Linux / WSL
Node.js
Python
Rust
Svelte
W64DevKit
```

---

# 20. License

PEDE is intended to be distributed under a **dual-license** model:

- **MIT License**
- **Apache License 2.0**

See:

- [`LICENSE-MIT.md`](LICENSE-MIT.md)
- [`LICENSE-APACHE-2.0.md`](LICENSE-APACHE-2.0.md)

> **Note:** Replace `[COPYRIGHT HOLDER]` in both license files with the actual copyright holder before public release.

---

# 21. Documentation Scope

This README covers:

- project goals and architecture;
- environment lifecycle;
- supported toolchains;
- directory structure;
- system requirements;
- launch and usage;
- isolated shell behavior;
- manifest tracking;
- cleanup;
- repacking;
- toolchain optimization;
- Git configuration;
- security and temporary files;
- antivirus considerations;
- workflow and operational rules;
- troubleshooting;
- licensing;
- quick reference.

Specific implementation details of individual `.bat` scripts are not invented beyond the documented project specification.

---

# PEDE at a Glance

| Property | PEDE |
|---|---|
| Platform | Windows 10/11 x64 |
| Primary technologies | Batch + PowerShell |
| Packaging | `7z` archives |
| Workspace | `.env` |
| Metadata | `.manifest` |
| Global PATH modification | No |
| Registry modification | No |
| UserProfile pollution | No |
| On-demand extraction | Yes |
| Cleanup modes | 4 |
| WSL support | Yes |
| Supported environments | 9 |

> **PEDE — develop when needed, isolate while working, clean when finished.**

---

# 🇻🇳 Phiên bản tiếng Việt

# PEDE — Portable Ephemeral Development Environments

> **Portable • Isolated • On-Demand • Zero Global Pollution**

**PEDE (Portable Ephemeral Development Environments)** là một hệ thống tự động hóa dựa trên **Windows Batch + PowerShell**, được thiết kế để tạo các môi trường phát triển **di động, cô lập và tạm thời** mà không cần cài đặt runtime, compiler hoặc toolchain trực tiếp vào Windows.

Thay vì cài đặt công cụ toàn hệ thống, mỗi toolchain được đóng gói trong `master.7z`. Khi cần sử dụng, PEDE giải nén vào workspace ẩn `.env`, thiết lập các biến môi trường chỉ trong phiên `cmd.exe` hiện tại, sau đó cung cấp cơ chế cleanup để giữ, loại bỏ hoặc đóng gói lại thay đổi.

---

## ✨ Highlights

- **Zero Global Pollution** — không chủ động thay đổi `PATH` toàn cục, Registry, `AppData` hoặc `USERPROFILE`.
- **On-Demand Extraction** — chỉ giải nén toolchain khi cần.
- **Ephemeral Workspace** — môi trường làm việc nằm trong `.env` và có thể xóa hoàn toàn.
- **Session-Scoped Environment** — các biến như `PATH`, `HOME`, `GOROOT`, `GOPATH`... chỉ được cấu hình cho shell cô lập.
- **Manifest Tracking** — theo dõi file bằng kích thước, `mtime` và MD5 khi cần.
- **Smart Cleanup** — hỗ trợ giữ nguyên, xóa file gốc nhưng giữ thay đổi, xóa toàn bộ hoặc repack thay đổi vào archive.
- **Portable Archives** — toolchain được phân phối dưới dạng archive thay vì cài đặt hệ thống.
- **Cross-Environment Support** — hỗ trợ Bun, Git, Go, WSL/Linux, Node.js, Python, Rust, Svelte và W64DevKit.
- **Lightweight Toolchain Strategy** — đặc biệt với Rust, PEDE có thể lược bỏ các thành phần GNU không cần thiết để giảm dung lượng.

---

## 📌 Project Status

PEDE hiện được tổ chức theo mô hình:

```text
Archive
   │
   ▼
Extract on demand
   │
   ▼
.env workspace
   │
   ▼
Session-scoped environment
   │
   ▼
Isolated development shell
   │
   ▼
User changes
   │
   ▼
Cleanup / Preserve / Repack
```

> README này phản ánh kiến trúc và hành vi được mô tả trong đặc tả PEDE hiện tại; không giả định thêm tính năng ngoài tài liệu nguồn.

---

# 1. Architecture

Mỗi môi trường PEDE tuân theo cùng một lifecycle:

```text
┌──────────────────────────┐
│ Run Launch Script        │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ Check .env               │
└────────────┬─────────────┘
             │
       .env exists?
        ┌────┴────┐
       YES        NO
        │          │
        │          ▼
        │   ┌──────────────────────┐
        │   │ Extract master.7z    │
        │   │ Build .manifest      │
        │   │ Create temp PS1      │
        │   └──────────┬───────────┘
        │              │
        └──────┬───────┘
               ▼
┌──────────────────────────────┐
│ Configure isolated variables │
│ PATH / HOME / GOROOT / ...   │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ Launch isolated CMD shell    │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ Development work             │
│ cargo / go / bun / python... │
└──────────────┬───────────────┘
               │
             exit
               │
               ▼
┌──────────────────────────────┐
│ Cleanup menu                 │
│                              │
│ [0] Keep                     │
│ [1] Delete origin, keep edit │
│ [2] Delete all               │
│ [3] Repack + delete          │
└──────────────────────────────┘
```

PEDE sử dụng manifest để phân biệt file nguyên bản với file mới hoặc đã bị thay đổi. Hệ thống manifest được tạo bằng PowerShell và hỗ trợ đường dẫn dài thông qua tiền tố `\\?\` nhằm tránh giới hạn `MAX_PATH` 260 ký tự.

---

# 2. Supported Environments

| Environment | Entry Script | Main Executable / Target | Isolation |
|---|---|---|---|
| **Bun** | `bun_start.bat` | `.env\bun.exe` | `BUN_INSTALL=.env`, bổ sung `.env` và `.env\bin` vào `PATH` |
| **Git** | `git_start.bat` | `.env\cmd\git.exe` | Cô lập `HOME`, `XDG_CONFIG_HOME`, `.gitconfig` |
| **Go** | `golang_start.bat` | `.env\bin\go.exe` | `GOROOT`, `GOPATH`, `GOCACHE`, tắt telemetry |
| **Linux / WSL** | `linux_start.bat` | WSL distro `LinuxBase` | `wsl --import`, hỗ trợ package overlay |
| **Node.js** | `nodejs_start.bat` | `.env\node.exe` | Cô lập npm prefix, cache và `.npmrc` |
| **Python** | `python_start.bat` | `.env\python.exe` | Python no-GUI, wrapper `pip.bat` / `pip3.bat` |
| **Rust** | `rust_start.bat` | `.env\.cargo\bin\cargo.exe` | Tích hợp W64DevKit MinGW GCC |
| **Svelte** | `svelte_start.bat` | `.env\package.json` | Sử dụng Bun runtime từ môi trường Bun |
| **W64DevKit** | `w64devkit_start.bat` | `.env\bin\gcc.exe` | MinGW-w64 C/C++ độc lập |

Các môi trường và cơ chế cô lập trên được mô tả trực tiếp trong đặc tả PEDE. 

---

# 3. Directory Structure

Cấu trúc chuẩn:

```text
COMPILER/
├── _Bin/
│   ├── bun_start.bat
│   ├── git_start.bat
│   ├── golang_start.bat
│   ├── linux_start.bat
│   ├── nodejs_start.bat
│   ├── python_start.bat
│   ├── rust_start.bat
│   ├── svelte_start.bat
│   └── w64devkit_start.bat
│
├── Bun/
│   ├── master.7z
│   └── bun_start.bat
│
├── Git/
│   ├── master.7z
│   └── git_start.bat
│
├── GoLang/
│   ├── master.7z
│   └── golang_start.bat
│
├── Linux/
│   ├── master.7z
│   ├── pkg.7z
│   └── linux_start.bat
│
├── NodeJS/
│   ├── master.7z
│   └── nodejs_start.bat
│
├── Python/
│   ├── master.7z
│   └── python_start.bat
│
├── Rust/
│   ├── master.7z
│   └── rust_start.bat
│
├── Svelte/
│   ├── master.7z
│   └── svelte_start.bat
│
└── W64DevKit/
    ├── master.7z
    └── w64devkit_start.bat
```

`_Bin\` đóng vai trò là nơi tập trung các shortcut khởi chạy nhanh. Các môi trường phụ thuộc chéo như Rust và Svelte yêu cầu cấu trúc thư mục tương đối đúng để script có thể resolve archive/toolchain liên quan.

---

# 4. Requirements

## 4.1 Operating System

- Windows 10 64-bit
- Windows 11 64-bit

## 4.2 7-Zip

PEDE yêu cầu 7-Zip tại:

```text
C:\Program Files\7-Zip\7z.exe
```

## 4.3 PowerShell

PEDE sử dụng Windows PowerShell có sẵn trên Windows.

Một số script sử dụng:

```powershell
-ExecutionPolicy Bypass
```

## 4.4 WSL

WSL **chỉ bắt buộc đối với môi trường Linux**.

Cần bật:

```text
Windows Subsystem for Linux
```

Các yêu cầu này được nêu trong đặc tả hệ thống.

---

# 5. Installation / Setup

PEDE không hoạt động theo mô hình cài đặt runtime toàn hệ thống.

Thay vào đó:

1. Chuẩn bị thư mục `COMPILER/`.
2. Đặt mỗi `master.7z` vào đúng thư mục môi trường.
3. Đặt script `.bat` tương ứng bên cạnh archive.
4. Có thể đặt shortcut khởi chạy trong `_Bin/`.
5. Với Linux, chuẩn bị WSL và archive `master.7z`; `pkg.7z` là overlay package tùy chọn.

Sau khi cấu trúc hoàn tất, không cần đăng ký compiler/runtime vào `PATH` toàn hệ thống.

---

# 6. Usage

## 6.1 Launch

Chạy script môi trường mong muốn:

```bat
_Bin\linux_start.bat
```

Hoặc:

```bat
Python\python_start.bat
```

Hay:

```bat
git_start.bat
```

Nếu `.env` chưa tồn tại, PEDE sẽ:

```text
master.7z
    │
    ├── Extract
    ▼
.env/
    │
    └── .manifest
```

---

## 6.2 Work Inside the Isolated Shell

Sau khi shell được mở, các lệnh toolchain có thể được sử dụng bình thường:

```bat
python --version
pip --version

go version

cargo --version

bun --version
```

Các biến môi trường được thiết lập cho phiên shell cô lập thay vì cài đặt trực tiếp vào môi trường Windows toàn cục.

---

## 6.3 Exit

Khi hoàn thành:

```bat
exit
```

PEDE sẽ hiển thị cleanup menu:

```text
====================================
 [0] Keep
 [1] Delete origin (keep changes)
 [2] Delete all
 [3] Save to archive + Delete
====================================
Choose (0-3):
```

---

# 7. Cleanup System

## `[0] Keep`

Giữ nguyên `.env`.

Phù hợp khi:

- Bạn sẽ tiếp tục làm việc với cùng toolchain.
- Muốn lần khởi động sau nhanh hơn.
- Không cần giải nén lại archive.

---

## `[1] Delete origin (keep changes)` (Unavailable for Linux at this time)

PEDE so sánh workspace hiện tại với `.manifest`.

Logic:

```text
Original file + unchanged
        ↓
      DELETE

Original file + modified
        ↓
       KEEP

New file
        ↓
       KEEP
```

Việc so sánh dựa trên kích thước, `mtime` và MD5 khi có áp dụng.

Đây là chế độ phù hợp khi muốn loại bỏ phần toolchain nguyên bản nhưng vẫn giữ những gì người dùng đã tạo hoặc chỉnh sửa.

---

## `[2] Delete all`

Xóa toàn bộ:

```text
.env/
```

Mục tiêu:

- giải phóng dung lượng;
- đưa workspace về trạng thái sạch;
- lần chạy sau sẽ extract lại từ `master.7z`.

---

## `[3] Save to archive + Delete`

Luồng hoạt động:

```text
.env
 │
 ├── Remove temporary/cache data
 │
 ├── Pack useful changes
 │
 ▼
master.7z
 │
 └── Delete .env
```

Chế độ này cho phép lưu thay đổi hữu ích trở lại archive trước khi xóa workspace. Đặc tả cũng khuyến nghị sao lưu `master.7z` trước khi sử dụng tùy chọn này.

---

# 8. Manifest System

Manifest là thành phần cốt lõi giúp PEDE thực hiện cleanup thông minh.

Thông tin được theo dõi gồm:

- File size
- Modification time (`mtime`)
- MD5 hash khi cần

Trong quá trình xử lý, PEDE tạo các PowerShell script tạm trong:

```text
%TEMP%
```

Ví dụ:

```text
_m<RANDOM>.ps1
_c<RANDOM>.ps1
```

Các script này phục vụ việc tạo manifest và so sánh trạng thái workspace.

PEDE cũng sử dụng:

```text
\\?\
```

để xử lý đường dẫn dài vượt giới hạn truyền thống của Windows.

---

# 9. Toolchain Optimization

## Rust + W64DevKit

Môi trường Rust sử dụng W64DevKit MinGW GCC làm thành phần hỗ trợ.

## Svelte + Bun

Môi trường Svelte sử dụng Bun làm thành phần hỗ trợ.

**Mục tiêu là giữ môi trường  target nhỏ gọn hơn trong khi vẫn cung cấp toolchain cần thiết.**

---

# 10. Git Configuration

Môi trường Git sử dụng các giá trị identity mẫu:

```bat
git config --global user.name "EXAMPLE_NAME"
git config --global user.email "EXAMPLE_EMAIL@DOMAIN.COM"
```

**Không sử dụng nguyên các giá trị mẫu khi commit repository thật.**

Hãy thay bằng identity Git thực tế trước khi commit.

---

# 11. Security & Cleanup Notice

> [!WARNING]
> PEDE tạo PowerShell script tạm trong `%TEMP%` trong quá trình tạo manifest và cleanup.

Sau khi sử dụng, nên:

- Kiểm tra các script PEDE còn sót trong `%TEMP%`.
- Xóa các script tạm không còn cần thiết.
- Không giữ các entry `PATH` tạm trỏ tới `%TEMP%` hoặc `.env` nếu chúng được thêm thủ công.
- Đảm bảo session cô lập đã kết thúc.

Mục tiêu là giảm file rác và tránh để lại cấu hình môi trường tạm ngoài ý muốn. 

---

# 12. Antivirus / Windows Defender

Do PEDE thực hiện các thao tác như:

- giải nén binary không ký số;
- tạo PowerShell script tạm;
- tạo/xóa file bằng Batch;
- tương tác với `gcc.exe`, `rust-lld.exe` và các linker/toolchain khác;

Windows Defender hoặc antivirus khác **có thể phát hiện nhầm** hành vi của PEDE. 

Nếu một file hợp lệ bị quarantine nhầm, đặc tả hiện tại đề xuất thêm thư mục project vào Windows Defender exclusion list. Tuy nhiên, chỉ nên làm điều này khi đã xác minh nguồn gốc và tính toàn vẹn của project/toolchain.

---

# 13. Recommended Workflow

Một workflow thực tế:

```text
┌─────────────────────────┐
│ 1. Start environment    │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 2. Extract if required  │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 3. Work in isolated CMD │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 4. Save source changes  │
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 5. exit                  │
└────────────┬────────────┘
             ▼
      ┌──────┴──────┐
      │ Cleanup     │
      └──────┬──────┘
             │
      ┌──────┼───────────────┐
      ▼      ▼       ▼       ▼
     [0]    [1]     [2]     [3]
    Keep   Clean   Reset   Repack
```

### Khuyến nghị lựa chọn

| Tình huống | Lựa chọn |
|---|---|
| Tiếp tục dùng ngay toolchain | `[0] Keep` |
| Muốn giữ code/thay đổi nhưng bỏ file gốc | `[1] Delete origin` |
| Muốn giải phóng toàn bộ workspace | `[2] Delete all` |
| Muốn lưu thay đổi vào archive | `[3] Save to archive + Delete` |

---

# 14. Design Philosophy

PEDE được xây dựng quanh 5 nguyên tắc:

### 1. Portable

Toolchain được đóng gói trong archive và có thể tổ chức theo project directory.

### 2. Ephemeral

Môi trường `.env` không phải một installation cố định. Nó có thể được tạo và xóa theo nhu cầu.

### 3. Isolated

Các biến môi trường được cấu hình trong session thay vì phụ thuộc vào cấu hình Windows toàn cục.

### 4. Reproducible

`master.7z` đóng vai trò nguồn toolchain ban đầu, còn `.manifest` cung cấp cơ sở để xác định những gì đã thay đổi.

### 5. Resource-aware

Các toolchain có thể được lược bỏ thành phần không cần thiết để giảm footprint, đặc biệt trong môi trường Rust/W64DevKit.

---

# 15. Troubleshooting

## `.env` không được tạo

Kiểm tra:

```text
master.7z
```

có tồn tại đúng thư mục môi trường hay không.

Ví dụ:

```text
Python/
├── master.7z
└── python_start.bat
```

---

## Không tìm thấy `7z.exe`

Kiểm tra:

```text
C:\Program Files\7-Zip\7z.exe
```

Nếu 7-Zip nằm ở vị trí khác, script hiện tại có thể không hoạt động đúng nếu nó đang hard-code đường dẫn này. Khuyến nghị tải dự án từ mã nguồn mở trên mạng rồi giải nén vào vị trí tương ứng.

---

## Linux environment không chạy

Kiểm tra:

```bat
wsl --status
```

và bảo đảm WSL đã được bật.

Kiểm tra archive:

```text
Linux/
├── master.7z
├── pkg.7z
└── linux_start.bat
```

`pkg.7z` là package overlay tùy chọn (~90% lệnh khi Ubuntu chưa cài gì trên máy Linux); 

`master.7z` là archive distro cơ sở.

---

## Git identity không đúng

Kiểm tra cấu hình:

```bat
git config --global user.name
git config --global user.email
```

Không dùng:

```text
EXAMPLE_NAME
EXAMPLE_EMAIL@DOMAIN.COM
```

cho repository thật.

---

## Workspace chiếm nhiều dung lượng

Có thể chọn:

```text
[2] Delete all
```

để xóa `.env`.

Nếu muốn giữ thay đổi cá nhân nhưng bỏ file gốc:

```text
[1] Delete origin (keep changes)
```

---

# 16. Operational Rules

PEDE nên được vận hành theo các quy tắc sau:

1. Luôn thoát shell bằng:
   ```bat
   exit
   ```
2. Kiểm tra `%TEMP%` định kỳ.
3. Không giữ `PATH` tạm trỏ tới `.env` hoặc `%TEMP%` sau khi session kết thúc.
4. Sao lưu `master.7z` trước khi sử dụng `[3]`.
5. Dùng `[1]` khi cần giữ thay đổi cá nhân.
6. Dùng `[2]` khi cần reset workspace hoàn toàn.
7. Không commit Git với identity mẫu.
8. Chỉ thêm project vào antivirus exclusion sau khi đã xác minh project/toolchain an toàn.

Các nguyên tắc vận hành trên được tổng hợp từ phần khuyến nghị của đặc tả PEDE.

---

# 17. Quick Reference

```text
PEDE
│
├── Archives
│   └── master.7z
│
├── Runtime Workspace
│   └── .env/
│
├── Metadata
│   └── .manifest
│
├── Launcher
│   └── *_start.bat
│
├── Temporary Automation
│   └── %TEMP%\*_*.ps1
│
└── Cleanup
    ├── [0] Keep
    ├── [1] Delete origin / Keep changes
    ├── [2] Delete all
    └── [3] Save to archive / Delete
```

### Supported toolchains

```text
Bun
Git
Go
Linux / WSL
Node.js
Python
Rust
Svelte
W64DevKit
```

---

# 18. License

PEDE được định hướng phát hành theo mô hình **dual license**:

- **MIT License**
- **Apache License 2.0**

Xem:

- [`LICENSE-MIT.md`](LICENSE-MIT.md)
- [`LICENSE-APACHE-2.0.md`](LICENSE-APACHE-2.0.md)

> **Lưu ý:** Hãy thay `[COPYRIGHT HOLDER]` trong hai file license bằng tên cá nhân hoặc tổ chức sở hữu bản quyền trước khi phát hành công khai.

---

# 19. Documentation Scope

README này mô tả:

- mục tiêu và kiến trúc PEDE;
- lifecycle của environment;
- các môi trường được hỗ trợ;
- cấu trúc thư mục;
- yêu cầu hệ thống;
- cách khởi chạy;
- cách sử dụng shell cô lập;
- manifest;
- cleanup;
- repack;
- tối ưu toolchain;
- Git configuration;
- bảo mật và temporary files;
- antivirus considerations;
- workflow vận hành;
- troubleshooting;
- quick reference.

Các chi tiết triển khai cụ thể của từng `.bat` không được suy đoán ngoài nội dung đặc tả hiện có.

---

