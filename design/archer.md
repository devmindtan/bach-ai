# Cung thủ (class thứ 3) — bản đề xuất, chờ người dùng duyệt

Trạng thái: bước 1–3 xong (nhân vật C, Tên nhanh, Mắt ưng); **tạm dừng** (người dùng 2026-11-23) chờ kế hoạch nhân vật ghép phần (sprite-lab/CUTOUT_PLAN.md).

## Tham khảo

- Archero (bắn khi đứng yên, chạy thì ngừng bắn) — lấy ý "đứng yên mạnh hơn" cho nội tại Mắt ưng.
- Vampire Survivors: mỗi vũ khí một kiểu bắn rõ (Knife bắn thẳng hướng nhìn, Runetracer nảy) — mỗi chiêu một quỹ đạo
  khác nhau, không phải 10 kiểu "mũi tên to hơn".
- Sprite: `sprite-lab/designs/cung-thu/variants.png` (3 phương án, nguồn trong `variants.py`).

## Nội tại: Mắt ưng (người dùng giữ, 2026-11-23)

Đòn trúng quái xa hơn 200 px: +30% sát thương; đứng yên 1 s thì tầm bắn +20%.

## Bộ 10 chiêu (đề xuất; hệ theo `species.json`)

| id | Tên | Hệ | Kiểu |
|---|---|---|---|
| quick_arrow | Tên nhanh | Vật lý | chiêu khởi đầu: bắn 1 mũi vào quái gần nhất; cấp 3/5 thêm mũi |
| pierce_shot | Tên xuyên | Vật lý | mũi dài bay thẳng xuyên mọi quái trên đường |
| arrow_rain | Mưa tên | Vật lý | tên rơi dày trên một vùng quanh quái đông nhất |
| fan_volley | Quạt tên | Vật lý | 5 mũi xoè hình quạt về hướng đang nhìn |
| fire_arrow | Tên lửa | Lửa | mũi nổ khi trúng, để lại đốm cháy |
| frost_arrow | Tên băng | Băng | làm chậm, cấp 4 đóng băng ngắn |
| thunder_arrow | Tên sét | Sét | trúng thì sét nhảy sang 3 quái gần |
| thorn_trap | Bẫy gai | Vật lý | đặt bẫy dưới chân, quái giẫm bị trói chân + chảy máu |
| hawk | Chim ưng | Vật lý | chim bay vòng, lao vào quái có máu cao nhất |
| dash | Lướt | — | dùng chung |

Thẻ chỉ số riêng: **Thêm tên** (như Thêm đòn / Thêm phép), Tay vững (tốc bắn), Tầm xa. Mốc 10/20/30: như hai class kia.

## Các bước (mỗi bước một commit)

1. Chọn sprite nhân vật (A/B/C) → vẽ đủ idle/run/hurt/death/dash, promote.
2. `classes.json` + `upgrades_archer.json` với Tên nhanh + Lướt; chơi được với một chiêu.
3. Nội tại Mắt ưng + test.
4. Từng chiêu còn lại: sprite hiệu ứng (2–3 phương án nếu mới) → code → test → ảnh.
5. Thẻ chỉ số, mốc, sảnh/Album/ui-shots, cân bằng bằng `--demo`.
