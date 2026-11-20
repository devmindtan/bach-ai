# Độ hiếm của thẻ (2026-11-20)

Người dùng: chia thẻ theo độ hiếm (thường, hiếm, đặc biệt…), tỉ lệ xuất hiện theo độ hiếm, để không còn quá nhiều chiêu AoE
mạnh xuất hiện thường xuyên; buộc người chơi cân nhắc thẻ thường với thẻ hiếm; xử lý trường hợp người chơi mang toàn thẻ
hiếm vào trận. Kỹ năng của món đồ gộp vào thẻ (làm sau, `design/card-rarity.md` mục "Thẻ từ món đồ").

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Slay the Spire, Card Rewards ([wiki](https://slay-the-spire.fandom.com/wiki/Card_Rewards)) | Quay độ hiếm từng thẻ: thường 60%, hiếm vừa 37%, hiếm 3% (tinh anh 50/40/10); **bù may**: mỗi thẻ thường +1% hiếm, ra hiếm thì đặt lại. |
| Balatro, Joker ([RNG guide](https://gameplay.tips/guides/balatro-rng-mechanics-guide.html), [Jokers](https://saschb2b.github.io/game-mechanics/games/balatro/jokers)) | 70 / 25 / 5; trong cùng độ hiếm mọi lá ngang nhau; huyền thoại không nằm trong bể thường. |
| Yu-Gi-Oh! Genesys ([Konami: why a point system](https://yugiohblog.konami.com/2025/genesys/why-do-a-point-system-at-all/), [Genesys](https://www.yugioh-card.com/en/genesys/)) | **Trần điểm cho cả bộ**: lá mạnh tốn điểm, lá thường 0 điểm; một lá rất mạnh ăn gần hết ngân sách. |

**Học:** quay độ hiếm trước rồi mới chọn thẻ; bù may để thẻ hiếm không mất hẳn; giới hạn bằng điểm thay vì cấm.
**Tránh:** bộ toàn thẻ mạnh mà vẫn được chia đều thẻ mạnh. **Quyết định:** dưới đây.

## Bậc

| Bậc | Màu (như món đồ) | Tỉ lệ mỗi ô khi lên cấp | Điểm bộ thẻ |
|---|---|---|---|
| Thường | kem | 60% | 0 |
| Hiếm | xanh | 30% | 1 |
| Sử thi | tím | 9% | 2 |
| Huyền thoại | vàng | 1% | 3 |

- Gán bậc (`rarity` trong `upgrades_<class>.json`): chiêu cơ bản và chỉ số đơn giản là Thường; chiêu đơn mục tiêu mạnh,
  chỉ số rộng (hồi chiêu toàn bộ, vùng) là Hiếm; **chiêu AoE mạnh** (Lốc xoáy, Dậm đất, Cột thánh, Băng hoàn, Thiên thạch,
  Lao sét…) và thẻ số lượng là Sử thi; chiêu mốc cấp (Địa chấn, Thái dương xạ, Thần chùy, Cầu hư không, Bão tuyết, Bão tố) là
  Huyền thoại (vẫn chỉ ra sau khi đã chọn ở mốc cấp, như cũ).
- **Bù may** (Slay the Spire): mỗi ô quay ra Thường/Hiếm thì cơ hội Sử thi +1% (lấy từ Thường), ra Sử thi trở lên thì đặt lại.

## Chia thẻ lên cấp

Mỗi ô của bộ 3 thẻ: (1) quay bậc theo tỉ lệ trên; (2) chọn một thẻ **trong bộ thẻ** đúng bậc đó (theo `weight`, chưa tối đa,
chưa có trong bộ 3); (3) không còn thẻ bậc đó thì lùi xuống bậc thấp hơn; không còn bậc nào thấp hơn thì ra **thẻ lấp chỗ**
(`fillers` trong `card_rarity.json`: Túi vàng +vàng, Linh đan hồi 20% máu), không lên cấp gì.

**Mang toàn thẻ hiếm thì sao:** (a) **trần điểm**: cả bộ thẻ (8 chiêu + 6 chỉ số) tối đa **7 điểm** (`deck_budget`), nên chỉ
mang được vài thẻ mạnh; (b) bộ thiếu thẻ Thường thì 60% số ô quay ra Thường sẽ thành **thẻ lấp chỗ** (bước 3), tức lên cấp
mà gần như không mạnh thêm. Vì vậy thẻ Thường là xương sống của bộ thẻ; thẻ hiếm là điểm nhấn.

## Rương

Rương báu: 20 / 50 / 25 / 5 (rương là phần thưởng, cho bậc cao hơn). Rương vàng: không có Thường (0 / 50 / 40 / 10).

## Giao diện

- Thẻ lên cấp: viền và nhãn màu bậc (dòng "CHIÊU · Hiếm"), nền ánh màu bậc nhạt.
- Màn Bộ thẻ: mỗi ô có chấm màu bậc; thanh **"Điểm bộ thẻ n / 7"**; thêm thẻ vượt trần thì nút tắt và ghi lý do.

## Thẻ từ món đồ (đã làm 2026-11-20)

12 kỹ năng của món đồ Huyền thoại thành **thẻ chỉ số** của lớp tương ứng (`sp_<món>`, `from_item`, `special`), 3 cấp (Tim
bất diệt 2): mỗi cấp sau sát thương +25% (`damage_mul`), hồi / chu kỳ −12%, hạ quái cần ít hơn 15%, hồi máu +2%, hồi sinh
+10% máu (`special_per_level`). Bậc: Sử thi cho Thần hộ, Phong hành, Huyết quyền, Lưu tinh, Hoả y; Huyền thoại cho Phản
chấn, Bàn thạch, Thánh kiếm, Lôi ấn, Tim bất diệt, Băng ấn, Vĩnh cửu. Icon theo loại kỹ năng (`item_<kind>`), hiệu ứng hình
ảnh giữ nguyên (`fx`). Trận dựng kỹ năng từ cấp thẻ (`Run.card_specials`), nguồn sát thương là id thẻ.

Món đồ không còn kỹ năng; bậc cao hơn chỉ khác ở **giới hạn cường hoá** (Thường +3, Hiếm +5, Sử thi +7, Huyền thoại +10,
`Profile.TIER_MAX_PLUS`) và **số dòng phụ** (0 / 1 / 2 / 3, mở ở +2 / +4 / +6, `items.json` `subs`). Dòng phụ mới lấy chỉ số
khác dòng chính, giá trị Hiếm ×1, Sử thi ×1,3, Huyền thoại ×1,6.

## Test

`tests/unit/run/card_rarity_test.gd` (tỉ lệ, bù may, lùi bậc, thẻ lấp chỗ, rương), `tests/unit/meta/deck_test.gd` (trần điểm).

## Khung theo bậc (người dùng 2026-11-20)

Tham khảo: Riftbound ([độ hiếm](https://riftbound.leagueoflegends.com/en-us/news/announcements/collectability-in-riftbound-origins)):
mỗi bậc một **hình viên đá** (tròn, tam giác, vuông, ngũ giác) và khung càng lên càng cầu kỳ; MTG
([khung](https://mtg.wiki/page/Frame)) phân bậc bằng màu ký hiệu. Học: đọc bậc được mà không cần màu. Tránh: chỉ
đổi màu một ô vuông nhỏ. Quyết định: bộ dùng chung `UiKit.rarity_style / rarity_gem / rarity_badge / rarity_corners`.

| Bậc | Viên đá (ui-icons) | Khung |
|---|---|---|
| Thường | `rarity_common` đá tròn xám | viền xám 2 px, bo 3 |
| Hiếm | `rarity_rare` thoi xanh | viền xanh 2 px, nền xanh đậm, bo 4 |
| Sử thi | `rarity_epic` ngũ giác tím | viền tím 3 px, nền tím, ánh sáng 4 px, góc trang trí tím |
| Huyền thoại | `rarity_legendary` sao vàng có tia | viền vàng 3 px, nền vàng đậm, ánh sáng 8 px, góc trang trí vàng |

Dùng ở: ô Bộ thẻ, thẻ lên cấp, ô trang bị quanh nhân vật, ô túi đồ. Ô nhỏ (bộ thẻ, trang bị, túi đồ) **không** có viên đá (người dùng 2026-11-20: rối mắt),
viên đá + tên bậc hiện ở khung chi tiết bên cạnh. Viên đá luôn ở góc trên trái nên góc trang trí bỏ góc đó.
