# Gacha (đợt 5)

Đợt 5 (`production/roadmap.md`). Dữ liệu: `assets/data/gacha_banner.json`, `assets/data/wallet.json`
(mỗi slot). Code: `src/meta/gacha.gd`, `src/meta/wallet.gd`. Test: `tests/unit/meta/gacha_test.gd`.

> **Chỉ đá gacha, không mua vàng.** Đá gacha có được bằng chơi; pity luôn kích hoạt. Không có banner trả phí
> nào trong game này. Nếu sau này thêm IAP, phải tách mô hình (server, anti-cheat) và cân nhắc kỹ — hiện không có.

## Nguyên lý

1. **Một loại tiền duy nhất cho gacha: đá gacha (đá quý).** Không có vàng/thẻ gacha.
2. **Tỉ lệ công bố ngay trong màn gacha** (bảng "Tỉ lệ", nút dấu ?); pity công bố rõ: mở đúng nút thứ-N chắc chắn
   ra hiếm trở lên; mở đúng nút thứ-N+1 thực thi reset pity.
3. **Trùng → tái thiêng:** quay ra món đã có → +1 nguyên liệu (không mất).
4. **Hai con đường song hành:** mốc ải (đợt 3) = luôn là nâng cấp; gacha = trang bị hiếm. Cả hai đều làm mạnh.
5. **Pity công bố, không random:** mở đúng lần thứ-N (ví dụ 80) phải ra hiếm +; nếu không, chắc chắn ra hiếm +
   ở lần tiếp theo.

## Hai banner (mua bằng đá)

| Banner | Nội dung | Tỉ lệ | Pity |
|---|---|---|---|
| **Banner vũ khí** | Kiếm, gậy, vũ khí độc lạ (epic, legendary) | 20% epic, 3% legendary, còn lại rare | 80 đá chắc chắn ra legendary |
| **Banner giáp** | Giáp, mũ, găng, giày | 20% epic, 3% legendary, còn lại rare | 80 đá chắc chắn ra legendary |

- Mỗi banner xoay 30 ngày; banner "chuyên biệt lớp" luôn có cho mỗi class.
- Bảng tỉ lệ công bố trong game: epic 20%, legendary 3%, hiếm 77%.
- 1 lượt = 1 đá; 10 lượt = 10 đá (giảm 10% coin nếu muốn, không — giữ thẳng số học).

## Đá gacha: nguồn và giá trị

| Nguồn | Đá | Điều kiện |
|---|---|---|
| Vượt ải lần đầu | gems_first (10) mỗi ải; boss ải 10/20/30: gems_boss_first (50) | mỗi ải một lần duy nhất |
| Vượt ải lần thứ ≥ 2 | gems_repeat (2) | không giới hạn |
| Đá gacha từ nhiệm vụ ngày | +10 / ngày (đợt 7) | — |
| Thành tựu | +50 / thành tựu | — |

- **Không có cách mua bằng vàng**. Sẽ không có gói đá gacha trả phí trong bản này.
- **Ước lượng số đá kiếm được**: ải 1-30 vượt lần đầu: 28 ải thường × 10 + 2 boss × 50 = ~380 đá.
- **Không cap đá.** Tích luỹ bao nhiêu cũng được để dành banner mong muốn.

## Luật chơi (không thể lách)

- Mỗi slot quay riêng; đá không chuyển giữa slot.
- Đá thừa giữ lại qua mọi phiên chơi.
- Kết quả random với seed `null` — khó deterministic; test dùng seed cố định kiểm tỉ lệ.
- Sau mỗi lần quay: pity +1, nếu ≥ 80 → ra legendary chắc chắn, pity reset 0.
- **Chọn banner không ảnh hưởng tới pity của banner còn lại** (canonicalization).

## Màn gacha (mở từ sảnh)

- Trên: "Gacha · <tên nhân vật>" bên trái, đá hiện có bên phải với icon đá.
- Trái (cột 380 px): hai banner (tạm gọi A, B), mỗi cái một thẻ lớn với: banner_banner, rarity bar,
  pity count ("n/80 → chắc chắn Legendary"), nút "Quay 1" (× 1 đá, nút phụ) và "Quay 10" (× 10 đá, nút chính).
- Giữa: ma trận 10 ô kết quả (lùi-disappear khi quay, hiện 1s, rarity bg viền, có sparkle nếu epic/legendary).
- Dưới cùng: "Đá của bạn: n  ·  Pity: m/80" — không bày lượt cuối.
- Lịch sử: nút "Lịch sử" mở một modal liệt kê 50 lần quay gần nhất (date, banner, input → output).

## Dữ liệu (`assets/data/gacha_banner.json`)

```json
{
  "_doc": "Gacha rates (gacha.md). weight × rarity, pity rule-based, banner rotated monthly.",
  "banners": [
    {"id": "weapon", "name": "Banner Vũ khí", "rotate_days": 30, "items": ["knight_sword" /* + pool */]}
  ],
  "pool_weapon": [ /* rare ≤ common rulings */ ],
  "rates": {"common": 0.0, "rare": 0.77, "epic": 0.20, "legendary": 0.03},
  "pity": {"legendary": 80}
}
```

## Kiểm thử

- `tests/unit/meta/gacha_test.gd`: roll 1.000.000 lần deterministic seed, sai số ≤ 1%; pity luôn kích hoạt đúng
  lần 80; mỗi banner reset pity đúng thứ tự; không thể quay 2 banner cùng lúc.
- `tests/integration/meta/wallet_test.gd`: đá ghi/đọc có nguồn (history: `first_clear`, `repeat_clear`, ...);
  không có nguồn `purchase` trong bản đầu; file hỏng không mất đá slot khác.

## Tiếp theo

- **Set gear**: một số món cùng bộ (ví dụ 3/5 món của bộ Long Thần → +10 % sát thương); chỉ có 2 bộ.
- ** Banner "Special"**: 20 ngày, tỉ lệ tăng lên 40 % rarity trở lên, dành cho các sự kiện lễ.
