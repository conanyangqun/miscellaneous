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
| `-f, --exclude-file FILE` | 从文件中读取排除路径，每行一个（支持 `#` 注释、空行） |
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

# 从排除列表文件读取（每行一个路径，# 开头为注释）
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

