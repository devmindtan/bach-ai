# Class và nội tại

Mỗi class có **một nội tại riêng** (`classes.json` → `passive`), luôn bật từ đầu lượt, không phải thẻ. Nội tại
cho class một lối chơi riêng mà thẻ không thay được. Sau này các mốc ải 10/20/30 (roadmap đợt 3) sẽ cho chọn
một trong ba cách **nâng nội tại** của slot.

| Class | Vai trò | Nội tại | Tác dụng | Trạng thái |
|---|---|---|---|---|
| Kiếm sĩ | Cận chiến · Lì đòn | **Bất khuất** | máu dưới 30%: +25% sát thương, nhận ít hơn 30% sát thương | có trong game |
| Pháp sư | Tầm xa · Phép thuật | **Cộng hưởng nguyên tố** | quái đang có trạng thái (chậm, choáng, băng, chảy máu, bỏng) nhận thêm 20% sát thương | có trong game |
| Cung thủ | Tầm xa · Cơ động | **Mắt ưng** (đề xuất) | đòn trúng quái ở xa hơn 200 px: +30% sát thương; đứng yên 1 s thì tầm bắn +20% | đợt 6 |
| Sát thủ | Cận chiến · Chí mạng | **Ẩn sát** (đề xuất) | sau khi lướt: đòn đầu tiên trong 2 s chí mạng ×2, hạ quái thì hồi lướt ngay | đợt 6 |

## Hiển thị

- **Sảnh:** thẻ nội tại (icon, tên, mô tả) dưới chỉ số của class.
- **Trong trận:** icon nội tại cạnh thanh máu; sáng lên khi nội tại đang bật (Bất khuất khi máu thấp).
- **Bảng Nhân vật:** nội tại ở đầu cột Chỉ số.
- **Dashboard:** tab Nhân vật hiện nội tại của từng class.

## Nâng nội tại (đợt 3, mốc ải 10/20/30)

| Class | Hướng A | Hướng B | Hướng C |
|---|---|---|---|
| Kiếm sĩ | ngưỡng máu 30% → 40% | thêm hồi 2 máu/giây khi bật | khi bật: miễn choáng / đẩy lùi |
| Pháp sư | +20% → +35% | trạng thái kéo dài +30% | quái chết khi có trạng thái thì nổ lan trạng thái |

## Dữ liệu

`passive` có: `id`, `name`, `desc` và các con số (`hp_below`, `damage_mul`, `taken_mul`, `vs_status_mul`). Code:
`Run.passive_active`, `Run.damage_taken_mul`, `Enemies.vs_status_mul`; test `tests/unit/run/passive_test.gd`.
