#!/bin/sh

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# GitHub 仓库信息
REPO_OWNER="xuanranran"
REPO_NAME="openwrt-netdata"

# GitHub 访问方式配置(将在用户选择后设置)
GITHUB_API=""
GITHUB_RELEASE=""
GITHUB_RAW=""

# 临时下载目录
TMP_DIR="/tmp/netdata_install"

# 是否使用 prerelease 版本
USE_PRERELEASE=false

# 打印信息函数
print_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1" >&2
}

print_warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

# 选择 GitHub 访问方式
select_github_mirror() {
    print_info "=========================================="
    print_info "选择 GitHub 访问方式"
    print_info "=========================================="
    echo ""
    printf "${CYAN}请选择访问方式:${NC}\n" >&2
    echo ""
    echo "  1) gh-proxy.com (镜像加速 - 推荐)"
    echo "  2) GitHub 官方 (直连)"
    echo ""
    printf "请输入选项 [1-2] (默认: 1): " >&2

    read choice < /dev/tty

    if [ -z "$choice" ]; then
        choice="1"
    fi

    echo ""

    case "$choice" in
        1)
            print_info "使用 gh-proxy.com 镜像加速"
            GITHUB_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
            GITHUB_RELEASE="https://gh-proxy.com/https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download"
            GITHUB_RAW="https://gh-proxy.com/https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}"
            ;;
        2)
            print_info "使用 GitHub 官方直连"
            GITHUB_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
            GITHUB_RELEASE="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download"
            GITHUB_RAW="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}"
            ;;
        *)
            print_warn "无效选项，使用默认方式: gh-proxy.com 镜像加速"
            GITHUB_API="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
            GITHUB_RELEASE="https://gh-proxy.com/https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download"
            GITHUB_RAW="https://gh-proxy.com/https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}"
            ;;
    esac

    echo ""
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        print_error "未找到命令: $1"
        return 1
    fi
    return 0
}

# 检测包管理器类型
detect_package_manager() {
    if command -v apk >/dev/null 2>&1; then
        echo "apk"
    elif command -v opkg >/dev/null 2>&1; then
        echo "opkg"
    else
        echo ""
    fi
}

# 检查必要的命令
check_requirements() {
    print_info "检查系统环境..."

    # 检测包管理器
    PKG_MANAGER=$(detect_package_manager)

    if [ -z "$PKG_MANAGER" ]; then
        print_error "未找到包管理器 (apk 或 opkg)"
        print_error "请确认您的系统是 OpenWrt"
        exit 1
    fi

    print_info "检测到包管理器: $PKG_MANAGER"

    if [ "$PKG_MANAGER" != "apk" ]; then
        print_error "预编译包仅支持 OpenWrt SNAPSHOT 的 apk 包管理器"
        print_error "当前系统使用 opkg，请自行源码编译或切换到 SNAPSHOT"
        exit 1
    fi

    # 检查 curl
    if ! check_command curl; then
        print_error "未找到命令: curl"
        print_error "请先安装 curl"
        exit 1
    fi

    # 检查 tar
    if ! check_command tar; then
        print_error "未找到命令: tar"
        print_error "请先安装 tar"
        exit 1
    fi

    print_info "系统环境检查通过"
}

# 检查是否已安装
check_installed() {
    print_info "检查安装状态..."

    local installed_version=""

    if [ "$PKG_MANAGER" = "apk" ]; then
        if apk info -e netdata >/dev/null 2>&1; then
            installed_version=$(apk list --installed 2>/dev/null | grep "^netdata-[0-9]" | head -n 1 | sed 's/netdata-\([^ ]*\).*/\1/')
        fi
    else
        if opkg list-installed | grep -q "^netdata "; then
            installed_version=$(opkg list-installed netdata | awk '{print $3}')
        fi
    fi

    if [ -n "$installed_version" ]; then
        print_warn "检测到已安装 netdata 版本: $installed_version"
        print_warn "本脚本将进行更新操作"
        echo ""
        printf "${YELLOW}是否继续? [Y/n]: ${NC}" >&2
        read confirm < /dev/tty

        if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
            print_info "已取消操作"
            exit 0
        fi

        echo ""
        return 0
    else
        print_info "未检测到已安装的 netdata"
        return 0
    fi
}

package_name_from_file() {
    local file="$1"
    local base="${file##*/}"

    case "$base" in
        *.ipk)
            base="${base%.ipk}"
            echo "${base%%_*}"
            ;;
        *.apk)
            base="${base%.apk}"
            echo "$base" | sed -E 's/-[0-9][^-]*-r[0-9].*$//'
            ;;
        *)
            echo "$base"
            ;;
    esac
}

is_force_package() {
    local pkg="$1"

    case "$pkg" in
        protobuf|protobuf-lite|*netdata*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_blocked_package() {
    local pkg="$1"

    case "$pkg" in
        libopenssl-padlock)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_package_installed() {
    local pkg="$1"

    if [ "$PKG_MANAGER" = "apk" ]; then
        apk info -e "$pkg" >/dev/null 2>&1
    else
        opkg list-installed "$pkg" 2>/dev/null | grep -q "^${pkg} -"
    fi
}

select_install_files() {
    local pattern="$1"
    local file pkg selected skipped forced blocked

    selected=""
    skipped=""
    forced=""
    blocked=""

    for file in $(find . -maxdepth 1 -type f -name "$pattern" | sort); do
        pkg=$(package_name_from_file "$file")

        if is_blocked_package "$pkg"; then
            blocked="${blocked}${pkg}
"
        elif is_force_package "$pkg"; then
            selected="${selected}${file}
"
            forced="${forced}${pkg}
"
        elif is_package_installed "$pkg"; then
            skipped="${skipped}${pkg}
"
        else
            selected="${selected}${file}
"
        fi
    done

    if [ -n "$blocked" ]; then
        print_warn "以下可选软件包将跳过:"
        printf "%s" "$blocked" | sed '/^$/d; s/^/  - /' >&2
    fi

    if [ -n "$skipped" ]; then
        print_info "以下已安装依赖将跳过:"
        printf "%s" "$skipped" | sed '/^$/d; s/^/  - /' >&2
    fi

    if [ -n "$forced" ]; then
        print_info "以下关键软件包将强制安装:"
        printf "%s" "$forced" | sed '/^$/d; s/^/  - /' >&2
    fi

    printf "%s" "$selected" | sed '/^$/d'
}

install_local_packages() {
    print_info "开始安装本地软件包..."

    cd "$TMP_DIR"

    if [ "$PKG_MANAGER" = "apk" ]; then
        local apk_files
        if [ -z "$(find . -maxdepth 1 -type f -name "*.apk" | head -n 1)" ]; then
            print_error "解压目录中未找到 .apk 软件包"
            exit 1
        fi

        apk_files=$(select_install_files "*.apk")

        if [ -z "$apk_files" ]; then
            print_info "所有非关键 APK 依赖均已安装，无需重复安装"
            return 0
        fi

        print_info "将安装以下 APK 软件包:"
        echo "$apk_files" | sed 's#^\./#  - #' >&2

        # shellcheck disable=SC2086
        apk add --allow-untrusted --force-overwrite --upgrade $apk_files
    else
        local ipk_files
        if [ -z "$(find . -maxdepth 1 -type f -name "*.ipk" | head -n 1)" ]; then
            print_error "解压目录中未找到 .ipk 软件包"
            exit 1
        fi

        ipk_files=$(select_install_files "*.ipk")

        if [ -z "$ipk_files" ]; then
            print_info "所有非关键 IPK 依赖均已安装，无需重复安装"
            return 0
        fi

        print_info "将安装以下 IPK 软件包:"
        echo "$ipk_files" | sed 's#^\./#  - #' >&2

        # 一次性传入全部本地包，让 opkg 能在本地文件之间解析依赖。
        # shellcheck disable=SC2086
        opkg install --force-downgrade --force-reinstall $ipk_files
    fi
}

# 获取 CPU 架构
get_cpu_arch() {
    print_info "检测 CPU 架构..."

    local arch=""

    # 优先从 /etc/openwrt_release 读取完整架构信息
    if [ -f /etc/openwrt_release ]; then
        . /etc/openwrt_release
        if [ -n "$DISTRIB_ARCH" ]; then
            arch="$DISTRIB_ARCH"
            print_info "从 OpenWrt 发行版信息获取架构: $arch"
        fi
    fi

    # 如果未获取到,使用包管理器检测
    if [ -z "$arch" ]; then
        if [ "$PKG_MANAGER" = "apk" ]; then
            arch=$(apk --print-arch 2>/dev/null)
        else
            arch=$(opkg print-architecture | awk '{print $2}' | grep -v "all" | grep -v "noarch" | head -n 1)
        fi
    fi

    if [ -z "$arch" ]; then
        print_error "无法检测 CPU 架构"
        exit 1
    fi

    print_info "检测到架构: $arch"
    echo "$arch"
}

# 获取最新版本号
get_latest_version() {
    print_info "获取最新版本信息..."

    local version=""

    if [ "$USE_PRERELEASE" = true ]; then
        print_info "使用 prerelease 模式，将获取最新的预发布版本"
        version=$(curl -sSL "${GITHUB_API}/releases" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
    else
        version=$(curl -sSL "${GITHUB_API}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    fi

    if [ -z "$version" ]; then
        print_error "无法获取最新版本信息"
        print_error "请检查网络连接或手动访问: https://github.com/${REPO_OWNER}/${REPO_NAME}/releases"
        exit 1
    fi

    print_info "最新版本: $version"
    echo "$version"
}

# 选择版本号
select_version() {
    local latest_version="$1"
    local display_version="${latest_version#v}"

    printf "${CYAN}请输入要安装的版本号 [默认: ${display_version}]: ${NC}" >&2
    read user_version < /dev/tty

    if [ -z "$user_version" ]; then
        user_version="$latest_version"
        print_info "使用默认版本: ${display_version}"
    else
        user_version="${user_version#v}"
        print_info "用户选择版本: ${user_version}"
        local version_tag="v${user_version}"

        print_info "验证版本是否存在..."
        local version_check=$(curl -sSL "${GITHUB_API}/releases/tags/${version_tag}" 2>/dev/null | grep '"tag_name":')

        if [ -z "$version_check" ]; then
            print_error "版本 ${user_version} 不存在"
            exit 1
        fi

        print_info "版本验证通过"
        user_version="$version_tag"
    fi

    echo "$user_version"
}

# 获取 Release Assets
get_release_assets() {
    local version="$1"
    print_info "获取 Release Assets 列表..."
    local assets=$(curl -sSL "${GITHUB_API}/releases/tags/${version}" | grep '"name":' | sed -E 's/.*"name":\s*"([^"]+)".*/\1/')

    if [ -z "$assets" ]; then
        print_error "无法获取 Release Assets 列表"
        exit 1
    fi
    echo "$assets"
}

# 匹配并下载安装
download_and_install() {
    local version="$1"
    local arch="$2"
    local assets="$3"

    # 仅发布 SNAPSHOT 构建。
    local sdk_suffix="SNAPSHOT"
    local target_filename="netdata-${arch}-${sdk_suffix}.tar.gz"

    print_info "正在寻找匹配的安装包: $target_filename"

    local matched_file=$(echo "$assets" | grep "$target_filename" | head -n 1)

    if [ -z "$matched_file" ]; then
        print_warn "未找到精确匹配: $target_filename"
        print_info "尝试模糊匹配..."
        matched_file=$(echo "$assets" | grep "netdata" | grep "${arch}" | grep "${sdk_suffix}" | grep ".tar.gz" | head -n 1)
    fi

    if [ -z "$matched_file" ]; then
        print_error "未找到适用于架构 ${arch} (SDK: ${sdk_suffix}) 的安装包"
        print_error "Release assets 列表:"
        echo "$assets"
        exit 1
    fi

    print_info "找到安装包: $matched_file"

    mkdir -p "$TMP_DIR"
    local url="${GITHUB_RELEASE}/${version}/${matched_file}"
    local output="${TMP_DIR}/${matched_file}"

    print_info "下载: $matched_file"
    if ! curl -fsSL --insecure --progress-bar -o "$output" "$url"; then
        print_error "下载失败"
        exit 1
    fi

    print_info "解压..."
    tar -zxf "$output" -C "$TMP_DIR"

    install_local_packages

    print_info "安装完成"

    # 清 LuCI 缓存，确保插件在 Web 界面中生效
    print_info "刷新 LuCI 缓存..."
    rm -f /tmp/luci-indexcache /tmp/luci-modulecache /tmp/luci-sessions 2>/dev/null || true
    rm -rf /tmp/luci-* 2>/dev/null || true
    [ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd reload 2>/dev/null || true
    [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd reload 2>/dev/null || true
}

# 清理
cleanup() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

main() {
    print_info "=========================================="
    print_info "netdata 一键安装脚本"
    print_info "=========================================="

    select_github_mirror
    check_requirements
    check_installed

    local arch=$(get_cpu_arch)
    local latest_version=$(get_latest_version)
    local version=$(select_version "$latest_version")

    local assets=$(get_release_assets "$version")

    download_and_install "$version" "$arch" "$assets"

    cleanup

    # 获取路由器管理 IP（优先取 br-lan，兜底用 LAN 第一个地址）
    local router_ip=""
    router_ip=$(ip -4 addr show br-lan 2>/dev/null | grep -oE '([0-9]+\.){3}[0-9]+' | head -n 1)
    if [ -z "$router_ip" ]; then
        router_ip=$(ip -4 addr show 2>/dev/null | grep -oE '([0-9]+\.){3}[0-9]+' | grep -v '^127\.' | head -n 1)
    fi
    if [ -z "$router_ip" ]; then
        router_ip="<router-ip>"
    fi

    print_info "=========================================="
    print_info "全部完成！"
    print_info "LuCI 入口: http://${router_ip}/cgi-bin/luci/admin/system/netdata"
    print_info "Netdata 面板: http://${router_ip}:19999/v3/"
    print_info "=========================================="
}

trap cleanup EXIT INT TERM

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --prerelease)
                USE_PRERELEASE=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo "  --prerelease    使用预发布版本"
                exit 0
                ;;
        esac
    done
}

parse_args "$@"
main
