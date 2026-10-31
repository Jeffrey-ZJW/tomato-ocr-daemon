# tomato-ocr-daemon

独立 TomatoOCR 本地 OCR 服务 daemon，不依赖 AutoTouch/按键精灵。

## 工作原理

- 编译成 LaunchDaemon，开机自启
- 加载 `/Library/Frameworks/TomatoOCR.framework`
- 监听 `127.0.0.1:9999`

## API

| 路径 | 说明 |
|---|---|
| `GET /status` | 返回 `{ready, license}` —— 看 setLicense 是否成功 |
| `GET /ocr?path=/var/.../shot.png` | 整图识别，返回 TomatoOCR 原生 JSON（文字+坐标） |

## AutoTouch 调用

```js
var axios = require('axios');
var r = await axios.get('http://127.0.0.1:9999/status');
console.log(r.data);
var ocr = await axios.get('http://127.0.0.1:9999/ocr', {params:{path:'/var/mobile/Library/AutoTouch/Scripts/shot.png'}});
console.log(ocr.data);
```

## 部署

1. 把本项目 push 到 GitHub 新仓库
2. GitHub Actions 自动编译 .deb
3. 手机上 `dpkg -i` 安装，或通过 Release 直链安装
4. `launchctl load /Library/LaunchDaemons/com.jeffrey.tomato-ocr.plist`
5. 测 `curl http://127.0.0.1:9999/status`

## 日志

`/var/mobile/Library/Preferences/tomato-ocr-daemon.log`
