# Cây kỹ năng lâu dài (đợt 4)

> **Lưu trữ (2026-11-21):** bản v1, đã thay bằng `design/skill-tree-v2.md` (phần tiền tệ và đặt lại đã gộp vào §0 ở đó).
> Không dùng file này làm spec.

> **Đã thay bằng cây v2** (`design/skill-tree-v2.md` §1, 2026-11-19): phần cây 3×3 dưới đây là bản cũ; tiền tệ
> và đặt lại vẫn giữ.

Dữ liệu: `assets/data/skill_tree.json` (node theo class), `assets/data/run_config.json` → `essence` (Tinh hoa rơi).
Code: `src/meta/skill_tree.gd` (mua, mở khoá, đặt lại, hiệu ứng), slot giữ node đã mua và ví. Màn:
`src/front/skill_tree.tscn` (`design/ux/skill-tree.md`). Test: `tests/unit/meta/skill_tree_test.gd`.

Quyết định của người dùng (2026-11-18):
- Node mua bằng **Tinh hoa**, nguyên liệu đặc biệt **rơi từ quái tinh anh và boss** khi cày ải.
- **Đặt lại cây** cần **Tẩy Tủy Đan** (nguyên liệu hoàn trả) **và vàng**; Tẩy Tủy Đan có ở **chế độ Thử thách**
  (`design/challenge.md`), cày lại được.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Vampire Survivors, [PowerUp](https://vampire-survivors.fandom.com/wiki/PowerUp?oldid=5168), [hoàn trả](https://www.siliconera.com/how-to-reset-progress-in-vampire-survivors/) | Nâng cấp vĩnh viễn mua bằng tiền tệ cày được; giá tăng dần; hoàn lại **đủ** khi đặt lại. |
| Soulstone Survivors, [cây kỹ năng](https://www.gamepressure.com/newsroom/soulstone-survivors-unique-skills-skill-tree-and-prestige/zf4c7a) | Cây chia nhánh theo vai trò (tấn công / phòng thủ / di chuyển), mua bằng tiền tệ riêng rơi trong trận; đặt lại được. |
| [Wayline: respec design](https://www.wayline.io/blog/respec-your-game-adapting-skill-tree), [Gears Tactics: Reset Token](https://www.inverse.com/gaming/gears-tactics-reset-token-guide-respec-skill-points) | Đặt lại bằng **vật phẩm kiếm từ nội dung khó** làm quyết định có trọng lượng; phải chặn việc nhân đôi tài nguyên khi hoàn trả. |

## Tiền tệ

| Thứ | Có từ đâu | Dùng để |
|---|---|---|
| **Tinh hoa** | quái tinh anh rơi 1, boss rơi 10 (`run_config.json` → `essence`); nhặt như vật phẩm; thua vẫn giữ phần đã nhặt | mua node |
| **Tẩy Tủy Đan** | thắng một thử thách (chế độ Thử thách) | đặt lại cây (1 viên + vàng) |
| Vàng | đã có | đặt lại cây: `10 × Tinh hoa đã tiêu` (ít nhất 50) |

Tinh hoa, Tẩy Tủy Đan, vàng thuộc **slot** (mỗi nhân vật một ví).

## Cây

Mỗi class 3 nhánh × 3 tầng. Tầng 2 cần đã mua tầng 1 cùng nhánh; tầng 3 cần tầng 2. Giá: tầng 1 = 5, tầng 2 = 10,
tầng 3 = 20 Tinh hoa (cả cây 105). Mỗi node một lần mua; hiệu ứng như một thẻ cấp 1 (cộng vào chỉ số ở mọi trận
của slot, cả sảnh và màn trang bị thấy).

| Kiếm sĩ | Tầng 1 | Tầng 2 | Tầng 3 |
|---|---|---|---|
| **Cuồng nộ** (sát thương) | Sát thương +8% | Vùng đánh +10% | Sát thương +15% |
| **Thần tốc** (nhịp đánh) | Hồi chiêu −6% | Tốc độ chạy +10% | Hồi chiêu −10% |
| **Vững chãi** (sống sót) | Giáp +1 | Hồi máu +1/giây | Máu tối đa +20% |

| Pháp sư | Tầng 1 | Tầng 2 | Tầng 3 |
|---|---|---|---|
| **Hỏa lực** (sát thương) | Sát thương +8% | Vùng đánh +10% | Sát thương +15% |
| **Lưu chuyển** (nhịp phép) | Hồi chiêu −8% | Tốc độ chạy +10% | Hồi chiêu −10% |
| **Hộ mệnh** (sống sót) | Máu tối đa +15 | Hồi máu +1/giây | Tầm hút +30%, máu tối đa +10% |

## Đặt lại

- Nút "Đặt lại cây" cần 1 Tẩy Tủy Đan và vàng; hoàn **đủ** Tinh hoa đã tiêu, bỏ mọi node.
- Không đủ thì nút tắt và ghi thiếu gì.

## Kiểm thử

- Mua: đủ Tinh hoa và đã có tầng trước; trừ đúng giá; không mua lại node đã có; sai class bị từ chối.
- Đặt lại: cần Tẩy Tủy Đan + vàng; hoàn đúng tổng đã tiêu (không nhân đôi khi đặt lại hai lần).
- Hiệu ứng: node đã mua đổi chỉ số qua PlayerStats như thẻ.
- Tinh hoa: tinh anh / boss rơi, nhặt cộng vào trận, hết trận cộng vào slot (thắng hay thua).
