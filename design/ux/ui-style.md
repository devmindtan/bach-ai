# Phong cách giao diện và tính năng lõi

Người dùng 2026-11-17: cần phong cách thiết kế rõ ràng trước khi xây dựng đúng cho mọi màn, tránh rối.
Tài liệu này là **chiều sâu của UI**, không phải checklist — mọi UX mới đều có thể trỏ về đây.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Vampire Survivors ([như nhiều bài phân tíchUI](https://www.gameinformer.com/lists/the-11-best-ui-designs-in-gaming)) | Luôn có **một hành động nổi bật** mỗi màn; hộp thoại to, chữ to, ít mục. |
| [Ään ui/gambi references](https://game UI:UI/UX pattern libraries) | Khung 4px viền, bán nguyệt chảy, dải màu của công cụ scope. |
| Tài liệu nội bộ Bách Ải | Hệ thống hiện có: màu chính `GOLD #c9a65a`, text creme `#f2ecd8`, muted `#b9b2a0`, panel `#2a2438`, hover `#3b3352`. |

## Phong cách chung: "Samsara dễ đọc"

1. **Đọc nhanh hơn đẹp.** Mọi UX phải rõ trong 1 giây: mục tiêu, hành động, phản hồi — không cần học.
2. **Chữ creme trên nền than tối.** Không dùng màu bão-hoà cao trên nền đen; không trắng tinh (#e8e2d0 mới đủ tương phản trên #1b1726).
3. **Đường viền luôn hiện diện.** 1 px PIP_EDGE + bóng 2 px (bỏ qua khi không có đủ kích thước để ve).
4. **Hình vuông, không tròn.** PanelButton không corner-radius > 4. Tròn thì chỉ ở icon nhỏ (thẻ chiêu/mode).
5. **Màu độ hiếm:** kem (thường) → xanh (hiếm) → tím (sử thi) → vàng cam (huyền thoại). Luôn kèm icon hiếm xác định, không chỉ bằng màu.
6. **Animations tối thiểu.** Chỉ khi: đạt mốc, rơi đồ, mở rương, lỗi — trễ sang chạy một màu nổi 2 frame rồi mất.
7. **Thùng chứa rõ ràng.** Mỗi màn có đúng một hộp chính (ProgressBox) và các cột trong đó; không có floating panel lẻ không có ai ở ngoài controls được kết nối.

## Cơ bản từng thành phần

| Thành phần | Kích thước chuẩn | Màu | Ghi chú |
|---|---|---|---|
| Header (toolbar) | 64 px | panel, `GOLD` title | Tiêu đề bên trái; nút bên phải |
| Panel (card) | 16 px round radius, 16–22 px padding | `PANEL #2a2438`, border `GOLD` 2 px | Mọi cột/khung |
| Button (chính) | 380 × 52 px, 26 px chữ | `GOLD` hoặc accent-màu class | Mỗi màn đúng một; không nằm chung cùng hàng với nút phụ cùng cỡ |
| Button (phụ) | 140 × 42 px, 18 px chữ | `PANEL`, hover `PANEL_HOVER` | Throat-of-the-lobby buttons |
| Label (chính) | 20–24 px chữ | `TEXT #f2ecd8` | Đầu cột, tiêu đề, chỉ số |
| Label (mô tả) | 12–14 px | `MUTED #b9b2a0` | Mô tả, ghi chú |
| Icon | 16–48 px tùy context | `UiIcons.*` | Luôn `TEXTURE_FILTER_NEAREST` |

## Navigation toàn cục (quy tắc Esc)

```text
Tiêu đề ──┬── Chọn nhân vật ──┬── Sảnh chuẩn bị ──┬── Trang bị
          │                    │                   ├── Cây kỹ năng (đợt 4)
          │                    │                   ├── Gacha (đợt 5)
          │                    │                   ├── Chọn ải ▶── Trận ── Kết quả ──┐
          │                    │                   └── Cài đặt                        │
          │                    └── (đóng, quay về màn trước)                         │
          └── Cài đặt ────────────────────────────────────────────────────────────────┘
```

- Esc mọi màn → màn trước; Esc trong trận → tạm dừng; Esc trong panel → đóng.
- Enter trên mọi nút nhưng cần focus state rõ, và một màn chỉ focus vào trước đang dùng.
- Màn nào cũng có tiêu đề; màn lớn (Chọn nhân vật, Trang bị, Cài đặt, Gacha, Cây kỹ năng) còn có
  "Quay lại (Esc)" bên phải.

## Các màn và tính năng cốt lõi

| Màn | Scene | Tính năng | Phải có |
|---|---|---|---|
| Tiêu đề | `src/front/title.tscn` | Chơi / Chọn nhân vật / Cài đặt / Thoát | Hình nhân vật trên bệ |
| Chọn nhân vật | `src/front/characters.tscn` | Tạo/chơi/xoá nhân vật, chọn class | Bảng chỉ số + nội tại |
| Sảnh chuẩn bị | `src/lobby/lobby.tscn` | Xem chỉ số, nội tại, trang bị, chọn ải | Các ô chỉ số; nút **Bắt đầu** |
| Chọn ải | `src/front/stage_select.tscn` | Chọn ải/chọn chế độ | Lưới 3 vùng × 10 ải; boss/mốc có viền vàng |
| Trang bị | `src/front/equipment.tscn` | Mặc/tháo đồ (búp bê giấy) | So sánh với đồ đang mặc; rarity bar |
| Cây kỹ năng | `src/front/skill_tree.tscn` (đợt 4) | Mở/hoàn điểm | 3 nhánh/class; pity-vàng khi unlock |
| Gacha | `src/front/gacha.tscn` (đợt 5) | Quay 1/Quay 10 | Tỉ lệ công bố, pity count |
| HUD | `src/run/run.tscn` | Đòn tự đánh, vào ải | Vòng hồi chiêu, HP, exp bar |
| Lên cấp | `src/run/run.tscn` | Chọn 1/3 thẻ | 4 thẻ nếu mốc 20 (Thêm lựa chọn) |
| Tạm dừng | `src/run/run_panels.gd` | Bảng thợ nâng cấp/Pause | Chỉ số, mọi kỹ năng |
| Kết quả | `src/run/run_panels.gd` | Thắng/thua, mốc, trang bị rơi | Vào HUD damage table; mốc mới chọn 1/3 |
| Cài đặt | `src/ui/settings_panel.gd` | Fullscreen/Scale/Đổi class | Dùng chung mọi màn |

## Không hình (no image)

- Không dùng ảnh nền hoa mỹ; mọi nền là `GRASS` tiles vẽ tay (hiện có) hoặc trơn màu.
- Không animation menu (mọi phần tử tĩnh trừ progress/hit bar).
- Không icon động; mọi icon tĩnh trừ nhấp nháy quái hurt (đã có).

## Icon & dữ liệu

- Icon: mọi icon mới từ `sprite-lab/sprites/ui-icons/` (gen.py), promote qua `gamekit art promote`.
- Màu rarity: `common` `#e8e2d0`, `rare` `#6fb7ff`, `epic` `#c38df5`, `legendary` `#f2b64a`.
- Rarity chỉ đổi **màu viền/icon nền** trong lists (loot drop, gear), ngoài trận hiển thị ở header ô.

## Kiểm thử đồ hoạ

- `tests/integration/ui/ux_spec_test.gd`: mọi màn trong `production/ui/screens.json` phải có `design/ux/<màn>.md`
  có mục `## Tham khảo` kèm ít nhất một link.
- `gamekit ui-shots <game>` để sinh `production/ui/*.png`; xem `--lobby-*` / `--front-*` trong tests.
