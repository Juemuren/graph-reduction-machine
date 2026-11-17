# 字符串编码

字符串是字符组成的有序列表，而字符是自然数。

字符串可以有多种编码方式——如果有序列表有 $n$ 种编码方式，自然数有 $m$ 种编码方式，那么字符串就可以有 $m\times n$ 种编码方式：

- 目前支持 $2$ 种有序列表编码方式，分别为 Church / Scott
- 目前支持 $3$ 种自然数编码方式，分别为 Church / Scott / Binary

因此目前实际存在 $6$ 种自然数编码方式。

## 示例

下面的示例均采用默认的字符串编码方式，即 Church 有序列表和 Binary 自然数。

### 你好世界

实现在 [hello.lambda](hello.lambda) 中。

在仓库根目录运行：

```sh
lambda-compiler examples/string/hello.lambda | ski-interpreter --decode=string
```

程序会输出 `你好，世界！`。

### 镜像文字

实现在 [mirror.lambda](mirror.lambda) 中。

在仓库根目录运行：

```sh
lambda-compiler examples/string/mirror.lambda | ski-interpreter --decode=string
```

程序将原字符串与倒序字符串连接。原字符串为 `cat`，因此输出为 `cattac`。

### 字符回声

实现在 [echo.lambda](echo.lambda) 中。

在仓库根目录运行：

```sh
lambda-compiler examples/string/echo.lambda | ski-interpreter --decode=string
```

程序将原字符串中的每个字符输出两次。原字符串为 `Hi!`，因此输出为 `HHii!!`。

### 插入分隔符

实现在 [separate.lambda](separate.lambda) 中。

在仓库根目录运行：

```sh
lambda-compiler examples/string/separate.lambda | ski-interpreter --decode=string
```

程序在原字符串的所有相邻字符之间插入一个字符。原字符串为 `Lambda`，插入字符为 `.`，因此输出为 `L.a.m.b.d.a`。

### ANSI 控制序列

实现在 [ansi.lambda](ansi.lambda) 中。

在仓库根目录运行：

```sh
lambda-compiler examples/string/ansi.lambda --encode-natural=binary | ski-interpreter --decode=string
```

程序会输出 `Hello, World!`。如果终端支持 ANSI 控制序列，那么 `Hello` 会变成红色，`World` 会变成绿色。
