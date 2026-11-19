# Cây kỹ năng v2: cây nhân vật, bộ thẻ mang vào trận, cây riêng của từng thẻ 

Người dùng 2026-11-19: thiết kế lại toàn hệ thống cây kỹ năng: không chỉ cây nhân vật; người chơi **chọn trước bộ
thẻ** mang vào trận; **mỗi thẻ có cây nâng cấp riêng** (các bậc); có giao diện cây và **icon riêng cho từng bậc**;
phải tham khảo hệ thống bên ngoài.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Last Epoch, cây chuyên môn từng chiêu ([Maxroll: passives and skills](https://maxroll.gg/last-epoch/resources/passives-and-skills), [Ludo: skill trees explained](https://www.ludo.guide/guide/last-epoch/characters-builds/skills-specializations/skill-trees-explained), [Ludo: skill leveling](https://www.ludo.guide/guide/last-epoch/characters-builds/skills-specializations/skill-leveling)) | **Mỗi chiêu một cây riêng**, nút toả từ gốc, nút mạnh cần đã đầu tư ở nút trước; **điểm cây do chính chiêu đó kiếm** khi được dùng; giới hạn số chiêu được chuyên môn (5); đặt lại được. Người chơi chê **nút chỉ +% sát thương** ("lười"): nút phải đổi cách chiêu hoạt động. |
| Vampire Survivors, Seal / Banish ([Prima: Seal](https://primagames.com/tips/how-to-unlock-seal-in-vampire-survivors), [GMDQ: banish](https://gmdq.substack.com/p/vampire-survivors-banish-mechanic)) | **Loại thẻ khỏi bể trước trận** (Seal) để bộ thẻ có chủ đích; trong trận có Banish. |
| Hades, Mirror of the Night (đã dùng ở cây hiện tại) | Hàng tài năng rõ giá, đặt lại hoàn đủ. |
| Diễn đàn Last Epoch / Diablo IV / Roblox về UI cây ([icon consistency](https://forum.lastepoch.com/t/icon-consistency/72618), [D4 contrast](https://us.forums.blizzard.com/en/d4/t/ui-feedback-more-contrast-between-learned-and-unlearned-skills/9152), [big trees](https://devforum.roblox.com/t/skill-tree-design-for-big-skill-trees/3586195)) | Icon nhất quán và **có nghĩa** (không lặp một icon 17 lần); **tương phản mạnh đã học / chưa học**; gộp nút giống nhau thành một nút nhiều cấp; khung chi tiết riêng (tên, mô tả, giá, điều kiện). |

**Học:** ba tầng tách bạch (nhân vật · bộ thẻ · cây từng thẻ); cây thẻ đổi **cách** chiêu hoạt động, không chỉ cộng
số; bộ thẻ chọn trước trận. **Tránh:** cây khổng lồ khó đọc; nút "+5% sát thương" lặp; icon lặp vô nghĩa.
**Quyết định (đề xuất):** xem từng mục dưới; các điểm có ★ cần người dùng chốt.

## Quyết định của người dùng (2026-11-19)

| Câu hỏi | Chốt |
|---|---|
| Điểm mở cây thẻ | **Mảnh thẻ** (tiền tệ mới) |
| Kiểu cây thẻ | **Cây toả nhánh tự do** (kiểu Last Epoch): nhiều nút, mỗi nút nhiều cấp, phân điểm tự do |
| Bộ thẻ | **8 chiêu + 6 thẻ chỉ số**, lưu 3 bộ |
| Phạm vi đợt này | **Bộ thẻ + cây thẻ cho các thẻ chiêu**; cây nhân vật giữ như cũ; thẻ chỉ số làm sau |

## 1. Cây nhân vật (v2, người dùng 2026-11-19: "còn skill tree của nhân vật")
Cây 3 nhánh × 3 tầng mua một lần (`design/skill-tree.md`) đổi sang **cùng kiểu với cây thẻ**: nút tròn trên lưới,
nhiều cấp, toả nhánh tự do, nút then chốt; vẫn mua bằng **Tinh hoa**, đặt lại vẫn cần **Tẩy Tủy Đan + vàng**.

Tham khảo thêm:

| Nguồn | Điều lấy |
|---|---|
| Path of Exile, keystone ([PoE2 wiki: Keystone](https://www.poe2wiki.net/wiki/Keystone_passive_skill), [Prima: passive tree guide](https://primagames.com/gaming/path-of-exile-passive-skill-tree-guide), [PCGamesN](https://www.pcgamesn.com/path-of-exile-2/passive-skill-tree)) | Nút then chốt **vừa lợi vừa hại**, đổi cách chơi; chọn một hướng build. |
| Last Epoch, cây bị động ([hỗ trợ chính thức: điểm vào cây Mastery](https://support.lastepoch.com/hc/en-us/articles/46363282865435-Can-I-spend-Passive-points-in-the-Mastery-trees), [Maxroll](https://maxroll.gg/last-epoch/resources/passives-and-skills)) | Nút mạnh **khoá theo tổng điểm đã tiêu** (20 điểm cây gốc), nút nhiều cấp. |

**Học:** nút nhiều cấp nhỏ ở gần gốc, then chốt đánh đổi ở cuối, khoá bằng tổng điểm. **Tránh:** nút "+x%" lặp tên
"I/II/III"; mỗi nút một icon riêng (icon chỉ số tương ứng). **Quyết định:**
- Mỗi lớp 13 nút: gốc (hàng 0) → 3 nhánh sát thương / nhịp đánh / sống sót, mỗi nhánh 3 nút (hàng 1–3, 2–3 cấp) →
  3 nút then chốt hàng 4, **loại trừ nhau**, cần **đã dùng 12 điểm** trong cây.
- Giá mỗi cấp theo hàng: `row_cost` = [3, 4, 6, 8, 25] Tinh hoa (cả cây ≈ 150).
- Then chốt có cái giá: Cuồng huyết (sát thương +25%, máu −15%), Bão kiếm (hồi chiêu −15%, sát thương −8%), Bất
  động (giáp +3, máu +20%, tốc chạy −10%); pháp sư tương tự.
- Ô lưu cũ còn node cũ (`k_fury_1`…): **hoàn đủ Tinh hoa** theo `legacy_refund` rồi bỏ node.
- Ô lưu giữ `tree` là danh sách id; mỗi lần mua thêm id một lần (cấp = số lần xuất hiện).

## 2. Bộ thẻ mang vào trận
- **Bộ sưu tập** của lớp = mọi thẻ trong `upgrades_<class>.json`. Bộ thẻ: **8 chiêu + 6 thẻ chỉ số**; chiêu khởi đầu
  của lớp luôn nằm trong bộ (không gỡ được). Lưu **3 bộ** mỗi ô lưu, chọn một bộ đang dùng.
- Trong trận: thẻ lên cấp, phần thưởng rương và mọi lựa chọn thẻ chỉ lấy từ **bộ đang dùng** (ngược với Seal của
  Vampire Survivors: chọn cái mang theo thay vì loại cái không mang). Bộ chưa đủ thẻ thì phần còn thiếu lấy mặc định.
- Chế độ thử thách dùng bộ thẻ như ải thường.

## 3. Cây riêng của từng thẻ chiêu
- Mỗi thẻ chiêu có **cây toả nhánh**: 7–10 nút đặt trên lưới (cột, hàng), nối bằng cạnh; **mỗi nút có 1–3 cấp**.
- Mở một cấp của nút: cần **nút trước đã có ≥ 1 cấp** (cạnh nối), và các nút hàng cuối (then chốt) cần **đã tiêu ≥ N
  điểm trong cây thẻ đó**; hai nút then chốt cùng hàng **loại trừ nhau**. Tổng điểm tối đa của một thẻ: `max_points`.
- **Giá**: cấp thứ k trong thẻ đó (đếm toàn cây) tốn `cost_base + cost_step × k` **Mảnh thẻ**.
- **Đặt lại** cây một thẻ: miễn phí, hoàn đủ Mảnh thẻ (khuyến khích thử, theo Last Epoch / Hades).
- **Nút đổi cách chiêu hoạt động** (bài học Last Epoch): ngoài số (sát thương, vùng, hồi chiêu) còn **thêm số lượng**,
  **thêm hiệu ứng khi trúng** (chảy máu, bỏng, giật điện, choáng, chậm), và nút then chốt đổi hẳn lối chơi.
- Hiệu ứng nút đi qua cùng đường với thẻ trong trận: `skill_damage.<id>`, `skill_area.<id>`, `skill_cd.<id>` (mul cộng
  dồn theo cấp), `skill_count.<id>` (cộng số lượng), `on_hit` (thêm trạng thái). Cây áp dụng **ngay từ khi chiêu được
  chọn trong trận**.

## 4. Mảnh thẻ (tiền tệ)
| Nguồn | Lượng (đề xuất, chỉnh ở `card_trees.json`) |
|---|---|
| Thắng ải | 3 + ải/5 |
| Boss | 5 |
| Rương báu nhặt trong trận | 1 |
| Gacha ra bản trùng | 2 |

## 5. Icon từng nút
Icon nút = **icon thẻ gốc** + **ký hiệu thay đổi** ở góc (sát thương ⚔, vùng ◎, hồi chiêu ⌛, số lượng ×2, chảy máu,
bỏng, giật, choáng, chậm) + **viền theo loại nút** (thường: bạc; then chốt: vàng, khung to). Ký hiệu vẽ một lần trong
Sprite Lab (`card-node-glyphs`), ghép trong game nên mỗi nút có icon riêng mà vẫn nhất quán (bài học "icon consistency").

## 6. Giao diện
- Sảnh → **"Bộ thẻ"**: trái là bộ sưu tập (lọc Chiêu / Chỉ số), giữa là 3 tab bộ và 8 + 6 ô của bộ đang sửa, phải là
  chi tiết thẻ + nút **"Cây thẻ"**.
- **Màn cây thẻ**: lưới nút tròn có icon, cạnh nối sáng khi mở; nút đã học tương phản mạnh với nút chưa học; số cấp
  "2/3" dưới nút; khung chi tiết bên phải (tên, cấp, hiệu ứng mỗi cấp, điều kiện, giá, nút **Học**); thanh "Đã dùng
  x/max_points điểm" và nút **Đặt lại thẻ**.

## 7. Thứ tự làm (task nguyên tử, mỗi task kiểm tra + commit)
1. Thiết kế này. 2. `CardTree` (luật, giá, đặt lại, hiệu ứng) + dữ liệu cây Chém kiếm + test. 3. Mảnh thẻ trong ô lưu
và các nguồn rơi. 4. Bộ thẻ: lưu + trận chỉ lấy thẻ trong bộ. 5. Nối hiệu ứng cây vào chiêu trong trận. 6. Màn Bộ thẻ.
7. Màn Cây thẻ + icon nút. 8. Cây cho mọi thẻ chiêu của hai lớp.

## Cây mẫu: Chém kiếm (`blade_arc`)
| Nút | Hàng | Cấp | Mỗi cấp | Cần |
|---|---|---|---|---|
| Lưỡi bén | 0 | 3 | sát thương +10% | — |
| Vung rộng | 1 | 2 | vùng +12% | Lưỡi bén |
| Nhanh tay | 1 | 2 | hồi chiêu −6% | Lưỡi bén |
| Rỉ máu | 2 | 1 | chảy máu khi trúng | Vung rộng |
| Chém đôi | 2 | 1 | +1 nhát | Nhanh tay |
| Mạnh tay | 2 | 2 | sát thương +12% | Lưỡi bén |
| **Kiếm lửa** (then chốt) | 3 | 1 | bỏng khi trúng, sát thương +15% | 8 điểm; loại trừ Kiếm sấm |
| **Kiếm sấm** (then chốt) | 3 | 1 | giật điện khi trúng, hồi chiêu −10% | 8 điểm; loại trừ Kiếm lửa |

Tối đa 12 điểm: không mở được hết, phải chọn hướng.
