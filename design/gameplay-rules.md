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
| `snappy` | bắt buộc | Hiệu ứng một lần ≤ 1,2 s, trúng trong 0,4 s đầu; hiệu ứng lặp có `duration` | Phản hồi tức thì, đọc được nhịp |
| `directional` | bắt buộc | Đòn chém có đủ 4 hướng | Game nhắm quái gần nhất theo 4 hướng |
| `levels` | bắt buộc | 3–5 cấp, mỗi cấp tăng sát thương hoặc cỡ; bậc sprite I–V = số cấp | Lên cấp phải thấy mạnh hơn |
| `small` | bắt buộc | Khung ≤ 96 px | Hiệu năng, cùng tỉ lệ pixel |
| `class` | nên | Tag `class-<x>` khớp class sở hữu kỹ năng | Bản sắc class (băng/phép cho Pháp sư, kiếm/đất cho Kiếm sĩ) |
| `dps` | nên | DPS cấp 1 (sát thương × số nhịp trúng / hồi chiêu, một mục tiêu) trong 0,4–3 lần đòn cơ bản của class; chiêu vùng được phép thấp hơn vì trúng nhiều quái | Không có chiêu "phá game" hay vô dụng ngay từ đầu |

## Ai kiểm tra

- `gamekit test bach-ai` chạy `tests/integration/data/gameplay_rules_test.gd`: luật **bắt buộc** sai thì test
  fail, không commit được.
- Dashboard (`sprite-lab/serve-viewer.sh` → `games.html`, tab **Luật gameplay**) chấm từng kỹ năng trong game và
  từng hiệu ứng trong kho Sprite Lab, để chọn cái nào đưa vào game.
- Sửa ngưỡng: sửa `assets/data/gameplay_rules.json` (và bảng này), rồi chạy lại test.
