# Game Brief: Bách Ải (tên tạm)

## In your words
"Hiện tại tôi vẫn chưa có ý tưởng cụ thể cho tựa game sắp làm chi biết là nó sẽ theo hướng rpg kết hợp nhiều yếu tố. Ví dụ tôi muốn lấy ý tưởng gameplay như vampire survival kết hợp thêm nhiều yếu tố của rpg như skill tree, exp,... Cụ thể là thế này người chơi sẽ vào 1 màn chơi với số lượng màn là 100 (hoặc hơn trong tương lai) với độ khó tăng dần các quái vật sẽ xuất hiện liên tục theo từng đợt. Nhiệm vụ của người chơi là sống sót, mỗi lần lên cấp sẽ được chọn 1 trong 3 mốc nâng cấp (dựa vào class của nhân vật đó), ngoài ra còn sẽ được chọn 1 trong những hiệu ứng đặc biệt nếu đạt các stage 10 - 20 - 30. Và đặc biệt người chơi sẽ build nhân vật của mình mong muốn để có thể vượt qua được màn 100 (tạm thời là vậy sau này có thể mở rộng thêm các chế độ endgame khác). Và tôi cũng muốn có chế độ gacha trong game ví dụ quay để lấy vũ khí với hiệu ứng buff đặc biệt, giáp,... Nếu họ chán họ có thể tạo 1 slot nhân vật mới để bắt đầu cày lại với lối build khác."

"Và trước tiên cần phải làm 1 kế hoạch đầy đủ và thực hiện theo từng đợt. Tập trung vào gameplay chính trước sau đó mới tới các vấn đề khác. Ngoài ra hiện chưa có quái vật cũng cần phải thiết kế quái vật hoặc là tận dụng các quái vật cơ bản từ repo trong hệ thống trước."

Quick questions (2026-11-16): tiến trình = **mỗi màn là một lượt mới** (vào màn bắt đầu cấp 1); quái vật = **vẽ mới trong Sprite Lab**;
nền tảng = **"Tôi muốn làm cả 2 nhưng mà hiện cứ làm bản pc trước. Ví dụ đăng lên steam chẳng hạn."**

**Pitch:** Chọn một nhân vật theo class, lần lượt vượt 100 ải sinh tồn giữa biển quái, mỗi lượt dựng một bộ chiêu khác nhau, còn sức mạnh lâu dài thì dồn vào cây kỹ năng, trang bị và vòng quay gacha của chính nhân vật đó.

**Genre:** survivors-like (auto-attack, sống sót qua các đợt quái) + RPG nhập vai theo class, tiến trình dài hạn.

**Controls:** PC: WASD / mũi tên để di chuyển (đánh tự động), chuột hoặc phím 1–3 để chọn nâng cấp, Esc tạm dừng; tay cầm hỗ trợ ở bản Steam. Mobile (sau): joystick ảo.

**Question:** Một lượt 5 phút có đủ căng và đủ "đã" để người chơi muốn vào lượt tiếp, và lựa chọn 1-trong-3 theo class có tạo ra những build khác nhau thật không?

**Hooks:** (1) 100 ải độ khó tăng dần, mỗi 10 ải một boss và một mốc chọn hiệu ứng đặc biệt vĩnh viễn; (2) mỗi slot nhân vật là một con đường build riêng (class + cây kỹ năng + trang bị gacha), muốn thử lối khác thì mở slot mới.

**Intent:** no goal to reach: không (mục tiêu là ải 100) · soft or no failure: không, thua là chơi lại ải đó · payoff builds: có, you said ("build nhân vật … để vượt màn 100")

## Look and references
- Look: pixel art tối giản, nhìn ngang (sprite quay phải và lật khi đi trái) trên sân nhìn từ trên xuống kiểu survivors; nhân vật 48×48 cao ~26–30 px, viền tối 1 px, mắt rõ; quái cùng phong cách, phân biệt bằng silhouette và màu; hiệu ứng chiêu sáng màu theo nguyên tố. Mọi sprite làm trong Sprite Lab (`../../sprite-lab`). *(inferred (strong): from the existing mage / swordsman the user approved)*
- References: Vampire Survivors (vòng lặp đánh tự động + chọn 1/3, you said); Brotato / 20 Minutes Till Dawn (lượt ngắn, build theo class) *(guessed)*; gacha vũ khí/giáp kiểu game mobile RPG *(you said "gacha")*.
- View: 2D · Camera: góc nhìn từ trên xuống, bám theo người chơi, sân rộng có giới hạn mềm.

## First minute
Chọn slot "Kiếm sĩ" → ải 1. Nhân vật đứng giữa bãi cỏ, kiếm tự chém vòng cung theo hướng đi; vài slime bò tới từ mép màn hình, chém trúng thì nổ ra viên kinh nghiệm. Nhặt đủ → lên cấp, game dừng, hiện 3 thẻ (ví dụ "Chém xoáy", "+20% máu", "Kiếm dài hơn"); chọn "Chém xoáy" → ngay đợt dơi kế tiếp, vòng xoáy quét sạch cả bầy: khoảnh khắc "build bắt đầu thành hình".

## Challenge
Phút 2–3 của ải 1 đợt dơi bay nhanh vây quanh, phút 4 có quái tinh anh (to, có hào quang), phút 5 boss nhỏ; thua là mất phần thưởng còn lại của lượt. Từ ải sau, quái nhiều máu hơn, đông hơn, đổi loài theo vùng (mỗi 20 ải một vùng), mỗi 10 ải có boss. Ải 100 chỉ vượt được với build đã đầu tư (cây kỹ năng, trang bị, hiệu ứng mốc).

## Core loop
- Trong lượt: di chuyển né quái, chiêu tự đánh → quái rơi kinh nghiệm/vàng → lên cấp, chọn 1/3 nâng cấp của class → sống qua các đợt và boss.
- Sau lượt: nhận vàng, đá gacha, điểm kỹ năng → nâng cây kỹ năng, quay gacha, mặc trang bị → vào ải tiếp (hoặc cày lại ải cũ).
- Mỗi 10 ải: chọn 1 hiệu ứng đặc biệt vĩnh viễn cho slot; muốn build khác: tạo slot mới.

## Goal & fail state
- Goal: vượt ải (sống hết giờ + hạ boss nếu có) để mở ải tiếp; mục tiêu dài hạn là ải 100.
- Fail: máu về 0 → thua lượt, giữ một phần vàng đã nhặt, chơi lại ải đó.

## Features
- [ ] Lượt chơi survivors: di chuyển, chiêu tự đánh, quái theo đợt, kinh nghiệm, lên cấp chọn 1/3 theo class, máu, hết giờ thì thắng
- [ ] 2 class đầu: Kiếm sĩ (cận chiến) và Pháp sư (tầm xa), mỗi class có bộ nâng cấp riêng
- [ ] Quái vật vẽ trong Sprite Lab: thường, tinh anh, boss mỗi 10 ải
- [ ] 100 ải độ khó tăng dần, mô tả bằng dữ liệu (`assets/data/stages.json` + công thức)
- [ ] Slot nhân vật (tạo / chơi / xoá), lưu tiến trình
- [ ] Hiệu ứng đặc biệt vĩnh viễn ở ải 10 / 20 / 30 (mở rộng mỗi 10 ải)
- [ ] Cây kỹ năng vĩnh viễn theo class
- [ ] Trang bị (vũ khí, giáp) có độ hiếm và hiệu ứng buff đặc biệt
- [ ] Gacha vũ khí / giáp, quay bằng đá cày trong game

## Your systems
- lượt chơi sống sót theo đợt (survivors) · in the slice
- kinh nghiệm + lên cấp chọn 1 trong 3 theo class · in the slice
- class nhân vật · in the slice
- 100 màn độ khó tăng dần · thin stand-in
- hiệu ứng đặc biệt ở stage 10 - 20 - 30 · later
- skill tree · later
- trang bị (vũ khí, giáp) · later
- gacha · later
- slot nhân vật · later
- chế độ endgame khác · later

## Keep
-

## Avoid
-

## Out of scope
- Bản mobile cho tới khi bản PC phát hành được (đợt 8 trong `production/roadmap.md`).
- Chế độ endgame ngoài 100 ải.
- Nạp tiền mua đá gacha: tính sau ("cơ chế nạp sẽ được tính sau", you said); hiện đá chỉ cày trong game.
- Chơi mạng / co-op.

## Build order
1. Lượt chơi 5 phút với Kiếm sĩ ở ải 1: di chuyển, 2 chiêu tự đánh, 3 loại quái theo đợt, kinh nghiệm + lên cấp 1/3, thua/thắng (đợt 1 của roadmap). Kèm thử tải 500 quái.
2. Độ sâu build: Pháp sư, đủ bộ nâng cấp 2 class, quái tinh anh, boss ải 10.
3. Tiến trình ải 1–30, chọn ải, lưu slot, hiệu ứng mốc 10/20/30.
4. Cây kỹ năng + trang bị.
5. Gacha.
6. Nội dung đủ 100 ải, 4 class, cân bằng.
7. Hoàn thiện + Steam. 8. Mobile.

---
**Kill condition:** nếu sau đợt 1 và một vòng chỉnh, một lượt 5 phút vẫn nhàm (người chơi không muốn vào lượt 2), dừng thêm hệ thống và làm lại vòng lặp cốt lõi trước.

**Who it's for / what they feel:** người thích Vampire Survivors và RPG cày build; cảm giác "từ yếu ớt tới quét sạch màn hình" trong mỗi lượt, và "nhân vật của tôi mạnh dần" qua nhiều ngày.

**Games you love / don't:** Love Vampire Survivors (vòng lặp sống sót + chọn nâng cấp) *(you said)*.
