# Bảng chi tiết ải (roadmap D2)

Nút **Chi tiết** ở khung thông tin ải (màn chọn ải) mở một bảng phủ lên màn hình. Bảng cho biết trước khi vào trận:
mọi quái của ải, boss, các mốc thời gian (tinh anh, boss, sự kiện) và phần thưởng.

## Tham khảo

- **Archero** (wiki chương [Land of Doom](https://archero.fandom.com/wiki/Land_of_Doom)): mỗi chương ghi số
  loại quái, danh sách boss và boss xuất hiện ở ải nào (5, 10, 15, 20). Lấy: tách riêng boss, ghi **mốc** boss.
- **Halls of Torment** ([tổng hợp các Hall](https://primagames.com/tips/how-many-levels-are-in-halls-of-torment-answered)):
  mỗi Hall có quái riêng, biến thể và boss theo thời gian. Lấy: liệt kê theo **thời điểm** xuất hiện, kèm biến thể
  (ở đây là tinh anh).
- **Vampire Survivors** (chọn màn): khung bên phải chỉ ghi tóm tắt, chi tiết nằm sau một lần bấm. Lấy: khung
  chính giữ gọn, bảng chi tiết mở bằng nút.

Học: tóm tắt ở khung chính, chi tiết sau một nút. Tránh: nhồi mọi số vào khung chính (đã tràn, D1).
Quyết định: bảng phủ hai cột, cột trái là quái, cột phải là mốc thời gian và phần thưởng; Esc hoặc nút Đóng.

## Nội dung

- **Quái**: ô hình, tên, máu, sát thương (đã nhân hệ số của ải), tốc độ; dấu "Tinh anh" nếu ải có bản tinh anh
  của con đó; boss ghi "BOSS".
- **Mốc thời gian** (theo giây, tăng dần):
  - quái mới bắt đầu xuất hiện;
  - đợt tinh anh;
  - boss;
  - sự kiện của vùng (từ ải `events.min_stage`).
- **Phần thưởng**: vàng, đá lần đầu, đá các lần sau.

## Kiểm tra

- Test `stage_detail_test.gd`: mốc thời gian sắp tăng dần, có boss ở ải boss, có sự kiện vùng từ ải min_stage.
- Ảnh `production/ui/02b-stage-detail.png`.
