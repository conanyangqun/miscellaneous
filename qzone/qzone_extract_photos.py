"""
用于从Qzone相册的HTML代码中提取照片的URL地址
Doubao-Seed-Code编写
"""
import re
from collections import defaultdict
import sys

# 检查命令行参数
if len(sys.argv) != 3:
    print("用法: python3 extract_photos.py <input_html_file> <output_txt_file>")
    print("示例: python3 extract_photos.py 2024.html photos_info.txt")
    sys.exit(1)

# 获取命令行参数
input_file = sys.argv[1]
output_file = sys.argv[2]

# 读取HTML文件
with open(input_file, 'r', encoding='utf-8') as f:
    html_content = f.read()

# 提取照片信息的正则表达式
# 匹配每个照片项
photo_items = re.findall(r'<li class="j-pl-photoitem.*?</li>', html_content, re.DOTALL)

photos_data = []
date_counter = defaultdict(int)
date_total = defaultdict(int)

# First pass: count total photos per date
for item in photo_items:
    date_match = re.search(r'<span title="([\d-]+)">([\d-]+)</span>', item)
    if date_match:
        date = date_match.group(1)
        url_match = re.search(r'src="([^"]+)"', item)
        if not url_match:
            url_match = re.search(r'data-src="([^"]+)"', item)
        
        if url_match:
            date_total[date] += 1

# Second pass: process photos with descending counter
for item in photo_items:
    # 提取日期
    date_match = re.search(r'<span title="([\d-]+)">([\d-]+)</span>', item)
    if date_match:
        date = date_match.group(1)
        # 提取URL（优先检查src属性，然后检查data-src属性）
        url_match = re.search(r'src="([^"]+)"', item)
        if not url_match:
            url_match = re.search(r'data-src="([^"]+)"', item)
        
        if url_match:
            url = url_match.group(1)
            # 增加日期计数器
            date_counter[date] += 1
            # 生成照片名称（使用总数减去当前计数加1，实现降序编号）
            photo_name = f"{date}_image_{(date_total[date] - date_counter[date] + 1):03d}"
            # 生成新URL
            # 处理不同格式的URL
            if '/mnull' in url:
                new_url = url.replace('/mnull', '/b').split('&')[0]
            elif '/m&' in url:
                new_url = url.replace('/m&', '/b&').split('&')[0]
            elif '/m?' in url:
                new_url = url.replace('/m?', '/b?').split('&')[0]
            elif '/m' in url:
                new_url = url.replace('/m', '/b').split('&')[0]
            else:
                new_url = url.split('&')[0]
            # 存储数据
            photos_data.append({
                'name': photo_name,
                'original_url': url,
                'new_url': new_url
            })

# 写入txt文件（tab分隔）
with open(output_file, 'w', encoding='utf-8') as f:
    for photo in photos_data:
        f.write(f"{photo['name']}\t{photo['original_url']}\t{photo['new_url']}\n")

print(f"成功提取 {len(photos_data)} 张照片信息并以tab分隔格式写入 {output_file} 文件")