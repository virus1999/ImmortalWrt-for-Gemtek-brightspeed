# IPTV 直播 4~5 分钟卡死：排查与修复（2026-11-23）

## 现象

直播起流后约 4~5 分钟画面静止卡死，切台或遥控器快进/快退可恢复一阵，之后再次卡死。
网页、代理、其它设备不受影响。另有一条"待机后再开机卡 A 面认证"，是另一个问题（须真拔电源冷启动）。

## 环境

- 硬件：Gemtek XG2010G（AN7581），本仓库自编固件
- 线路：上海电信，**IPTV 直播走 service VLAN 85（B 面）**，multicast VLAN 51
- 机顶盒：HG680-J，接 `mux-dn1`（VLAN85 子接口）
- 桥 `br-mux-1` 三个成员：`mux-up1`（85 上联）、`mux-dn1`（85 下联/盒子）、`mux-mc1`（51 组播面）
- 固件参数：`onu-iptv` mode=trunk、service_vlan=85、multicast_vlan=51、igmp_snooping=1、multicast_querier=1

## 根因

1. 固件 `/usr/libexec/iptv-trunk-multicast`（hotplug `25-iptv-trunk-multicast` 调用）在 trunk 模式下执行：
   - `bridge link set dev mux-dn1 mcast_flood off mcast_router 0`
   - `bridge link set dev mux-mc1 mcast_router 0 ... mcast_flood off`
   三个 IPTV 端口因此全是 `multicast_router=0`，桥不再把 IGMP query 当"路由口"往机顶盒转。
2. 机顶盒收不到 query 就收不到"你还在不在"的提醒，不会定期发报告；上游 OLT 与网内 mdb 的成员关系
   在 260 秒左右同时过期，上游掐流，画面卡死。切台/快进 = 重新加入一次，故能恢复 4~5 分钟。
3. 换台后新加入的那一路尤其脆弱：只要那一轮没人续订，到点必断。

## 判据（排查时直接用）

- 判流量看 `/proc/net/dev`：`mux-mc1`(或 `mux-up1`) 收 与 `mux-dn1` 出 应 1:1（单路约 9.4 Mbps）。
  卡死瞬间两者同时停 = 上游过期；只有 `dn1` 出向停 = 本桥不转发。
- `bridge -s mdb show dev br-mux-1` 末列是成员剩余秒数；被刷新（回到 240~260）说明盒子在回应查询。
- `tcpdump` 在 `mux-dn1`/`mux-mc1` 上基本是瞎的（`flow_offloading` 开着，报文走快路径），不要拿它当唯一证据。
- 定向放行看 `nft list chain bridge iptv multicast_forward` 的计数器。

## 修法（本仓库 files/ 已落地）

1. `files/etc/hotplug.d/iface/96-iptv-mcast`：三个 IPTV 端口 `multicast_router=1`，`mux-dn1` `multicast_flood=1`。
   （编号排在固件 `25-` 之后，ifup 时后手覆盖）
2. `files/usr/bin/iptv-keepalive-loop` + `files/etc/init.d/iptv-keepalive`：每 20 秒从 mdb 挑
   "剩余计时最长"的那条 dn1 组（= 最新加入的台），每 300 秒先起新加入、4 秒后退旧的，由本机
   `rtp2httpd`（127.0.0.1:5140）代订，让电信持续推流；日志 `/var/log/iptv-keepalive.log`。
3. 桥级 `multicast_query_use_ifaddr=1`（本桥做查询器时 query 源地址不用 0.0.0.0）。

## 实测结果

- 修前基线：4~5 分钟必卡；一次加入后约 260 秒（4 分 20 秒）断。
- 修后：30 秒一对采样 1:1 连续 40 分钟无缺口；换台后 10 秒内保活自动跟到新台，全程无掉流；
  盒子成员计时每约 121 秒被刷新一次（对得上桥的 `query_interval=125`）。

## 两个坑（实测，值得记）

1. `multicast_flood=1` 不是"无条件永远泛洪"：当某组在桥里已有成员（哪怕成员是本机自己代订的），
   桥只按成员转发，泛洪不生效。这时若盒子自己那条断了，画面会停，尽管上游还在推。
2. 只做"关掉泛洪 + 端口 router=1 + 不保活"是不够的：换台后新那一路无人续订，260 秒照样断。
   上游续订那条腿不能省。

## 落地注意

- 通过网页提交的文件默认是 644；`files/etc/init.d/iptv-keepalive` 与 `files/usr/bin/iptv-keepalive-loop`
  需要可执行位，编译前在本地 `chmod +x`，或在构建脚本里补一行 `chmod`，否则开机不会跑。
- 小米 BE6500 Pro（做 AP/VLAN 透传）侧本轮核对无嫌疑：VLAN 85/51 均 `0t 1t 2t 3t 4t`，QinQ `switch_ext` 为 0。
