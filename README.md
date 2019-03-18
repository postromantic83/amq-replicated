
# Build from scratch

```
$ export REDHAT_REPO_URL=<>
$ export APP_NAME=amq-test-01
$ export AMQ_IMAGE=amq-paas
$ export PROMETHEUS_JMX_AGENT_VERSION=0.3.1
$ export PROMETHEUS_JMX_REPO_URL=http://central.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/$PROMETHEUS_JMX_AGENT_VERSION
$ export ADMIN_PASSWORD=$(apg -n 1)
$ export ADMIN_USER=$(apg -n 1)
$ export LOGGING_LEVEL=DEBUG

$ oc new-build \
    -l app=${APP_NAME} \
    https://github.com/dsevost/openshift-xpaas-images-tp \
    --context-dir=amq \
    -e PROMETHEUS_JMX_REPO_URL=$PROMETHEUS_JMX_REPO_URL \
    -e PROMETHEUS_JMX_AGENT_VERSION=$PROMETHEUS_JMX_AGENT_VERSION \
    -e REDHAT_COMPONENT_NAME=amq-broker-7.2.0-bin.zip \
    -e REDHAT_REPO_URL=$REDHAT_REPO_URL \
    --name=$AMQ_IMAGE \
    --strategy=docker \
    --image-stream=redhat-openjdk18-openshift:1.2

$ oc new-app \
    $AMQ_IMAGE \
    --name=$APP_NAME \
    -e ADMIN_USER=$ADMIN_USER \
    -e ADMIN_PASSWORD=$ADMIN_PASSWORD \
    -e LOGGING_LEVEL=$LOGGING_LEVEL

$ oc expose \
    dc/$APP_NAME \
    -l app=${APP_NAME} \
    --name ${APP_NAME}-broker-amq-tcp \
    --port 9779

$ oc expose \
    dc/$APP_NAME \
    -l app=${APP_NAME} \
    --name ${APP_NAME}-console \
    --port 8161

$ oc expose \
    svc/${APP_NAME}-console \
    -l app=${APP_NAME}
```

# Build from template
## Simplest instance
```
$ oc create -f amq/resources/amq71-basic.yaml
```

## Replicated instance
```
$ oc create -f amq/resources/amq71-replicates.yaml
```
