#!/usr/bin/env bash
#
# generate_hash.sh
#
# 为指定目标文件夹下的所有文件生成哈希值，每个文件一行。
# 输出格式兼容 GNU coreutils 的 <algo>sum -c 校验（如 md5sum -c、
# sha256sum -c），在 macOS 上 sha 系列可用 shasum -a <N> -c 校验。
#
# 平台支持：Linux、macOS。
# 默认算法：md5。可通过 -a 选择 md5 / sha1 / sha256 / sha512。
#
# 说明：
#   - 符号链接（含指向普通文件的链接）不会被哈希。
#   - 文件名可包含空格、换行等特殊字符（排除文件中的路径不支持换行）。
#
# 用法示例：
#   ./generate_hash.sh -d /path/to/folder
#   ./generate_hash.sh -d /path/to/folder -a sha256 -o hashes.sha256
#   ./generate_hash.sh -d /path/to/folder -e /abs/path/to/skip -e ./rel/skip
#   ./generate_hash.sh -d /path/to/folder -f exclude.txt
#
# 校验：
#   cd /path/to/folder && md5sum -c    hashes.md5      # Linux (md5)
#   cd /path/to/folder && sha256sum -c hashes.sha256  # Linux (sha256)
#   cd /path/to/folder && shasum -a 256 -c hashes.sha256  # macOS (sha256)

set -euo pipefail

# 起始工作目录，供输出文件等相对路径解析使用
ORIG_PWD="$PWD"

# ---------------------------------------------------------------------------
# 帮助信息
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
用法: $(basename "$0") [选项] -d <目标文件夹>

选项:
  -d, --dir DIR            目标文件夹（必填）
  -a, --algorithm ALGO    哈希算法，可选: md5(默认) / sha1 / sha256 / sha512
  -e, --exclude PATH       排除某个文件或文件夹，可重复指定。
                           PATH 可为绝对路径，也可为相对于目标文件夹的相对路径。
  -f, --exclude-file FILE  从文件中读取排除路径，每行一个（# 开头或空白符后跟 #
                           的部分视为注释；路径中的连续空格会被保留）
  -o, --output FILE        将哈希结果写入文件（默认输出到标准输出）。
                           相对路径相对于当前工作目录。
  -h, --help               显示本帮助
EOF
}

# ---------------------------------------------------------------------------
# 配置哈希命令
# ---------------------------------------------------------------------------
ALGORITHM="md5"          # 默认算法
HASH_RAW=()              # 实际调用的哈希命令（数组）
HASH_TOOL=""             # 用于校验提示的命令名
IS_MACOS=0               # 平台标志，避免在循环中反复调用 uname
MD5_REWRITE=0            # macOS md5 -r 输出格式需要重写为双空格格式

# 根据平台与算法设置哈希命令
setup_hash() {
    local alg="$1"
    local sys
    sys="$(uname -s)"

    if [[ "$sys" == "Darwin" ]]; then
        IS_MACOS=1
        # ---- macOS ----
        case "$alg" in
            md5)
                if command -v md5 >/dev/null 2>&1; then
                    HASH_RAW=(md5 -r)
                    HASH_TOOL="md5sum"
                    MD5_REWRITE=1
                else
                    echo "错误: 未找到 md5 命令。" >&2; exit 1
                fi
                ;;
            sha1|sha256|sha512)
                if command -v shasum >/dev/null 2>&1; then
                    local n="${alg#sha}"
                    HASH_RAW=(shasum -a "$n")
                    HASH_TOOL="shasum -a $n"
                else
                    echo "错误: 未找到 shasum 命令。" >&2; exit 1
                fi
                ;;
            *)
                echo "错误: 不支持的算法 '$alg'（macOS 支持 md5/sha1/sha256/sha512）。" >&2
                exit 1
                ;;
        esac
    else
        # ---- Linux / GNU coreutils ----
        case "$alg" in
            md5)    HASH_RAW=(md5sum);    HASH_TOOL="md5sum" ;;
            sha1)   HASH_RAW=(sha1sum);   HASH_TOOL="sha1sum" ;;
            sha256) HASH_RAW=(sha256sum); HASH_TOOL="sha256sum" ;;
            sha512) HASH_RAW=(sha512sum); HASH_TOOL="sha512sum" ;;
            *)
                echo "错误: 不支持的算法 '$alg'（支持 md5/sha1/sha256/sha512）。" >&2
                exit 1
                ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------------------
TARGET_DIR=""
ALGORITHM="md5"
EXCLUDE_PATHS=()
EXCLUDE_FILE=""
OUTPUT_FILE=""

# 校验选项参数存在，避免 set -u 报出晦涩的错误
require_arg() {
    if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "错误: 选项 '$1' 缺少参数。" >&2
        usage
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)           require_arg "$@"; TARGET_DIR="$2"; shift 2 ;;
        -a|--algorithm)     require_arg "$@"; ALGORITHM="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"; shift 2 ;;
        -e|--exclude)       require_arg "$@"; EXCLUDE_PATHS+=("$2"); shift 2 ;;
        -f|--exclude-file)  require_arg "$@"; EXCLUDE_FILE="$2"; shift 2 ;;
        -o|--output)        require_arg "$@"; OUTPUT_FILE="$2"; shift 2 ;;
        -h|--help)          usage; exit 0 ;;
        *)                  echo "未知参数: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$TARGET_DIR" ]]; then
    echo "错误: 必须指定目标文件夹 (-d)。" >&2
    usage
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "错误: '$TARGET_DIR' 不是有效的文件夹或不存在。" >&2
    exit 1
fi

# 根据算法与平台配置哈希命令（必须在解析完参数后调用）
setup_hash "$ALGORITHM"

# 目标文件夹的绝对路径
TARGET_ABS="$(cd "$TARGET_DIR" && pwd)"

# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------

# 将路径规范化为绝对路径（不解析符号链接），去除结尾的斜杠。
# 相对路径基于传入的 base 目录解析。
normalize() {
    local p="$1" base="$2"
    p="${p%/}"
    if [[ "$p" != /* ]]; then
        p="${base%/}/${p}"
    fi
    printf '%s' "$p"
}

# 计算单个文件的哈希值，输出统一为 GNU coreutils 校验格式: "<hash>  <file>"
# （两个空格分隔，与 md5sum/sha256sum -c 兼容）
hash_of() {
    local f="$1"
    if [[ "$MD5_REWRITE" -eq 1 ]]; then
        # macOS 的 md5 -r 输出为 "hash file"（单空格），且文件名可能含空格，
        # 这里取首个十六进制字段为哈希，其余为文件名，重写为双空格格式。
        "${HASH_RAW[@]}" "$f" | sed -E 's/^([0-9a-fA-F]+)[[:space:]]+(.*)$/\1  \2/'
    else
        "${HASH_RAW[@]}" "$f"
    fi
}

# ---------------------------------------------------------------------------
# 构建排除列表
# 相对路径基于目标文件夹 (TARGET_ABS) 解析。
# ---------------------------------------------------------------------------
EXCLUDE_LIST=()      # 所有排除项（含文件），用于精确匹配
EXCLUDE_DIRS=()      # 其中确实存在的目录，用于前缀匹配

# 命令行 -e 指定的排除项
for p in "${EXCLUDE_PATHS[@]:-}"; do
    [[ -z "$p" ]] && continue
    EXCLUDE_LIST+=("$(normalize "$p" "$TARGET_ABS")")
done

# -f 指定的排除文件（每行一个，# 开头或空白符后跟 # 为注释，空白行忽略）
# 注意：仅去除首尾空白，保留路径内部的连续空格；同时兼容 CRLF 行尾。
if [[ -n "$EXCLUDE_FILE" ]]; then
    if [[ ! -f "$EXCLUDE_FILE" ]]; then
        echo "错误: 排除文件 '$EXCLUDE_FILE' 不存在。" >&2
        exit 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 去掉 \r（CRLF 兼容）、行内注释（# 前须为行首或空白符）与首尾空白
        line="${line%$'\r'}"
        line="$(printf '%s' "$line" | sed -E 's/(^|[[:space:]])#.*$//' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        [[ -z "$line" ]] && continue
        EXCLUDE_LIST+=("$(normalize "$line" "$TARGET_ABS")")
    done < "$EXCLUDE_FILE"
fi

# 预先筛出真实存在的目录，避免校验阶段对每个文件重复 stat
for e in "${EXCLUDE_LIST[@]:-}"; do
    [[ -z "$e" ]] && continue
    if [[ -d "$e" ]]; then
        EXCLUDE_DIRS+=("$e")
    fi
done

# 判断某个绝对路径是否应被排除
is_excluded() {
    local f="$1" e
    for e in "${EXCLUDE_LIST[@]:-}"; do
        [[ -z "$e" ]] && continue
        # 精确匹配文件或文件夹本身
        if [[ "$f" == "$e" ]]; then
            return 0
        fi
    done
    # 若排除项为目录，则其下所有文件均排除
    for e in "${EXCLUDE_DIRS[@]:-}"; do
        [[ -z "$e" ]] && continue
        if [[ "$f" == "$e/"* ]]; then
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# 生成哈希
# ---------------------------------------------------------------------------
cd "$TARGET_DIR"

# 输出文件按原始工作目录（或绝对路径）解析，与用法说明一致。
# 若输出文件位于目标文件夹内，自动将其排除，避免自我引用导致校验失败。
OUT_ABS=""
if [[ -n "$OUTPUT_FILE" ]]; then
    OUT_ABS="$(normalize "$OUTPUT_FILE" "$ORIG_PWD")"
    if [[ "$OUT_ABS" == "$TARGET_ABS"/* ]]; then
        EXCLUDE_LIST+=("$OUT_ABS")
    fi
fi

generate() {
    # 输出相对路径，使校验命令可在目标文件夹内直接运行。
    # 使用 NUL 分隔（find -print0 / sort -z），以正确处理含换行符的文件名。
    find . -type f -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' f; do
        f="${f#./}"                 # 去掉开头的 ./
        [[ -z "$f" ]] && continue
        abs="$TARGET_ABS/$f"
        is_excluded "$abs" && continue
        hash_of "$f"
    done
}

if [[ -n "$OUTPUT_FILE" ]]; then
    # cd 之后相对路径会失效，因此统一使用解析好的绝对路径重定向
    generate > "$OUT_ABS"
    echo "哈希结果已写入: $OUT_ABS" >&2
else
    generate
fi
