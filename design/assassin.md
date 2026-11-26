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

+15% tỉ lệ chí mạng; chí mạng ×2,5 thay vì ×1,75. Làm bằng chỉ số gốc `crit_chance` / `crit_mul` của class
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

## Bước sau (tuỳ chọn, chỉ làm khi người dùng muốn)

Chiêu riêng thêm cho Sát thủ (ví dụ dao nảy, bom khói, dao độc), mỗi chiêu một commit.
