# Màn tiêu đề, chọn nhân vật, sảnh chuẩn bị

Người dùng 2026-11-17: sảnh còn nhiều lỗi; cần một màn mở đầu riêng như các game khác, chọn nhân vật ở đó;
thiết kế theo các game cùng loại, không đoán.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Vampire Survivors, [wiki Main menu](https://vampire.survivors.wiki/w/Main_menu) | Luồng: "nhấn để bắt đầu" → menu chính → **Start** → chọn nhân vật → (chọn màn khi đã mở nhiều màn) → vào trận. Menu chính là một cột nút lớn; Options/Quit ở thanh trên. |
| Vampire Survivors, [wiki Character](https://vampire.survivors.wiki/w/Character) (mục Interface) | Màn chọn nhân vật: **lưới nhân vật**; **bảng chỉ số** cạnh lưới; **bảng dưới** có tên, hình, vũ khí khởi đầu, mô tả; bảng phải có tiến độ (ải đã vượt); nút xác nhận vào trận. |
| [Snackbar Games: menus](https://www.snackbar-games.com/features/new-game-truly-great-games-need-intuitive-menus) | **Tiếp tục** đặt trên **Chơi mới**: người chơi bấm "Tiếp tục" gần như mọi lần. |
| [Apple WWDC 2017 · 811](https://developer-rno.apple.com/videos/play/wwdc2017/811/), [ORK start menu](https://orkframework.com/guide/documentation/ui-system/start-menu) | Nút chơi là thứ nổi bật nhất; menu 3–5 mục; ẩn "Tiếp tục" khi chưa có save. |
| [Phân tích màn chọn nhân vật (Hades)](https://docs.google.com/presentation/d/1jsvllj2sBSOSasFaSqI4e9R211R_tVyEhe_RB9Kx0zU/htmlpresent) | Thấy **mọi** nhân vật cùng lúc, mỗi nhân vật có nét nhận diện riêng (hình, màu). |
| [Roblox devforum: save slot UI](https://devforum.roblox.com/t/having-trouble-with-a-save-slot-ui-feedback-needed/413770) | Ô save phải cho biết lần chơi trước (hình nhân vật, tiến độ) để nhận ra ngay. |


**Icon cho nút sảnh (2026-11-20).** Tham khảo: [hướng dẫn thanh điều hướng có icon](https://blog.appmysite.com/bottom-navigation-bar-in-mobile-apps-heres-all-you-need-to-know/)
(mỗi mục chính một icon dễ nhận, 3–5 mục quan trọng nhất dễ với tới), [Zach Gage's three reads](https://rymdkraftverk.itch.io/tails/devlog/86052/applying-zach-gages-three-reads-to-our-ui)
(đọc được bằng hình trước, chữ sau). Học: icon riêng cho từng nút. Tránh: icon trùng icon chỉ số, chữ nhỏ. Quyết định:
bộ `card-icons` `nav_*` (24 px), nút trên ×1, ba nút dưới ×2; hàng nút trên căn phải theo độ rộng thật.

## Luồng

```text
Mở game → Màn tiêu đề ──Tiếp tục──────────────→ Sảnh chuẩn bị (nhân vật chơi lần trước)
                      └─Chọn nhân vật → Màn chọn nhân vật ──Chơi──→ Sảnh chuẩn bị
Sảnh chuẩn bị ──Trang bị──→ Màn trang bị (design/ux/equipment.md)
              └─Chọn ải ▶─→ Màn chọn ải / chế độ (design/ux/stage-select.md) ──Bắt đầu──→ Trận → Kết quả → Sảnh
                                           └─ + Tạo nhân vật (chọn class, đặt tên)
```

- Mọi lượt chơi đều thuộc một nhân vật (slot). Sảnh không còn chế độ "không slot" và không đổi class.
- Esc ở mỗi màn quay về màn trước: chọn nhân vật → tiêu đề; sảnh → chọn nhân vật.

## Màn tiêu đề (`src/front/title.tscn`, là màn chạy đầu tiên)

- Nền: đồng cỏ trôi chậm như sảnh; hai nhân vật (kiếm sĩ, pháp sư) đứng trên bệ hai bên.
- Giữa trên: logo **BÁCH ẢI** lớn, dưới là "Vượt trăm ải".
- Giữa: một cột nút rộng bằng nhau, nút đầu là nút chính (màu nổi):
  1. **Tiếp tục**, dòng phụ "<tên> · <class> · Ải <n>" (chỉ khi có nhân vật), hoặc **Chơi** khi chưa có (mở màn chọn nhân vật ở chế độ tạo);
  2. **Chọn nhân vật**;
  3. **Cài đặt** (bảng cài đặt dùng chung);
  4. **Thoát**.
- Dưới: phiên bản ở góc trái, phím tắt ở góc phải. Lên/xuống + Enter chọn; nút đầu có focus.

## Màn chọn nhân vật (`src/front/characters.tscn`)

- Trên: tiêu đề "Chọn nhân vật" bên trái, "Quay lại (Esc)" bên phải.
- Trái (cột 360 px): danh sách nhân vật (tối đa 4) dạng ô: hình nhân vật, tên, class, "Ải n". Ô đang chọn viền
  trắng. Ô cuối "+ Tạo nhân vật" khi còn chỗ. File hỏng: ô đỏ "Không đọc được".
- Phải (bảng lớn), nhân vật đang chọn:
  - hình nhân vật lớn trên bệ, tên, "class · vai trò";
  - tiến độ: ải cao nhất, vàng, đá;
  - 4 ô chỉ số (máu, sát thương, tốc độ, tầm hút) đã tính trang bị;
  - nội tại; trang bị đang mặc (5 ô);
  - dưới cùng: **Chơi ▶** (nút chính), Đổi tên, Xóa (bấm hai lần).
- Khi chọn "+ Tạo nhân vật": bảng phải đổi thành hai **thẻ class** cạnh nhau (hình, tên, vai trò, chỉ số gốc,
  nội tại, chiêu khởi đầu); bấm thẻ để chọn; ô nhập tên; **Tạo nhân vật**. Tạo xong thì nhân vật mới được chọn.

## Sảnh chuẩn bị (`src/lobby/lobby.tscn`)

- Là nơi chuẩn bị cho nhân vật đã chọn: xem chỉ số, nội tại, bộ chiêu; nút **Trang bị** (màn trang bị) và
  **Chọn ải ▶** (nút chính, mở màn chọn ải / chế độ). Không còn thẻ ải và nút Bắt đầu ở sảnh.
- Thanh trên: **Nhân vật** (về màn chọn nhân vật), **Cài đặt**, **Menu chính**.
- Không có mũi tên đổi class, không có trang quản lý slot (đã chuyển sang màn chọn nhân vật).
- Không có nhân vật nào (file bị xoá) → chuyển sang màn chọn nhân vật.

## Kiểm tra

- `gamekit ui-shots`: `00-title`, `00b-characters`, `00c-characters-new`, `01g-lobby-slot`; soi từng vùng ×2.
- `tests/integration/ui/ux_spec_test.gd`: mỗi màn trong `production/ui/screens.json` có `spec` thì file đó tồn tại
  và có mục "Tham khảo" với ít nhất một liên kết; màn của `src/front/` và `src/lobby/` bắt buộc có `spec`.
