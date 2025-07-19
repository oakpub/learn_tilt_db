# K8s Helm Tilt Service

Система из двух независимых тестовых микросервисов для изучения Kubernetes. Каждый микросервис имеет свою собственную базу данных PostgreSQL с персистентным хранилищем. Проект использует Helm для управления Kubernetes манифестами и Tilt для автоматизации разработки.

## Особенности

- ✅ **Два независимых микросервиса** с собственными базами данных
- ✅ **Модульная архитектура** - каждый микросервис можно включать/отключать независимо
- ✅ **Гибкое управление персистентным хранилищем** для каждого микросервиса отдельно
- ✅ **Различные профили развертывания** для разных сред
- ✅ **Автоматизация с Tilt** - live reload и мониторинг
- ✅ **Готовые тесты** для проверки функциональности

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
├─────────────────────────┬───────────────────────────────────┤
│     Microservice 1      │        Microservice 2             │
│  ┌─────────────────┐    │    ┌─────────────────┐            │
│  │   Web App       │    │    │   Web App       │            │
│  │   Port: 5001    │    │    │   Port: 5002    │            │
│  └─────────────────┘    │    └─────────────────┘            │
│  ┌─────────────────┐    │    ┌─────────────────┐            │
│  │  PostgreSQL     │    │    │  PostgreSQL     │            │
│  │  service1_db    │    │    │  service2_db    │            │
│  └─────────────────┘    │    └─────────────────┘            │
│  ┌─────────────────┐    │    ┌─────────────────┐            │
│  │      PVC        │    │    │      PVC        │            │
│  │   (optional)    │    │    │   (optional)    │            │
│  └─────────────────┘    │    └─────────────────┘            │
└─────────────────────────┴───────────────────────────────────┘
```

## Предварительные требования

- [Docker](https://docs.docker.com/get-docker/)
- [Kubernetes](https://kubernetes.io/docs/setup/) (minikube, kind, или полноценный кластер)
- [Helm 3](https://helm.sh/docs/intro/install/)
- [Tilt](https://docs.tilt.dev/install.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Быстрый старт

### 1. Клонирование репозитория

```bash
git clone <repository-url>
cd k8s-helm-tilt-service
```

### 2. Запуск с Tilt (рекомендуется для разработки)

```bash
# Запуск с профилем разработки (по умолчанию)
tilt up

# Запуск с конкретным профилем
tilt up -- --environment=dev
tilt up -- --environment=test
tilt up -- --environment=service1-only
tilt up -- --environment=service2-only
```

Откройте Tilt UI: http://localhost:10350

### 3. Доступ к сервисам

- **Microservice 1**: http://localhost:8001
- **Microservice 2**: http://localhost:8002

### 4. Остановка

```bash
tilt down
```

## Развертывание с Helm

### Установка с профилем по умолчанию

```bash
helm install my-release ./helm-chart
```

### Установка с конкретным профилем

```bash
# Полная разработческая среда
helm install my-release ./helm-chart -f ./environments/dev-values.yaml

# Только первый микросервис
helm install my-release ./helm-chart -f ./environments/service1-only-values.yaml

# Только второй микросервис
helm install my-release ./helm-chart -f ./environments/service2-only-values.yaml

# Тестовая среда без персистентного хранилища
helm install my-release ./helm-chart -f ./environments/test-values.yaml
```

### Обновление

```bash
helm upgrade my-release ./helm-chart -f ./environments/dev-values.yaml
```

### Удаление

```bash
helm uninstall my-release
```

## Профили развертывания

### 1. Development (`dev-values.yaml`)
- Оба микросервиса включены
- Персистентное хранилище включено (2Gi каждый)
- Увеличенные ресурсы
- Always pull policy для образов

### 2. Test (`test-values.yaml`)
- Оба микросервиса включены
- Персистентное хранилище отключено (emptyDir)
- Уменьшенные ресурсы
- Данные удаляются при рестарте

### 3. Service 1 Only (`service1-only-values.yaml`)
- Только первый микросервис
- Персистентное хранилище включено
- Второй микросервис полностью отключен

### 4. Service 2 Only (`service2-only-values.yaml`)
- Только второй микросервис
- Персистентное хранилище включено
- Первый микросервис полностью отключен

## API Endpoints

### Microservice 1 (порт 8001)

- `GET /` - Информация о сервисе
- `GET /health` - Health check
- `GET /db-status` - Статус подключения к базе данных
- `GET /api/service1` - API endpoint сервиса

### Microservice 2 (порт 8002)

- `GET /` - Информация о сервисе
- `GET /health` - Health check
- `GET /db-status` - Статус подключения к базе данных
- `GET /api/service2` - API endpoint сервиса

## Конфигурация

### Основные параметры

```yaml
global:
  namespace: default
  labels: {}

microservice1:
  enabled: true                    # Включить/отключить микросервис
  webApp:
    image:
      repository: microservice1
      tag: latest
      pullPolicy: IfNotPresent
    service:
      type: ClusterIP
      port: 80
      targetPort: 5001
    replicas: 1
    resources: {}
  postgres:
    enabled: true                  # Включить/отключить PostgreSQL
    persistence:
      enabled: true                # Включить/отключить персистентное хранилище
      size: 1Gi
      storageClass: ""
    auth:
      database: service1_db
      username: service1_user
      password: service1_password

microservice2:
  # Аналогичная структура для второго микросервиса
```

### Переменные окружения

Микросервисы используют следующие переменные окружения:

- `DB_HOST` - Хост базы данных
- `DB_PORT` - Порт базы данных
- `DB_NAME` - Имя базы данных
- `DB_USER` - Пользователь базы данных
- `DB_PASSWORD` - Пароль базы данных

## Тестирование

### Тесты Helm templates

```bash
./helm-chart/tests/template-tests.sh
```

### Интеграционные тесты

```bash
# После развертывания в кластере
./helm-chart/tests/integration-tests.sh
```

### Ручное тестирование

```bash
# Проверка health check
curl http://localhost:8001/health
curl http://localhost:8002/health

# Проверка статуса базы данных
curl http://localhost:8001/db-status
curl http://localhost:8002/db-status

# Проверка API endpoints
curl http://localhost:8001/api/service1
curl http://localhost:8002/api/service2
```

## Мониторинг и логи

### Просмотр логов

```bash
# Логи микросервисов
kubectl logs -f deployment/microservice1-web
kubectl logs -f deployment/microservice2-web

# Логи баз данных
kubectl logs -f statefulset/microservice1-postgres
kubectl logs -f statefulset/microservice2-postgres
```

### Проверка статуса

```bash
# Статус всех ресурсов
kubectl get all

# Статус персистентных томов
kubectl get pvc

# Детальная информация о подах
kubectl describe pods
```

## Troubleshooting

### Проблема: Поды не запускаются

1. Проверьте статус подов:
   ```bash
   kubectl get pods
   kubectl describe pod <pod-name>
   ```

2. Проверьте логи:
   ```bash
   kubectl logs <pod-name>
   ```

3. Проверьте ресурсы кластера:
   ```bash
   kubectl top nodes
   kubectl get events
   ```

### Проблема: База данных недоступна

1. Проверьте статус StatefulSet:
   ```bash
   kubectl get statefulset
   kubectl describe statefulset microservice1-postgres
   ```

2. Проверьте PVC:
   ```bash
   kubectl get pvc
   kubectl describe pvc microservice1-postgres-pvc
   ```

3. Проверьте логи PostgreSQL:
   ```bash
   kubectl logs statefulset/microservice1-postgres
   ```

### Проблема: Сервисы недоступны

1. Проверьте Services:
   ```bash
   kubectl get svc
   kubectl describe svc microservice1-web
   ```

2. Проверьте port-forward:
   ```bash
   kubectl port-forward svc/microservice1-web 8001:80
   ```

3. Проверьте endpoints:
   ```bash
   kubectl get endpoints
   ```

## Разработка

### Структура проекта

```
k8s-helm-tilt-service/
├── Tiltfile                    # Конфигурация Tilt
├── docker/
│   ├── microservice1/         # Первый микросервис
│   └── microservice2/         # Второй микросервис
├── helm-chart/                # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── environments/              # Профили развертывания
├── docs/                      # Документация
└── README.md
```

### Добавление нового микросервиса

1. Создайте директорию в `docker/`
2. Добавьте конфигурацию в `helm-chart/values.yaml`
3. Создайте templates в `helm-chart/templates/`
4. Обновите `Tiltfile`
5. Добавьте тесты

### Изменение конфигурации

1. Отредактируйте `helm-chart/values.yaml` или файлы в `environments/`
2. При использовании Tilt изменения применятся автоматически
3. При использовании Helm выполните `helm upgrade`

## Лицензия

MIT License