# Tiltfile for k8s-helm-tilt-service

# Configuration
config.define_string("environment", args=False, usage="Environment to deploy (dev, test, service1-only, service2-only)")
cfg = config.parse()
environment = cfg.get("environment", "dev")

# Determine values file based on environment
values_file = "./environments/{}-values.yaml".format(environment)
if not os.path.exists(values_file):
    values_file = "./helm-chart/values.yaml"

print("Using values file: {}".format(values_file))

# Build Docker images for microservices with live reload
docker_build(
    'microservice1', 
    './docker/microservice1',
    dockerfile='./docker/microservice1/Dockerfile',
    live_update=[
        sync('./docker/microservice1/src', '/app'),
        run('pip install -r requirements.txt', trigger=['./docker/microservice1/requirements.txt'])
    ]
)

docker_build(
    'microservice2', 
    './docker/microservice2',
    dockerfile='./docker/microservice2/Dockerfile',
    live_update=[
        sync('./docker/microservice2/src', '/app'),
        run('pip install -r requirements.txt', trigger=['./docker/microservice2/requirements.txt'])
    ]
)

# Deploy using Helm with selected environment
k8s_yaml(helm('./helm-chart', values=[values_file]))

# Port forwards for local development
k8s_resource('microservice1-web', port_forwards='8001:80')
k8s_resource('microservice2-web', port_forwards='8002:80')

# Resource grouping for better UI organization
k8s_resource(
    workload='microservice1-web',
    objects=[
        'microservice1-web:service', 
        'microservice1-config:configmap', 
        'microservice1-secret:secret'
    ],
    resource_deps=['microservice1-postgres'],
    labels=['microservice1']
)

k8s_resource(
    workload='microservice2-web', 
    objects=[
        'microservice2-web:service', 
        'microservice2-config:configmap', 
        'microservice2-secret:secret'
    ],
    resource_deps=['microservice2-postgres'],
    labels=['microservice2']
)

k8s_resource(
    workload='microservice1-postgres',
    objects=[
        'microservice1-postgres:service', 
        'microservice1-postgres-pvc:persistentvolumeclaim'
    ],
    labels=['microservice1', 'database']
)

k8s_resource(
    workload='microservice2-postgres',
    objects=[
        'microservice2-postgres:service', 
        'microservice2-postgres-pvc:persistentvolumeclaim'
    ],
    labels=['microservice2', 'database']
)

# Local resource for running tests
local_resource(
    'helm-lint',
    'helm lint ./helm-chart',
    deps=['./helm-chart'],
    labels=['validation']
)

# Watch for changes in values files
watch_file(values_file)
watch_file('./helm-chart/values.yaml')

print("Tilt is configured for environment: {}".format(environment))
print("Access microservice1 at: http://localhost:8001")
print("Access microservice2 at: http://localhost:8002")