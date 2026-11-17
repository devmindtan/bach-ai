# Trang bị

Trạng thái: **bản đầu có trong game** (2026-11-17). Dữ liệu `items.json` → `equipment`; hồ sơ người chơi
`src/meta/profile.gd` (`user://profile.json`); test `tests/unit/meta/profile_test.gd`.

- **5 ô**: đầu, ngực, tay, chân, vũ khí (đúng các lớp vẽ của nhân vật). Mỗi class mặc bộ riêng.
- **Món đồ**: tên, ô, độ hiếm (thường / hiếm / sử thi: màu khung), có thể chỉ cho một class, `effects` như thẻ
  nâng cấp (PlayerStats cấp 1), icon trong `ui-icons`.
- **Nhận**: thắng ải được 1 món ngẫu nhiên hợp class; mở rương (quái tinh anh) 25% có thêm 1 món; lần đầu chơi được
  Mũ sắt + Ủng nhẹ, mặc sẵn cho mọi class. Hiện trên màn kết quả.
- **Mặc**: sảnh → Trang bị: mỗi ô một dòng, "Đổi" chọn lần lượt đồ hợp trong túi (và tháo). Ô chỉ số ở sảnh và bảng
  Nhân vật tính cả đồ (nguồn ghi tên món đồ).

## Tiếp theo

1. **Hình trên người**: vẽ lớp giáp theo ô (Sprite Lab, cùng tư thế minifig), `SpriteSheet.compose_layers` thay
   đúng ô khi mặc (nhân vật đã vẽ theo lớp cho việc này).
2. Thêm đồ theo vùng ải, độ hiếm sử thi có hiệu ứng đặc biệt (ví dụ: chiêu đầu tiên +1 số lượng).
3. Nâng cấp / phân rã đồ bằng vàng (vàng hiện chỉ đếm) — cùng đợt với cây kỹ năng (roadmap đợt 4).
4. Lưu theo **slot nhân vật** (roadmap đợt 3) thay cho một hồ sơ chung.
