# Bách Ải — Kịch bản thiết kế tổng quan

> Tài liệu chủ (master document). Mọi hệ thống của game được liệt kê ở đây; chi tiết nằm ở các
> file cùng cấp. Mọi thay đổi phạm vi hệ thống phải cập nhật file này. Ngày chốt: 2026-11-17.

**Pitch:** Survivors-like nhập vai: chọn class, 30 ải (100 ải trong tương lai), mỗi lượt dựng bộ
chiêu riêng, sức mạnh lâu dài vào cây kỹ năng, trang bị và gacha.

**Thể loại:** survivors-like (auto-attack, đợt quái ập tới) + RPG theo class.
**Nền tảng:** PC trước (Steam); mobile sau. **Camera:** trên xuống; nhân vật nhìn ngang.
**Người chơi:** một người, 1–4 slot nhân vật.

## Trụ cột (nguồn: `design/game-brief.md`)

1. **Vượt ải dễ hiểu, xây build thì sâu.** Vòng lặp: ải 5 phút, chọn 1 trong 3 mỗi cấp, học theo class.
2. **Mỗi lượt là một build khác.** 2 class × nhiều kỹ năng × bậc I–V; không có build "tối ưu duy nhất".
3. **Tiến trình dài hạn rõ ràng.** Cây kỹ năng + trang bị + gacha làm người chơi thấy nhân vật mạnh dần.
4. **Đọc được trong biển quái.** Mọi hiệu ứng rõ hình, rõ lúc trúng; không che cả màn hình.
5. **Chạy nhanh.** 600 quái + hiệu ứng vẫn 60 fps; nút bấm ít, phản hồi tức thì.

## Lộ trình (tier)

Đợt 1 ✅ · Đợt 2 ✅ · Đợt 3 ✅ (slot, 30 ải, mốc) · Đợt 4 (đang làm) · Đợt 5 (gacha) · Đợt 6 (100 ải) · Đợt 7 (hoàn thiện, Steam) · Đợt 8 (mobile).

## Sơ đồ hệ thống

```text
┌──────────────────────────────────────────────────────────────┐
│ TIỀN TRẬN (sáng, sảnh)                                       │
│  Tiêu đề ─ Chọn nhân vật ─ Sảnh chuẩn bị                    │
│                                                              │
│  Sảnh: thẻ chỉ số (gồm trang bị), nội tại, chiêu, mốc 10/20/30 │
│   ├─ Trang bị (Màn Trang bị)                                 │
│   ├─ Cây kỹ năng (Đợt 4, design/skill-tree.md)               │
│   ├─ Gacha (Đợt 5, design/gacha.md)                          │
│   └─ Chọn ải / chế độ (design/ux/stage-select.md)            │
└───────────────────────────┬──────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ TRẬN CHIẾN (tối, trong ải)                                    │
│  Di chuyển → chiêu tự đánh → quái rơi kinh nghiệm/vàng        │
│  → lên cấp → 3 thẻ → sống tới hết giờ + boss (ải 10/20/30)    │
│  → mốc cấp 10/20/30: 1/3 phần thưởng cho trận đó              │
└───────────────────────────┬──────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────┐
│ HẬU TRẬN (kết quả)                                           │
│  Vàng, đá gacha, điểm kỹ năng + trang bị rơi (boost lần đầu)  │
│  → nâng cây kỹ năng, quay gacha, mặc đồ → ải tiếp             │
└──────────────────────────────────────────────────────────────┘
```

## Các hệ thống (tier nguồn)

| # | Hệ thống | Trạng thái | File | Ghi chú |
|---|---|---|---|---|
| 1 | Vòng chiến (trong trận) | ✅ | `design/gameplay-rules.md` | chiêu tự đánh, thanh máu, HUD |
| 2 | Công thức độ khó (stages) | ✅ | `design/progression.md` | 30 ải, công thức đơn điệu tăng |
| 3 | Quái | ✅ | `design/monsters.md` | slime/dơi/goblin/boss; `waves/stage_NNN.json` |
| 4 | Class & nội tại | ✅ | `design/classes.md` | 2 class đầu (Kiếm sĩ, Pháp sư) |
| 5 | Nâng cấp trong trận | ✅ | `assets/data/upgrades_<class>.json` | 6–9 thẻ mỗi class, bậc I–V |
| 6 | Cây kỹ năng (dài hạn) | 🛠 Đợt 4 | `design/skill-tree.md` | mua bằng Tinh hoa (tinh anh/boss rơi), đặt lại bằng Tẩy Tủy Đan + vàng |
| 14 | Chế độ Thử thách | 🛠 Đợt 4 | `design/challenge.md` | thử thách luật riêng, rơi Tẩy Tủy Đan |
| 7 | Trang bị | 🛠 Đợt 4 | `design/equipment.md` | 5 ô, rarity, ngẫu nhiên qua ải |
| 8 | Gacha | 🛠 Đợt 5 | `design/gacha.md` | **full design** |
| 9 | Mốc cấp 10/20/30 (trong trận) | ✅ | `design/progression.md` (mục mốc) | 6 chiêu độc nhất, 3 nội tại, 3 luật; chỉ trong trận |
| 10 | Slot nhân vật | ✅ | `design/progression.md` (mục slot) | tối đa 4 slot, schema v1 |
| 11 | Trang bị rơi (elite) | ✅ | `assets/data/run_config.json` (rewards) | thắng ải 1 món, rương tinh anh 25% |
| 12 | UX / màn hình | 🛠 | `design/ux/` | xem `ux/ui-style.md` cho hướng thiết kế |
| 13 | Hiệu ứng/trạng thái | ✅ | `design/statuses.md` | chậm, choáng, băng, chảy máu, bỏng, điện giật |

## Các loại phần thưởng (những con số)

| Đợt | Đơn vị | Từ đâu | Làm gì |
|---|---|---|---|
| Trong trận | kinh nghiệm | quái | lên cấp, chọn 1/3 thẻ |
| Trong trận | vàng | quái, boss | **chỉ** điểm mua sắm ngoài trận (gacha/đồ) |
| Trong trận | Tinh hoa | quái tinh anh (1), boss (10) | mua node cây kỹ năng |
| Ngoài trận | Tẩy Tủy Đan | thắng thử thách | đặt lại cây kỹ năng (kèm vàng) |
| Ngoài trận | vàng | ải + vàng trong trận | mua đồ / quay gacha / đổi trang bị |
| Ngoài trận | đá gacha | ải lần đầu & lặp, boss | quay gacha |
| Ngoài trận | trang bị | ải (1 món/trận), rương elite (25 %) | mặc vào 5 ô, đổi build |

## Người chơi thấy gì (journey)

```text
Lần đầu → Tiêu đề → Chọn nhân vật (tạo Kiếm sĩ/Pháp sư) → Sảnh → Chọn ải 1
→ Ải 1: slime, dơi, goblin; 5 phút; thắng → Kết quả → Sảnh → Ải 2 (hoặc ải 1 lại)
→ Ải 3…10 (Vua Thạch Nhầy); trong trận lên cấp 10/20/30 chọn 1/3 phần thưởng mốc → Ải 11…20 (boss ải 20)
→ Ải 21…30 (boss ải 30) → slot mạnh dần qua cây kỹ năng + trang bị
→ Mở ải 31+ (vùng mới) khi có đủ 30/30 (hoặc vượt ải 30 đủ số lần)
```

## Quyết định còn mở (cập nhật khi có đáp án)

| Chủ đề | Câu hỏi | Ai quyết | Hạn |
|---|---|---|---|
| `stages.json` | ải 100 / ấu cấp bao nhiêu một boss | người chơi | đợt 3 xong (trước đoi 6) |
| Cây kỹ năng | đã chốt 2026-11-18: Tinh hoa từ tinh anh/boss, đặt lại bằng Tẩy Tủy Đan (thử thách) + vàng | người chơi | ✅ |
| Gacha | tỉ lệ 55/30/11/4, pity 60/100 chưa chốt | người chơi | chốt trước đợt 5 |
| Màu đặc trưng | Pháp sư: xanh dương, Kiếm sĩ: vàng đỏ | thiết kế | trước đợt 7 |

## Ràng buộc cứng (không đổi)

- **Vượt ải là cách duy nhất lấy đá gacha** (có thể thêm mission sau); không mua vàng/tiêu tiền.
- **Slot nhân vật**: class của slot **cố định khi tạo**; mỗi slot có tiến độ, đồ, kỹ năng riêng.
- Không có revive giữa trận (trừ phần thưởng mốc cấp 30 "Bất tử", chỉ trong trận đó).
- Không có trang bị thanh toán; mọi trang bị lấy từ chơi.
- Không có chế độ chơi mạng.

## Tài liệu liên quan

| Spec | Vai trò |
|---|---|
| `design/master.md` | **file này** — bản đồ hệ thống |
| `design/skill-tree.md` | Đợt 4 — cây kỹ năng lâu dài |
| `design/challenge.md` | Đợt 4 — chế độ Thử thách |
| `design/gacha.md` | Đợt 5 — hệ thống gacha |
| `design/equipment.md` | Trang bị: ô, rarity, drop rate |
| `design/progression.md` | 30 ải / slot / mốc |
| `design/gameplay-rules.md` | Luật cứng của chiêu/hiệu ứng |
| `design/classes.md` | Class và nội tại |
| `design/monsters.md` | Quái vật |
| `design/statuses.md` | Hiệu ứng |
| `design/data-schemas.md` | Schema dữ liệu |
| `design/ux/` | Các màn: front-end, equipment, stage-select, ui-style |
