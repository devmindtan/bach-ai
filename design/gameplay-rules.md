# Luật gameplay Bách Ải (chốt 2026-11-16)

Bách Ải là game **2D sinh tồn kiểu Vampire Survivors**: người chơi chỉ di chuyển, mọi đòn tự đánh, quái tràn
tới theo đợt, lên cấp chọn 1 trong 3 thẻ. Mọi kỹ năng, hiệu ứng và quái mới phải hợp với lối chơi này.
Luật dưới đây là **bắt buộc khi thiết kế**; số liệu nằm trong `assets/data/gameplay_rules.json`.

## Trụ cột lối chơi

1. **Chỉ di chuyển, đòn tự đánh.** Không có nút tấn công, không ngắm. Kỹ năng tự nhắm (quái gần nhất) hoặc
   tác động quanh người.
2. **Đọc được giữa biển quái.** Hàng trăm quái trên màn hình; hiệu ứng phải rõ hình, rõ lúc trúng, không che
   cả màn hình.
3. **Nhịp nhanh, phản hồi tức thì.** Đòn ra nhanh, có số sát thương bay lên, quái chớp khi trúng.
4. **Build theo cấp.** Mỗi lần lên cấp chọn 1/3 thẻ; mỗi cấp của kỹ năng phải mạnh lên thấy rõ.
5. **Màn hình là sân đấu.** Người chơi luôn ở giữa màn hình 1280×720; mọi tầm ảnh hưởng nằm trong khung đó.
6. **Nhân vật nhìn ngang, hiệu ứng tách rời.** Nhân vật chỉ đi trái/phải; đòn đánh là sprite hiệu ứng riêng có
   hitbox; nhân vật vẽ theo lớp để mặc giáp.
7. **Hitbox là pixel.** Vùng trúng đo từ hình (Sprite Lab), không gõ tay.
8. **Nhẹ.** 600 quái + hiệu ứng vẫn 60 fps.

## Luật kiểm tra được

| Luật | Mức | Nội dung | Vì sao |
|---|---|---|---|
| `auto` | bắt buộc | Kỹ năng tự kích hoạt, hồi chiêu 0,3–6 s | Không có nút đánh; quá nhanh thì rối, quá chậm thì người chơi không thấy chiêu |
| `hitbox` | bắt buộc | Mọi animation hiệu ứng game phát có hitbox đo từ pixel | Thấy gì trúng nấy |
| `screen` | bắt buộc | Tầm ở cấp tối đa 24–360 px (đạn bay: chỉ giới hạn trên); bắn xa ≤ 560 px | Không che màn hình, không đánh trúng thứ người chơi không thấy |
| `snappy` | bắt buộc | Trúng trong 0,4 s đầu, hết frame gây sát thương trong 1,2 s; sau đó pha kết thúc (đọng lại, tan) ≤ 1,0 s; hiệu ứng lặp có `duration` | Phản hồi tức thì, đọc được nhịp; có đoạn kết rõ (người dùng 2026-11-18) |
| `directional` | bắt buộc | Đòn chém có đủ 4 hướng | Game nhắm quái gần nhất theo 4 hướng |
| `levels` | bắt buộc | 3–5 cấp, mỗi cấp tăng sát thương hoặc cỡ; bậc sprite I–V = số cấp | Lên cấp phải thấy mạnh hơn |
| `small` | bắt buộc | Khung × `px_scale`: rộng ≤ 96 px, cao ≤ 128 px (hiệu ứng thẳng đứng: sét, cột sáng); sprite mật độ đôi ≤ 192 px thật chiều ngang, ≤ 256 px chiều cao | Hiệu năng |
| `fx_craft` | nên (bắt buộc khi sprite có `px_scale`) | Hiệu ứng vùng một lần: ≥ 12 frame; ≥ 1 frame mở đầu trước frame gây sát thương; pha kết thúc 0,3–1,0 s sau frame gây sát thương cuối; vẽ mật độ gấp đôi (`px_scale` 0.5) bằng `sprite-lab/lib/fxkit.py` | Hiệu ứng thể hiện sức mạnh, xuất hiện và tan rõ ràng (người dùng 2026-11-18) |
| `class` | nên | Tag `class-<x>` khớp class sở hữu kỹ năng | Bản sắc class (băng/phép cho Pháp sư, kiếm/đất cho Kiếm sĩ) |
| `dps` | nên | DPS cấp 1 (sát thương × số nhịp trúng / hồi chiêu, một mục tiêu) trong 0,4–3 lần đòn cơ bản của class; chiêu vùng được phép thấp hơn vì trúng nhiều quái | Không có chiêu "phá game" hay vô dụng ngay từ đầu |

## Ai kiểm tra

- `gamekit test bach-ai` chạy `tests/integration/data/gameplay_rules_test.gd`: luật **bắt buộc** sai thì test
  fail, không commit được.
- Dashboard (`sprite-lab/serve-viewer.sh` → `games.html`, tab **Luật gameplay**) chấm từng kỹ năng trong game; tab
  **Kỹ năng** cho xem lúc chiêu trúng hình nhân.
- Sửa ngưỡng: sửa `assets/data/gameplay_rules.json` (và bảng này), rồi chạy lại test.

## Chuẩn vẽ hiệu ứng chiêu (người dùng 2026-11-18)

Áp dụng cho mọi hiệu ứng vùng mới hoặc vẽ lại (luật `fx_craft`; mẫu: Băng nổ `frost-nova-*`):

| Mục | Chuẩn |
|---|---|
| Độ phân giải | khung gấp đôi bản logic, `"px_scale": 0.5` trong json; khung thật ≤ 192 px, logic ≤ 96 px |
| Số frame | ≥ 12 (thường 12–18) |
| Pha | mở đầu (tụ / báo trước, ≥ 1 frame) → trúng (chớp sáng + tia khi nổ) → đọng lại → tan (dither Bayer, không mờ alpha) |
| Thời gian | trúng trước 0,4 s, hết frame gây sát thương trước 1,2 s, pha kết thúc 0,3–1,0 s |
| Khối | dùng `fxkit`: tinh thể / đá có mặt sáng, mặt tối, sống sáng và viền tối (`stack(..., outline)`); hạt có vệt (`streak`); lấp lánh 4 cánh (`sparkle`); vòng nhiều lớp (`ring_band`) |
| Bậc I–V | bậc sau thêm chi tiết của riêng nó (thêm vòng, rune, cụm tinh thể…), không chỉ to hơn |
| Khung | không có gì bị cắt ở mép (giới hạn bán kính vẽ theo cỡ khung) |
| Lớp vẽ | hiệu ứng nằm trên đất (`ground_fx` trong data) vẽ dưới quái |
| Kiểm | `gamekit art run` + xem từng frame trên nền cỏ; `gameplay_rules_test` (fx_craft) + dashboard tab Kỹ năng |
