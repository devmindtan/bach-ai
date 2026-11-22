# Bảng cuối trận (Vượt ải / Thất bại)

Người dùng 2026-11-22 (roadmap B): hiện chi tiết hơn — sát thương gián tiếp của nội tại / buff, máu hồi, sát thương
nhận, sát thương được giảm — mà bảng không tràn.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Vampire Survivors, bảng kết quả (thảo luận người chơi: [straightdope](https://boards.straightdope.com/t/vampire-survivors-fun-indie-rogue-lite-game-with-72-000-overwhelmingly-positive-reviews-on-steam-costs-3/962791?page=19)) | Tổng sát thương theo từng vũ khí là phần người chơi đọc nhiều nhất: giữ bảng chiêu làm tab đầu. |
| Halls of Torment ([PC Gamer review](https://www.pcgamer.com/games/action/halls-of-torment-review)) | Game có hơn 20 chỉ số; phần phòng thủ (giáp, chặn) là một nhóm riêng: tách "Nhận vào" khỏi "Gây ra". |

Tra cứu 2026-11-22 không tìm được tài liệu chính thức về màn tổng kết của các game này; bố cục dưới dựa trên bảng sẵn
có của Bách Ải và hai điều trên.

## Bố cục

- Hàng chỉ số (giờ, cấp, quái hạ, vàng) và dòng phần thưởng giữ nguyên.
- **3 tab** cùng một khung (chiều cao cố định, không nhảy khi đổi tab):
  - **Gây ra**: bảng chiêu (sát thương, %, trúng, hạ, DPS) + dòng "Gián tiếp · <nội tại>: +N sát thương".
  - **Nhận vào**: hai cột — "Sát thương nhận vào" (Quái, Vũng độc, từng sự kiện) và "Sát thương được giảm" (Giáp, nội
    tại, Vỏ đá); mỗi dòng: tên, thanh tỉ lệ, số (%). Tối đa 6 dòng.
  - **Hồi máu**: theo nguồn (Hồi máu theo thời gian, Khát máu, thẻ đặc biệt…).
- Dòng tổng và nút (Chơi lại / Ải tiếp / Về sảnh) giữ nguyên.

Dữ liệu: `run.taken_by`, `reduced_by`, `heal_by`, `enemies.bonus_by`; tên qua `run.ledger_rows`. Cờ chụp `--end-tab=`.
