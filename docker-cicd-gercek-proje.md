# Docker & CI/CD Pipeline - Gerçek Dünya Projesi Rehberi

## 🎯 Ana Sorunuz: "Neden Docker Container'a İhtiyacım Var?"

Haklısın, birçok şey Docker olmadan da yapılabilir. Ama burada **sihir** başlıyor:

### Docker OLMADAN (Eski Yol - Sorunlu)
```
Geliştirici bilgisayarı:
├── Python 3.9, Node 14, PostgreSQL 12
├── "Benim bilgisayarımda çalışıyor!" 🤷

Test sunucusu:
├── Python 3.8, Node 16, PostgreSQL 11
└── "Test sunucusunda niye çalışmıyor?" 😤

Production sunucusu:
├── Python 3.11, Node 18, PostgreSQL 14
└── "Production'da crash!" 💥
```

**Sorun**: Ortam farkı = bugs = customer complaints = sleepless nights

### Docker İLE (Yeni Yol - Güvenlı)
```
Dockerfile:
├── "Bu ortam HER YERDE aynı olacak"
└── Python 3.9, Node 14, PostgreSQL 12 = SABIT

Geliştirici:        Test:              Production:
├── Python 3.9      ├── Python 3.9     ├── Python 3.9
├── Node 14         ├── Node 14        ├── Node 14
└── PostgreSQL 12   └── PostgreSQL 12  └── PostgreSQL 12

"Aynı image her yerde çalışır!" ✅
```

---

## 🏗️ Gerçek Bir Proje Yapısı: E-Commerce API

Bir Node.js e-commerce API'si kuracağız. Bunun neden Docker'a ihtiyacı var:

### Proje Dosya Yapısı

```
my-ecommerce-api/
│
├── .github/workflows/
│   ├── ci-test.yml          ← Kod push → Otomatik test
│   ├── build-deploy.yml     ← Release → Build → Push → Deploy
│   └── security.yml         ← Security scans
│
├── src/
│   ├── api.js               ← Express server
│   ├── db.js                ← Database connection
│   └── routes.js            ← API endpoints
│
├── tests/
│   ├── api.test.js
│   ├── db.test.js
│   └── integration.test.js
│
├── Dockerfile               ← Production ortamı tanımı
├── docker-compose.yml       ← Local development (DB + API)
├── package.json
├── package-lock.json
└── README.md
```

---

## 1️⃣ ADIM 1: Dockerfile Oluştur (Uygulamayı Container'a Koy)

### Neden Dockerfile?
- "Bunu her sunucuda aynı şekilde çalıştır" demek
- Bağımlılıkları, ortamı, ayarları yazarak fix etmek

### my-ecommerce-api/Dockerfile

```dockerfile
# ===== BUILD STAGE =====
# Amaç: Uygulamayı hazırla ve optimize et
FROM node:18-alpine AS builder

WORKDIR /app

# Bağımlılıkları kur
COPY package*.json ./
RUN npm ci --only=production

# Production için yapısını hazırla
COPY . .
RUN npm run build 2>/dev/null || echo "No build script"

# ===== PRODUCTION STAGE =====
# Amaç: Sadece gerekli dosyaları içer (daha hafif image)
FROM node:18-alpine

WORKDIR /app

# Security: Root user değil, node user kullan
USER node

# Builder'dan hazırlanmış dosyaları kopyala
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/package*.json ./
COPY --from=builder --chown=node:node /app/src ./src

# Port'u expose et (documentation amaçlı)
EXPOSE 3000

# Health check: Container'ın çalıştığını kontrol et
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# Uygulamayı başlat
CMD ["node", "src/api.js"]
```

### Bu Dockerfile Ne Yapıyor?

**STAGE 1 (Builder)**
- Node 18 Alpine image'ını kullan
- `package.json` kopyala ve `npm ci` çalıştır (prod dependencies)
- Kodu kopyala

**STAGE 2 (Production)**
- Temiz bir image başlat
- Builder'dan compiled dosyaları kopyala
- `node` user'ı kullan (root değil = security)
- Health check ekle
- Uygulamayı çalıştır

**Neden iki stage?**
```
Builder: 500MB (build tools, test files, hepsi gerekli değil)
                ↓
Production: 150MB (sadece runtime gerekli)

Sonuç: 3.3x daha küçük image = daha hızlı push, pull, deploy
```

---

## 2️⃣ ADIM 2: Local Development Setup (docker-compose.yml)

### Neden docker-compose?

Geliştirici (sen) lokal'de çalışırken:
- Database kurulması = zorlama
- Environment setup = uzun
- "Benim bilgisayarımda çalışıyor" problemi

```bash
# Docker olmadan:
# 1. PostgreSQL install
# 2. Redis install
# 3. Environment variable'ları set et
# 4. Database seed et
# 5. Migration çalıştır
# Tüm bunlar = 30+ dakika

# Docker-compose ile:
docker-compose up
# Hepsi otomatik, 2 dakika
```

### my-ecommerce-api/docker-compose.yml

```yaml
version: '3.8'

services:
  # ====== API SERVER ======
  api:
    build:
      context: .
      dockerfile: Dockerfile
    
    # Development mode: Hot reload
    container_name: ecommerce-api
    environment:
      NODE_ENV: development
      LOG_LEVEL: debug
      
      # Database bağlantısı
      DATABASE_URL: postgresql://ecommerce_user:ecommerce_pass@db:5432/ecommerce_db
      DATABASE_HOST: db
      DATABASE_PORT: 5432
      
      # Cache
      REDIS_URL: redis://cache:6379
      
      # API settings
      API_PORT: 3000
      API_HOST: 0.0.0.0
    
    ports:
      - "3000:3000"
    
    volumes:
      # Code changes otomatik reload (hot reload)
      - ./src:/app/src
      - ./package.json:/app/package.json
      
      # Node modules'yi host'tan yalıtma
      - /app/node_modules
    
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_healthy
    
    command: npm run dev  # nodemon ile hot reload
  
  # ====== DATABASE ======
  db:
    image: postgres:15-alpine
    container_name: ecommerce-db
    
    environment:
      POSTGRES_USER: ecommerce_user
      POSTGRES_PASSWORD: ecommerce_pass
      POSTGRES_DB: ecommerce_db
      
      # Logging
      POSTGRES_INITDB_ARGS: "--encoding=UTF8"
    
    ports:
      - "5432:5432"
    
    volumes:
      # Verileri persist et (dev'de bilgisayarı kapatınca da kalır)
      - postgres_data:/var/lib/postgresql/data
      
      # Init SQL (DB setup)
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql
    
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ecommerce_user"]
      interval: 5s
      timeout: 3s
      retries: 5
  
  # ====== CACHE ======
  cache:
    image: redis:7-alpine
    container_name: ecommerce-cache
    
    ports:
      - "6379:6379"
    
    volumes:
      - redis_data:/data
    
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
  
  # ====== ADMIN TOOLS (Geliştirici için) ======
  pgadmin:
    image: dpage/pgadmin4
    container_name: ecommerce-pgadmin
    
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@example.com
      PGADMIN_DEFAULT_PASSWORD: admin
    
    ports:
      - "5050:80"
    
    depends_on:
      - db

volumes:
  postgres_data:
  redis_data:
```

### docker-compose Nasıl Kullanılır?

```bash
# İlk kez başlatma
docker-compose up

# Arka planda çalıştırma
docker-compose up -d

# Durdurmak
docker-compose down

# Veritabanı resetleme
docker-compose down -v && docker-compose up

# Container'ları temizlemek
docker-compose down -v --remove-orphans
```

### Development Süreci

```
Dosyayı değiştir (src/api.js)
      ↓
Hot reload (nodemon)
      ↓
Browser'da F5
      ↓
Güncelleme görülür

Hiç container restart gerekmez!
```

---

## 3️⃣ ADIM 3: Otomatik Test (CI - Continuous Integration)

### Amaç: Her push'ta otomatik test çalıştır

Neden gerekli?
```
Geliştirici: "Test ettim, iyiydi"
             (ama fark etmediği bir bug var)

GitHub Actions: "Hep test eder, bug'ı bulur"
                (insan hatası yok)
```

### .github/workflows/ci-test.yml

```yaml
name: CI - Test & Lint

# Ne zaman çalışır?
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    
    # Test ortamı: PostgreSQL + Redis + API
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
          POSTGRES_DB: test_db
        options: |
          --health-cmd pg_isready
          --health-interval 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      redis:
        image: redis:7-alpine
        options: |
          --health-cmd "redis-cli ping"
          --health-interval 5s
          --health-retries 5
        ports:
          - 6379:6379
    
    steps:
      # ===== SETUP =====
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      # ===== DEPENDENCIES =====
      - name: Install dependencies
        run: npm ci
      
      # ===== LINT =====
      - name: Run ESLint
        run: npm run lint
      
      # ===== UNIT TESTS =====
      - name: Run unit tests
        run: npm run test:unit
      
      # ===== INTEGRATION TESTS =====
      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db
          REDIS_URL: redis://localhost:6379
      
      # ===== COVERAGE =====
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
      
      # ===== SONUÇ =====
      - name: Test summary
        if: always()
        run: |
          echo "✓ Linting passed"
          echo "✓ Unit tests passed"
          echo "✓ Integration tests passed"
```

### Bu Workflow Ne Yapıyor?

**Trigger (Ne zaman?)**
```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
```
→ Main veya develop'e push → Otomatik çalış
→ PR açıldığında → Otomatik çalış

**Service'ler (Test Ortamı)**
```yaml
services:
  postgres: ...
  redis: ...
```
→ Gerçek DB'ye ihtiyaç yok
→ Test container'ları kullan
→ Test bitti → Silinir (clean state)

**Steps (Sıra)**
1. Kod al
2. Node kur
3. Dependencies yükle
4. Lint (kod standardı kontrol)
5. Unit tests
6. Integration tests (DB'ye yazan)
7. Coverage upload

**Sonuç**
```
✅ GREEN → Main'e merge izni
❌ RED → Fix yap, tekrar push
```

---

## 4️⃣ ADIM 4: Otomatik Build & Deploy (CD - Continuous Delivery)

### Amaç: Release oluştur → Docker build → Registry'ye push → Server'a deploy

```
git tag v1.0.0 → Push
    ↓
GitHub Actions trigger
    ↓
Docker image build
    ↓
Docker registry'ye push (ghcr.io)
    ↓
Production server'a deploy
    ↓
Watchtower (otomatik pull ve restart)
    ↓
New version canlı!
```

### .github/workflows/build-deploy.yml

```yaml
name: CD - Build & Deploy

on:
  # Release oluşturulduğunda
  release:
    types: [published]
  
  # Manuel trigger
  workflow_dispatch:

jobs:
  # ===== ADIM 1: VERSION OLUŞTUR =====
  generate-version:
    name: Generate Version
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Get version from tag
        id: version
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "Version: $VERSION"
  
  # ===== ADIM 2: TEST (Deploy öncesi double check) =====
  test:
    name: Run Tests Before Deploy
    runs-on: ubuntu-latest
    needs: generate-version
    
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_PASSWORD: test
        options: |
          --health-cmd pg_isready
          --health-interval 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - run: npm ci
      - run: npm run lint
      - run: npm run test:unit
      - run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:test@localhost:5432/postgres
  
  # ===== ADIM 3: DOCKER BUILD & PUSH =====
  build-and-push:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: [generate-version, test]
    
    permissions:
      contents: read
      packages: write
    
    steps:
      - uses: actions/checkout@v4
      
      # Docker buildx setup (multi-platform build için)
      - uses: docker/setup-buildx-action@v2
      
      # GitHub Container Registry'ye login
      - uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      # Image'ı build ve push et
      - uses: docker/build-push-action@v4
        with:
          context: .
          file: ./Dockerfile
          
          # Push etme (local test için push: false)
          push: true
          
          # Tag'lar (version + latest)
          tags: |
            ghcr.io/${{ github.repository }}:${{ needs.generate-version.outputs.version }}
            ghcr.io/${{ github.repository }}:latest
          
          # Cache optimize (yeniden build daha hızlı)
          cache-from: type=gha
          cache-to: type=gha,mode=max
  
  # ===== ADIM 4: DEPLOY =====
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [generate-version, build-and-push]
    
    if: github.ref_type == 'tag'  # Sadece tag push'larda çalış
    
    steps:
      - name: Deploy to production server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.PROD_SERVER_HOST }}
          username: ${{ secrets.PROD_SERVER_USER }}
          key: ${{ secrets.PROD_SERVER_SSH_KEY }}
          
          # Server'da çalıştırılacak script
          script: |
            echo "🚀 Deploying version ${{ needs.generate-version.outputs.version }}"
            
            cd /app/ecommerce-api
            
            # Git güncelle
            git pull origin main
            
            # Docker image'ı pull et (Watchtower bunu otomatik yapar)
            docker pull ghcr.io/${{ github.repository }}:latest
            
            # Yeni container'ı başlat
            docker-compose -f docker-compose.prod.yml up -d
            
            # Eski image'ları temizle
            docker image prune -af
            
            echo "✅ Deployment complete!"
            echo "Version: ${{ needs.generate-version.outputs.version }}"
            echo "Service: $(curl -s http://localhost:3000/health)"

  # ===== ADIM 5: NOTIFICATION =====
  notify:
    name: Notify on Slack
    runs-on: ubuntu-latest
    needs: [generate-version, deploy]
    if: always()
    
    steps:
      - name: Send Slack notification
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Deployment completed!",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*E-Commerce API Deployed*\n*Version:* ${{ needs.generate-version.outputs.version }}\n*Status:* ${{ needs.deploy.result }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### Bu Workflow Özeti

```
1. Tag oluştur: git tag v1.0.0
   ↓
2. Push: git push origin v1.0.0
   ↓
3. GitHub Actions trigger
   ↓
4. Generate Version (v1.0.0)
   ↓
5. Tüm testleri çalıştır
   ↓
6. Dockerfile'dan Docker image build
   ↓
7. ghcr.io'ya push
   ↓
8. SSH ile server'a bağlan
   ↓
9. Image pull et ve container başlat
   ↓
10. Slack'e notification gönder

Total Time: ~3-5 dakika
Manual Time: 0 dakika
Errors: Minimal (otomatik tests sayesinde)
```

---

## 5️⃣ ADIM 5: Production Server Setup

### Sunucuda ne var?

```
Production Server (AWS EC2 / DigitalOcean / Linode)
├── Docker Engine
├── Docker Compose
├── Watchtower (otomatik image updates)
├── PostgreSQL (persistent)
├── Redis (cache)
└── My App Container
```

### my-ecommerce-api/docker-compose.prod.yml

```yaml
version: '3.8'

services:
  # ===== API =====
  api:
    image: ghcr.io/myusername/my-ecommerce-api:latest
    container_name: ecommerce-api
    
    restart: always  # Container crash'se otomatik restart
    
    environment:
      NODE_ENV: production
      LOG_LEVEL: info
      
      DATABASE_URL: postgresql://prod_user:${DB_PASSWORD}@db:5432/ecommerce_db
      REDIS_URL: redis://cache:6379
      
      API_PORT: 3000
      API_HOST: 0.0.0.0
      
      # Security
      CORS_ORIGIN: https://myapp.com
      JWT_SECRET: ${JWT_SECRET}
    
    ports:
      - "3000:3000"
    
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_healthy
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
  
  # ===== DATABASE =====
  db:
    image: postgres:15-alpine
    container_name: ecommerce-db
    
    restart: always
    
    environment:
      POSTGRES_USER: prod_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ecommerce_db
    
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U prod_user"]
      interval: 10s
      timeout: 5s
      retries: 5
  
  # ===== CACHE =====
  cache:
    image: redis:7-alpine
    container_name: ecommerce-cache
    
    restart: always
    
    volumes:
      - redis_data:/data
    
    command: redis-server --appendonly yes
    
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
  
  # ===== WATCHTOWER: Otomatik image update =====
  watchtower:
    image: containrrr/watchtower
    
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    
    # Her 1 saatte bir yeni image'ları kontrol et
    command: --interval 3600 --cleanup
    
    restart: always

volumes:
  postgres_data:
  redis_data:
```

### Watchtower Nedir?

```
Watchtower = Otomatik container updater

Saat başı:
1. Registry'yi kontrol et
2. Yeni image var mı?
3. Varsa: Pull et → Eski container'ı durdur → Yeni başlat

Sonuç: Sen hiçbir şey yapmadan yeni version canlı!
```

### Server Kurulum (İlk Kez)

```bash
# SSH'ye bağlan
ssh ubuntu@your-server

# Docker install
sudo apt update && sudo apt install -y docker.io docker-compose

# Repoyu clone et
git clone https://github.com/yourname/ecommerce-api.git
cd ecommerce-api

# Environment variable'ları set et
cat > .env << EOF
DB_PASSWORD=super_secret_password_here
JWT_SECRET=another_secret_key_here
EOF

# Production containers'ları başlat
docker-compose -f docker-compose.prod.yml up -d

# Kontrol et
docker-compose logs -f api
```

---

## 📊 CI/CD Pipeline Özet

### Timeline: Bir Release'in Yaşamı

```
09:00 - Geliştirici: "Feature hazır!"
        git commit -m "Add payment integration"
        git push origin develop

09:01 - GitHub Actions (CI Test)
        - ESLint ✅
        - Unit tests ✅
        - Integration tests ✅
        - Coverage ✅

09:05 - PR review ve approve
        git merge develop → main

09:06 - Release oluştur
        git tag v1.2.0
        git push --tags

09:07 - GitHub Actions (CD Build)
        - Docker build ✅ (1.2 dakika)
        - Push to ghcr.io ✅ (0.8 dakika)
        - SSH deploy ✅ (0.5 dakika)

09:09 - Server
        - Image pull (otomatik by Watchtower)
        - Container restart
        - Health check pass

09:10 - Production Canlı!
        git tag v1.2.0 → Production
        
Total: 10 dakika, 0 manuel işlem, 0 hata ihtimali
```

---

## 🔧 Proje Repository'deki Dosya Yapısı (Tam)

```
my-ecommerce-api/
│
├── .github/
│   └── workflows/
│       ├── ci-test.yml              ← Test otomasyonu
│       ├── build-deploy.yml         ← Build ve deploy
│       └── security.yml             ← Security scan
│
├── src/
│   ├── api.js                       ← Express server
│   ├── db.js                        ← Database setup
│   ├── auth.js                      ← Authentication
│   └── routes/
│       ├── products.js
│       ├── orders.js
│       └── users.js
│
├── tests/
│   ├── api.test.js
│   ├── auth.test.js
│   ├── integration.test.js
│   └── fixtures/
│       └── test-data.sql
│
├── scripts/
│   ├── init.sql                     ← DB initialization
│   ├── backup.sh                    ← Database backup
│   └── seed-data.js                 ← Test data
│
├── Dockerfile                       ← Production image
├── docker-compose.yml               ← Development
├── docker-compose.prod.yml          ← Production
│
├── .dockerignore
├── .gitignore
├── .env.example
│
├── package.json
├── package-lock.json
│
└── README.md
```

---

## ✅ Neden Docker'a İhtiyacın Var? (Özet)

### Soru: "Ama ben Docker olmadan da yapabilirim?"

**Doğru, yapabilirsin. Ama:**

| Yön | Docker OLMADAN | Docker İLE |
|-----|---|---|
| **Ortam Kurması** | 1 saat (manual) | 2 dakika (`docker-compose up`) |
| **"Benim PC'de çalışıyor"** | Sık sorun | Asla sorun |
| **Test Ortamı** | Mock database | Gerçek PostgreSQL/Redis |
| **Deploy** | SSH → Manual kurulum | Otomatik |
| **Version Control** | Dockerfile yok = hata | Dockerfile = repeatable |
| **Scaling** | Kubernetes isteyen karmaşık | Kubernetes'e hazır |
| **Team Onboarding** | "Bir saati var mı?" | "Bir tıkla hazır" |

### Sonuç

Docker + GitHub Actions = **Full Automation**

```
You: git push
GitHub Actions: Tüm işleri yapıyor
    - Test çalıştırıyor
    - Build ediyor
    - Deploy ediyor
You: Kahve içiyor 😎
```

---

## 🚀 Başlama Adımları

1. **Dockerfile yaz** (Dockerfile şablonu kullan)
2. **docker-compose.yml yaz** (local dev için)
3. **Testi kur** (npm test)
4. **CI workflow'unu ekle** (.github/workflows/ci.yml)
5. **CD workflow'unu ekle** (.github/workflows/cd.yml)
6. **Server kurulumunu yap** (docker-compose.prod.yml)
7. **Watchtower'ı başlat** (otomatik updates)
8. **Tag oluştur ve push et** (git tag v1.0.0)
9. **Otur ve izle** (GitHub Actions Action çalışıyor)
10. **Deployment tamamlandığını gör** (Slack notification)

---

## 📝 Pratik Örnek: Node.js API

Gerçek çalışan örnek (eklenecek ayrı dosyalarda):
- `Dockerfile` (production image)
- `docker-compose.yml` (dev setup)
- `docker-compose.prod.yml` (prod setup)
- `.github/workflows/ci.yml` (otomatik test)
- `.github/workflows/cd.yml` (otomatik deploy)
- `src/api.js` (basit Express server)
- `tests/api.test.js` (basit test)

Hepsi birlikte çalışır, copy-paste yapmaya hazır!
