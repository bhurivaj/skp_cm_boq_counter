# SKP CM BoQ Counter

SketchUp plugin สำหรับนับ component และสร้าง Bill of Quantities (export CSV, ส่ง stock request)

- รองรับ: SketchUp 2024+
- เดิมเป็นส่วนหนึ่งของ Classmat Suite
- หน้า report ใช้ Vue 3 + Tailwind จาก CDN — ต้องต่ออินเทอร์เน็ต

## ติดตั้ง

SketchUp → Extensions → Extension Manager → Install Extension → เลือก `skp_cm_boq_counter_<version>.rbz`

## บัญชี / Send Stock Request

Send Stock Request ต้องติดตั้ง **SKP CM Extensions Hub 0.4.0+** และ login ที่การ์ด "บัญชี" ใน Hub
(Save as CSV ใช้ได้โดยไม่ต้อง login). บัญชีที่ BoQ 1.x บันทึกไว้จะถูกย้ายไป Hub อัตโนมัติเมื่อเปิดหน้า BoQ Report

## ย้ายจาก Classmat Suite

ครั้งแรกที่เปิด plugin จะ copy ค่า settings และ login จาก `classmat_config.json` เดิมให้อัตโนมัติ (login ถูกย้ายต่อไป Hub)
ถ้ายังมี Classmat Suite ตัวเก่า plugin จะแสดงรายการไฟล์ที่ต้องลบในโฟลเดอร์ Plugins

## Config

- Windows: `%APPDATA%/SkpCm/boq_counter/config.json`
- macOS: `~/Library/Application Support/SkpCm/boq_counter/config.json`

## Development

    for t in tests/tc_*.rb; do ruby "$t"; done   # unit tests (ไม่ต้องใช้ SketchUp)
    ./build.sh                        # ได้ skp_cm_boq_counter_<VERSION>.rbz
