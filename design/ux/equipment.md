# Màn trang bị

Người dùng 2026-11-17: bảng trang bị cần thiết kế lại chuẩn hơn.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Halls of Torment ([danh sách ô trang bị](https://gamesradar.com/halls-of-torment-items-tier-list)) | Mỗi ô trên người nhân vật một món (mũ, áo, giày, găng…); trang bị là bộ ô cố định quanh nhân vật. |
| [Salt & Steel: inventory spec](https://salt-and-steel.pages.dev/docs/12/inventory-and-stash), [Abratabia: inventory UI](https://www.abratabia.com/game-ui-design/inventory-ui.php) | **So với món đang mặc** khi xem món mới; xanh ▲ = tốt hơn, đỏ ▼ = kém hơn; chi tiết món theo bố cục cố định (tên, loại, chỉ số, hiệu ứng, gợi ý); hỗ trợ cả chuột và tay cầm. |
| [Beamdog forum: so sánh trang bị](https://forums.beamdog.com/discussion/comment/808009) | Chỉ hiện dòng chỉ số **thay đổi**, không liệt kê dòng giữ nguyên. |
| [UI của Destiny 2: màn nhân vật](https://medium.com/@saoliveri95/ui-of-destiny-2-the-character-screen-3463f8fc0e3a) | Nhân vật ở giữa, các ô trang bị xếp hai bên; chọn ô thì danh sách món của ô đó mở ra cạnh ô. |

## Bố cục (`src/front/equipment.tscn`, mở từ sảnh)

- Trên: "Trang bị · <tên nhân vật>"; "Quay lại (Esc)" bên phải.
- Trái (cột 380 px), kiểu búp bê giấy: nhân vật trên bệ ở giữa; 5 ô xếp quanh: **Đầu** và **Ngực** bên trái,
  **Tay**, **Chân** bên phải, **Vũ khí** dưới. Ô có đồ: icon + viền màu độ hiếm; ô trống: khung mờ + tên ô.
  Ô đang chọn viền trắng. Dưới: 4 ô chỉ số (máu, sát thương, tốc độ, tầm hút) đã tính trang bị.
- Giữa: **túi đồ** của ô đang chọn (chỉ món mặc được cho class này), xếp từ hiếm nhất: mỗi món một hàng (icon trong
  khung màu độ hiếm, tên màu độ hiếm, "độ hiếm · ✓ đang mặc"); món trùng ghi "×n". Hàng thay cho lưới icon vì các
  món cùng ô trông giống nhau ở 64 px (ảnh thử lần đầu). Túi trống: "Chưa có đồ cho ô này. Thắng ải hoặc mở rương tinh anh."
- Phải (cột 340 px): **chi tiết món đang xem** theo bố cục cố định: tên (màu độ hiếm), "độ hiếm · ô · chỉ <class>",
  mô tả; khối **So với đang mặc**: từng chỉ số thay đổi, số trước → sau, ▲ xanh / ▼ đỏ; rồi nút **Mặc** (nút
  chính) hoặc **Bỏ ra** khi món đó đang mặc.
- Màu độ hiếm: thường (kem), hiếm (xanh), sử thi (tím), huyền thoại (vàng cam).
