#!/bin/bash

# 检查网络连接
function check_network() {
    echo "Checking network connection..."
    if ping -c 1 8.8.8.8 &>/dev/null; then
        echo "Network connection is normal. Installation can proceed."
    else
        echo "Network connection is abnormal. Please check the network settings and run the script again."
        exit 1
    fi
}

# 安装中文字体（以文泉驿微米黑字体为例，可以根据需要替换）
function install_fonts() {
    echo "开始安装中文字体..."
    pacman -Syy
    pacman -S wqy-microhei
    echo "中文字体安装完成。"
}

# 更换软件源为国内镜像
function change_mirror_source() {
    echo "开始更换软件源为国内镜像..."
    # 备份原始的镜像列表文件
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

    # 创建新的镜像列表内容，先添加头部注释
    mirrorlist_content="# 由 insA.sh 在 $(date) 生成\n"

    # 依次添加各个国内镜像源
    mirrorlist_content+="Server = http://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch\n"
    mirrorlist_content+="Server = http://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch\n"
    # ...（根据需要添加其他镜像）

    # 将新的镜像列表内容写入镜像列表文件
    echo -e "$mirrorlist_content" > /etc/pacman.d/mirrorlist
    pacman -Syy
    echo "软件源更换完成。"
}

# 磁盘分区操作（引导用户进入cfdisk进行分区，后续获取分区信息用于后续安装流程）
function disk_partition() {
    echo "即将进入磁盘分区操作，请使用cfdisk工具手动分区。"
    echo "以下是系统识别到的磁盘设备列表："
    lsblk
    read -p "请输入要安装系统的硬盘设备名称（例如 /dev/sda）：" disk_device
    # 简单验证输入格式（这里只是很基础的验证，确保类似 /dev/sd开头，实际可以更严格完善）
    if [[ ! $disk_device =~ ^/dev/sd ]]; then
        echo "输入的硬盘设备名称格式不正确，请重新运行脚本并正确输入。"
        exit 1
    fi
    # 调用cfdisk让用户进行分区操作
    cfdisk $disk_device
    # 获取分区后的磁盘设备根分区和交换分区信息（假设用户按常规分区创建了根分区和交换分区）
    read -p "请输入分区后的根分区设备名称（例如 /dev/sda1）：" root_partition
    read -p "请输入分区后的交换分区设备名称（例如 /dev/sda2）：" swap_partition
    echo "磁盘分区操作完成，以下是您输入的分区信息："
    echo "根分区设备：$root_partition"
    echo "交换分区设备：$swap_partition"
    # 将分区信息传递回主函数，后续用于安装流程
    echo $root_partition > /tmp/root_partition.txt
    echo $swap_partition > /tmp/swap_partition.txt
}

function install_archlinux() {
    echo "开始Arch Linux安装流程，请谨慎操作，可能导致数据丢失"
    # 获取之前记录的分区信息
    root_partition=$(cat /tmp/root_partition.txt)
    swap_partition=$(cat /tmp/swap_partition.txt)

    # 格式化分区
    echo "正在格式化根分区..."
    mkfs.ext4 $root_partition
    echo "正在格式化交换分区..."
    mkswap $swap_partition
    echo "正在启用交换分区..."
    swapon $swap_partition

    # 挂载分区
    echo "正在挂载根分区到 /mnt..."
    mount $root_partition /mnt

    # 安装Arch Linux基础系统（使用pacstrap工具简单示意）
    echo "正在安装Arch Linux基础系统..."
    pacstrap /mnt base base-devel linux linux-firmware

    # 生成fstab文件
    echo "正在生成fstab文件..."
    genfstab -U /mnt >> /mnt/etc/fstab

    # 切换到新安装的系统环境（chroot操作）
    echo "正在切换到新安装的系统环境进行配置..."
    arch-chroot /mnt /bin/bash

    # 设置时区（示例选上海时区，可按需换）
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    hwclock --systohc

    # 本地化设置（编辑locale.gen文件并生成locale信息）
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    # 设置主机名（示例主机名为archlinux,可按需换）
    echo "archlinux" > /etc/hostname

    # 设置根用户密码（会提示输入密码两次进行确认）
    echo "请输入root用户密码，输入后会提示再次输入进行确认"
    passwd

    # 安装引导程序（以GRUB为例，不同硬件平台需相应调整）
    pacman -S grub
    grub-install --target=i386-pc $(echo $root_partition | sed 's/[0-9]*$//')
    # 根据硬件改引导程序安装目标参数
    grub-mkconfig -o /boot/grub/grub.cfg

    # 安装GNOME桌面环境和显示管理器
    echo "正在安装GNOME桌面环境和显示管理器..."
    pacman -S gnome gdm
    systemctl enable gdm.service

    # 创建普通用户（示例用户名为arch）
    echo "正在创建普通用户arch..."
    useradd -m -G wheel arch
    # 设置普通用户密码（会提示输入密码两次进行确认）
    echo "请为普通用户arch输入密码，输入后会提示再次输入进行确认。"
    passwd arch

    # 退出chroot环境
    exit

    # 卸载挂载的分区
    umount -R /mnt

    echo "Arch Linux安装完成，可重启电脑进入新系统"
}

# 主函数，按顺序调用各功能函数
main() {
    check_network
    install_fonts
    change_mirror_source
    disk_partition
    install_archlinux
}

main
