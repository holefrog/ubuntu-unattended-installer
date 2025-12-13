#!/bin/bash
# ==============================================================================
# Ubuntu 24.04 Server Autoinstall USB Maker
# 专门优化：Server 版本的无人值守安装
# ==============================================================================

set -e

# 颜色定义
RED='\033[38;5;196m'
GREEN='\033[38;5;46m'
YELLOW='\033[38;5;226m'
BLUE='\033[38;5;21m'
CYAN='\033[38;5;51m'
NC='\033[0m'

# 路径定义
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_DATA_FILE="$BASE_DIR/user-data"
META_DATA_FILE="$BASE_DIR/meta-data"

# 辅助函数
log() { echo -e "${BLUE}==> $1${NC}"; }
ok() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}! $1${NC}"; }
err() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${CYAN}  $1${NC}"; }

# ==============================================================================
# 显示帮助信息
# ==============================================================================
show_help() {
    cat << EOF
Ubuntu Server 24.04 Autoinstall USB Maker

用法: sudo $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -d, --device DEV    指定 USB 设备 (如 sdc)
  -y, --yes           跳过确认提示
  --check-only        仅检查配置文件，不制作 USB

示例:
  sudo $0                    # 交互式制作 USB
  sudo $0 -d sdc -y          # 自动制作到 /dev/sdc
  sudo $0 --check-only       # 只检查配置文件

EOF
}

# ==============================================================================
# 检查依赖
# ==============================================================================
check_dependencies() {
    log "检查依赖工具..."
    
    local missing=()
    command -v xorriso &>/dev/null || missing+=("xorriso")
    command -v mkfs.vfat &>/dev/null || missing+=("dosfstools")
    command -v sgdisk &>/dev/null || missing+=("gdisk")
    command -v rsync &>/dev/null || missing+=("rsync")
    command -v python3 &>/dev/null || missing+=("python3")
    
    if [ ${#missing[@]} -gt 0 ]; then
        warn "缺少工具: ${missing[*]}"
        log "正在安装依赖..."
        sudo apt update -qq || err "apt update 失败"
        sudo apt install -y xorriso dosfstools gdisk rsync python3 python3-yaml || err "依赖安装失败"
    fi
    
    ok "依赖检查完成"
}

# ==============================================================================
# 验证配置文件
# ==============================================================================
validate_config() {
    log "验证配置文件..."
    
    local has_error=0
    
    # 检查文件存在性
    if [ ! -f "$USER_DATA_FILE" ]; then
        err "缺少 user-data 文件"
    fi
    
    if [ ! -f "$META_DATA_FILE" ]; then
        warn "缺少 meta-data 文件，将自动创建"
        cat > "$META_DATA_FILE" << EOF
instance-id: ubuntu-autoinstall-$(date +%s)
local-hostname: ubuntu-server
EOF
    fi
    
    # YAML 语法检查
    info "检查 user-data YAML 语法..."
    if command -v python3 &>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$USER_DATA_FILE'))" 2>/dev/null; then
            ok "user-data 语法正确"
        else
            warn "user-data 可能有 YAML 语法错误"
            python3 -c "import yaml; yaml.safe_load(open('$USER_DATA_FILE'))" 2>&1 || true
            has_error=1
        fi
    fi
    
    # 检查必要字段
    info "检查必要配置项..."
    
    if ! grep -q "autoinstall:" "$USER_DATA_FILE"; then
        warn "缺少 autoinstall: 部分"
        has_error=1
    fi
    
    if grep -q "YOUR_\|CHANGE_THIS\|REPLACE_ME" "$USER_DATA_FILE"; then
        warn "发现占位符文本，请修改配置:"
        grep --color=always "YOUR_\|CHANGE_THIS\|REPLACE_ME" "$USER_DATA_FILE" || true
        has_error=1
    fi
    
    # 检查密码加密
    if grep -q 'password:.*"\$6\$' "$USER_DATA_FILE"; then
        ok "密码已加密"
    elif grep -q 'password:.*"\$[0-9]\$' "$USER_DATA_FILE"; then
        ok "密码已加密（非 SHA-512）"
    else
        warn "密码可能未加密，建议使用: mkpasswd -m sha-512 your_password"
        has_error=1
    fi
    
    # 检查主机名和用户名
    if grep -q "hostname:" "$USER_DATA_FILE"; then
        local hostname=$(grep "hostname:" "$USER_DATA_FILE" | head -1 | awk '{print $2}')
        info "主机名: $hostname"
    fi
    
    if grep -q "username:" "$USER_DATA_FILE"; then
        local username=$(grep "username:" "$USER_DATA_FILE" | head -1 | awk '{print $2}')
        info "用户名: $username"
    fi
    
    if [ $has_error -eq 1 ]; then
        echo
        warn "配置文件存在问题，建议修复后再制作 USB"
        read -p "是否继续? (y/N): " continue_anyway
        [[ ! "$continue_anyway" =~ ^[Yy]$ ]] && exit 1
    else
        ok "配置文件验证通过"
    fi
}

# ==============================================================================
# 查找 ISO 文件
# ==============================================================================
find_iso() {
    log "查找 Ubuntu Server ISO..."
    
    shopt -s nullglob
    local isos=("$BASE_DIR"/ubuntu-*-live-server-*.iso)
    
    if [ ${#isos[@]} -eq 0 ]; then
        # 也尝试查找 desktop 版本
        isos=("$BASE_DIR"/ubuntu-*.iso)
        if [ ${#isos[@]} -eq 0 ]; then
            err "找不到 Ubuntu ISO 文件
请下载 Server 版本:
  wget https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"
        else
            warn "找到的是 Desktop ISO，建议使用 Server ISO"
            UBUNTU_ISO="${isos[0]}"
        fi
    else
        UBUNTU_ISO="${isos[0]}"
        ok "找到 Server ISO: $(basename "$UBUNTU_ISO")"
    fi
    
    # 检查 ISO 大小
    local iso_size=$(stat -f%z "$UBUNTU_ISO" 2>/dev/null || stat -c%s "$UBUNTU_ISO" 2>/dev/null)
    local iso_size_mb=$((iso_size / 1024 / 1024))
    info "ISO 大小: ${iso_size_mb}MB"
    
    if [ $iso_size_mb -gt 4000 ]; then
        warn "ISO 超过 4GB，如果使用 FAT32 可能会有问题"
    fi
}

# ==============================================================================
# 选择 USB 设备
# ==============================================================================
select_device() {
    if [ -n "$USB_DEVICE" ]; then
        DEV_PATH="/dev/$USB_DEVICE"
        return
    fi
    
    log "扫描可用的存储设备..."
    echo
    lsblk -o NAME,SIZE,TYPE,VENDOR,MODEL,MOUNTPOINT | grep -E "disk|NAME" || true
    echo
    
    read -p "请输入 USB 设备名称 (如 sdc，不带 /dev/): " usb_input
    [ -z "$usb_input" ] && err "未输入设备名称"
    
    USB_DEVICE="$usb_input"
    DEV_PATH="/dev/$USB_DEVICE"
}

# ==============================================================================
# 验证设备安全性
# ==============================================================================
validate_device() {
    log "验证设备 $DEV_PATH..."
    
    # 检查设备存在
    [ ! -b "$DEV_PATH" ] && err "设备不存在: $DEV_PATH"
    
    # 检查是否是系统盘
    if lsblk "$DEV_PATH" -no MOUNTPOINT | grep -qE "^/$|^/boot$|^/home$"; then
        err "危险！不能选择系统盘: $DEV_PATH"
    fi
    
    # 检查设备大小
    local dev_size=$(lsblk "$DEV_PATH" -no SIZE -b | head -1)
    local dev_size_gb=$((dev_size / 1024 / 1024 / 1024))
    
    if [ $dev_size_gb -lt 4 ]; then
        err "设备容量太小 (${dev_size_gb}GB)，需要至少 4GB"
    elif [ $dev_size_gb -lt 8 ]; then
        warn "设备容量较小 (${dev_size_gb}GB)，建议使用 8GB 以上"
    else
        info "设备容量: ${dev_size_gb}GB"
    fi
    
    ok "设备验证通过"
}

# ==============================================================================
# 确认操作
# ==============================================================================
confirm_operation() {
    if [ "$AUTO_YES" = "true" ]; then
        return
    fi
    
    echo
    warn "=========================================="
    warn "  警告: 即将格式化以下设备"
    warn "=========================================="
    lsblk "$DEV_PATH" -o NAME,SIZE,TYPE,VENDOR,MODEL,MOUNTPOINT
    echo
    warn "所有数据将被清空！"
    echo
    
    read -p "确认请输入 YES (大写): " confirm
    if [ "$confirm" != "YES" ]; then
        log "操作已取消"
        exit 0
    fi
}

# ==============================================================================
# 制作 USB
# ==============================================================================
create_usb() {
    log "开始制作 USB 安装盘..."
    
    # 卸载所有分区
    log "卸载现有分区..."
    for part in $(lsblk "$DEV_PATH" -no PATH | grep -v "^$DEV_PATH$"); do
        sudo umount "$part" 2>/dev/null || true
    done
    
    # 清空分区表
    log "清空分区表..."
    sudo sgdisk --zap-all "$DEV_PATH" >/dev/null 2>&1 || true
    sudo dd if=/dev/zero of="$DEV_PATH" bs=1M count=10 >/dev/null 2>&1 || true
    
    # 创建新分区
    log "创建 GPT 分区表..."
    sudo sgdisk --new=1:0:0 --typecode=1:ef00 --change-name=1:"UBUNTU_SRV" "$DEV_PATH" || err "创建分区失败"
    
    # 等待设备更新
    sleep 2
    sudo partprobe "$DEV_PATH" 2>/dev/null || true
    sleep 1
    
    # 确定分区路径
    local part_path="${DEV_PATH}1"
    [ ! -b "$part_path" ] && part_path="${DEV_PATH}p1"
    [ ! -b "$part_path" ] && err "找不到分区: ${DEV_PATH}1 或 ${DEV_PATH}p1"
    
    # 格式化
    log "格式化为 FAT32..."
    sudo mkfs.vfat -F 32 -n "UBUNTU_SRV" "$part_path" >/dev/null || err "格式化失败"
    
    # 挂载
    local usb_mnt=$(mktemp -d)
    local iso_mnt=$(mktemp -d)
    
    log "挂载分区..."
    sudo mount "$part_path" "$usb_mnt" || err "挂载 USB 失败"
    sudo mount -o loop,ro "$UBUNTU_ISO" "$iso_mnt" || err "挂载 ISO 失败"
    
    # 复制文件
    log "复制 ISO 内容 (需要几分钟，请耐心等待)..."
    
    # Server ISO 通常没有循环符号链接问题，但为了安全还是排除
    sudo rsync -aL --info=progress2 \
        --exclude="ubuntu" \
        --exclude="md5sum.txt" \
        --exclude="README.diskdefines" \
        --exclude=".disk/info" \
        "$iso_mnt/" "$usb_mnt/" || {
            # 检查关键文件
            if [ -f "$usb_mnt/casper/vmlinuz" ]; then
                warn "部分文件复制失败，但关键文件存在"
            else
                sudo umount "$usb_mnt" "$iso_mnt" 2>/dev/null || true
                err "复制失败"
            fi
        }
    
    ok "ISO 内容复制完成"
    
    # 部署 autoinstall 配置
    log "部署 autoinstall 配置..."
    
    # Server 版本：直接放在根目录，使用 autoinstall 作为前缀
    sudo cp "$USER_DATA_FILE" "$usb_mnt/user-data"
    sudo cp "$META_DATA_FILE" "$usb_mnt/meta-data"
    
    # 设置权限
    sudo chmod 644 "$usb_mnt/user-data"
    sudo chmod 644 "$usb_mnt/meta-data"
    
    ok "配置文件部署完成"
    
    # 修改 GRUB（Server 版本的 GRUB 配置）
    log "配置 GRUB 引导菜单..."
    
    local grub_cfg="$usb_mnt/boot/grub/grub.cfg"
    
    if [ -f "$grub_cfg" ]; then
        sudo cp "$grub_cfg" "$grub_cfg.backup"
    fi
    
    # Server 版本的 GRUB 配置更简单
    cat <<'GRUBEOF' | sudo tee "$grub_cfg" >/dev/null
set timeout=30
set default=0

# 强制显示菜单
set timeout_style=menu

# 加载字体和图形模式
if loadfont /boot/grub/font.pf2 ; then
    set gfxmode=auto
    insmod efi_gop
    insmod efi_uga
    insmod video_bochs
    insmod video_cirrus
    insmod all_video
    insmod gfxterm
    terminal_output gfxterm
fi

set menu_color_normal=cyan/blue
set menu_color_highlight=white/blue

menuentry 'Autoinstall Ubuntu Server 24.04' --class ubuntu {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/ quiet splash ---
    initrd  /casper/initrd
}

menuentry 'Autoinstall Ubuntu Server (Debug - Show Details)' --class ubuntu {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/ ---
    initrd  /casper/initrd
}

menuentry 'Autoinstall Ubuntu Server (Safe Graphics)' --class ubuntu {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/ nomodeset ---
    initrd  /casper/initrd
}

menuentry 'Try or Install Ubuntu Server (Manual)' --class ubuntu {
    set gfxpayload=keep
    linux   /casper/vmlinuz ---
    initrd  /casper/initrd
}

menuentry 'Test memory' {
    linux /boot/memtest86+.bin
}
GRUBEOF
    
    ok "GRUB 配置完成"
    
    # 同步并卸载
    log "同步数据到 USB（请勿拔出）..."
    sync
    sync
    
    sudo umount "$usb_mnt"
    sudo umount "$iso_mnt"
    rmdir "$usb_mnt" "$iso_mnt"
    
    ok "USB 制作完成！"
}

# ==============================================================================
# 显示使用说明
# ==============================================================================
show_instructions() {
    echo
    ok "==========================================="
    ok "  USB 安装盘制作成功！"
    ok "==========================================="
    echo
    log "使用步骤："
    info "1. 插入 USB 到目标机器"
    info "2. 进入 BIOS/UEFI 设置"
    info "3. 设置 USB 为第一启动项"
    info "4. 保存并重启"
    echo
    log "GRUB 菜单选项："
    info "• Autoinstall - 无人值守安装（推荐）"
    info "• Autoinstall (verbose) - 显示详细日志"
    info "• Manual Install - 手动安装"
    echo
    warn "重要提示："
    info "• 安装过程约 10-20 分钟"
    info "• 安装完成后会自动重启"
    info "• 首次登录使用 user-data 中配置的用户名和密码"
    echo
    log "如果安装失败："
    info "• 选择 verbose 模式查看详细日志"
    info "• 检查 user-data 配置"
    info "• 确保目标机器网络连接正常（如需下载软件包）"
    echo
}

# ==============================================================================
# 主流程
# ==============================================================================

# 参数解析
USB_DEVICE=""
AUTO_YES="false"
CHECK_ONLY="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--device)
            USB_DEVICE="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_YES="true"
            shift
            ;;
        --check-only)
            CHECK_ONLY="true"
            shift
            ;;
        *)
            err "未知参数: $1
使用 -h 查看帮助"
            ;;
    esac
done

# 显示标题
echo "=============================================="
echo "  Ubuntu Server 24.04 Autoinstall USB Maker"
echo "=============================================="
echo

# 检查 root 权限
if [ "$EUID" -ne 0 ] && [ "$CHECK_ONLY" != "true" ]; then
    err "请使用 sudo 运行此脚本"
fi

# 执行流程
check_dependencies
validate_config
find_iso

if [ "$CHECK_ONLY" = "true" ]; then
    ok "配置检查完成，未制作 USB"
    exit 0
fi

select_device
validate_device
confirm_operation
create_usb
show_instructions

echo
ok "全部完成！"
