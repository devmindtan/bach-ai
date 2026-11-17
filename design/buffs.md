# Buff tạm thời (vật phẩm nhặt trong ải)

Trạng thái: **đợt A đã có trong game** (2026-11-17). Dữ liệu: `assets/data/items.json` → `buffs`,
`assets/data/run_config.json` → `buffs`. Code: `src/run/buffs.gd` (test: `tests/unit/run/buffs_test.gd`).

## Bốn buff hiện có

| Buff | Huy hiệu | Tác dụng | Thời gian | Vầng sáng |
|---|---|---|---|---|
| Rune tốc độ | vàng, tia sét | tốc độ chạy +40%, hồi chiêu −30% | 8 s | vòng rune vàng dưới chân |
| Ngọc sức mạnh | tím, thanh kiếm | sát thương mọi đòn +50% | 8 s | ấn tím quanh thân |
| Hoa hồi phục | xanh lá, dấu cộng | hồi 6 máu/giây | 6 s | hoa xanh dưới chân |
| Khiên từ | xanh dương, khiên | miễn mọi sát thương, tầm hút ×4 | 6 s | bong bóng lục giác quanh thân |

- Huy hiệu là một họ chung (`sprite-lab/lib/buffitem.py`): lục giác 18 px, khác xu (tròn) và ngọc (nhỏ).
- Buff tác động như thẻ cấp 1 (`Buffs.as_upgrades`), nên chỉ số, hồi chiêu, HUD và bảng Nhân vật đều
  thấy nó mà không cần công thức riêng. Nhặt lại buff đang chạy thì **làm mới thời gian, không cộng dồn**.
- Vầng sáng vẽ **sau** nhân vật (vẽ đè lên thì che mất người). HUD: huy hiệu nhỏ + thanh thời gian + số
  giây dưới thanh máu.

## Đợt A: xuất hiện ngẫu nhiên (đang dùng)

Lần đầu sau 15 s, rồi mỗi 25–40 s một buff ngẫu nhiên hiện trên vòng 160–300 px quanh người chơi; nằm
20 s (nhấp nháy 4 s cuối), tối đa 2 cái cùng lúc. Mọi con số ở `run_config.json` → `buffs`.

**Câu hỏi khi chơi thử:** người chơi có thấy buff và đổi hướng đi để nhặt không? Có buff nào mạnh quá
(Khiên từ ở cuối ải) hoặc vô vị (Hoa hồi phục lúc đầy máu) không?

## Kế hoạch tiếp theo

| Đợt | Nội dung | Ghi chú |
|---|---|---|
| B | Rơi từ quái tinh anh và rương (đợt 2 roadmap) thay cho một phần xuất hiện ngẫu nhiên | tỉ lệ theo loại quái trong `monsters.json` |
| B | Trọng số theo tình huống: máu thấp thì Hoa hồi phục dễ ra hơn | giữ RNG có seed để test được |
| C | Thẻ nâng cấp tác động lên buff: "buff kéo dài +X%", "tầm nhặt buff" | thêm khóa `buff_duration` vào PlayerStats |
| C | Debuff do quái gây ra (chậm, độc, chảy máu): dùng cùng hệ thống `active` + vầng sáng | tab Hiệu ứng trên dashboard đã sẵn |
| D | Buff hiếm (viền bạc/vàng), buff riêng theo class | sau khi có Pháp sư |

## Kỹ năng dash (đã ghi nhận, 2026-11-17)

Sau này có kỹ năng dash, nên nhân vật cần thêm animation `dash` (trái/phải như các animation khác), làm
trong Sprite Lab trên các lớp trang bị hiện có (head, chest, arms, legs, weapon) để giáp đi theo. Nên làm
cùng lúc với thiết kế kỹ năng dash (khoảng cách, bất tử trong lúc lướt, hồi chiêu) để animation khớp thời
gian lướt.
