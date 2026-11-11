# Dragon Legends — Game Brief

Game koleksi & ternak naga (genre: dragon breeding / island builder). Semua naga,
elemen, nama, dan seni orisinal.

## Loop inti (MVP)
1. Bangun **habitat** berelemen (Bara, Arus, Rimba, Petir) di petak pulau.
2. Beli **telur** → tetaskan di **Penetasan** → naga masuk habitat berelemen cocok.
3. Naga menghasilkan **emas** per detik (berlanjut saat offline, dibatasi kapasitas habitat).
4. **Ladang** mengubah emas menjadi **makanan**; makanan menaikkan level naga (emas lebih cepat).
5. Dua naga Lv 4+ dikawinkan di **Gua Kawin** → telur acak dari naga yang elemennya
   berasal dari kedua induk (naga hibrida hanya bisa didapat begini).
6. Lengkapi **Koleksi** 10 naga.

## Struktur
- `data/balance.json`, `data/dragons.json` — semua angka & definisi naga (data-driven).
- `src/core/game_state.gd` — aturan murni (waktu & RNG disuntik, bisa diuji).
- `src/ui/` — layar utama, petak pulau, gambar naga prosedural.
- Simpanan: `user://save.json` (otomatis setiap aksi).

## Jalankan
- Main: buka `project.godot` di Godot 4.7, tekan F5.
- Tes: `godot --headless -s res://tests/unit/core/test_game_state.gd`
- Screenshot bukti: `godot -- --shot <file.png>` → `production/qa/evidence/`

## Belum ada (kandidat berikutnya)
Arena pertarungan, layar makan + evolusi visual, buku naga detail, "kemungkinan hasil"
kawin, animasi penetasan, ekspor Android.
