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
| Lưới túi đồ kéo thả ([Abratabia: inventory UI](https://www.abratabia.com/game-ui-design/inventory-ui.php), [Bugnet: drag and drop in a game UI](https://bugnet.io/blog/how-to-implement-drag-and-drop-in-a-game-ui), [D4 forum: item visual clarity](https://us.forums.blizzard.com/en/d4/t/inventory-item-visual-clarity-is-a-growing-issue/177655)) | Kéo: icon theo con trỏ, **ô thả được sáng lên**; số/huy hiệu ở **góc ô**; quá nhiều huy hiệu trên icon nhỏ thì khó đọc, nên chỉ giữ một. |
| [UI của Destiny 2: màn nhân vật](https://medium.com/@saoliveri95/ui-of-destiny-2-the-character-screen-3463f8fc0e3a) | Nhân vật ở giữa, các ô trang bị xếp hai bên; chọn ô thì danh sách món của ô đó mở ra cạnh ô. |

## Ô theo class (người dùng 2026-11-25)

- Kiếm sĩ: **Mũ, Áo, Giày, Vũ khí (kiếm), Khiên**: không có găng tay, quần (`classes.json` `equip_slots`). Găng và
  quần cũ trong save đổi thành khiên cùng bậc (`items.json` `equipment_renamed`). Pháp sư giữ 6 ô.
- Búp bê: nửa đầu các ô cột trái, phần còn lại cột phải; tab túi đồ = "Tất cả" + các ô của class.

## Bố cục (`src/front/equipment.tscn`, mở từ sảnh)

- Trên: "Trang bị · <tên nhân vật>"; "Quay lại (Esc)" bên phải.
- Trái (cột 380 px), kiểu búp bê giấy: nhân vật trên bệ ở giữa; 5 ô xếp quanh: **Đầu** và **Ngực** bên trái,
  **Tay**, **Chân** bên phải, **Vũ khí** dưới. Ô có đồ: icon + viền màu độ hiếm; ô trống: khung mờ + tên ô.
  Ô đang chọn viền trắng. Dưới: 4 ô chỉ số (máu, sát thương, tốc độ, tầm hút) đã tính trang bị.
- Giữa: **túi đồ** (người dùng 2026-11-19: khung chi tiết đã có thông tin, ô giữa chỉ cần icon): tiêu đề + số món;
  **tab** Tất cả / Mũ / Áo / Quần / Tay / Giày / Vũ khí (chọn ô trên búp bê cũng đổi tab); **Xếp theo** Độ hiếm /
  Mới nhất. Món xếp **lưới 5 cột, ô 64 px** (cuộn được): icon 48 px trong khung màu độ hiếm, nền ánh màu độ hiếm;
  góc trên phải **"+n"** (nền tối đặc) khi món đã cường hoá; không thêm huy hiệu nào khác. Di chuột: tooltip tên,
  độ hiếm, ô, mô tả. Ô đang xem viền trắng. Túi trống: một dòng hướng dẫn.
- **Kéo thả:** kéo món trong túi thả vào ô đúng loại quanh nhân vật thì **mặc**; trong lúc kéo, ô đó **viền xanh**;
  ô sai loại không nhận. Kéo món đang mặc từ ô quanh nhân vật thả vào khung túi thì **tháo ra**. Bấm vẫn chọn để xem,
  nút Mặc / Bỏ ra ở khung chi tiết vẫn dùng được (bàn phím, tay cầm). Dòng hướng dẫn dưới tiêu đề nói cách kéo.
- Phải (cột 340 px): **chi tiết món đang xem** theo bố cục cố định: tên (màu độ hiếm), "độ hiếm · ô · chỉ <class>",
  mô tả; khối **So với đang mặc**: từng chỉ số thay đổi, số trước → sau, ▲ xanh / ▼ đỏ; rồi nút **Mặc** (nút
  chính) hoặc **Bỏ ra** khi món đó đang mặc.
- Màu độ hiếm: thường (kem), hiếm (xanh), sử thi (tím), huyền thoại (vàng cam).
