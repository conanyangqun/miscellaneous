## QQ空间照片半自动下载方式

实现思路：把某个相册下照片的HTML代码手动复制到文件中保存，利用程序`qzone_extract_photos.py`提取照片URL。同一个日期有多张照片时，编号会自动增加。再利用`download_images.sh`下载照片。

具体操作步骤如下：

访问：`qzone.qq.com`。

访问某个相册。若相册分页（某一页总计6 x 16 = 96P），先浏览到最后一张，确保全部加载完毕。右击最后一张，检查元素。照片的URL在以下元素中。

```html
<div class="mod-photo-list">
</div>
```

复制此元素的内容到`html`文件中。依次操作直至添加全部需要的内容，例如`all.html`文件。

执行以下命令，从HTML文件中提取所有照片的URL信息。

```python
python qzone_extract_photos.py all.html all.images.txt
```

导出当前的cookies文件为netscape格式，以`cookies.txt`保存在程序目录下（chrome浏览器可使用cookie editor插件）。注意，部分照片需要登录后下载，否则只获得“加密图片”的文件，但是部分近期照片不需要登录。

执行以下命令下载照片。

```bash
bash download_images.sh all.images.txt qzone_images
```

### 其他

提取照片URL的xpath语法为：

```
//div[@class='mod-photo-list']//li[@class='j-pl-photoitem']//img[@class='j-pl-photoitem-img']/@src
```

