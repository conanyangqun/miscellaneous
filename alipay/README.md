## 支付宝账单到fireflyIII转换工具

将支付宝导出的对账单（csv格式），转换为fireflyIII的csv格式，并处理相关交易账号的映射方式。

### 使用方法

从支付宝导出原始对账单。

运行程序，转换为fireflyIII的csv格式。

```bash
python3 alipay2firefly.py -i 支付宝账单.csv -o firefly.csv
```

打开firefly.csv文件，按照需要修改部分交易记录。

