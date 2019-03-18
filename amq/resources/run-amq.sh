#!/bin/bash

set -ex

ADM_USER=${ADMIN_PASSWORD:-admin}
ADM_PASSWORD=${ADMIN_USER:-admin}

#PEER=$(echo $HOSTNAME | sed 's/-0$//')

if ! [ -z "$AMQ_CLUSTERED" ] ; then
    if test $(echo $HOSTNAME | grep '^[a-z0-9-]\+-0$') ; then
	PEER=${HEADLESS_SERVICE_NAME}-1.$HEADLESS_SERVICE_NAME
    else
	if test $(echo $HOSTNAME | grep '^[a-z0-9-]\+-1$') ; then
	    SLAVE="--slave"
	    PEER=${HEADLESS_SERVICE_NAME}-0.$HEADLESS_SERVICE_NAME
	else
	    echo "Only Replica '2' is supported"
	    sleep 120
	    exit 1
	fi
    fi
    CLUSTERED="\
	--replicated \
	--failover-on-shutdown \
	--clustered \
	--host $HOSTNAME.$HEADLESS_SERVICE_NAME \
	--cluster-user $ADM_USER \
	--cluster-password $ADM_PASSWORD \
	--max-hops 1 \
	${SLAVE} \
    "
    JKS_NAME=$HOSTNAME
else
    PEER=127.0.0.1
    JKS_NAME=amq
fi

INSTANCE_HOME=/var/run/amq/broker

$AMQ_HOME/bin/artemis create \
    --addresses=localhost,$HOSTNAME.$HEADLESS_SERVICE_NAME \
    --allow-anonymous \
    --data /amq-broker-data \
    --password ${ADM_USER} \
    --role admin \
    --user ${ADM_PASSWORD} \
    --verbose \
    $CLUSTERED \
    $INSTANCE_HOME

LOGGING_LEVEL=${LOGGING_LEVEL:-INFO}

sed -ci.bak1 "\
    s/^loggers=\(.*\)/loggers=\1,aio.prometheus.jmx/ ; \
    s/logger.handlers=.*/logger.handlers=CONSOLE/ ; \
    s/handler.FILE/#handler.FILE/ ; \
    s/\.level=INFO/.level=$LOGGING_LEVEL/g ; \
    " $INSTANCE_HOME/etc/logging.properties

if [ -z "${AMQ_CONSOLE_PUBLIC_URL}" ] ; then
    sed -ci.bak1 \
	"s|<cors>|<cors>\n		<allow-origin>*amq-*</allow-origin>\n| ;" \
	$INSTANCE_HOME/etc/jolokia-access.xml
else
    sed -ci.bak1 \
	"s|<cors>|<cors>\n		<allow-origin>${AMQ_CONSOLE_PUBLIC_URL}</allow-origin>\n| ;" \
	$INSTANCE_HOME/etc/jolokia-access.xml
fi

sed -ci.bak1 \
    's|http://localhost:8161|http://0.0.0.0:8161|' \
    $INSTANCE_HOME/etc/bootstrap.xml

sed -ci.bak1 \
    '/JAVA_ARGS \\/a $JAVA_OPTS_APPEND \\' \
    $INSTANCE_HOME/bin/artemis

sed -ci.bak1 "\
    s/<master\/>/<master>\n		<check-for-live-server>true<\/check-for-live-server>\n		<\/master>/ ; \
    s/<slave\/>/<slave>\n		<allow-failback>true<\/allow-failback>\n		<\/slave>/ ; \
    /<broadcast-groups>/,/<\/discovery-groups>/d ; \
    s/<\/connector>/<\/connector>\n\
      <connector name=\"discovery-connector\">tcp:\/\/${PEER}:61616<\/connector>/ ; \
    s/<discovery-group-ref discovery-group-name=\"dg-group1\"\/>/\n\
      <static-connectors>\n\
      	<connector-ref>discovery-connector<\/connector-ref>\n\
      <\/static-connectors>/ ; \
    " $INSTANCE_HOME/etc/broker.xml

case "$SSL_ENABLED" in
	True|true|TRUE|Yes|yes|YES|1)
    	export KEYSTORE_PATH=/var/run/secrets/amq/keystores/${JKS_NAME}-broker.jks
        AMQPS="\
        <acceptor name=\"amqps\">tcp://${HOSTNAME}.$HEADLESS_SERVICE_NAME:5673?\
tcpSendBufferSize=1048576;\
tcpReceiveBufferSize=1048576;\
protocols=AMQP;\
useEpoll=true;\
amqpCredits=1000;\
amqpMinCredits=300;\
sslEnabled=true;\
keyStorePath=/var/run/secrets/amq/keystores/${KEYSTORE_PATH};\
keyStorePassword=$JKS_PASSWORD\
</acceptor>"
        sed -ci.ssl "/<acceptor name=\"amqp\">tcp:/a $AMQPS" $INSTANCE_HOME/etc/broker.xml
    ;;
esac

sed -ci.bak1 "\
    s/<whitelist>/<whitelist>\n	<entry domain=\"org.apache.activemq.artemis\"\/>/ ; \
    " $INSTANCE_HOME/etc/management.xml

for i in {1..10} ; do
    dig +search +short ${PEER} | grep '^\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}$' && { found=1; break ; }
    if [ "$i" -lt 10 ] ; then
	sleep 30
    fi
done

if [ -z "$found" ] ; then
    echo "PEER '${PEER}' not resolved"
    exit 1
fi

exec $INSTANCE_HOME/bin/artemis run

