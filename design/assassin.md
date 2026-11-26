# Sát thủ (class thứ 4)

Người dùng 2026-11-26: nhân vật do người dùng vẽ (`sprite-lab/sources/user/assassin-2026-11-25.png`); ô trang bị mũ,
áo, vũ khí (dao), giày, bao tay; **ném dao tầm gần**; "kỹ năng tự do phát triển"; mở khóa dần như mọi class.

## Tham khảo

- Brotato, Knife: vũ khí dựa vào chí mạng (bội số chí mạng cao hơn vũ khí khác)
  (https://brotato.wiki.spellsandguns.com/Knife). Lấy: nội tại Ám sát thiên về chí mạng.
- Brotato, nhân vật Crazy: bắt đầu với dao nhưng chịu −30% né tránh, người chơi than là khó thắng
  (https://steamcommunity.com/app/1942280/discussions/0/3389546207224188789). Tránh: không dựa vào né tránh, Sát thủ
  vẫn có Lướt và máu 80.
- Vampire Survivors, Knife: ném thẳng, bay nhanh, nhiều lưỡi khi lên cấp. Lấy: Phi đao bay nhanh, cấp 3/5 thêm dao;
  quyết định của mình là tầm ngắn (bay 0,45 s ≈ 250 px) để khác Tên nhanh của Cung thủ.

## Nội tại: Ám sát

+15% tỉ lệ chí mạng; chí mạng ×2,25 thay vì ×1,75 (2026-11-26: hạ từ ×2,5 khi chí mạng bắt đầu hoạt động, xem design/rogue-kits.md). Làm bằng chỉ số gốc `crit_chance` / `crit_mul` của class
(`run_sheet.gd` đã cộng chúng vào chí mạng của đòn), không cần code riêng.

## Chiêu (bước 1)

| id | Tên | Kiểu |
|---|---|---|
| throw_knife | Phi đao | chiêu khởi đầu: ném dao vào quái gần nhất, tầm gần; cấp 3: 2 dao, cấp 5: 3 dao |
| dash | Lướt | dùng chung |

Thẻ chỉ số: Tay lẹ (hồi chiêu), Dao bén (sát thương), Thêm dao, cùng các thẻ chung. Thẻ đặc biệt mốc 10/20/30:
Bước ảnh, Săn mồi, Màn đêm, Vòng dao, Dao sấm, Ảnh tốc (cùng cơ chế với bộ của Cung thủ).

## Mở khóa class

`unlocks.json` `class_<id>`: tạo được class khi có nhân vật bất kỳ đã qua ải N. Kiếm sĩ mở sẵn, Pháp sư ải 2,
Cung thủ ải 4, Sát thủ ải 6 (agent chọn, người dùng chỉnh được). Nhân vật đã tạo không bị khóa lại.

## Chiêu (bước 2, người dùng 2026-11-26: "hoàn thành cho tất cả nhân vật")

| id | Tên | Hệ | Kiểu |
|---|---|---|---|
| fan_knives | Quạt dao | Vật lý | 3–6 dao xoè hình quạt, tầm gần |
| piercing_knife | Dao xuyên | Vật lý | dao rất nhanh xuyên mọi quái |
| bleed_knife | Dao rạch | Vật lý | chảy máu |
| venom_knife | Dao độc | Bóng tối | ăn mòn + làm chậm |
| fire_knife | Dao lửa | Lửa | nổ khi trúng, bỏng |

## Chiêu (bước 3, 2026-11-26): hiệu ứng riêng (sprite-lab/lib/roguefx.py)

| id | Tên | Kiểu |
|---|---|---|
| smoke_bomb | Bom khói | quanh người: chậm, cấp 3 choáng |
| blade_ring | Vòng dao | quanh người: 6 dao xoay rồi bay ra |
| shadow_strike | Ám kích | chém chéo quái gần nhất, sát thương cao, cấp 3 chảy máu |

Đủ 10 chiêu (kể cả Lướt) như Kiếm sĩ và Pháp sư.
