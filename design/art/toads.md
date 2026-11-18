# Cóc Độc và Cóc Chúa: mô tả vẽ

Người dùng 2026-11-18: hai con cóc "quá xấu", cần mô tả kỹ và tham khảo; nhảy thì phải có animation nhảy.
Bản cũ: một khối bầu dục phẳng, mụn là chấm cam rời, không thấy chân, không có pha nhảy.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| [OpenGameArt: frog animation sprite sheet](https://opengameart.org/content/frog-animation-sprite-sheet), [animated frog](https://opengameart.org/content/animated-frog) | Ếch nhìn ngang: đùi sau to gập bên hông, chân trước chống đất, đầu liền thân. |
| [OpenGameArt: LPC frogman, bình luận](https://opengameart.org/comment/89117) | "Thu chân về phía trước trước khi đáp". |
| [itch.io: frog pack (Idle, Croak, Hop, Jump, Fall, Land)](https://seethingswarm.itch.io/frogpack), [Elthen: Giant Toad](https://elthen.itch.io/2d-pixel-art-giant-toad-sprites) | Tách animation: ngồi/kêu, nhảy (lên, rơi), đáp. Cóc khổng lồ: thân bè, da sần, miệng rộng. |
| [Sprite-AI: animation principles](https://www.sprite-ai.art/guides/animation-principles), [Pixel Grimoire #3](https://medium.com/pixel-grimoire/how-to-start-making-pixel-art-3-c9eb70270fa1) | Nén khi lấy đà/đáp, duỗi khi bật; giữ thể tích (cao thêm thì hẹp lại); 8–12 fps. |

**Học:** dáng cóc đọc ra nhờ **đùi sau to gập**, **chân trước chống**, **mắt có gờ mày**, **tuyến độc sau mắt**,
**miệng rộng kéo tới dưới mắt**; da sần là mụn **nổi khối** (sáng trên, tối dưới), không phải chấm phẳng.
**Tránh:** khối bầu dục không chân; mụn rải đều như chấm bi; nhảy bằng cách chỉ dời sprite.
**Quyết định:** vẽ theo bộ phận (thư viện `sprite-lab/lib/toadkit.py`, dùng chung cho hai con), pha nhảy riêng,
game nâng sprite lên theo đường cong khi bay và giữ bóng dưới đất.

## Giải phẫu (nhìn ngang, quay phải)

- Thân: bầu dục hơi nghiêng lên phía đầu; đầu liền thân, mõm tròn ở bên phải.
- Mắt: lồi trên đỉnh đầu, tròng vàng, **đồng tử ngang** (đặc trưng của cóc), gờ mày tối phía trên.
- Tuyến độc (parotoid): bướu bầu dục sáng hơn ngay sau mắt.
- Miệng: đường tối từ mõm kéo ngược về dưới mắt.
- Chân trước: tay dày, khuỷu chĩa ra, bàn tay xòe 3 ngón chống đất.
- Chân sau: đùi to như "đùi gà" gập sát hông, cẳng chân gập dưới đùi, bàn chân dài ngón ra sau.
- Bụng: kem vàng, có vệt; họng nhạt hơn.

## Màu

| Vai trò | Cóc Độc | Cóc Chúa |
|---|---|---|
| Lưng sáng / lưng / sườn tối | `#8a8a3a` / `#5e6a2a` / `#38401c` | như Cóc Độc, nhưng tối hơn một bậc |
| Bụng / họng | `#d8c47a` / `#efe2a8` | như trên |
| Mụn độc (nổi khối: sáng/giữa/tối) | `#ffb04a` / `#e0702a` / `#8a3a1a`, chỉ dọc sống lưng và tuyến độc | nhiều hơn, to hơn |
| Mắt / đồng tử / gờ mày | `#f0c040` / `#14160c` / `#2a2a14` | như trên |
| Riêng Cóc Chúa | | vương miện nấm độc tím `#7a3aa8`/`#b070e0`, chân nấm `#e0d8c0`; dãi độc xanh `#8ad040` |

## Animation

| Tên | Khung | Nội dung |
|---|---|---|
| `move` | 4 | ngồi, họng phập phồng, thân nhún 1 px (cóc bò chậm) |
| `crouch` | 2 | lấy đà: thân hạ thấp, đùi nén, tay co (game phát khi gồng `WINDUP`) |
| `jump` | 4 | bật: thân ngẩng 30°, chân sau duỗi → đỉnh: thân ngang, chân sau duỗi thẳng ra sau, tay vươn trước → rơi: tay chúc xuống, chân sau thu về trước → đáp: bẹp, tay xòe (game phát khi bay `DASH`, nâng sprite theo đường cong `hop_height`) |
| `hurt` | 2 | chớp trắng, giật lùi |
| `death` | 4 | lật bẹp, mắt nhắm, chảy thành vũng độc |

Cóc Độc: khung 32×24, neo (16, 23). Cóc Chúa: cùng bộ phận phóng ×1.7, khung 56×44, neo (28, 43), thêm vương miện nấm,
mụn to, dãi độc ở mép khi gồng.
