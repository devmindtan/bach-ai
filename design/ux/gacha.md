# Màn gacha

Luật: `design/gacha.md` (số liệu trong `assets/data/gacha.json`). Mở từ sảnh (thanh trên, "Gacha").
`src/front/gacha.tscn`. Người dùng 2026-11-18: hình thành game trước, làm đẹp sau; màn này dùng được là đủ.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Genshin Impact, theo [DotGG: pity systems](https://dotgg.gg/how-gacha-pity-systems-actually-work-soft-pity-hard-pity-and-the-50-50/), [Gamespace: Genshin odds](https://gamespace.com/all-articles/news/genshin-7-1-odds-what-gacha-pulls-really-tell-you/) | Công bố tỉ lệ gốc và mốc pity chắc chắn; bộ đếm pity **riêng từng banner**; nói rõ cái gì đặt lại bộ đếm. |
| [Shattered: gacha RNG fair](https://shattered.io/is-gacha-rng-provably-fair-explained-2026/), [Bestforandroid: so sánh odds](https://bestforandroid.com/tips/gacha-game-odds-pity-raid-genshin-star-rail/) | Đừng giấu tỉ lệ sau nút "?"; không dùng lời nhắc kiểu "sắp trúng"; quay 1 và quay 10 cùng tỉ lệ, ghi rõ. |
| Genshin Impact, [Sportskeeda: banner history](https://www.sportskeeda.com/esports/genshin-impact-how-count-pity-using-banner-history-details) | Nút / tab **Lịch sử** ngay trên màn quay; lọc theo banner; mỗi dòng: loại, tên món, thời điểm nhận. |

## Bố cục

- Trên: "Gacha · <tên>"; ví (Đá, vàng) cạnh tiêu đề; "Quay lại (Esc)" bên phải.
- Trái: hai banner (Vũ khí, Giáp) dạng nút; banner đang chọn viền trắng; mỗi banner ghi nội dung và bộ đếm
  "n/50 lượt tới huyền thoại chắc chắn" của chính nó.
- Giữa: kết quả lần quay gần nhất, lưới 5 × 2 thẻ: icon trong khung màu độ hiếm, tên, độ hiếm, "Mới" hoặc
  "Trùng → +n vàng". Chưa quay: một dòng hướng dẫn.
- Phải: bảng tỉ lệ (hiện sẵn, không giấu), luật pity, giá; nút **Quay 1** và **Quay 10** (nút chính), tắt khi thiếu đá.

## Lịch sử quay (2026-11-18)

- Cột giữa có hai tab: **Kết quả** (lượt quay vừa rồi) và **Lịch sử** (banner đang chọn, mới nhất trước).
- Mỗi dòng: thời điểm (ngày/tháng giờ:phút, giờ máy), tên món theo màu độ hiếm, độ hiếm, "Mới" hoặc "+n vàng" (trùng).
- Giữ `history_keep` lượt mỗi banner (`gacha.json`, 100); lưu trong slot (`gacha_log`). Bảng cuộn được, căn từ trên.
- Quay xong tự về tab Kết quả. Ảnh: `production/ui/01k2-gacha-history.png`.

## Hiệu ứng mở kết quả (6D.2, 2026-11-19)

Tham khảo: màu báo độ hiếm khi quay của Genshin / Honkai Star Rail / Wuthering Waves ([Hostedgg: gacha reveal colour culture](https://hostedgg.com/blog/gacha-pull-reveal-color-culture),
[Twinfinite: 4★ vs 5★ trong Star Rail](https://twinfinite.net/guides/difference-between-4-star-5-star-pulls-in-honkai-star-rail/),
[Samurai Gamers: WuWa rarity indicator](https://samurai-gamers.com/wuthering-waves/wuwa-wish-rarity-indicator-guide/)): màu lạnh = thường, tím
= hiếm cao, vàng = cao nhất; bỏ qua hiệu ứng không đổi kết quả. **Quyết định:** quay xong, các thẻ lật từ mặt sau lần
lượt (`CardFlip`, chung với thẻ lên cấp); **viền mặt sau báo độ hiếm** trước khi lật (thường xám, hiếm xanh, sử thi tím,
huyền thoại vàng); sử thi chờ thêm 0,2 s, huyền thoại 0,45 s, cả hai **nảy** khi lộ mặt. Bấm bất kỳ: hiện hết ngay. Đổi tab
hay dựng lại màn không lật lại. Bản xem trước cố định không lật; cờ chụp `--gacha-demo --reveal-shot`.
