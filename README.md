# Shiori 栞

河北大学教务系统第三方客户端（Android，Flutter 构建）。课表、成绩与 GPA、
考试安排、一键评教——纯客户端架构，不设后端，凭据只保存在手机本地。

> 本项目仅供学习交流使用，不收集任何用户数据，请勿用于抢课等高频请求场景。

## 功能规划

| 模块 | 状态 |
| --- | --- |
| Material 3 主题系统（绿色种子色 / 动态取色 / OLED 纯黑） | ✅ Phase 0 完成 |
| WebVPN 加密 URL 改写（AES-128-CFB） | ✅ Phase 0 完成 |
| WebVPN 登录（WebView 兜底 + Cookie 桥接持久化 + 会话状态机） | ✅ Phase 1 完成 |
| 原生协议直接登录（A 路径，依赖抓包） | 🚧 抓包逆向就绪待接入 |
| 周课表（M3 自绘 GridView）+ 系统日历导入（.ics）+ 考试安排倒计时 | ✅ Phase 2 完成 |
| 历年成绩 + GPA 多模式计算引擎 + fl_chart 走势曲线 | ✅ Phase 3 完成 |
| 一键评教（问卷智能解析、表单构建、批量好评与进度反馈） | ✅ Phase 4 完成 |
| GitHub Releases 自查更新 / 隐私免责声明 / 架构打磨 | ✅ Phase 5 完成 |

完整规划见 `docs/`；协议逆向笔记与抓包指引见 [docs/protocol.md](docs/protocol.md)。

## 技术栈

Flutter 3 (Material 3) · Riverpod · go_router · dio · drift · pointycastle

## 开发环境（Windows）

1. Flutter SDK stable ≥ 3.24（国内镜像：
   `PUB_HOSTED_URL=https://pub.flutter-io.cn`、
   `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`）
2. Android Studio（Android SDK + JDK 17）
3. `flutter doctor` 确认环境就绪

```bash
flutter pub get
flutter analyze   # very_good_analysis
flutter test      # 含 WebVPN URL 改写已知答案测试
flutter run
```

## 贡献

协议抓包结果请按 `docs/protocol.md` 的模板补充；抓包文件务必脱敏。

## 许可

待定（公开仓库时补充）。参考致谢：
[Kazumi](https://github.com/Predidit/Kazumi)（UI 风格）、
[webvpn-dlut](https://github.com/ESWZY/webvpn-dlut)（WebVPN URL 算法）、
[JLU_schedule](https://github.com/JFyuhong/JLU_schedule)（会话管理设计）、
[sachet](https://github.com/wyvern1723/sachet)（Flutter 教务客户端架构）。
