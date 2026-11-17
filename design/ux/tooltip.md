# Tooltip

Người dùng 2026-11-17: tooltip hiện chưa tốt (ô xám mặc định của Godot, chữ trơn), cần làm lại.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| [Flook: tooltip design 2026](https://flook.co/blog/tooltip-design) | Trễ một chút khi rê chuột, hiện/ẩn mờ dần, không bật tắt giật. |
| [UX Planet: tooltip guidelines](https://uxplanet.org/tooltip-guidelines-best-practices-and-common-mistakes-with-examples-bde5993048f0), [Mockplus](https://www.mockplus.com/blog/post/tooltip-ui-design) | Đặt sát phần tử nó nói tới; ngắn, đúng trọng tâm; một kiểu thống nhất cho cả giao diện. |
| [Abratabia: inventory UI](https://www.abratabia.com/game-ui-design/inventory-ui.php) | Tooltip món đồ theo bố cục cố định: tên (màu độ hiếm), loại, chỉ số, hiệu ứng, gợi ý. |
| [Bugnet: tooltip system](https://bugnet.io/blog/how-to-build-a-tooltip-system) | Một hệ thống dùng chung, luôn nằm trong màn hình. |

## Thiết kế (`src/ui/tip.gd`, `Tip.attach`)

- Thẻ tối viền theo màu nhấn (vàng mặc định, màu độ hiếm với đồ), bo góc, đệm 10 px, rộng tối đa 320 px.
- Bố cục cố định: icon (nếu có) bên trái; **tiêu đề** (17, màu nhấn); dòng loại (13, mờ); nội dung (14, tự xuống dòng).
- Vị trí: dưới phần tử, cách 8 px; không đủ chỗ thì lên trên; luôn trong màn hình (cách mép 8 px).
- Hiện sau 0,2 s rê chuột, hoặc ngay khi phần tử có focus (bàn phím/tay cầm); mờ dần vào 0,12 s; rời chuột / mất
  focus / phần tử bị xoá thì ẩn.
- Mọi tooltip của giao diện dùng hệ thống này (không còn `tooltip_text` mặc định).
- Chụp thử: cờ `--tip=<chữ>` mở tooltip đầu tiên có tiêu đề chứa chữ đó.
