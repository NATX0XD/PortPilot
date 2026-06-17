# PortPilot

แอป macOS สำหรับมอนิเตอร์ services/projects ที่กำลังรันอยู่ — เห็นว่าตัวไหนรัน port อะไร, กด **Restart** (kill แล้วรันคำสั่งเดิมซ้ำ) หรือ **Close** (หยุด process) ได้ มีทั้ง **หน้าต่าง desktop เต็มตัว (มี Dock icon)** และ **menu bar item** ที่มี badge นับจำนวน service ของคุณ

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
- **Show system** (admin): สแกนด้วยสิทธิ์ root เพื่อเห็น listener ของ root/user อื่น (one-shot กัน popup ซ้ำ)
- freshness indicator "updated Ns ago" + error banner ที่ปิดได้
- ปุ่ม action enable เฉพาะ process ของคุณ (`.user`) กันเผลอ kill Apple daemon

## โครงสร้างโปรเจกต์
```
PortPilot/
├── Package.swift                 # SPM manifest (สำรอง — ใช้ build-app.sh เป็นหลัก)
├── README.md
├── scripts/
│   ├── build-app.sh              # คอมไพล์ + ห่อเป็น PortPilot.app
│   └── Info.plist                # bundle config (LSUIElement = menu bar only)
└── Sources/PortPilot/
    ├── PortPilotApp.swift        # @main: Window (desktop) + MenuBarExtra
    ├── ContentView.swift         # UI: sections, inline confirm/rename, context menu
    ├── AppModel.swift            # state, auto-refresh, pins, sections, actions
    ├── PortScanner.swift         # parse lsof + ps -> ServiceInfo
    ├── ProcessManager.swift      # close / restart (PID-reuse guard)
    ├── Shell.swift               # run (with timeout), argv via sysctl, spawn
    └── Models.swift              # ServiceInfo + USER/SYSTEM category
```

## วิธี build & run
```bash
cd PortPilot
./scripts/install.sh        # build + ติดตั้ง /Applications + auto-start ตอน login + เปิด
# หรือแค่ build เฉยๆ:
./scripts/build-app.sh && open PortPilot.app
```
หลังเปิดจะมีหน้าต่าง PortPilot + ไอคอน 📡 บน menu bar (มี badge นับจำนวน service ของคุณ)

## ถอนการติดตั้ง
```bash
launchctl unload ~/Library/LaunchAgents/com.portpilot.app.plist
rm ~/Library/LaunchAgents/com.portpilot.app.plist
rm -rf /Applications/PortPilot.app
```

## หมายเหตุ toolchain
ต้องมี Command Line Tools ที่ compiler/SDK ตรงกัน (ลงสดด้วย `xcode-select --install`).
ถ้าเจอ error แบบ `this SDK is not supported by the compiler` ให้ลง CLT ใหม่:
`sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --install`
