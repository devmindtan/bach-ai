# Cây kỹ năng lâu dài (đợt 4)

Đợt 4 (`production/roadmap.md`). Dữ liệu: `assets/data/skills_knight.json`, `skills_mage.json`,
`assets/data/skill_points.json` (điểm tích luỹ per slot). Code: `src/meta/skill_tree.gd` (node),
`src/meta/skill_store.gd` (lưu lịch sử điểm). Test: `tests/unit/meta/skill_tree_test.gd`.

> **Nuôi chất build thành hệ thống lâu dài.** Mỗi slot có cây riêng; build một class đủ sâu đồng nghĩa với
> mỗi trận bắt đầu mạnh đi rõ rệt. Một slot đã max cây không được mạnh hơn slot mới 3 lần — đủ để quái không biến
> thành tép, đủ để người chơi thấy tiến trình.

## Nguyên tắc thiết kế

1. **Mỗi điểm là một quyết định.** Không có "tăng +1% sát thương tất cả" — mỗi node nằm trên một nhánh và có
   một mục tiêu rõ ràng (tầm/đòn/tốc độ/máu/khuộc).
2. **Nhánh không chéo.** Cây của Kiếm sĩ và Máy pháp sư khác nhau hoàn toàn — không "chung một tài phi hữu".
3. **Giá tăng theo tầng:** tầng 1 → 1 điểm, tầng 2 → 2 điểm, tầng 3 → 3 điểm (mỗi node).
4. **Ô có thể khoá.** Ô tầng 2 mở khi cây đó đã có ≥ 3 điểm (tầng 1, bất kỳ node). Ô tầng 3 mở khi có
   ≥ 5 điểm (tầng ≤ 2). Trước khi đủ điểm: ô mờ, bấm không mở; dòng phụ ghi "Cần n điểm ở nhánh này".
5. **Hoàn điểm bằng vàng:** nhấn "Đặt lại nốt điểm" ở góc dưới bên phải; hoàn vàng 30% số điểm đã tiêu.
6. **Không đối xứng tuyệt đối giữa 2 class** — nhánh không hoàn toàn giống nhau; mục tiêu giống nhau nhưng số
   liệu khác (Ma pháp sư sát thương phép, Kiếm sĩ sát thương cận chiến).

## Điểm kỹ năng

- **Nguồn nhận điểm (theo slot):**
  - Vượt ải lần đầu thứ n: `floor(n / 3)` điểm (ải 3, 6, 9, ..., 30 → 10 điểm tổng).
  - Mốc đạt lần đầu (10/20/30): mỗi mốc +3 điểm.
  - Trong trận: điểm kỹ năng không rơi — chỉ sau trận, không ở trong trận.
- **Giới hạn:** một slot có tối đa 30 điểm (30 ải × 1 + mốc 9). Đây là tổng 30 điểm tối đa cho mỗi slot.
- **Không tiêu điểm động khi đang chạy trận.** Điểm chỉ chi tiêu ở sảnh, sau trận.

## Kiếm sĩ — ba nhánh

| Nhánh | Phong cách | Node tầng 1 (1 điểm) | Node tầng 2 (2 điểm) | Node tầng 3 (3 điểm) |
|---|---|---|---|---|
| **Cơ học** | Chém nhanh, xoay người | `+8%` hồi chiêu mọi chiêu | `+15%` sát thương vùng | `+20%` tốc độ di chuyển |
| **Đội hình** | Chém xa, vòng quét | `+10%` vùng đánh (blade_arc, ground_slam, cleave_wave) | `+12%` tầm hút vật phẩm | `+15%` máu tối đa |
| **Vững chãi** | Giáp, hồi máu, đứng yên | `+1` giáp | `+2` hồi máu/giây | `+20%` máu |

## Pháp sư — ba nhánh

| Nhánh | Phong cách | Node tầng 1 | Node tầng 2 | Node tầng 3 |
|---|---|---|---|---|
| **Tốc độ** | Nhiều đạn, hồi chiêu | `+10%` hồi chiêu mọi chiêu | `+15%` tốc độ đạn của mọi projectile | `+20%` tốc độ di chuyển |
| **Vùng** | Diện rộng, nổ, phủ | `+15%` vùng đánh (frost_nova, blizzard, storm) | `+15%` sát thương vùng phép (vùng chịu hiệu ứng) | `+20%` máu tối đa |
| **Tập trung** | Một mục tiêu, Băng/nổ | `+15%` sát thương một mục đối với fireball/arcane_bolt/thunder_javelin/meteor | `+15%` thời gian làm chậm/đóng băng | `+2` hồi máu/giây |

## Giao diện (màn Cây kỹ năng, mở từ sảnh)

- Trên: "Cây kỹ năng · <tên nhân vật>" bên trái, điểm khả dụng bên phải ("Điểm: n").
- Trái (cột 380 px): nhân vật; dưới là **điểm đã tiêu / điểm tối đa**; dưới nữa là **vàng hoàn** (=30 % số điểm đã tiêu × 25 vàng, làm tròn) và nút "Đặt lại" (nút chính).
- Giữa: ba nhánh, mỗi nhánh một **bảng** gồm 3 ô (tầng 1, 2, 3). Ô đã mở: viền vàng, nội dung sáng. Ô khoá: ô mờ + icon khoá + "Cần n điểm ở nhánh". Cả ô là button; rõ rê-over, focus.
- Phải (cột 340 px): **chi tiết node đang xem**: tên, mô tả, số liệu trước → sau, xác nhận "Mở" (nút chính) hoặc "Đã mở".
- Bàn phím: Tab đi qua các node; Enter = mở; Esc = đóng. Tay cầm: LT/RT chọn nhánh, D-pad chọn node, A = mở.

## Dữ liệu mẫu (`assets/data/skill_points_knight.json`)

```json
{
  "_doc": "Per-slot skill points (added by winning stages & milestone; spent in the Skill Tree; see design/skill-tree.md).",
  "points": 4,
  "spent": [
    {"branch": "cơ_học", "node": "cd_cap", "cost": 1},
    {"branch": "đội_hình", "node": "area_plus", "cost": 1}
  ]
}
```

## Kiểm thử

- `tests/unit/meta/skill_tree_test.gd`: mở node, tính unlock (tầng 2 mở khi đủ tầng 1, tầng 3 khi đủ tầng 2),
  hoàn điểm (30% vàng), điểm tổng định mốc (floor(n/3) đến 30, chặn ở 30), mỗi node kẹp về min/max của PlayerStats.
- `tests/integration/meta/skill_points_test.gd`: điểm ghi vào đúng `user://slots/<id>/skill_points.json`; file hỏng không làm mất điểm của slot khác; tạo lại 30 = 10 ải + 9 mốc +1 (tổng 30, không vượt).

## Tiếp theo

- **Cung Thương (Sát thủ) và Cung thủ**: 2 class mở rộng (đợt 6), mỗi class có 3 nhánh riêng.
- **Node dùng chiêu độc nhất**: mốc 30 Chiêu độc nhất + Cây kỹ năng có node nâng nó (độc lướt, độc thả).
