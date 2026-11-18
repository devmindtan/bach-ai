# Màn gacha

Luật: `design/gacha.md` (số liệu trong `assets/data/gacha.json`). Mở từ sảnh (thanh trên, "Gacha").
`src/front/gacha.tscn`. Người dùng 2026-11-18: hình thành game trước, làm đẹp sau; màn này dùng được là đủ.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Genshin Impact, theo [DotGG: pity systems](https://dotgg.gg/how-gacha-pity-systems-actually-work-soft-pity-hard-pity-and-the-50-50/), [Gamespace: Genshin odds](https://gamespace.com/all-articles/news/genshin-7-1-odds-what-gacha-pulls-really-tell-you/) | Công bố tỉ lệ gốc và mốc pity chắc chắn; bộ đếm pity **riêng từng banner**; nói rõ cái gì đặt lại bộ đếm. |
| [Shattered: gacha RNG fair](https://shattered.io/is-gacha-rng-provably-fair-explained-2026/), [Bestforandroid: so sánh odds](https://bestforandroid.com/tips/gacha-game-odds-pity-raid-genshin-star-rail/) | Đừng giấu tỉ lệ sau nút "?"; không dùng lời nhắc kiểu "sắp trúng"; quay 1 và quay 10 cùng tỉ lệ, ghi rõ. |

## Bố cục

- Trên: "Gacha · <tên>"; ví (Đá, vàng) cạnh tiêu đề; "Quay lại (Esc)" bên phải.
- Trái: hai banner (Vũ khí, Giáp) dạng nút; banner đang chọn viền trắng; mỗi banner ghi nội dung và bộ đếm
  "n/50 lượt tới huyền thoại chắc chắn" của chính nó.
- Giữa: kết quả lần quay gần nhất, lưới 5 × 2 thẻ: icon trong khung màu độ hiếm, tên, độ hiếm, "Mới" hoặc
  "Trùng → +n vàng". Chưa quay: một dòng hướng dẫn.
- Phải: bảng tỉ lệ (hiện sẵn, không giấu), luật pity, giá; nút **Quay 1** và **Quay 10** (nút chính), tắt khi thiếu đá.
