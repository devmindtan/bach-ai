# Màn chọn ải và chế độ chơi

Người dùng 2026-11-17: tách sảnh chờ khỏi việc chọn màn chơi và các chế độ chơi sau này.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Vampire Survivors, [wiki Stages](https://vampire-survivors.fandom.com/wiki/Stages) | Chọn màn là **một màn riêng** sau chọn nhân vật. Các chế độ (Hyper, Hurry, Inverse, Endless) bật/tắt trong **cửa sổ riêng ngay trên màn chọn màn**; thông số thưởng của chế độ hiện ở cửa sổ phía trên. |
| Vampire Survivors, [hướng dẫn mở khoá chế độ](https://primagames.com/tips/how-to-unlock-all-stages-and-modes-in-vampire-survivors-answered-explained) | Chế độ mở dần; chế độ chưa mở vẫn hiện (khoá) để người chơi biết có. |
| [Thiết kế menu: một hành động chính](https://www.snackbar-games.com/features/new-game-truly-great-games-need-intuitive-menus) | Màn có một nút chính nổi bật (**Bắt đầu**). |

## Luồng

```text
Sảnh chuẩn bị ──Chọn ải ▶──→ Màn chọn ải ──Bắt đầu ▶──→ Trận
      ↑                         │
      └─────── Quay lại (Esc) ──┘
```

Sảnh chỉ còn chuẩn bị nhân vật (trang bị, xem chỉ số); không còn thẻ ải ở thanh dưới.

## Bố cục (`src/front/stage_select.tscn`)

- Trên: "Chọn ải" bên trái; "Quay lại (Esc)" bên phải.
- Trái (cột 220 px): **chế độ chơi**, mỗi chế độ một nút dọc:
  - **Vượt ải** (đang có): 30 ải, mở dần;
  - **Vô tận**, **Thử thách**: hiện khoá, dòng phụ "Sắp có" (đợt sau). Bấm không làm gì.
- Giữa: lưới ải của chế độ đang chọn: 3 hàng (vùng: tên vùng ở đầu hàng) × 10 ô. Ô: số ải; ✓ khi đã vượt; viền
  vàng + đầu lâu cho ải boss; mờ khi chưa mở. Ô đang chọn viền trắng.
- Phải (cột 330 px): **chi tiết ải đang chọn**: tên ải, vùng, BOSS nếu có; thời gian trụ; độ khó so với ải 1
  (máu quái ×, sát thương quái ×, mật độ ×); quái xuất hiện (icon); phần thưởng thắng (vàng, đá lần đầu / lặp lại);
  "Đã vượt n lần" hoặc "Chưa vượt".
- Dưới phải: **Bắt đầu ▶** (nút chính, rộng bằng cột phải). Ải chưa mở thì nút tắt.
- Bàn phím / tay cầm: các ô là nút, di chuyển bằng mũi tên; Enter chọn ô; nút Bắt đầu nhận focus sau khi chọn.
