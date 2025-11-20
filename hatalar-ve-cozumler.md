# GitHub Actions Docker - Sık Yapılan Hatalar ve Çözümleri

## Hata 1: Service Container'a Bağlanamama

### ❌ YANLIŞ KOD
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432
    
    steps:
      - name: Test connection
        run: |
          # localhost yerine service adı kullanılmalı!
          psql -h localhost -U postgres -c "SELECT 1"
          # Error: could not connect
```

**Problem**: Service container'a `localhost` ile bağlanmaya çalışılıyor, fakat job container'da değiliz.

### ✅ DOĞRU KOD
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    
    # Çözüm 1: Service adı ile bağlan
    services:
      postgres:  # Service adı: "postgres"
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432
    
    steps:
      - name: Test connection
        run: |
          # Doğru: Service adı kullanılır
          psql -h postgres -U postgres -c "SELECT 1"
          # Success!
```

**Çözüm**: Service'e kendi adı ile erişilir. `postgres` → hostname olur.

---

## Hata 2: Container Health Check Başarısız

### ❌ YANLIŞ KOD
```yaml
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: test
    # Health check yok!
    
    ports:
      - 5432:5432

steps:
  - name: Connect immediately
    run: psql -h postgres -U postgres -c "SELECT 1"
    # Hata: Connection refused (container henüz hazır değil)
```

**Problem**: Container başlamış olabilir ama henüz hazır değil. Health check gerekir.

### ✅ DOĞRU KOD
```yaml
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: test
    
    # Health check ekle
    options: |
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
      --health-start-period 10s
    
    ports:
      - 5432:5432

steps:
  - name: Connect safely
    run: |
      # Health check başarılı olana kadar GitHub bekler
      psql -h postgres -U postgres -c "SELECT 1"
      # Success!
```

**Çözüm**: Health check'ler container'ın gerçekten hazır olup olmadığını kontrol eder.

---

## Hata 3: Environment Variable'lar Görünmüyor

### ❌ YANLIŞ KOD
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    
    # Job level (workflow level)
    env:
      API_KEY: secret123
    
    container:
      image: node:18
      # Container level env yok!
    
    steps:
      - name: Check env
        run: echo $API_KEY
        # Hata: API_KEY boş
```

**Problem**: Job-level env, container'a otomatik geçmez. Container'ın kendi env'si olmalı.

### ✅ DOĞRU KOD
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    
    container:
      image: node:18
      
      # Container level env
      env:
        API_KEY: ${{ secrets.API_KEY }}
        DATABASE_URL: postgresql://user:pass@db:5432/db
        NODE_ENV: test
    
    steps:
      - name: Check env
        run: |
          echo "API_KEY: $API_KEY"
          echo "DATABASE_URL: $DATABASE_URL"
          # Success!
```

**Çözüm**: Environment variable'lar `container.env` altında tanımlanmalı.

---

## Hata 4: Container'da Dosya Paylaşımı

### ❌ YANLIŞ KOD
```yaml
steps:
  - name: Create file in container
    uses: docker://ubuntu:latest
    with:
      entrypoint: /bin/bash
      args: |
        -c '
        echo "test data" > /tmp/data.txt
        echo "Data saved"
        '
  
  - name: Read file
    run: cat /tmp/data.txt
    # Hata: File not found
    # Sebep: Önceki step container'da dosya oluşturuldu ama silinmişti
```

**Problem**: Her step container kendi izole environment'ında çalışır. Dosyalar paylaşılmaz.

### ✅ DOĞRU KOD
```yaml
steps:
  - name: Create file
    run: |
      mkdir -p data
      echo "test data" > data/test.txt
      echo "File created"
  
  - name: Read file
    run: cat data/test.txt
    # Success! /github/workspace shared olduğu için dosya vardır
  
  - name: Container'dan dosya oluştur (workspace'e)
    uses: docker://ubuntu:latest
    with:
      entrypoint: /bin/bash
      args: |
        -c '
        echo "container data" > /github/workspace/container-data.txt
        '
  
  - name: Container'dan oluşturulan dosyayı oku
    run: cat container-data.txt
    # Success!
```

**Çözüm**: Dosyaları `/github/workspace` altında oluştur (paylaşılan volume).

---

## Hata 5: Windows/macOS'ta Container Kullanma

### ❌ YANLIŞ KOD
```yaml
jobs:
  test:
    runs-on: windows-latest  # HATA!
    
    container:
      image: node:18  # Windows'ta container çalışmaz
    
    steps:
      - run: npm test
```

**Problem**: Container'lar sadece Linux runner'larda çalışır.

### ✅ DOĞRU KOD
```yaml
jobs:
  test:
    runs-on: ubuntu-latest  # Linux gerekli!
    
    container:
      image: node:18
    
    steps:
      - run: npm test
      # Başarılı!

# Eğer Windows/macOS gerekiyorsa:
jobs:
  test-windows:
    runs-on: windows-latest
    # Container kullanma, doğrudan çalıştır:
    steps:
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm test

  test-mac:
    runs-on: macos-latest
    # Container kullanma, doğrudan çalıştır:
    steps:
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm test
```

**Çözüm**: Container'lar sadece `ubuntu-*` runner'larda çalışır.

---

## Hata 6: Port Çakışması

### ❌ YANLIŞ KOD
```yaml
services:
  db1:
    image: postgres:15
    ports:
      - 5432:5432
  
  db2:
    image: postgres:15
    ports:
      - 5432:5432  # Aynı port!

# Hata: Port 5432 zaten kullanılıyor
```

**Problem**: İki service aynı port kullanmaya çalışıyor.

### ✅ DOĞRU KOD
```yaml
services:
  postgres-app:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: pass1
    ports:
      - 5432:5432  # Host port: 5432

  postgres-cache:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: pass2
    ports:
      - 5433:5432  # Host port: 5433 (farklı!)

steps:
  - name: Connect to services
    run: |
      # Host port'lar farklı
      psql -h postgres-app -p 5432 -U postgres  # Service name + exposed port
      psql -h postgres-cache -p 5432 -U postgres
```

**Çözüm**: Farklı host port'ları kullan veya sadece bir tanesini expose et.

---

## Hata 7: Secret'lar Loglanıyor

### ❌ YANLIŞ KOD
```yaml
steps:
  - name: Login
    run: |
      API_KEY=${{ secrets.API_KEY }}
      echo "Connecting with key: $API_KEY"
      # HATA: Secret log'da görünüyor!
      curl -H "Authorization: Bearer $API_KEY" https://api.example.com
```

**Problem**: Log'a yazdırılan secret görünür.

### ✅ DOĞRU KOD
```yaml
steps:
  - name: Login
    run: |
      curl -H "Authorization: Bearer ${{ secrets.API_KEY }}" https://api.example.com
      # GitHub otomatik olarak secret'ı masker eder
    
    # Veya environment variable kullan:
    env:
      API_KEY: ${{ secrets.API_KEY }}
    
  - name: Don't print secrets
    run: |
      # ❌ Bunu yapma:
      # echo "API_KEY: $API_KEY"
      
      # ✅ Bunu yap:
      echo "Login successful"
      # Secret hiç loglanmaz
```

**Çözüm**: Secret'ları hiçbir zaman `echo` etme. GitHub otomatik masker yapar.

---

## Hata 8: Dependency Cache Etmek

### ❌ YANLIŞ KOD
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    
    container:
      image: node:18
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install dependencies
        run: npm ci
        # Her çalıştırmada dependencies tekrar indirilir (YAVAŞ!)
      
      - name: Test
        run: npm test
```

**Problem**: Dependencies her seferinde indirilir.

### ✅ DOĞRU KOD
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    
    container:
      image: node:18
    
    steps:
      - uses: actions/checkout@v4
      
      # Cache ekle
      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: node_modules
          key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-npm-
      
      - name: Install dependencies
        run: npm ci
        # Cache varsa çok hızlı, yoksa normal yükleme
      
      - name: Test
        run: npm test
```

**Çözüm**: Dependencies'i cache'le.

---

## Hata 9: Credentials Geçmemek (Private Registry)

### ❌ YANLIŞ KOD
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    
    container:
      image: ghcr.io/myorg/private-image:latest
      # Credentials yok!
    
    steps:
      - run: npm test
      # Hata: Image pull başarısız (403 Forbidden)
```

**Problem**: Private registry'den image çekemiyoruz.

### ✅ DOĞRU KOD
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    
    container:
      image: ghcr.io/myorg/private-image:latest
      
      # Credentials ekle
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    steps:
      - run: npm test
      # Başarılı!
```

**Çözüm**: Private registry için credentials geç.

---

## Hata 10: Container Memory Hatası

### ❌ YANLIŞ KOD
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    
    container:
      image: node:18
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build
        run: npm run build
        # Hata: JavaScript heap out of memory
```

**Problem**: Container'a yeterli bellek ayrılmadı.

### ✅ DOĞRU KOD
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    
    container:
      image: node:18
      
      # Bellek options
      options: |
        --cpus 2
        --memory 4096m
    
    env:
      NODE_OPTIONS: "--max-old-space-size=3072"
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build
        run: npm run build
        # Başarılı!
```

**Çözüm**: Container'a yeterli resource ayır ve Node.js bellek limiti artır.

---

## Özet: Hata Kategorileri ve Çözümleri

| Hata | Sebep | Çözüm |
|------|-------|-------|
| Service bağlantısı başarısız | localhost kullanıldı | Service adı kullanmak |
| Connection refused | Container hazır değil | Health check eklemek |
| Env variable boş | Job-level env kullanıldı | Container.env kullanmak |
| Dosya bulunamadı | Step container silinmiş | /github/workspace kullanmak |
| Container çalışmadı | Windows/macOS runner | Ubuntu runner kullanmak |
| Port çakışması | Aynı port 2x | Farklı port'lar kullanmak |
| Secret loglandı | Echo komutu | Secret'ları loglamamak |
| Yavaş build | Cache yok | Cache eklemek |
| Image pull başarısız | Credentials yok | Credentials geçmek |
| Memory error | Yetersiz resource | Memory artırmak |

---

## Debugging İpuçları

### Adım 1: Container'da mı çalışıyoruz?
```yaml
- name: Check container
  run: |
    if [ -f /.dockerenv ]; then
      echo "✓ In container"
    else
      echo "✗ Not in container"
    fi
```

### Adım 2: Service'ler aktif mi?
```yaml
- name: Check services
  run: |
    docker ps
    netstat -tlnp | grep LISTEN
```

### Adım 3: Environment variable'lar neler?
```yaml
- name: Debug env
  run: |
    env | sort
    echo "SPECIFIC_VAR: $SPECIFIC_VAR"
```

### Adım 4: Dosyalar nerede?
```yaml
- name: Check files
  run: |
    pwd
    ls -la /github/workspace
    df -h
```

### Adım 5: Log'ları kontrol et
```bash
# GitHub Actions web interface'de "View logs" butonuna tıkla
# Detaylı hata mesajları görebilirsin
```

---

## Kaynaklar

- GitHub Docs: https://docs.github.com/en/actions
- Docker: https://docs.docker.com
- Stack Overflow: Tag `github-actions`
