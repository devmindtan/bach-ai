# Nhiệm vụ ngày

Dữ liệu `assets/data/missions.json`; code `src/meta/daily.gd` (trạng thái trong `Slot.daily`), màn
`src/front/missions.tscn` (`design/ux/missions.md`). Test `tests/unit/meta/daily_test.gd`.

- Mỗi ngày, mỗi nhân vật 4 nhiệm vụ lấy từ 8 loại (theo ngày + id nhân vật, cố định cả ngày, đổi lúc 0 giờ).
- Mỗi nhiệm vụ 5 đá; nhận đủ 4 thì thưởng thêm 10 đá: 30 đá/ngày = 3 lượt gacha (mặc định đề xuất 2026-11-18,
  người dùng chưa chốt; số trong JSON).
- Đếm: số trận, ải thắng, quái hạ, tinh anh/boss hạ, Tinh hoa nhặt (cuối trận), lượt quay gacha, lần cường hoá,
  thử thách thắng. Thành tựu (thưởng một lần) để sau.
