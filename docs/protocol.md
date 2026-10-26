# Shiori 协议逆向笔记

> 目标：还原河北大学 WebVPN（v.hbu.cn，网瑞达 WRD）登录协议与本科教务系统（URP）
> 页面结构，为原生登录（A 路径）与数据解析提供依据。
>
> **安全约定：抓包文件包含个人凭据，脱敏后才能提交到仓库或分享。**

## 0. 抓包准备

- 浏览器 DevTools（F12）→ Network，勾选 **Preserve log**（跨域跳转不断链）
- 手机端进阶：mitmproxy / HttpCanary（需安装并信任 CA 证书）
- 使用校园网（HBU-WEB / HBU-1X）与手机流量各走一遍，分别记录
  直连与 WebVPN 两条链路的行为差异

## 1. WebVPN 登录（v.hbu.cn）

入口：<https://v.hbu.cn/login>，提供「CAS 统一认证（推荐）」与「账号登录」两种方式。

### 1.1 需要确认的清单

- [ ] 登录接口 URL 与方法（表单提交还是 XHR？）
- [ ] **密码字段是否加密**：在登录页源码中搜索 `encrypt` / `aes` / `rsa` / `publicKey`，
      找到内联 JS 的加密函数（网瑞达常见做法：AES-CBC/ECB 后 Base64，或 RSA 公钥加密）
- [ ] 验证码：接口地址、是否登录必带、触发条件（错几次出现）、能否刷新
- [ ] 会话 Cookie：名称（网瑞达常见 `wrdvpnismeaningful!`、`webvpn_*` 系列）、
      有效期、作用域（按 IP 还是按域名）
- [ ] CAS 链路：统一认证地址、login service 参数、ticket 回跳与校验
- [ ] 登录成功判据：跳转 URL / 响应体特征

### 1.2 记录模板

| 项 | 值 |
| --- | --- |
| 登录 URL | （待抓包） |
| 请求方法 | |
| 请求字段 | |
| 密码加密方式 | |
| 验证码接口 | |
| 会话 Cookie | |
| 成功判据 | |

## 2. WebVPN URL 改写（已实现，待验证密钥配对）

- 算法：AES-128-CFB（无填充，小写 hex），URL 结构
  `https://{网关}/{scheme}[-{port}]/{ivHex}{域名密文hex}/{原始路径}`
- 参考实现：[webvpn-dlut](https://github.com/ESWZY/webvpn-dlut)、
  [Get-Web-Address](https://github.com/HollowMan6/Get-Web-Address)
- Dart 实现：`lib/core/transport/webvpn_url.dart`（含已知答案单测）

### 2.1 确认 v.hbu.cn 实际使用的 key / iv 配对

1. 登录 WebVPN 后进入教务系统，从门户列表页复制跳转链接
2. 取链接中密文段（形如 `/http/77726476706e.../`）的**前 32 个 hex 字符**，即当前 IV
3. 已知常见配对：
   - 老配对：key = iv = `wrdvpnisthebest!`（hex 前缀 `77726476...7421`）
   - 新配对：key = iv = `Wxzxvpn2023key@$`（hex 前缀 `57787a78...4024`）
4. 若前 32 hex 不匹配任何已知配对，需要从登录页 JS 或网关下发的配置中找 key
   （搜索 `wrdvpn` / `aes` / `CFB` 关键字）
5. 确认后修改 `WebVpnUrlRewriter.hbu()` 工厂中的配对并更新单测

## 3. 教务系统（URP）

### 3.1 版本判定

| 特征 | 老版 URP | 新版 URP（URP高校教务管理系统） |
| --- | --- | --- |
| 登录页 | `loginAction.do` / `login.jsp` | 标题含「URP高校教务管理系统」 |
| 登录字段 | `zjh` / `mm` / `v_yzm` | `j_username` / `j_password` / `j_captcha` / `tokenValue` |
| 密码加密 | 明文或 MD5 | 加盐 MD5（盐 `Urp602019`，规则见 SCU-URP-Helper） |
| 页面编码 | GBK/GB2312 | UTF-8 为主 |
| 功能路径 | `*.do` 端点 | `/student/integratedQuery/...` 等现代路径 |

- [ ] 判定结果：______（抓包后填写）
- [ ] 校内直连地址（域名/IP:端口）：______
- [ ] 页面编码实测：______

### 3.2 功能 URL 表（抓包后补充）

| 功能 | 原始 URL | 页面结构（表格 id/class） |
| --- | --- | --- |
| 学籍信息 | | |
| 本学期成绩 | | |
| 历年成绩 | | |
| 课表 | | |
| 考试安排 | | |
| 评教列表 | | |
| 评教提交 | | |

### 3.3 会话失效特征

- [ ] 失效时跳转的 URL / 返回的状态码 / 页面关键字
- [ ] 同账号互踢时的表现（`有人登陆了您的账号` 之类文案）

## 4. 评教（Phase 4 前完成）

- [ ] 问卷列表接口与页面结构
- [ ] 提交字段（`wjbm` / `bpr` / `pgnr` / 单选组编号等）
- [ ] tokenValue 获取方式（新版）

## 5. 已知坑位备忘

- 教务服务器可能返回 **HTTP 200 + 页面内容为 500 Servlet Exception**，
  不能只看状态码判断请求成败（NEAU-URP 项目实测）
- 大量 URP 站点用裸 IP + HTTP 明文访问，Cookie 按 IP 存；Android 9+ 需
  networkSecurityConfig 白名单放行（Phase 1 落地）
- 教务系统处理选课/批量请求有延迟，批量操作请求间需要间隔
- 同账号异地登录互踢：网页登录会挤掉客户端会话，SessionManager 需静默重登
