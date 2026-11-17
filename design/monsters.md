# Bách Ải: quái vật

Mọi quái được vẽ trong Sprite Lab (`../../sprite-lab`, skill `pixel-sprite`), cùng phong cách với `swordsman` / `mage`:
pixel art tối giản, nhìn ngang, quay phải (game tự lật khi đi trái), viền tối 1 px, mắt rõ, màu phẳng.
Quái trên mặt đất dùng `write_anim_meta(..., ground=True)`; quái bay dùng neo ở tâm thân.

## Quy ước chung

| Mục | Quy ước |
|---|---|
| Animation tối thiểu | `move` (lặp), `attack` (1 lần), `hurt` (1 lần, nháy trắng), `death` (1 lần) · thêm `idle` nếu quái có lúc đứng yên |
| Khung | nhỏ 24×24 · thường 32×32 hoặc 48×48 · lớn/boss 64×64 – 96×96 |
| Đọc được ở đám đông | mỗi loài một silhouette + một màu chủ đạo khác hẳn nhau; tinh anh = cùng sprite, to ×1.5, hào quang theo vùng |
| Hành vi (tham số trong `monsters.json`) | `chase` (đuổi thẳng), `swarm` (đuổi theo bầy, lệch nhẹ), `charge` (dừng, lấy đà, lao), `ranged` (giữ khoảng cách, bắn), `split` (tách khi chết), `ghost` (đi xuyên quái khác) |
| Chỉ số | máu, sát thương chạm, tốc độ, exp rơi, kích thước hitbox; scale theo ải bằng công thức trong `stages.json` |

## Vùng 1: Đồng cỏ (ải 1–20) · cần cho đợt 1–3

| Quái | Khung | Hành vi | Mô tả hình | Đợt |
|---|---|---|---|---|
| Slime xanh | 24 | chase, chậm | khối thạch tròn, nảy lên khi di chuyển, mắt to | 1 |
| Dơi | 24 (bay) | swarm, nhanh, máu thấp | cánh vỗ 4 frame, thân tím than | 1 |
| Goblin | 32 | charge | da xanh lá, dao găm, tai nhọn | 1 |
| Nấm độc | 32 | chase, để lại vũng độc khi chết | mũ đỏ chấm trắng, chân ngắn | 2 |
| Sói | 48 | swarm nhanh theo đàn 3–5 | xám, dáng thấp dài | 3 |
| **Boss ải 10: Vua Slime** | 64 | chase + nhảy đè + tách 4 slime nhỏ khi máu 50% | slime to đội vương miện | 2 |
| **Boss ải 20: Tù trưởng Goblin** | 64 | charge + gọi goblin + ném rìu | goblin to, mặt nạ, rìu lớn | 3 |

## Vùng 2: Nghĩa địa (ải 21–40) · đợt 3 + 6
Xương binh (chase), Xương cung thủ (ranged), Xác sống (chậm, trâu), Hồn ma (ghost, bay) · Boss 30: Hiệp sĩ xương · Boss 40: Lich.

## Vùng 3: Hang băng (ải 41–60) · đợt 6
Người tuyết nhỏ (ném cầu tuyết), Sói băng, Pha lê băng (đứng yên, bắn mảnh), Dơi băng · Boss 50: Golem băng · Boss 60: Nữ hoàng băng.

## Vùng 4: Núi lửa (ải 61–80) · đợt 6
Slime dung nham (tách lửa), Imp (bay, ném cầu lửa), Thằn lằn lửa (charge), Rùa đá (trâu) · Boss 70: Rồng non · Boss 80: Chúa quỷ lửa.

## Vùng 5: Hư không (ải 81–100) · đợt 6
Mắt hư không (ranged), Bóng ma (ghost, nhanh), Kỵ sĩ bóng tối (charge), Xúc tu (từ đất trồi lên) · Boss 90: Kẻ gác cổng · **Boss 100: Chúa tể Hư không** (nhiều giai đoạn).

## Thứ tự vẽ trong Sprite Lab
1. Đợt 1: slime, dơi, goblin (đủ `move`, `attack`, `hurt`, `death`) + viên exp, vàng.
2. Đợt 2: nấm độc, Vua Slime (+ slime nhỏ khi tách), hào quang tinh anh, rương.
3. Đợt 3: sói, Tù trưởng Goblin, vùng 2 cơ bản (xương binh, xác sống).
4. Đợt 6: phần còn lại.

Mỗi quái: `gamekit art new <tên> --size N` → `gen.py` (silhouette trước, ASCII map tay cho đầu/mặt) → `gamekit art run` →
xem preview + `gamekit art shot <tên> sheet|move` → `gamekit art promote <tên> bach-ai` khi đạt.

## Nhịp xuất hiện trong một ải (2026-11-17)

Quái yếu (slime, dơi) lên đỉnh ở khoảng giữa ải rồi **thưa dần**, quái mạnh (goblin, rồi quái mới của các vùng sau)
**tăng dần tới cuối ải**; quái tinh anh xuất hiện theo mốc. Trong dữ liệu, một quái có thể có nhiều dòng `waves` nối
nhau (lên rồi xuống). Test `test_stages_shift_to_stronger_monsters_over_time` chặn: quái yếu nhất phải xuống dưới
60% đỉnh của nó trong 20% thời gian cuối, và máu trung bình của quái sinh ra cuối ải phải cao hơn đầu ải ≥ 30%.
