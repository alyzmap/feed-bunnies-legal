# Splash Screen Oluşturma Talimatları

## 📐 Boyut:
- **1080x1920 piksel** (dikey full HD)
- veya **720x1280** (daha küçük dosya)

## 🎨 İçerik:
```
┌──────────────────┐
│                  │
│    [boşluk]      │
│                  │
│   🐰 Tavşan      │
│   İkonu          │
│                  │
│  "Feed Bunnies"  │
│   (büyük yazı)   │
│                  │
│    [boşluk]      │
│                  │
└──────────────────┘
```

## Renk Şeması:
- **Arka plan**: Krem/Bej (#F2EBE0) - oyunun arka planıyla uyumlu
- **Tavşan ikonu**: Merkezde, büyük (400x400px civarı)
- **Başlık**: Oyun fontu, koyu kahve rengi
- **Temiz ve minimal**

## Kaydetme:
1. 1080x1920 veya 720x1280 olarak oluştur
2. PNG formatında kaydet
3. `splash.png` adıyla workspace'e kaydet
4. Godot otomatik algılayacak

## Not:
Arka plan rengini project.godot'ta ayarladım: `bg_color=Color(0.95, 0.92, 0.88, 1)`
Splash görseli bu rengin üzerine gelecek, bu yüzden transparent PNG kullanabilirsin.
