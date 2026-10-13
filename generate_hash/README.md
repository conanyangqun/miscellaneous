## generate_hash

### 基本需求

创建一个shell脚本，用户指定目标文件夹，脚本为文件夹下的所有文件生成哈希值，每个文件一个哈希值，输出格式可以用对应的哈希命令校验。具体功能点如下：
- 支持Linux、Macos平台。
- 可选的，用户指定排除列表，包含文件夹或文件的绝对路径或相对路径。排除列表中的文件不计算哈希值。
- 支持多种哈希算法：默认使用 md5，可通过参数选择 md5、sha1、sha256、sha512。
- 输出格式与 GNU coreutils 的 `<算法>sum -c` 兼容（macOS 上 sha 系列可用 `shasum -a N -c` 校验），可直接用对应命令校验。

### 用法

脚本：`generate_hash.sh`

```bash
./generate_hash.sh [选项] -d <目标文件夹>
```

| 选项 | 说明 |
| --- | --- |
| `-d, --dir DIR` | 目标文件夹（必填） |
| `-a, --algorithm ALGO` | 哈希算法，可选 `md5`（默认）/ `sha1` / `sha256` / `sha512` |
| `-e, --exclude PATH` | 排除某个文件或文件夹，可重复指定（绝对路径，或相对于目标文件夹的相对路径） |
| `-f, --exclude-file FILE` | 从文件中读取排除路径，每行一个（行首或空白符后跟 `#` 的部分视为注释，空行忽略；保留路径内部的连续空格） |
| `-o, --output FILE` | 将哈希结果写入文件（默认输出到标准输出，相对路径相对于当前工作目录） |
| `-h, --help` | 显示帮助信息 |

#### 示例

```bash
# 默认算法 md5，输出到标准输出
./generate_hash.sh -d /path/to/folder

# 使用 sha256 算法，结果写入文件
./generate_hash.sh -d /path/to/folder -a sha256 -o hashes.sha256

# 排除指定的文件或文件夹（相对路径相对于目标文件夹）
./generate_hash.sh -d /path/to/folder -e skip -e sub -e ./rel/skip

# 从排除列表文件读取（每行一个路径，# 开头或空白符后跟 # 为注释）
./generate_hash.sh -d /path/to/folder -f exclude.txt
```

#### 校验

输出文件位于目标文件夹内时，可在该文件夹下直接用对应命令校验：

```bash
# md5（Linux）
cd /path/to/folder && md5sum -c hashes.md5

# sha256（Linux）
cd /path/to/folder && sha256sum -c hashes.sha256

# sha256（macOS）
cd /path/to/folder && shasum -a 256 -c hashes.sha256
```

### 行为说明

- **符号链接**：不会被哈希（`find -type f` 不跟踪链接，包括指向普通文件的链接）。
- **特殊文件名**：文件遍历使用 `find -print0` / `sort -z` / `read -d ''`（NUL 分隔），文件名可安全包含空格、连续空格、换行符等特殊字符；`sort` 使用 `LC_ALL=C` 保证顺序稳定。
- **输出文件**：相对路径相对于运行脚本时的当前工作目录解析。若输出文件位于目标文件夹内，会自动将其排除，避免自我引用导致校验失败。
- **排除文件（`-f`）**：兼容 CRLF 行尾；行首或空白符后跟 `#` 的部分视为行内注释；仅去除行首尾空白，路径内部的连续空格会保留。
- **macOS 的 md5**：使用系统自带 `md5 -r`，脚本会将输出重写为 GNU coreutils 的双空格格式（`<hash>  <file>`）。

### 已知边界情况

- **md5 + 文件名含换行/反斜杠**：GNU coreutils 约定此类文件名在校验文件中需转义（如 `\we\nird.txt`）。`shasum` 系列输出已自动转义，但 macOS 的 md5 分支输出保留原始字符、未做转义，因此这种极端文件名在 md5 格式下用 `md5sum -c` 校验可能失败。
- **排除文件（`-f`）中的路径**：不支持包含换行符的文件名；文件名中若含 `#` 且 `#` 前有空白符，会被当作行内注释截断，此类文件名请改用 `-e` 指定。
- **排除目录的判断**：在构建排除列表时即判断路径是否存在且为目录；若排除项指向的目录在运行期间才创建，其子文件不会被排除。

