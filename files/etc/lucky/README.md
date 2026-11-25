# Lucky 核心的保留位置（小版本升级不重编固件）

本目录（`/etc/lucky/`）在 `/etc/sysupgrade.conf` 的保留表里，**sysupgrade 不会清掉它**。

## 为什么有这个目录

镜像自带的 Lucky 核心装在 `/usr/bin/lucky`，而 `/usr/bin` **不在保留表**里。
所以每次刷固件（无论保不保留配置），`/usr/bin/lucky` 都会回退成镜像自带的那一版。

想"升了小版本但不想重新编译固件"，就把新核心放在这里：

```
/etc/lucky/lucky
```

首次启动时 `/etc/uci-defaults/99-lucky-core` 会把 `/usr/bin/lucky` 做成指向它的软链，
之后无论是重启还是 sysupgrade，运行的都是这里这份。

## 升级步骤（在路由器 SSH 里）

```sh
# 假定新核心已解包到 /tmp/lk/lucky
/etc/init.d/lucky stop
cp /tmp/lk/lucky /etc/lucky/lucky.new && chmod 755 /etc/lucky/lucky.new
/tmp/lk/lucky -info                     # 先确认版本/架构正确
mv /etc/lucky/lucky.new /etc/lucky/lucky
/etc/init.d/lucky start
```

注意：

1. 必须先 `stop`，否则覆盖正在执行的二进制会报 `Text file busy`
   （Lucky 后台自带的"在线更新"就是栽在这里，实测校验通过但文件没变）。
2. 内核架构必须是 `arm64`（`-info` 里 `ARCH` 字段），否则起不来。
3. 想回退到镜像自带版本：`rm /etc/lucky/lucky` 后重新刷一次固件，或
   `cp /rom/usr/bin/lucky /usr/bin/lucky` 再 `chmod 755`。
4. 备份配置目录用 `/etc/config/lucky.daji`（默认配置目录）。