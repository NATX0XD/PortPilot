# PortPilot

[English](README.md) · **ไทย**

แอป macOS สำหรับมอนิเตอร์ services/projects ที่กำลังรันอยู่ — เห็นว่าตัวไหนรัน port อะไร, กด **Restart** (kill แล้วรันคำสั่งเดิมซ้ำ) หรือ **Close** (หยุด process) ได้ มีทั้ง **หน้าต่าง desktop เต็มตัว (มี Dock icon)** และ **menu bar item** ที่มี badge นับจำนวน service ของคุณ

<!-- ใส่ screenshot ได้ที่นี่: ![PortPilot](docs/screenshot.png) -->

## ฟีเจอร์
- สแกน listening TCP services ทั้งหมดด้วย `lsof` (auto-refresh ทุก 5 วิ)
- แสดง port, ชื่อ, PID, protocol, user, uptime, working directory
- แยกกลุ่ม **Pinned / Your services / System** + ปักหมุดรายการโปรด
- badge **USER/SYSTEM** แยกจาก path executable (จับ Apple daemon ที่รันใต้ user ได้)
- **Restart**: ดึง argv จริงผ่าน `KERN_PROCARGS2` แล้ว spawn ใหม่ (ไม่ผ่าน shell — คำสั่งที่มี space/quote ไม่เพี้ยน)
- **Close**: SIGTERM → SIGKILL พร้อม guard กัน PID reuse (เช็ก lsof ว่ายังถือ port เดิมก่อนยิงสัญญาณ)
- **inline confirm** ก่อน kill/restart (ใช้ได้ทั้งในหน้าต่างและ menu bar)
- ตั้งชื่อ project ต่อ port (เก็บถาวร) + ค้นหา/กรอง
- คลิกขวา: Open `localhost:PORT`, Copy port/PID/URL/command/cwd, Reveal in Finder, Open in Terminal
- **Show system** (admin): สแกนด้วยสิทธิ์ root เพื่อเห็น listener ของ root/user อื่น (ถามรหัสครั้งเดียวต่อ session แล้ว cache)
- freshness indicator "updated Ns ago" + error banner ที่ปิดได้
- ปุ่ม action enable เฉพาะ process ของคุณ (`.user`) กันเผลอ kill Apple daemon

## ดาวน์โหลด & ใช้งาน (ไม่ต้อง build เอง)
1. ไปที่ **[Releases](https://github.com/NATX0XD/PortPilot/releases/latest)** โหลด `PortPilot-x.y.z.zip` (Apple Silicon)
2. แตก zip แล้วย้าย **PortPilot.app** เข้า `/Applications`
3. **เปิดครั้งแรก:** คลิกขวาที่แอป → **Open** → กด **Open** ซ้ำในกล่องที่เด้งมา
   (แอปเซ็นแบบ ad-hoc ยังไม่ notarize เลยโดน Gatekeeper บล็อกเฉพาะครั้งแรก double-click)
   ถ้ายังเปิดไม่ได้ ให้ล้าง quarantine ครั้งเดียว:
   ```bash
   xattr -dr com.apple.quarantine /Applications/PortPilot.app
   ```
4. เปิดแล้วจะมีหน้าต่าง + ไอคอน 📡 บน menu bar และ auto-start ตอน login. เวอร์ชันปัจจุบันโชว์ที่ footer

## วิธี build & run
```bash
cd PortPilot
./scripts/install.sh        # build + ติดตั้ง /Applications + auto-start ตอน login + เปิด
# หรือแค่ build เฉยๆ:
./scripts/build-app.sh && open PortPilot.app
```
หลังเปิดจะมีหน้าต่าง PortPilot + ไอคอน 📡 บน menu bar (มี badge นับจำนวน service ของคุณ)

## การออกเวอร์ชัน (release)
เวอร์ชันเก็บใน `scripts/Info.plist` (`CFBundleShortVersionString`) และโชว์ที่ footer ของแอป

- **บนเครื่อง Mac:** คำสั่งเดียว bump version + build + zip + tag + publish:
  ```bash
  ./scripts/release.sh 1.0.1
  ```
- **บน GitHub (ไม่ต้องมี Mac):** แท็บ Actions → **Build & Release** → Run workflow → ใส่เวอร์ชัน
  มันจะ build บน macOS runner แล้ว publish ให้ (เลือกใช้ทางใดทางหนึ่ง อย่าใช้ทั้งคู่กับเวอร์ชันเดียวกัน)

## ถอนการติดตั้ง
```bash
launchctl unload ~/Library/LaunchAgents/com.portpilot.app.plist
rm ~/Library/LaunchAgents/com.portpilot.app.plist
rm -rf /Applications/PortPilot.app
```

## โครงสร้างโปรเจกต์
```
PortPilot/
├── Package.swift                 # SPM manifest (สำรอง — ใช้ build-app.sh เป็นหลัก)
├── README.md
├── scripts/
│   ├── make-icon.sh / .swift     # สร้าง AppIcon.icns
│   ├── build-app.sh              # คอมไพล์ + ห่อเป็น PortPilot.app
│   ├── install.sh                # build + ติดตั้ง + auto-start
│   └── Info.plist                # bundle config
└── Sources/PortPilot/
    ├── PortPilotApp.swift        # @main: AppKit NSWindow (desktop) + MenuBarExtra
    ├── ContentView.swift         # UI: sections, inline confirm/rename, context menu
    ├── AppModel.swift            # state, auto-refresh, pins, sections, actions
    ├── PortScanner.swift         # parse lsof + ps -> ServiceInfo
    ├── ProcessManager.swift      # close / restart (PID-reuse guard)
    ├── Shell.swift               # run (with timeout), argv via sysctl, spawn
    └── Models.swift              # ServiceInfo + USER/SYSTEM category
```

## หมายเหตุ toolchain
ต้องมี Command Line Tools ที่ compiler/SDK ตรงกัน (ลงสดด้วย `xcode-select --install`).
ถ้าเจอ error แบบ `this SDK is not supported by the compiler` ให้ลง CLT ใหม่:
```bash
sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --install
```

## License
MIT
