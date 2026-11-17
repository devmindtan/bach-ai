# Màn trang bị

Người dùng 2026-11-17: bảng trang bị cần thiết kế lại chuẩn hơn.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Halls of Torment ([danh sách ô trang bị](https://gamesradar.com/halls-of-torment-items-tier-list)) | Mỗi ô trên người nhân vật một món (mũ, áo, giày, găng…); trang bị là bộ ô cố định quanh nhân vật. |
| [Salt & Steel: inventory spec](https://salt-and-steel.pages.dev/docs/12/inventory-and-stash), [Abratabia: inventory UI](https://www.abratabia.com/game-ui-design/inventory-ui.php) | **So với món đang mặc** khi xem món mới; xanh ▲ = tốt hơn, đỏ ▼ = kém hơn; chi tiết món theo bố cục cố định (tên, loại, chỉ số, hiệu ứng, gợi ý); hỗ trợ cả chuột và tay cầm. |
| [Beamdog forum: so sánh trang bị](https://forums.beamdog.com/discussion/comment/808009) | Chỉ hiện dòng chỉ số **thay đổi**, không liệt kê dòng giữ nguyên. |
| [Strayspark: inventory players enjoy](https://www.strayspark.studio/blog/inventory-crafting-system-players-enjoy), [Games by Hyper: list inventory](https://gamesbyhyper.com/docs/item-management/list-inventory/) | 4–6 tab loại là đủ; sắp xếp theo độ hiếm / mới nhất, cách đang dùng phải thấy rõ; **đánh dấu món mới** cho tới khi người chơi đã xem; danh sách dễ sắp xếp hơn lưới. |
| [EarlyGame: Diablo 4 gear](https://earlygame.com/general-news/diablo-4-gear-how-to-always-be-best-equipped), [Gamepressure: so sánh đồ D4](https://www.gamepressure.com/diablo-iv/how-to-compare-items/z4109c7) | Dấu nâng cấp ngay trên món trong túi (xanh = tốt hơn), so sánh chi tiết khi xem món. |
| [UI của Destiny 2: màn nhân vật](https://medium.com/@saoliveri95/ui-of-destiny-2-the-character-screen-3463f8fc0e3a) | Nhân vật ở giữa, các ô trang bị xếp hai bên; chọn ô thì danh sách món của ô đó mở ra cạnh ô. |

## Bố cục (`src/front/equipment.tscn`, mở từ sảnh)

- Trên: "Trang bị · <tên nhân vật>"; "Quay lại (Esc)" bên phải.
- Trái (cột 380 px), kiểu búp bê giấy: nhân vật trên bệ ở giữa; 5 ô xếp quanh: **Đầu** và **Ngực** bên trái,
  **Tay**, **Chân** bên phải, **Vũ khí** dưới. Ô có đồ: icon + viền màu độ hiếm; ô trống: khung mờ + tên ô.
  Ô đang chọn viền trắng. Dưới: 4 ô chỉ số (máu, sát thương, tốc độ, tầm hút) đã tính trang bị.
- Giữa: **túi đồ**: tiêu đề + số món; **tab** Tất cả / Đầu / Ngực / Tay / Chân / Vũ khí (chọn ô trên búp bê cũng đổi
  tab); **Xếp theo** Độ hiếm (hiếm nhất trước) / Mới nhất, nút đang bật sáng viền vàng. Mỗi món một thẻ (cuộn được):
  icon trong khung màu độ hiếm, nền ánh màu độ hiếm; tên màu độ hiếm (×n khi trùng) và huy hiệu **MỚI** tới khi đã xem
  món đó; "độ hiếm · ô" (ô chỉ hiện ở tab Tất cả); mô tả ngắn một dòng; bên phải **Đang mặc** hoặc dấu so với đồ đang
  mặc ở ô đó: ▲ xanh tốt hơn, ▼ đỏ kém hơn, ⇅ vàng có hơn có kém (tooltip giải thích). Túi trống: một dòng hướng dẫn.
- Phải (cột 340 px): **chi tiết món đang xem** theo bố cục cố định: tên (màu độ hiếm), "độ hiếm · ô · chỉ <class>",
  mô tả; khối **So với đang mặc**: từng chỉ số thay đổi, số trước → sau, ▲ xanh / ▼ đỏ; rồi nút **Mặc** (nút
  chính) hoặc **Bỏ ra** khi món đó đang mặc.
- Màu độ hiếm: thường (kem), hiếm (xanh), sử thi (tím), huyền thoại (vàng cam).
