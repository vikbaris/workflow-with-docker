# GitHub Actions Docker Container Rehberi - Eksiksiz Eğitim Materyalleri

## 📚 İçerik Özeti

Bu pakette GitHub Actions'ta Docker container kullanımı hakkında kapsamlı eğitim materyalleri bulunmaktadır.

---

## 📖 1. Ana Rehber (Başla Buradan)

**Dosya**: `github_actions_docker_rehberi.md`

Bu dosya şu konuları kapsar:
- ✅ Container'lar ne zaman ve neden kullanılır
- ✅ Container'ların nerede çalıştığı
- ✅ Container'ların lifecycle'ı (başlama, çalışma, sonlanma)
- ✅ 3 seviyeli container kullanımı (Job, Step, Service)
- ✅ Global-level konfigürasyon
- ✅ Service container'ları detaylı
- ✅ Gerçek dünya senaryoları
- ✅ En iyi uygulamalar

**Okuma süresi**: 30-40 dakika

---

## 🔧 2. Pratik Örnekler (Kopyala-Yapıştır)

### Örnek 1: Job-Level Container
**Dosya**: `workflow-example-1-job-level.yml`

İçeriği:
- Tüm adımların aynı container'da çalışması
- PostgreSQL ve Redis service container'ları
- Environment variable'lar ve port konfigürasyonu
- Service health check'leri
- Artifact upload

**Teknik Seviye**: Başlangıç

```yaml
container:
  image: node:18-alpine
  env:
    NODE_ENV: test

services:
  postgres:
    image: postgres:15-alpine
  redis:
    image: redis:7-alpine
```

---

### Örnek 2: Step-Level Container
**Dosya**: `workflow-example-2-step-level.yml`

İçeriği:
- Her step'te farklı container kullanımı
- Python, JavaScript, Ruby, Go, Java kombinasyonu
- Host machine'de çalışan step
- Step container'ların izolasyonu

**Teknik Seviye**: Orta

```yaml
steps:
  - uses: docker://python:3.11
  - uses: docker://node:18
  - uses: docker://ruby:3.2
  - run: echo "Host machine"
```

---

### Örnek 3: Service Container'lar
**Dosya**: `workflow-example-3-service-containers.yml`

İçeriği:
- 6 farklı service container (PostgreSQL, Redis, MongoDB, Elasticsearch, RabbitMQ, MinIO)
- Health check'ler
- Service connectivity verification
- Database schema setup
- Integration tests

**Teknik Seviye**: İleri

```yaml
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: test
    options: |
      --health-cmd pg_isready
      --health-retries 5

  redis:
    image: redis:7
    options: |
      --health-cmd "redis-cli ping"
```

---

### Örnek 4: Eksiksiz Mimari
**Dosya**: `workflow-example-4-complete-architecture.yml`

İçeriği:
- Global, Job, Step ve Service seviyelerinin kombinasyonu
- 3 farklı job örneği (Comprehensive, Step-level Only, Services Only)
- Kontainer lifecycle'ının detaylı açıklanması
- Architecture summary artifact'ı

**Teknik Seviye**: İleri

```yaml
# GLOBAL LEVEL
env:
  DOCKER_BUILDKIT: 1

jobs:
  comprehensive-example:
    container:        # JOB LEVEL
      image: node:18
    services:         # SERVICE LEVEL
      postgres: ...
    steps:
      - uses: docker://python:3.11  # STEP LEVEL
```

---

## ⚠️ 3. Sık Yapılan Hatalar ve Çözümleri

**Dosya**: `hatalar-ve-cozumler.md`

10 yaygın hata ve çözümleri:

1. **Service Container'a Bağlanamama**
   - Problem: `localhost` kullanmak
   - Çözüm: Service adı kullanmak

2. **Health Check Başarısız**
   - Problem: Container'ın hazır olmasını beklememe
   - Çözüm: Health check eklemek

3. **Environment Variable'lar Görünmüyor**
   - Problem: Job-level env, container'a geçmiyor
   - Çözüm: Container.env altında tanımlamak

4. **Container'da Dosya Paylaşımı**
   - Problem: `/tmp` gibi yerlerde dosya oluşturma
   - Çözüm: `/github/workspace` kullanmak

5. **Windows/macOS'ta Container Kullanma**
   - Problem: Container sadece Linux'ta çalışır
   - Çözüm: Ubuntu runner kullanmak

6. **Port Çakışması**
   - Problem: İki service aynı port
   - Çözüm: Farklı port'lar kullanmak

7. **Secret'lar Loglanıyor**
   - Problem: Secret'ları echo etme
   - Çözüm: Secret'ları loglamamak

8. **Dependency Cache Etmek**
   - Problem: Her çalıştırmada tekrar download
   - Çözüm: Cache action'ı kullanmak

9. **Private Registry Credentials**
   - Problem: Private image pull başarısız
   - Çözüm: Credentials geçmek

10. **Container Memory Hatası**
    - Problem: Yetersiz bellek
    - Çözüm: Container'a bellek ayırmak

---

## 📋 Hızlı Referans

### Container Seviyeleri Karşılaştırması

| Seviye | Kapsam | Kullanım | Lifecycle |
|--------|--------|----------|-----------|
| **Job-Level** | Tüm adımlar | `container:` | Job boyunca |
| **Step-Level** | Tek adım | `uses: docker://` | Step boyunca |
| **Service** | Arka plan | `services:` | Job boyunca |

### Container Nerede Çalışır?

```
GitHub Runner (Ubuntu VM)
├── Job Container (docker run)
│   ├── /github/workspace (paylaşılan volume)
│   ├── Services (ayrı container'lar)
│   └── Step Container (sadece o adımda)
└── Host Runner (job tamamlanınca temizlenir)
```

### Container Lifecycle

```
1. Container başlatılır (Job başında)
2. Adımlar çalışır
3. Service'ler bağlanır
4. Testler çalışır
5. Container silinir (Job sonunda)
```

### Dosya Paylaşımı

```yaml
# ✅ Paylaşılır (/github/workspace)
- /github/workspace
- ./
- ~/

# ❌ Paylaşılmaz (container özel)
- /tmp
- /var
- /home (container'ın kendisi hariç)
```

---

## 🎯 Hangi Örneği Kullanmalı?

### Senaryo 1: Node.js Uygulaması Test Etmek
**Kullan**: `workflow-example-1-job-level.yml`
- Tüm adımlar Node container'da çalışır
- PostgreSQL + Redis database servisleri
- Basit ve anlaşılır yapı

### Senaryo 2: Çok Dilli Proje (Python, Node, Ruby vb)
**Kullan**: `workflow-example-2-step-level.yml`
- Her dil için kendi container'ı
- Step-level container'lar ile izolasyon
- Esnek ve modüler

### Senaryo 3: Mikroservis Mimarisi (6+ Servis)
**Kullan**: `workflow-example-3-service-containers.yml`
- PostgreSQL, Redis, MongoDB, Elasticsearch, RabbitMQ, MinIO
- Kompleks integration test'leri
- Eksiksiz setup

### Senaryo 4: Tüm Seviyeleri Anlamak
**Kullan**: `workflow-example-4-complete-architecture.yml`
- Global, Job, Step, Service seviyelerinin hepsi
- Lifecycle'ın detaylı açıklanması
- Learning purpose

---

## 🚀 Başlangıç Adımları

### 1. Teoriyi Öğren
```bash
1. github_actions_docker_rehberi.md dosyasını oku
2. Bölüm 1-3'ü detaylı incele
3. Container lifecycle'ı anla
```

### 2. İlk Örneği Dene
```bash
1. workflow-example-1-job-level.yml'yi indir
2. Kendi GitHub repository'ne `.github/workflows/` klasörüne koy
3. Dosya adını test.yml şeklinde değiştir
4. Push et ve Actions tab'inde çalıştığını gözlemle
```

### 3. Hataları Öğren
```bash
1. hatalar-ve-cozumler.md'i oku
2. Her hatanın sebebini ve çözümünü anla
3. Kendi projende ne kadarını uygulayabileceğini düşün
```

### 4. Diğer Örnekleri Dene
```bash
1. Step-level örneğini test et
2. Service container'ları ekle
3. Kendi workflow'unla oyna
```

---

## 💡 En İyi Uygulamalar Özet

### ✅ Yapılması Gerekenler

1. **Alpine image'ları kullan** (daha hafif)
   ```yaml
   image: node:18-alpine
   ```

2. **Health check'ler tanımla**
   ```yaml
   options: --health-cmd pg_isready
   ```

3. **Kaynakları sınırla**
   ```yaml
   options: --cpus 2 --memory 2048m
   ```

4. **Environment variable'ları secure geç**
   ```yaml
   env:
     API_KEY: ${{ secrets.API_KEY }}
   ```

5. **Artifact'ları yükle**
   ```yaml
   - uses: actions/upload-artifact@v3
   ```

### ❌ Yapılmaması Gerekenler

1. ❌ Container'da hardcoded credential'lar
2. ❌ Çok büyük image'lar (800MB+)
3. ❌ Health check olmadan service container'lar
4. ❌ Container'da permanent data beklenti
5. ❌ localhost ile service'lere bağlantı

---

## 📚 Dosya Yapısı

```
github-actions-docker-training/
├── github_actions_docker_rehberi.md          ← Ana rehber (buradan başla)
├── workflow-example-1-job-level.yml          ← Job-level örneği
├── workflow-example-2-step-level.yml         ← Step-level örneği
├── workflow-example-3-service-containers.yml ← Service örneği
├── workflow-example-4-complete-architecture.yml ← Tüm seviyeler
├── hatalar-ve-cozumler.md                    ← Sık hatalar
└── INDEX.md                                  ← Bu dosya
```

---

## 🎓 Öğrenme Yolu

**Başlangıç** (30 dakika)
1. Rehber'in ilk 3 bölümünü oku
2. Örnek 1 ve 2'yi gözden geçir

**Orta Seviye** (1-2 saat)
1. Rehber'in tüm bölümlerini oku
2. Tüm 4 örneği incele
3. Sık hatalar dosyasını oku

**İleri Seviye** (2-4 saat)
1. Kendi projende uygula
2. Service container'lar ekle
3. CI/CD pipeline'ını optimize et

**Uzman** (4+ saat)
1. Multiple job'ları ayarla
2. Custom Docker image'ları kullan
3. Performance tuning yap

---

## 🔗 Faydalı Kaynaklar

- **GitHub Docs**: https://docs.github.com/en/actions
- **Docker Docs**: https://docs.docker.com
- **GitHub Actions Marketplace**: https://github.com/marketplace?type=actions
- **Community Forums**: GitHub Discussions

---

## 📝 Notlar

- Tüm örnekler Linux runner'lar için (ubuntu-latest)
- Container'lar job sonunda otomatik olarak silinir
- Dosya paylaşımı `/github/workspace` üzerinden olur
- Service'lere service adı ile erişilir (localhost değil)

---

## ❓ Sorular ve Cevaplar

### S: Container'lar ne kadar yer kaplıyor?
**C**: Kullandığınız image'ın boyutuna bağlı. Alpine image'lar 50-150MB, tam image'lar 500MB+ olabilir.

### S: Container'lar ne kadar hızlı başlıyor?
**C**: Genellikle 2-10 saniye. Image cache'ye bağlı.

### S: Container'ların içinde yaşanan değişiklikler kalıcı mı?
**C**: Hayır. Container silinir ve değişiklikler kaybolur. Artifact'ları upload etmelisin.

### S: Kaç tane service container kullanabilirim?
**C**: Teknik sınır yok ama resource'lar sınırlı. 3-5 tavsiye edilir.

### S: Kendi Dockerfile'ımı kullanabilir miyim?
**C**: Evet! Step-level container'larda `uses: docker://` ile kullanabilirsin.

---

## 🎉 Bitirdin!

Tüm materyalleri okuduğun zaman GitHub Actions'ta Docker container'ları eksik olmayan bir şekilde anlamış olacaksın.

**Başarılar!** 🚀

---

**Son Güncelleme**: 2024
**Versiyon**: 1.0
**Dil**: Türkçe
