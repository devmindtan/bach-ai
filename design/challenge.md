# Chế độ Thử thách

Người dùng 2026-11-18: Tẩy Tủy Đan (đặt lại cây kỹ năng) có ở chế độ Thử thách, cày lại được.
Dữ liệu: `assets/data/challenges.json`. Màn: chế độ "Thử thách" ở màn chọn ải (`design/ux/stage-select.md`).

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Vampire Survivors, [Stages](https://vampire-survivors.fandom.com/wiki/Stages), [màn đặc biệt](https://en.seinanities.com/2026/06/vampire-survivors-special-stages-guide.html) | Màn thử thách là màn riêng với **luật khác hẳn** (Room 1665: đủ 1665 quái, không rơi vũ khí), mở bằng điều kiện riêng, có phần thưởng riêng. |
| [Wayline: respec design](https://www.wayline.io/blog/respec-your-game-adapting-skill-tree) | Vật phẩm đặt lại kiếm từ nội dung khó, cày lại được. |

## Luật

- Mở khi slot đã vượt ải 10. Mỗi thử thách có điều kiện mở riêng (ải đã vượt).
- Mỗi thử thách dựa trên một ải có sẵn rồi đổi luật: thời gian, hệ số máu / mật độ quái, đợt dồn thêm.
- Thắng: 1 Tẩy Tủy Đan (lần đầu 2), vàng như ải gốc; tinh anh / boss vẫn rơi Tinh hoa. Thua: giữ vàng, Tinh hoa đã nhặt.
- Không mở ải mới, không tính vào "ải cao nhất".

| Thử thách | Mở khi | Dựa trên | Luật |
|---|---|---|---|
| **Đêm dơi** | vượt ải 10 | ải 8 | 3 phút; dơi ×3 mật độ, đợt 60 dơi mỗi phút |
| **Hội tinh anh** | vượt ải 15 | ải 14 | 4 phút; mỗi 20 giây 3 quái tinh anh |
| **Vua trở lại** | vượt ải 20 | ải 20 | 3 phút; hai Vua Thạch Nhầy ở 30 giây và 90 giây; máu quái ×1,3 |

## Hiển thị

- Màn chọn ải: chế độ "Thử thách" mở (khoá kèm điều kiện khi chưa đủ); lưới là các thẻ thử thách: tên, dựa trên ải,
  luật, phần thưởng, số lần đã thắng.
- Màn kết quả: "Tẩy Tủy Đan +1".
