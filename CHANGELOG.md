# Changelog

## [Unreleased]

### Removed
- BoQ ไม่เก็บ username/password เองแล้ว (ย้ายไป SKP CM Extensions Hub)

### Fixed
- ค่า Expected Return Days ใน Settings บันทึกไม่ได้ (ชื่อ key ไม่ตรงกันระหว่าง JS กับ Ruby)

## [1.0.0] - 2026-10-11

### Added

- แยก BoQ Counter ออกจาก Classmat Suite 2.0.0 เป็น plugin เดี่ยว
- ย้าย config + credentials จาก Classmat Suite ให้อัตโนมัติ (ครั้งแรกที่เปิด)
- เตือนเมื่อพบ Classmat Suite ตัวเก่าติดตั้งอยู่

### Changed

- รองรับ SketchUp 2024+ เท่านั้น
- ลงทะเบียนผ่าน Extension Manager (เปิด/ปิดได้)
- เก็บ config ในโฟลเดอร์ข้อมูลผู้ใช้ (ไม่หายเมื่ออัปเดต plugin)
  - Windows: `%APPDATA%/SkpCm/boq_counter/config.json`
  - macOS: `~/Library/Application Support/SkpCm/boq_counter/config.json`
