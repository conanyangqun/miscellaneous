#!/bin/bash

# 检查参数是否正确
if [ $# -ne 2 ]; then
    echo "使用方法: $0 <图像信息文件> <输出文件夹名称>"
    echo "示例: $0 2026.images.txt 2026_images"
    exit 1
fi

# 赋值参数
INFO_FILE="$1"
OUTPUT_DIR="$2"

# 检查信息文件是否存在
if [ ! -f "$INFO_FILE" ]; then
    echo "错误: 图像信息文件 '$INFO_FILE' 不存在"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 读取文件并下载图像
while IFS= read -r line; do
    # 跳过空行
    if [ -z "$line" ]; then
        continue
    fi
    
    # 提取第1列（名称）和第3列（URL）
    name=$(echo "$line" | awk '{print $1}')
    url=$(echo "$line" | awk '{print $3}')
    
    # 检查是否成功提取
    if [ -z "$name" ] || [ -z "$url" ]; then
        echo "警告: 无法解析行: $line"
        continue
    fi
    
    # 下载图像
    echo "正在下载: $name"
    curl -L -b cookies.txt -s -o "$OUTPUT_DIR/$name.jpeg" "$url"
    
    # 检查下载是否成功
    if [ $? -eq 0 ]; then
        echo "成功: $name"
    else
        echo "失败: $name"
    fi
done < "$INFO_FILE"

echo "下载完成!"
