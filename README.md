<div align="center">

# 👗 GiyGeç

### *Akıllı Mağaza Alışveriş & Yapay Zeka Stil Danışmanı*

[![Flutter](https://img.shields.io/badge/Flutter-3.16+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Render](https://img.shields.io/badge/Render-Deployed-46E3B7?style=for-the-badge&logo=render&logoColor=white)](https://render.com)

<br/>

> **GiyGeç**, mağaza içi alışveriş deneyimini yapay zeka ile dönüştüren bir mobil uygulamadır.  
> NFC etiketlerinden ürün okuma, Grok AI destekli kombin önerisi ve Fashn.ai ile sanal deneme kabini bir arada.

<br/>

![GiyGeç Banner](https://img.shields.io/badge/version-1.0.0-blueviolet?style=flat-square) 
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

</div>

---

## 📖 İçindekiler

- [✨ Özellikler](#-özellikler)
- [🏗️ Mimari Yapı](#️-mimari-yapı)
- [🛠️ Teknoloji Yığını](#️-teknoloji-yığını)
- [📱 Uygulama Ekranları](#-uygulama-ekranları)
- [🚀 Kurulum](#-kurulum)
  - [Ön Koşullar](#ön-koşullar)
  - [Flutter Uygulaması](#flutter-uygulaması)
  - [Python Sunucu](#python-sunucu)
- [☁️ Render.com'da Deployment](#️-rendercomda-deployment)
- [🔑 Çevre Değişkenleri](#-çevre-değişkenleri)
- [📡 API Endpoint'leri](#-api-endpointleri)
- [🤝 Katkıda Bulunma](#-katkıda-bulunma)
- [📄 Lisans](#-lisans)

---

## ✨ Özellikler

### 🤖 Yapay Zeka Kombin Önerisi
- **Grok AI (xAI)** destekli doğal dil anlama
- Metin veya fotoğraf ile kombin isteği
- 60-30-10 renk kuralı ve moda prensiplerine dayalı öneri motoru
- Kullanıcının cinsiyetine ve bütçesine göre filtreleme
- Her sorguda **3 farklı alternatif kombin** sunma
- Kombinlerin popülerlik puanı hesaplama

### 👗 Sanal Deneme Kabini (Virtual Try-On)
- **Fashn.ai tryon-max** modeli ile gerçekçi kıyafet giydirme
- Tek parça veya zincirleme çok parçalı kombin giydirme
- Üst → Alt → Tek parça → Ayakkabı sıralı uygulama
- Kullanıcı kendi fotoğrafını yükleyerek deneme yapabilme
- Sonuçları kaydetme ve paylaşma

### 📲 NFC Akıllı Etiket Sistemi
- Mağaza ürünlerine NFC etiketi yapıştırarak dijital katalog oluşturma
- Telefonu ürüne yaklaştırarak anında ürün bilgisi görüntüleme
- NFC UID ↔ Barkod eşleştirme
- Depo yönetimi: stok takibi, kullanım sayacı

### 🛒 Akıllı Sepet & Mağaza
- Firebase Firestore tabanlı gerçek zamanlı ürün kataloğu
- Cinsiyet bazlı ürün filtreleme (Erkek / Kadın / Unisex)
- Sepetteki ürünlere göre eksik parçaları tamamlama
- Ödeme durumu takibi (NFC ile ödeme entegrasyonu altyapısı)

### 🎙️ Sesli Asistan
- **Text-to-Speech (TTS)** ile kombin önerilerini sesli okuma
- **Speech-to-Text** ile sesli kombin isteği yapma
- Türkçe dil desteği

### 👤 Kullanıcı Profili
- **Google Sign-In** ile hızlı giriş
- Kaydedilen kombinler kütüphanesi
- Profil fotoğrafı ve kullanıcı bilgileri

---

## 🏗️ Mimari Yapı

```
giygec/
├── 📱 lib/                          # Flutter Mobil Uygulaması
│   ├── core/
│   │   └── theme.dart               # Uygulama tema & renk sistemi
│   ├── models/                      # Veri modelleri
│   ├── providers/                   # Riverpod state management
│   │   └── auth_provider.dart       # Kimlik doğrulama durumu
│   ├── screens/                     # Uygulama ekranları
│   │   ├── splash_screen.dart       # Giriş & Hoşgeldin ekranı
│   │   ├── main_screen.dart         # Ana navigasyon
│   │   ├── shop_screen.dart         # Mağaza & NFC tarama
│   │   ├── ai_consultant_screen.dart # AI Stil Danışmanı
│   │   ├── virtual_tryon_screen.dart # Sanal Deneme Kabini
│   │   ├── profile_screen.dart      # Kullanıcı profili
│   │   └── payment_success_screen.dart # Ödeme başarı
│   ├── services/                    # Dış servis bağlantıları
│   │   ├── ai_service.dart          # Render API çağrıları
│   │   ├── auth_service.dart        # Firebase Auth
│   │   ├── firestore_service.dart   # Firestore CRUD
│   │   └── nfc_service.dart         # NFC okuma/yazma
│   └── widgets/                     # Yeniden kullanılabilir bileşenler
│
├── 🐍 server/                       # Python FastAPI Backend
│   ├── main.py                      # Tüm API endpoint'leri
│   └── requirements.txt             # Python bağımlılıkları
│
├── 🤖 android/                      # Android platform kodu
├── 🍎 ios/                          # iOS platform kodu
├── pubspec.yaml                     # Flutter bağımlılıkları
└── README.md
```

### Sistem Akışı

```
┌─────────────┐     NFC Okuma      ┌──────────────────┐
│             │ ─────────────────► │                  │
│   Flutter   │                    │   Firebase       │
│   Mobil App │ ◄───────────────── │   Firestore      │
│             │   Ürün Verisi      │                  │
└──────┬──────┘                    └──────────────────┘
       │
       │ HTTP (Kombin / Try-On)
       ▼
┌─────────────────────────────────────────────────────┐
│           FastAPI Backend (Render.com)               │
│                                                     │
│  /kombin-oner  ──────────► Grok AI (xAI)           │
│  /vision-analiz ─────────► Grok Vision              │
│  /virtual-try-on-step ───► Fashn.ai Try-On Max      │
│  /virtual-try-on-chain ──► Fashn.ai (Zincirleme)    │
│  /depo/* ─────────────────► Firebase Firestore      │
└─────────────────────────────────────────────────────┘
```

---

## 🛠️ Teknoloji Yığını

### Mobil (Flutter)
| Paket | Sürüm | Kullanım |
|-------|-------|---------|
| `flutter_riverpod` | ^2.6.1 | State Management |
| `firebase_core` | ^3.12.1 | Firebase entegrasyonu |
| `firebase_auth` | ^5.5.1 | Kimlik doğrulama |
| `cloud_firestore` | ^5.6.5 | Gerçek zamanlı veritabanı |
| `google_sign_in` | ^6.2.2 | Google ile giriş |
| `nfc_manager` | ^4.1.1 | NFC okuma/yazma |
| `image_picker` | ^1.1.2 | Fotoğraf seçme |
| `flutter_tts` | ^4.2.2 | Metin-sesli okuma |
| `speech_to_text` | 7.3.0 | Sesli komut |
| `cached_network_image` | ^3.4.1 | Optimize görsel yükleme |
| `shimmer` | ^3.0.0 | Yükleme animasyonu |
| `gal` | ^2.3.0 | Galeriye kaydetme |

### Backend (Python)
| Paket | Sürüm | Kullanım |
|-------|-------|---------|
| `fastapi` | 0.115.12 | API framework |
| `uvicorn` | 0.34.2 | ASGI sunucu |
| `firebase-admin` | 6.6.0 | Firebase Admin SDK |
| `requests` | 2.32.3 | HTTP istekleri |
| `python-multipart` | 0.0.20 | Dosya yükleme |

### Harici Servisler
| Servis | Kullanım |
|--------|---------|
| **Grok AI (xAI)** | Kombin önerisi & Vision analizi |
| **Fashn.ai** | Sanal kıyafet deneme (Try-On Max) |
| **Firebase Firestore** | Ürün kataloğu & kullanıcı verisi |
| **Firebase Auth** | Google kimlik doğrulama |
| **Render.com** | Python backend hosting |

---

## 📱 Uygulama Ekranları

| Ekran | Açıklama |
|-------|---------|
| **Splash / Giriş** | Google ile giriş, animasyonlu karşılama |
| **Mağaza** | NFC tarama, ürün listesi, sepet |
| **AI Danışman** | Metin/fotoğraf ile kombin isteği, sesli asistan |
| **Sanal Kabin** | Kıyafet try-on, zincirleme deneme |
| **Profil** | Kaydedilen kombinler, kullanıcı ayarları |

---

## 🚀 Kurulum

### Ön Koşullar

- **Flutter SDK** ≥ 3.16.0 ([kurulum](https://docs.flutter.dev/get-started/install))
- **Python** ≥ 3.11 ([kurulum](https://www.python.org/downloads/))
- **Firebase projesi** (Firestore + Authentication etkin)
- **Grok API key** ([xAI Console](https://console.x.ai))
- **Fashn.ai API key** ([Fashn.ai](https://fashn.ai))

---

### Flutter Uygulaması

#### 1. Repoyu Klonla
```bash
git clone https://github.com/KULLANICI_ADIN/giygec.git
cd giygec
```

#### 2. Firebase Kurulumu

Firebase Console'dan projeyi oluşturun ve `google-services.json` (Android) ile `GoogleService-Info.plist` (iOS) dosyalarını indirin:

```
android/app/google-services.json   ← buraya koy
ios/Runner/GoogleService-Info.plist ← buraya koy
```

> ⚠️ Bu dosyalar `.gitignore`'da yer almakta olup repoya dahil edilmez. Her geliştirici kendi Firebase projesinden almalıdır.

#### 3. Bağımlılıkları Yükle
```bash
flutter pub get
```

#### 4. Sunucu URL'ini Güncelle

`lib/services/ai_service.dart` dosyasında Render URL'ini kendi sunucunuzla değiştirin:
```dart
static const String baseUrl = 'https://SENIN-RENDER-URL.onrender.com';
```

#### 5. Uygulamayı Çalıştır
```bash
flutter run
```

---

### Python Sunucu

#### 1. Sanal Ortam Oluştur
```bash
cd server
python -m venv venv

# Windows
venv\Scripts\activate

# macOS / Linux
source venv/bin/activate
```

#### 2. Bağımlılıkları Yükle
```bash
pip install -r requirements.txt
```

#### 3. Çevre Değişkenlerini Ayarla

`.env` dosyası oluştur (ya da sistem ortam değişkenlerini kullan):
```env
FIREBASE_KEY={"type":"service_account","project_id":"..."}
GROK_API_KEY=xai-xxxxxxxxxxxxxxxxxxxxxxxx
FASHN_API_KEY=fa-xxxxxxxxxxxxxxxxxxxxxxxx
```

> ⚠️ `.env` dosyasını **asla** repoya ekleme! `.gitignore`'a eklenmiştir.

#### 4. Sunucuyu Başlat
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API dokümantasyonu: [http://localhost:8000/docs](http://localhost:8000/docs)

---

## ☁️ Render.com'da Deployment

GiyGeç'in Python backend'i ve (isteğe bağlı olarak) web frontend'i Render.com üzerinde barındırılabilir.

---

### 🐍 Python Backend (FastAPI) — Render Web Service

#### Adım 1: GitHub'a Yükle

Kodu GitHub'a push'ladıktan sonra [render.com](https://render.com) adresine gidin.

#### Adım 2: Yeni Web Service Oluştur

1. **Dashboard** → **New +** → **Web Service**
2. GitHub reponuzu bağlayın
3. Ayarları şu şekilde yapılandırın:

| Alan | Değer |
|------|-------|
| **Name** | `giygec-backend` |
| **Region** | Frankfurt (EU Central) |
| **Branch** | `main` |
| **Root Directory** | `server` |
| **Runtime** | `Python 3` |
| **Build Command** | `pip install -r requirements.txt` |
| **Start Command** | `uvicorn main:app --host 0.0.0.0 --port $PORT` |
| **Instance Type** | Starter ($7/ay) veya Free |

#### Adım 3: Çevre Değişkenlerini Ekle

Render Dashboard'da **Environment** sekmesine gidin ve şu değişkenleri ekleyin:

```
FIREBASE_KEY    = {"type":"service_account","project_id":"giygec-xxxx",...}
GROK_API_KEY    = xai-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
FASHN_API_KEY   = fa-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> 📌 `FIREBASE_KEY` değeri, Firebase Admin SDK JSON dosyasının **tüm içeriğini** tek satır halinde string olarak yapıştırılmalıdır.

#### Adım 4: Deploy Et

**Create Web Service** butonuna basın. Render otomatik olarak:
- Bağımlılıkları yükler (`pip install -r requirements.txt`)
- Uvicorn sunucusunu başlatır
- HTTPS URL'i atar (örn: `https://giygec-backend.onrender.com`)

#### Adım 5: Sağlık Kontrolü

```bash
curl https://giygec-backend.onrender.com/
# {"status":"ok","message":"GİYGEÇ Sistemi — AI Kombin Motoru & Sanal Kabin Devrede!"}
```

#### ⚡ Uyku Modundan Uyanma (Free Plan)

Free plan'da sunucu 15 dakika hareketsizlik sonrası uyku moduna geçer. İlk istekte ~30 saniye gecikme olabilir. Bunu önlemek için:

- **UptimeRobot** gibi ücretsiz bir servis ile her 10 dakikada bir `/` endpoint'ine ping atın
- Ya da **Starter ($7/ay)** plan kullanın (her zaman açık)

---

### 🔁 Otomatik Yeniden Deploy (Auto-Deploy)

Render, `main` branch'e her push'ta otomatik yeniden deploy eder. Bu özelliği Dashboard → Settings → **Auto-Deploy** bölümünden açıp kapatabilirsiniz.

---

## 🔑 Çevre Değişkenleri

| Değişken | Açıklama | Nereden Alınır |
|----------|---------|----------------|
| `FIREBASE_KEY` | Firebase Admin SDK JSON (tüm içerik) | Firebase Console → Proje Ayarları → Hizmet Hesabı |
| `GROK_API_KEY` | xAI Grok API anahtarı | [console.x.ai](https://console.x.ai) |
| `FASHN_API_KEY` | Fashn.ai API anahtarı | [fashn.ai/dashboard](https://fashn.ai) |

---

## 📡 API Endpoint'leri

### Genel

| Method | Endpoint | Açıklama |
|--------|---------|---------|
| `GET` | `/` | Sunucu durum kontrolü |
| `GET` | `/check-payment` | NFC ödeme durumu sorgulama |

### AI Kombin

| Method | Endpoint | Açıklama |
|--------|---------|---------|
| `POST` | `/kombin-oner` | Metinle kombin önerisi |
| `POST` | `/vision-analiz` | Fotoğrafla kombin önerisi |

### Sanal Deneme Kabini

| Method | Endpoint | Açıklama |
|--------|---------|---------|
| `POST` | `/virtual-try-on-step` | Tek kıyafet giydirme |
| `POST` | `/virtual-try-on-chain` | Zincirleme kombin giydirme |
| `POST` | `/virtual-try-on` | Legacy endpoint (geriye dönük) |

### Depo Yönetimi

| Method | Endpoint | Açıklama |
|--------|---------|---------|
| `GET` | `/depo/stok-ozet` | Toplam stok özeti |
| `POST` | `/depo/nfc-barkod-esle` | NFC ↔ Barkod eşleştirme |
| `GET` | `/depo/nfc-bilgi` | NFC UID detayları |

> 📚 Tam API dokümantasyonu için: `https://SENIN-RENDER-URL.onrender.com/docs`

---

## 🔐 Güvenlik Notları

- **Firebase Admin SDK JSON** dosyasını (`giygec-*-firebase-adminsdk-*.json`) asla repoya yükleme
- **API key'leri** ortam değişkeni olarak sakla, kaynak koduna yazma
- `google-services.json` ve `GoogleService-Info.plist` dosyaları `.gitignore`'da yer alır
- Render'da tüm secret'ları Environment Variables bölümünden yönet

---

## 🤝 Katkıda Bulunma

1. Repoyu fork'la
2. Feature branch oluştur: `git checkout -b feature/harika-ozellik`
3. Değişikliklerini commit et: `git commit -m 'feat: harika özellik eklendi'`
4. Branch'i push'la: `git push origin feature/harika-ozellik`
5. Pull Request aç

---

## 📄 Lisans

Bu proje **MIT Lisansı** ile lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.

---

<div align="center">

**GiyGeç** — *Yapay Zeka ile Moda, Parmak Ucunda.*

Made with ❤️ using Flutter & FastAPI

</div>
