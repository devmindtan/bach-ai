# Mở khoá dần ở sảnh

## Tham khảo

- Archero 2 (hướng dẫn người mới, https://mobi.gg/en/tips/archero-2-beginners-guide và
  https://gamingonphone.com/guides/archero-2-beginners-guide-and-tips): tính năng mở theo chương; sau chương 1 mới mở
  Bộ sưu tập (thẻ, gacha) và Trang bị. Lấy: mở từng lớp theo tiến độ ải.
- Archero (phân tích của Game Developer, https://gamedeveloper.com/design/finding-the-fun-archero-part-2---progression):
  "drip feed" nội dung mới theo từng chương. Cộng đồng ghi các mốc mở theo chương (r/Archero FAQ). Lấy: mỗi lần mở
  chỉ thêm một thứ mới; tránh: mở hàng loạt cùng lúc.
- Bản đánh giá dự án (người dùng 2026-11-23): 4 loại tài nguyên và 6 màn chuẩn bị mở ngay ải 1 làm người mới bị ngợp.

## Quyết định (người dùng 2026-11-23: "Ok làm đi" với mốc của bản đánh giá)

| Màn | Mở khi | Ghi chú |
|---|---|---|
| Trang bị, Chọn ải, Nhiệm vụ, Album, Cài đặt | ngay từ đầu | |
| Bộ thẻ (gồm Cây thẻ) | qua ải 3 | |
| Gacha, Cây kỹ năng | qua ải 5 | |
| Thử thách | qua ải 10 | đã có từ trước (`challenges.json` `unlock`) |

- Mốc nằm ở `assets/data/unlocks.json` (`Unlocks`), so với `slot.best`.
- Nút bị khoá vẫn hiện, giữ khung nhưng mờ, không bấm/không nhận focus, có nhãn nhỏ "ải N"; tooltip "Mở khi qua ải N".
- Nhân vật cũ đã qua các mốc thì không đổi gì.

## Ảnh

`production/qa/evidence/progressive-unlocks/01-lobby-after-stage-3.png` (`--force-slots --preview-best=3`).
