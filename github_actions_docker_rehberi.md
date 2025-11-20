# GitHub Actions'ta Docker Container Kullanımı - Kapsamlı Rehber

## 1. Giriş: Docker Container'lar Ne Zaman Gereklidir?

### Container'lar Ne Zaman Kullanılmalı?

Docker container'ları GitHub Actions workflow'larında şu durumlarda kullanılır:

1. **Tutarlı Ortam (Consistent Environment)**: Her çalıştırmada aynı environment'ta çalışmak. Örneğin, Python 3.11, PostgreSQL 15 ve Redis 7 gibi belirli sürümleri garantilemek.

2. **Izole Ortam (Job Isolation)**: Farklı job'ların farklı araç ve kütüphanelerini çatışmasız kullanması. Bir job Node.js 18, diğeri Node.js 20 kullanabilir.

3. **Hızlı Setup**: Runner'da her seferinde bağımlılıkları kurma yerine, önceden hazırlanmış image kullanmak.

4. **Çoklu Servis (Multi-Service Jobs)**: Uygulamanız PostgreSQL ve Redis gibi birden çok servise ihtiyaç duyarsa.

5. **Platform Bağımsızlığı**: Kodun Windows, macOS veya Linux'ta aynı şekilde çalışmasını sağlamak.

### Nerede Çalışırlar?

Container'lar GitHub tarafından sağlanan **runner makinesinde** çalışır. İşlem sırası:

1. **Runner başlatılır** → Ubuntu VM (github.com hosted runner)
2. **Container başlatılır** → Runner içinde Docker container oluşturulur
3. **Workflow adımları çalışır** → Container içinde execution gerçekleşir
4. **Container sonlandırılır** → Job tamamlanınca container silinir

### Container'lar Devam Eder mi Yoksa Sonlanır mı?

**Container'lar job tamamlandığında otomatik olarak SONLANIR ve silinir.**

- Container'ın içinde oluşturulan dosyalar GitHub workspace'e yazılmadığı sürece kaybolur
- Container'ın yapısında yapılan değişiklikler persistent değildir
- Her job yeni bir container başlatır (service container'lar hariç)

---

## 2. Docker Container'ların Üç Kullanım Seviyesi

### Seviye 1: JOB-LEVEL (Tüm Job bir Container'da)

Tüm adımlar aynı container içinde çalışır.

```yaml
name: Job Level Container Example
on: [push]

jobs:
  test-job:
    runs-on: ubuntu-latest
    # Tüm adımlar bu container içinde çalışır
    container:
      image: node:18-alpine
      env:
        NODE_ENV: production
      ports:
        - 3000:3000
      volumes:
        - cache_volume:/app/node_modules
      options: --cpus 2 --memory 1024m
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Build application
        run: npm run build

volumes:
  cache_volume:
```

**Avantajları:**
- Tüm adımlar aynı ortamda çalışır
- Konfigürasyon basit
- Environment variable'lar paylaşılır
- Volume'ler adımlar arasında paylaşılır

**Dezavantajları:**
- Tüm adımlar için tek image kullanılır
- Farklı tool sürümleri kullanamaz

---

### Seviye 2: STEP-LEVEL (Tek Step bir Container'da)

Belirli adımlar farklı container'larda çalışır.

```yaml
name: Step Level Container Example
on: [push]

jobs:
  multi-container-job:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      # Node container'ında çalışır
      - name: Check Node version
        uses: docker://node:18-alpine
        with:
          entrypoint: node
          args: --version
      
      # Python container'ında çalışır
      - name: Check Python version
        uses: docker://python:3.11-alpine
        with:
          entrypoint: python
          args: --version
      
      # Java container'ında çalışır
      - name: Check Java version
        uses: docker://openjdk:17-alpine
        with:
          entrypoint: java
          args: --version
      
      # Host machine'de çalışır (container yok)
      - name: Run on host
        run: echo "This runs on the runner, not in a container"
```

**Avantajları:**
- Farklı adımlar için farklı araçlar kullanılabilir
- Esnek ve modüler yapı
- Ağır tool'ları sadece ihtiyaç olduğunda yükler

**Dezavantajları:**
- Daha fazla container overhead
- Her step ayrı container'da çalışırsa, dosya paylaşımı daha karmaşık

---

### Seviye 3: SERVICE CONTAINERS (Destekleyici Servisler)

Tüm job boyunca çalışan veritabanları, cache'ler vb.

```yaml
name: Service Container Example
on: [push]

jobs:
  integration-test:
    runs-on: ubuntu-latest
    
    # Ana container: Uygulamayı çalıştırır
    container:
      image: node:18-alpine
      ports:
        - 3000:3000
    
    # Destekleyici container'lar: Tüm job boyunca çalışır
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_PASSWORD: test123
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
        volumes:
          - postgres_data:/var/lib/postgresql/data
      
      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379
      
      elasticsearch:
        image: docker.elastic.co/elasticsearch/elasticsearch:8.5.0
        env:
          discovery.type: single-node
          xpack.security.enabled: "false"
        options: >-
          --health-cmd "curl http://localhost:9200 > /dev/null"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 9200:9200
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Install dependencies
        run: npm ci
      
      - name: Wait for services
        run: |
          echo "Waiting for PostgreSQL..."
          until nc -z postgres 5432; do
            sleep 1
          done
          echo "PostgreSQL is ready!"
          
          echo "Waiting for Redis..."
          until nc -z redis 6379; do
            sleep 1
          done
          echo "Redis is ready!"
      
      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:test123@postgres:5432/testdb
          REDIS_URL: redis://redis:6379
          ELASTICSEARCH_URL: http://elasticsearch:9200
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results/

volumes:
  postgres_data:
```

**Avantajları:**
- Birden çok servisi kolay yönetebilir
- Service container'lar tüm job boyunca çalışır
- Service'lere job container'ından hostname ile erişilir
- Health check'ler container'ın hazır olup olmadığını kontrol eder

**Dezavantajları:**
- Birden çok container = daha fazla kaynak kullanımı
- İlk başlatma biraz daha yavaş

---

## 3. GLOBAL-LEVEL Container Yapılandırması

Repository düzeyinde varsayılan container ayarları:

```yaml
name: Global Container Config Example
on: [push]

env:
  REGISTRY: ghcr.io
  DOCKER_BUILDKIT: 1

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    
    # GLOBAL: Tüm adımlar için varsayılan shell
    defaults:
      run:
        shell: bash
        working-directory: ./app
    
    container:
      image: node:18-alpine
      
      # GLOBAL: Container environment variables
      env:
        CI: "true"
        NODE_ENV: test
        LOG_LEVEL: debug
      
      # GLOBAL: Container port bindings
      ports:
        - 8080:8080
        - 3000:3000
      
      # GLOBAL: Container volumes (job süresince kalır)
      volumes:
        - build_cache:/app/.build
        - npm_cache:/app/node_modules/.cache
      
      # GLOBAL: Container runtime seçenekleri
      options: |
        --cpus 2
        --memory 2048m
        --memory-reservation 1024m
        --pids-limit 256
        --ipc host
        --cap-add SYS_PTRACE
      
      # GLOBAL: Private registry credentials
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Install dependencies
        run: npm ci
      
      - name: Build
        run: npm run build
      
      - name: Test
        run: npm test

volumes:
  build_cache:
  npm_cache:
```

**Global Ayarlar Nelerdir:**
- `image`: Kullanılacak Docker image
- `env`: Container içindeki environment variable'lar
- `ports`: Expose edilecek port'lar
- `volumes`: Container içinde kullanılacak volume'ler
- `options`: Docker runtime seçenekleri
- `credentials`: Private registry'ye erişim

---

## 4. Step-Level Container Detaylı Örnekler

### Step-Level Örnek 1: Farklı Dil Runtime'ları

```yaml
name: Multi-Language Step Testing
on: [push]

jobs:
  test-multiple-languages:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      # Python adımı
      - name: Python Tests
        uses: docker://python:3.11-slim
        with:
          entrypoint: /bin/bash
          args: |
            -c '
            pip install pytest requests
            pytest tests/python/
            '
      
      # Node.js adımı
      - name: JavaScript Tests
        uses: docker://node:18-alpine
        with:
          entrypoint: sh
          args: |
            -c '
            npm install
            npm test
            '
      
      # Ruby adımı
      - name: Ruby Tests
        uses: docker://ruby:3.2
        with:
          entrypoint: /bin/bash
          args: |
            -c '
            gem install bundler
            bundle install
            bundle exec rspec
            '
      
      # Go adımı
      - name: Go Tests
        uses: docker://golang:1.21
        with:
          entrypoint: bash
          args: |
            -c '
            go test ./...
            go build -o app
            '
```

### Step-Level Örnek 2: Custom Dockerfile Kullanımı

```yaml
name: Custom Docker Image Step
on: [push]

jobs:
  custom-image-job:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      # Custom Dockerfile'dan image oluştur ve çalıştır
      - name: Build and run custom image
        uses: docker://docker:latest
        with:
          entrypoint: sh
          args: |
            -c '
            docker build -t my-custom-app:latest .
            docker run --rm my-custom-app:latest
            '
      
      # Private registry'den image çek
      - name: Run from private registry
        uses: docker://ghcr.io/myorg/myimage:latest
        with:
          entrypoint: /app/script.sh
```

### Step-Level Örnek 3: Environment ve Arguments

```yaml
name: Step Environment Variables
on: [push]

jobs:
  step-env-example:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Run with environment
        uses: docker://python:3.11
        env:
          # Container içindeki env var'lar
          API_KEY: ${{ secrets.API_KEY }}
          DATABASE_URL: postgresql://user:pass@db:5432/mydb
          DEBUG: "true"
        with:
          entrypoint: python
          args: |
            -c "
            import os
            print(f'API Key: {os.getenv(\"API_KEY\")}')
            print(f'Database: {os.getenv(\"DATABASE_URL\")}')
            print(f'Debug: {os.getenv(\"DEBUG\")}')
            "
```

---

## 5. Service Container'lar - Detaylı Kullanım

### Örnek 1: Tüm Servisler ile Eksiksiz Setup

```yaml
name: Complete Service Containers Setup
on: [push]

jobs:
  full-stack-test:
    runs-on: ubuntu-latest
    
    # Ana container
    container:
      image: node:18-alpine
      ports:
        - 3000:3000
      env:
        NODE_ENV: test
    
    # Destekleyici servisler
    services:
      # PostgreSQL Database
      db:
        image: postgres:15-alpine
        env:
          POSTGRES_USER: testuser
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: testdb
        options: |
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      # Redis Cache
      redis:
        image: redis:7-alpine
        options: |
          --health-cmd "redis-cli ping"
          --health-interval 5s
          --health-timeout 3s
          --health-retries 5
        ports:
          - 6379:6379
      
      # MongoDB
      mongo:
        image: mongo:6
        env:
          MONGO_INITDB_ROOT_USERNAME: admin
          MONGO_INITDB_ROOT_PASSWORD: adminpass
        options: |
          --health-cmd "mongosh --eval 'db.adminCommand(\"ping\")'"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 27017:27017
      
      # RabbitMQ
      rabbitmq:
        image: rabbitmq:3.12-management
        env:
          RABBITMQ_DEFAULT_USER: guest
          RABBITMQ_DEFAULT_PASS: guest
        options: |
          --health-cmd "rabbitmq-diagnostics ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5672:5672
          - 15672:15672
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Wait for services
        run: |
          # PostgreSQL hazır mı?
          until nc -z db 5432; do
            echo "Waiting for PostgreSQL..."
            sleep 2
          done
          echo "✓ PostgreSQL is ready"
          
          # Redis hazır mı?
          until nc -z redis 6379; do
            echo "Waiting for Redis..."
            sleep 1
          done
          echo "✓ Redis is ready"
          
          # MongoDB hazır mı?
          until nc -z mongo 27017; do
            echo "Waiting for MongoDB..."
            sleep 2
          done
          echo "✓ MongoDB is ready"
          
          # RabbitMQ hazır mı?
          until nc -z rabbitmq 5672; do
            echo "Waiting for RabbitMQ..."
            sleep 2
          done
          echo "✓ RabbitMQ is ready"
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run integration tests
        run: npm run test:integration
        env:
          # Service container'lara erişim
          DATABASE_URL: postgresql://testuser:testpass@db:5432/testdb
          REDIS_URL: redis://redis:6379/0
          MONGODB_URL: mongodb://admin:adminpass@mongo:27017/admin
          RABBITMQ_URL: amqp://guest:guest@rabbitmq:5672
          
      - name: Upload test reports
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-reports
          path: reports/
```

### Örnek 2: Conditional Service Containers

```yaml
name: Conditional Services
on: [push, pull_request]

jobs:
  smart-testing:
    runs-on: ubuntu-latest
    
    container:
      image: node:18-alpine
    
    services:
      # Sadece integration test çalışacaksa başlat
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        options: |
          --health-cmd pg_isready
          --health-interval 5s
          --health-timeout 3s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run unit tests
        run: npm run test:unit
      
      - name: Run integration tests
        if: github.event_name == 'push'
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:test@postgres:5432/testdb
```

### Örnek 3: Service Container Health Checks

```yaml
name: Advanced Health Checks
on: [push]

jobs:
  health-check-demo:
    runs-on: ubuntu-latest
    
    container:
      image: node:18-alpine
    
    services:
      # Gelişmiş health check
      api:
        image: myorg/myapi:latest
        options: |
          --health-cmd "curl -f http://localhost:8080/health || exit 1"
          --health-interval 2s
          --health-timeout 2s
          --health-retries 10
          --health-start-period 5s
        ports:
          - 8080:8080
        env:
          LOG_LEVEL: debug
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Verify API health
        run: |
          for i in {1..30}; do
            if curl -f http://api:8080/health; then
              echo "✓ API health check passed"
              exit 0
            fi
            echo "Attempt $i failed, retrying..."
            sleep 1
          done
          echo "✗ API health check failed"
          exit 1
      
      - name: Run tests against API
        run: npm run test:api
```

---

## 6. Pratik Örnekler: Gerçek Dünya Senaryoları

### Senaryo 1: Python Web Uygulaması Test Etme

```yaml
name: Python App CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    container:
      image: python:3.11-slim
      env:
        PYTHONUNBUFFERED: 1
        PIP_NO_CACHE_DIR: 1
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: appdb
          POSTGRES_USER: appuser
          POSTGRES_PASSWORD: apppass
        options: |
          --health-cmd pg_isready
          --health-interval 5s
          --health-timeout 3s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov pytest-django
      
      - name: Run tests
        run: |
          pytest --cov=. --cov-report=xml tests/
        env:
          DATABASE_URL: postgresql://appuser:apppass@postgres:5432/appdb
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
```

### Senaryo 2: Docker Image Build ve Push

```yaml
name: Build and Push Docker Image
on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build-push:
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      packages: write
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
      
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=registry,ref=ghcr.io/${{ github.repository }}:buildcache
          cache-to: type=registry,ref=ghcr.io/${{ github.repository }}:buildcache,mode=max
```

### Senaryo 3: Multi-Stage Pipeline

```yaml
name: Multi-Stage Pipeline
on: [push]

jobs:
  lint:
    runs-on: ubuntu-latest
    container:
      image: node:18-alpine
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint
  
  test:
    needs: lint
    runs-on: ubuntu-latest
    container:
      image: node:18-alpine
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        options: |
          --health-cmd pg_isready
          --health-interval 5s
          --health-timeout 3s
          --health-retries 5
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
        env:
          DATABASE_URL: postgresql://postgres:test@postgres:5432/postgres
  
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v2
      - uses: docker/build-push-action@v4
        with:
          context: .
          push: false
          tags: myapp:${{ github.sha }}
  
  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to production
        run: echo "Deploying to production..."
```

---

## 7. En İyi Uygulamalar (Best Practices)

### ✅ Yapılması Gerekenler

1. **Alpine image'ları kullan** (daha hafif)
   ```yaml
   image: node:18-alpine  # İyi
   image: node:18         # Ağır
   ```

2. **Health check'leri tanımla**
   ```yaml
   options: |
     --health-cmd "curl -f http://localhost:8080"
     --health-interval 10s
     --health-retries 5
   ```

3. **Kaynakları sınırla**
   ```yaml
   options: |
     --cpus 2
     --memory 2048m
   ```

4. **Secret'ları güvenli kullan**
   ```yaml
   env:
     API_KEY: ${{ secrets.API_KEY }}
   ```

5. **Artifact'ları yükle**
   ```yaml
   - uses: actions/upload-artifact@v3
     with:
       name: build-output
       path: dist/
   ```

### ❌ Yapılmaması Gerekenler

1. Container'da hardcoded credential'lar
2. Çok büyük image'lar (800MB+ tercih edilmez)
3. Health check'ler olmadan service container'lar
4. Container içinde permanent data beklenti
5. Runner'ın kaynaklarını tüm container'lara ayırma

---

## 8. Troubleshooting

### Problem: Container başlamıyor

```yaml
steps:
  - name: Debug container startup
    run: |
      docker ps -a
      docker logs <container_id>
```

### Problem: Service'e bağlanamıyor

```yaml
steps:
  - name: Test service connectivity
    run: |
      nc -zv postgres 5432
      nc -zv redis 6379
```

### Problem: Environment variable'lar görünmüyor

```yaml
# Doğru
container:
  env:
    MY_VAR: value

# Yanlış
env:
  MY_VAR: value  # Bu job level, container level değil!
```

---

## Özet

| Seviye | Kullanım | Avantaj | Dezavantaj |
|--------|----------|---------|-----------|
| **Job-Level** | Tüm adımlar | Basit, paylaşılan ortam | Tek image |
| **Step-Level** | Belirli adımlar | Farklı araçlar | Daha fazla overhead |
| **Service** | Veritabanı vb. | Arka plan servisleri | Daha fazla kaynak |

**Docker container'lar GitHub Actions'ta powerful araçlardır.** Doğru yapılandırıldığında tutarlı, hızlı ve güvenilir CI/CD pipeline'ları oluşturabilirsiniz.
