# Примеры использования

Этот документ содержит практические примеры использования системы k8s-helm-tilt-service в различных сценариях.

## Сценарии развертывания

### 1. Разработка с полной функциональностью

**Цель**: Запустить оба микросервиса с персистентным хранилищем для разработки.

```bash
# Запуск с Tilt (рекомендуется)
tilt up -- --environment=dev

# Или с Helm
helm install dev-release ./helm-chart -f ./environments/dev-values.yaml
```

**Результат**:
- Microservice 1: http://localhost:8001
- Microservice 2: http://localhost:8002
- Данные сохраняются между перезапусками
- Live reload при изменении кода

### 2. Тестирование без персистентных данных

**Цель**: Быстрое тестирование без сохранения данных.

```bash
# Запуск тестовой конфигурации
tilt up -- --environment=test

# Или с Helm
helm install test-release ./helm-chart -f ./environments/test-values.yaml
```

**Результат**:
- Оба микросервиса работают
- Данные удаляются при рестарте подов
- Меньше потребление ресурсов

### 3. Изолированное тестирование первого микросервиса

**Цель**: Тестирование только первого микросервиса.

```bash
# Только первый микросервис
tilt up -- --environment=service1-only

# Или с Helm
helm install service1-release ./helm-chart -f ./environments/service1-only-values.yaml
```

**Результат**:
- Только Microservice 1: http://localhost:8001
- Microservice 2 не развертывается
- Экономия ресурсов кластера

### 4. Изолированное тестирование второго микросервиса

**Цель**: Тестирование только второго микросервиса.

```bash
# Только второй микросервис
tilt up -- --environment=service2-only

# Или с Helm
helm install service2-release ./helm-chart -f ./environments/service2-only-values.yaml
```

**Результат**:
- Только Microservice 2: http://localhost:8002
- Microservice 1 не развертывается
- Экономия ресурсов кластера

## Примеры API вызовов

### Проверка состояния сервисов

```bash
# Health check для обоих сервисов
curl -s http://localhost:8001/health | jq '.'
curl -s http://localhost:8002/health | jq '.'

# Ожидаемый ответ:
{
  "service": "microservice1",
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.123456",
  "database_connected": true,
  "message": "Service is healthy"
}
```

### Проверка состояния баз данных

```bash
# Статус базы данных для каждого сервиса
curl -s http://localhost:8001/db-status | jq '.'
curl -s http://localhost:8002/db-status | jq '.'

# Ожидаемый ответ:
{
  "service": "microservice1",
  "database": {
    "connected": true,
    "version": "PostgreSQL 15.x...",
    "tables_count": 1,
    "test_records": 5,
    "last_check": "2024-01-15T10:30:00.123456"
  }
}
```

### Использование API endpoints

```bash
# API endpoints сервисов
curl -s http://localhost:8001/api/service1 | jq '.'
curl -s http://localhost:8002/api/service2 | jq '.'

# Ожидаемый ответ:
{
  "service": "microservice1",
  "message": "Hello from Microservice 1!",
  "timestamp": "2024-01-15T10:30:00.123456",
  "endpoints": ["/health", "/db-status", "/api/service1"]
}
```

## Мониторинг и отладка

### Просмотр логов в реальном времени

```bash
# Логи веб-приложений
kubectl logs -f deployment/microservice1-web
kubectl logs -f deployment/microservice2-web

# Логи баз данных
kubectl logs -f statefulset/microservice1-postgres
kubectl logs -f statefulset/microservice2-postgres

# Все логи одновременно (требует stern)
stern microservice
```

### Проверка ресурсов

```bash
# Статус всех подов
kubectl get pods -o wide

# Использование ресурсов
kubectl top pods

# Статус персистентных томов
kubectl get pvc

# События кластера
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Отладка сетевых проблем

```bash
# Проверка Services
kubectl get svc

# Проверка Endpoints
kubectl get endpoints

# Тестирование подключения изнутри кластера
kubectl run debug --image=busybox -it --rm -- sh
# Внутри пода:
nslookup microservice1-web
nslookup postgres-service1
wget -qO- http://microservice1-web/health
```

## Кастомизация конфигурации

### Создание собственного профиля

Создайте файл `environments/my-custom-values.yaml`:

```yaml
global:
  namespace: my-namespace
  labels:
    environment: custom
    team: my-team

microservice1:
  enabled: true
  webApp:
    replicas: 2  # Увеличиваем количество реплик
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 1000m
        memory: 1Gi
  postgres:
    enabled: true
    persistence:
      enabled: true
      size: 5Gi  # Увеличиваем размер хранилища
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 2Gi

microservice2:
  enabled: false  # Отключаем второй сервис
```

Использование:

```bash
helm install custom-release ./helm-chart -f ./environments/my-custom-values.yaml
```

### Переопределение отдельных параметров

```bash
# Изменение количества реплик
helm install my-release ./helm-chart \
  --set microservice1.webApp.replicas=3 \
  --set microservice2.webApp.replicas=2

# Отключение персистентного хранилища
helm install my-release ./helm-chart \
  --set microservice1.postgres.persistence.enabled=false \
  --set microservice2.postgres.persistence.enabled=false

# Изменение размера хранилища
helm install my-release ./helm-chart \
  --set microservice1.postgres.persistence.size=10Gi
```

## Интеграция с CI/CD

### GitHub Actions пример

```yaml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Helm
      uses: azure/setup-helm@v1
      with:
        version: '3.8.0'
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v1
    
    - name: Run Helm tests
      run: |
        ./helm-chart/tests/template-tests.sh
    
    - name: Deploy to staging
      run: |
        helm upgrade --install staging-release ./helm-chart \
          -f ./environments/test-values.yaml \
          --namespace staging \
          --create-namespace
    
    - name: Run integration tests
      run: |
        export NAMESPACE=staging
        export RELEASE_NAME=staging-release
        ./helm-chart/tests/integration-tests.sh
```

### GitLab CI пример

```yaml
stages:
  - test
  - deploy

helm-test:
  stage: test
  script:
    - ./helm-chart/tests/template-tests.sh

deploy-staging:
  stage: deploy
  script:
    - helm upgrade --install staging-release ./helm-chart 
        -f ./environments/test-values.yaml
        --namespace staging
        --create-namespace
  only:
    - main

integration-test:
  stage: deploy
  script:
    - export NAMESPACE=staging
    - export RELEASE_NAME=staging-release
    - ./helm-chart/tests/integration-tests.sh
  needs:
    - deploy-staging
```

## Производственное развертывание

### Подготовка к продакшену

1. **Создайте production values файл**:

```yaml
# environments/prod-values.yaml
global:
  namespace: production
  labels:
    environment: production

microservice1:
  enabled: true
  webApp:
    image:
      tag: "v1.0.0"  # Используйте конкретные теги
      pullPolicy: IfNotPresent
    replicas: 3  # Множественные реплики для HA
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 2000m
        memory: 2Gi
  postgres:
    persistence:
      enabled: true
      size: 50Gi  # Больше места для продакшена
      storageClass: "fast-ssd"  # Быстрое хранилище
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 4Gi

microservice2:
  # Аналогичная конфигурация
```

2. **Развертывание**:

```bash
# Создание namespace
kubectl create namespace production

# Развертывание
helm install prod-release ./helm-chart \
  -f ./environments/prod-values.yaml \
  --namespace production

# Проверка
kubectl get all -n production
```

### Мониторинг в продакшене

```bash
# Настройка алертов на основе health checks
kubectl create configmap monitoring-config --from-literal=config.yaml="
targets:
  - http://microservice1-web.production.svc.cluster.local/health
  - http://microservice2-web.production.svc.cluster.local/health
"

# Проверка метрик
kubectl top pods -n production
kubectl get events -n production --sort-by=.metadata.creationTimestamp
```

## Backup и восстановление

### Backup баз данных

```bash
# Backup первого микросервиса
kubectl exec -it microservice1-postgres-0 -n production -- \
  pg_dump -U service1_user service1_db > microservice1-backup.sql

# Backup второго микросервиса
kubectl exec -it microservice2-postgres-0 -n production -- \
  pg_dump -U service2_user service2_db > microservice2-backup.sql
```

### Восстановление

```bash
# Восстановление первого микросервиса
kubectl exec -i microservice1-postgres-0 -n production -- \
  psql -U service1_user service1_db < microservice1-backup.sql

# Восстановление второго микросервиса
kubectl exec -i microservice2-postgres-0 -n production -- \
  psql -U service2_user service2_db < microservice2-backup.sql
```

## Масштабирование

### Горизонтальное масштабирование

```bash
# Увеличение количества реплик веб-приложений
kubectl scale deployment microservice1-web --replicas=5
kubectl scale deployment microservice2-web --replicas=3

# Или через Helm
helm upgrade prod-release ./helm-chart \
  -f ./environments/prod-values.yaml \
  --set microservice1.webApp.replicas=5 \
  --set microservice2.webApp.replicas=3 \
  --namespace production
```

### Автоматическое масштабирование

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: microservice1-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: microservice1-web
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

```bash
kubectl apply -f hpa.yaml
kubectl get hpa
```

Эти примеры покрывают основные сценарии использования системы от разработки до продакшена.