# Chế độ Vô tận

## Tham khảo

- Vampire Survivors, Endless (https://www.destructoid.com/how-to-unlock-endless-mode-in-vampire-survivors/,
  https://gamespot.com/articles/vampire-survivors-1-0-patch-notes-new-stage-and-modes/1100-6508498/): hết phút cuối thì
  đợt quái chạy lại từ phút 0 thành một "vòng"; mỗi vòng quái thêm máu (+100%), sát thương (+25%), số lượng; không có
  Thần chết. Lấy: vòng lặp và hai con số máu/sát thương.
- Brotato, Endless Mode (https://brotato.wiki.spellsandguns.com/Endless_Mode): sau đợt 20 chơi tới khi chết, độ khó tăng
  theo hệ số từng đợt. Lấy: kết thúc bằng cái chết, ghi kỷ lục. Tránh: công thức lũy thừa khó đoán.

## Luật (bản đầu, 2026-11-23; số trong `assets/data/endless.json`)

- Mở khi vượt ải 10 (cùng mốc Thử thách). Chọn ở màn Chọn ải → Chế độ → Vô tận.
- Chơi ải thường cao nhất đã vượt (ải boss lùi về ải trước), vùng và đợt quái của ải đó.
- Mỗi `duration` của ải (5:00) là một Vòng: đợt quái chạy lại từ 0; quái mới sinh có máu ×(1 + 1,0 × vòng),
  sát thương ×(1 + 0,25 × vòng). Tăng theo phút (time_scale) tính trong từng vòng.
- Không có boss, không tính vượt ải, không phần thưởng ải. Chết là hết; giữ vàng, Tinh hoa, Mảnh thẻ đã nhặt.
- Nhân vật giữ thời gian lâu nhất (`slot.endless_best`), hiện ở nút chế độ và khung bên phải; bảng kết thúc báo
  "Kỷ lục mới!".
- HUD: đồng hồ "MM:SS · Vòng N".

## Chưa làm (tuỳ chọn)

- Sự kiện vùng chỉ xảy ra ở Vòng 1; số lượng quái chưa tăng theo vòng; chưa có phần thưởng theo mốc thời gian.

## Ảnh

`production/qa/evidence/endless/01-stage-select-endless.png`, `02-run-cycle-2.png`, `03-end-panel.png`.
