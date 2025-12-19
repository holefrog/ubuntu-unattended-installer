![Logo](logo.png)
# Ubuntu Autoinstall Maker

[![Ubuntu Version](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu)](https://ubuntu.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash)](auto-install.sh)

Automated Ubuntu 24.04 Desktop installation tool with USB creation and VM testing support.

[English](#english) | [中文](#中文)

---

## English

### 📋 Overview

A complete solution for automating Ubuntu 24.04 Desktop installation with zero user interaction. Create bootable USB drives or test installations in virtual machines using cloud-init configuration.

### ✨ Features

- **Zero-Touch Installation**: Fully automated with no manual intervention required
- **Dual Mode Support**: 
  - Physical USB installation with Wi-Fi support
  - Virtual machine testing with KVM/QEMU
- **Smart Network Configuration**: Auto-detects wired adapters (eth0/ens33/enp3s0), supports Wi-Fi pre-configuration
- **Minimal System**: Only essential kernel packages installed
- **Custom Optimizations**:
  - Removes Snap package manager
  - Configures passwordless sudo
  - Pre-configures Bash aliases (ll, uu, etc.)
  - Auto-creates common directories (Programs, Downloads, Temp)

### 🚀 Quick Start

#### Prerequisites

The script auto-detects and installs required dependencies:
- `xorriso` - ISO image processing
- `cloud-image-utils` - Cloud-init utilities
- `virt-install` - Virtual machine management
- `dosfstools` - FAT32 filesystem tools

#### Initial Setup

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/ubuntu-autoinstall-maker.git
cd ubuntu-autoinstall-maker
```

2. **Download Ubuntu 24.04 ISO**
```bash
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso
```

3. **Create configuration files from samples**
```bash
cp user-data.sample user-data
cp network-config.sample network-config
```

4. **Customize your settings** (see [Configuration](#configuration))

#### Usage

**Option 1: Create USB Installer**
```bash
chmod +x auto-install.sh
sudo ./auto-install.sh
# Select option 1
```

**Option 2: Test in Virtual Machine** (Recommended first)
```bash
sudo ./auto-install.sh
# Select option 2
```

Monitor VM installation:
```bash
virsh list --all
virt-viewer ubuntu-autoinstall-XXXXXX
```

### ⚙️ Configuration

#### Generate Encrypted Password

```bash
# Using mkpasswd (recommended)
mkpasswd -m sha-512 your_password

# Or using openssl
openssl passwd -6 your_password
```

#### Edit `user-data`

```yaml
identity:
  hostname: your-hostname          # Set your hostname
  username: your-username          # Set your username
  password: "$6$..."               # Paste encrypted password

locale: en_US.UTF-8                # Language setting
timezone: America/Vancouver        # Your timezone

packages:                          # Additional packages
  - git
  - curl
  - vim
```

#### Edit `network-config` (for Wi-Fi)

```yaml
wifis:
  wlan0:
    access-points:
      "YourWiFiName":               # Your Wi-Fi SSID
        password: "YourPassword"    # Your Wi-Fi password
```

### 📁 Project Structure

```
ubuntu-autoinstall-maker/
├── auto-install.sh           # Main control script
├── user-data.sample          # Sample autoinstall configuration
├── network-config.sample     # Sample network configuration
├── meta-data                 # Instance metadata
├── README.md                 # This file
└── ubuntu-*.iso              # Ubuntu ISO (download separately)
```

### ⚠️ Important Notes

#### 1. Virtual Machine Firmware Settings

When manually creating VMs in Virtual Machine Manager (virt-manager):

1. At the final step, **check** `Customize configuration before install`
2. Select **Overview** in the left panel
3. Under **Firmware**, choose:
   ```
   UEFI x86_64: /usr/share/OVMF/OVMF_CODE_4M.fd
   ```
4. **Avoid** firmware versions containing `secboot` or `ms`
5. Click **Apply**, then **Begin Installation**

**Reason**: Secure Boot may cause autoinstall failures.

#### 2. Network Configuration Differences

**Virtual Machines**:
- No Wi-Fi adapters available
- Network interfaces typically named `ens3`, `ens4`, etc.
- Default `user-data` auto-matches any interface starting with `e`

**Physical USB Installation**:
- Wi-Fi configuration fully supported
- Script automatically deploys Wi-Fi settings from `network-config`
- Can use both wired and wireless simultaneously

### 🔍 Troubleshooting

**VM Won't Start**
```bash
# Check KVM support
egrep -c '(vmx|svm)' /proc/cpuinfo  # Should be > 0

# Check virtualization service
sudo systemctl status libvirtd
```

**USB Boot Failure**
1. Enable UEFI boot in BIOS/UEFI
2. Disable Secure Boot if necessary
3. Set USB device as first boot priority

**Network Config Not Applied**
- Use 2-space indentation (not tabs)
- YAML syntax requires space after colons
- Quote Wi-Fi passwords

### 📋 System Requirements

**Target Machine**:
- Minimum: 2GB RAM, 15GB disk
- Recommended: 4GB RAM, 25GB disk
- Network: Wired or supported wireless adapter

**Build Environment**:
- Ubuntu/Debian system
- Root privileges
- 8GB+ USB device (for USB creation)

### 🛡️ Security Recommendations

1. Use strong passwords and secure encrypted credentials
2. Always test in VM before physical deployment
3. Backup data - USB/installation will erase target device
4. Review security settings in `user-data` before deployment

### 📚 Resources

- [Ubuntu Autoinstall Documentation](https://ubuntu.com/server/docs/install/autoinstall)
- [Cloud-init Reference](https://cloudinit.readthedocs.io/)
- [Netplan Configuration](https://netplan.io/reference/)

### 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 中文

### 📋 概述

Ubuntu 24.04 桌面版无人值守安装完整解决方案，支持 USB 安装盘制作和虚拟机测试。

### ✨ 功能特性

- **零交互安装**：完全自动化，无需手动干预
- **双模式支持**：
  - USB 物理安装（支持 Wi-Fi）
  - 虚拟机测试（KVM/QEMU）
- **智能网络配置**：自动适配有线网卡（eth0/ens33/enp3s0 等），支持 Wi-Fi 预配置
- **最小化系统**：只安装最基本的内核
- **自定义优化**：
  - 移除 Snap 软件包管理器
  - 配置 sudo 免密码
  - 预设 Bash 别名（ll、uu 等）
  - 自动创建常用目录（Programs、Downloads、Temp）

### 🚀 快速开始

#### 前置要求

脚本会自动检测并安装所需依赖：
- `xorriso` - ISO 镜像处理
- `cloud-image-utils` - Cloud-init 工具
- `virt-install` - 虚拟机管理
- `dosfstools` - FAT32 文件系统工具

#### 初始设置

1. **克隆仓库**
```bash
git clone https://github.com/yourusername/ubuntu-autoinstall-maker.git
cd ubuntu-autoinstall-maker
```

2. **下载 Ubuntu 24.04 ISO**
```bash
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso
```

3. **从示例文件创建配置**
```bash
cp user-data.sample user-data
cp network-config.sample network-config
```

4. **自定义配置**（参见[配置说明](#配置说明)）

#### 使用方法

**方式 1：制作 USB 安装盘**
```bash
chmod +x auto-install.sh
sudo ./auto-install.sh
# 选择选项 1
```

**方式 2：虚拟机测试**（推荐先测试）
```bash
sudo ./auto-install.sh
# 选择选项 2
```

监控虚拟机安装：
```bash
virsh list --all
virt-viewer ubuntu-autoinstall-XXXXXX
```

### ⚙️ 配置说明

#### 生成加密密码

```bash
# 使用 mkpasswd（推荐）
mkpasswd -m sha-512 your_password

# 或使用 openssl
openssl passwd -6 your_password
```

#### 编辑 `user-data`

```yaml
identity:
  hostname: your-hostname          # 设置主机名
  username: your-username          # 设置用户名
  password: "$6$..."               # 粘贴加密密码

locale: en_US.UTF-8                # 语言设置
timezone: America/Vancouver        # 时区设置

packages:                          # 额外安装的软件包
  - git
  - curl
  - vim
```

#### 编辑 `network-config`（Wi-Fi 配置）

```yaml
wifis:
  wlan0:
    access-points:
      "你的WiFi名称":                # Wi-Fi SSID
        password: "你的WiFi密码"     # Wi-Fi 密码
```

### 📁 项目结构

```
ubuntu-autoinstall-maker/
├── auto-install.sh           # 主控脚本
├── user-data.sample          # 自动安装配置示例
├── network-config.sample     # 网络配置示例
├── meta-data                 # 实例元数据
├── README.md                 # 本文件
└── ubuntu-*.iso              # Ubuntu ISO（需单独下载）
```

### ⚠️ 重要注意事项

#### 1. 虚拟机固件设置

使用 Virtual Machine Manager (virt-manager) 手动创建虚拟机时：

1. 在最后一步，**勾选** `Customize configuration before install`
2. 在左侧面板选择 **Overview**
3. 在 **Firmware** 下拉菜单中选择：
   ```
   UEFI x86_64: /usr/share/OVMF/OVMF_CODE_4M.fd
   ```
4. **不要选择**包含 `secboot` 或 `ms` 字样的固件版本
5. 点击 **Apply**，然后点击 **Begin Installation**

**原因**：安全启动（Secure Boot）可能导致无人值守安装失败。

#### 2. 网络配置差异

**虚拟机环境**：
- 没有 Wi-Fi 网卡
- 网卡名称通常为 `ens3`、`ens4` 等
- 默认 `user-data` 已针对虚拟机优化（自动匹配以 `e` 开头的网卡）

**物理机 USB 安装**：
- 支持 Wi-Fi 网卡配置
- 脚本自动将 `network-config` 中的 Wi-Fi 配置部署到安装盘
- 可同时使用有线和无线网络

### 🔍 故障排查

**虚拟机无法启动**
```bash
# 检查 KVM 支持
egrep -c '(vmx|svm)' /proc/cpuinfo  # 应大于 0

# 检查虚拟化服务
sudo systemctl status libvirtd
```

**USB 启动失败**
1. 在 BIOS/UEFI 中启用 UEFI 启动
2. 必要时禁用 Secure Boot
3. 将 USB 设备设为第一启动项

**网络配置未生效**
- 使用 2 空格缩进（不是 Tab）
- YAML 语法：冒号后必须有空格
- Wi-Fi 密码需用引号包裹

### 📋 系统要求

**目标机器**：
- 最低：2GB RAM、15GB 硬盘
- 推荐：4GB RAM、25GB 硬盘
- 网络：有线网卡或支持的无线网卡

**制作环境**：
- Ubuntu/Debian 系统
- Root 权限
- 8GB+ USB 设备（制作安装盘时）

### 🛡️ 安全建议

1. 使用强密码并妥善保管加密密文
2. 实际部署前务必在虚拟机中测试
3. 备份数据 - USB 制作和安装会清空目标设备
4. 根据实际需求审查 `user-data` 中的安全设置

### 📚 扩展资源

- [Ubuntu Autoinstall 官方文档](https://ubuntu.com/server/docs/install/autoinstall)
- [Cloud-init 配置参考](https://cloudinit.readthedocs.io/)
- [Netplan 网络配置](https://netplan.io/reference/)

### 📄 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

---

**提示**：首次使用建议先在虚拟机中测试完整流程，确认配置正确后再制作物理 USB 安装盘。
