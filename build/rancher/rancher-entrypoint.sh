#!/bin/sh

initdb() {
cat > /tmp/init.sql <<EOF
use config
insert into groups values ('${ACTORDB_GROUP}','cluster')
insert into nodes values ('${ACTORDB_NODE}','${ACTORDB_GROUP}')
create user '${ACTORDB_ADMIN_USER}' identified by '${ACTORDB_ADMIN_PASSWORD}'
commit
EOF

log "info" "Initialising node, \"user_exists\" error expected if already initialised."
actordb_console -u ${ACTORDB_ADMIN_USER} -pw ${ACTORDB_ADMIN_PASSWORD} -f /tmp/init.sql
###rm /tmp/init.sql
}

updatedb() {
cat > /tmp/init.sql <<EOF
use config
insert into nodes values ('${ACTORDB_NODE}','${ACTORDB_GROUP}')
commit
EOF

log "info" "Joining cluster, \"insert_on_existing_node\" error expected if already joined."
actordb_console -u ${ACTORDB_ADMIN_USER} -pw ${ACTORDB_ADMIN_PASSWORD} -f /tmp/init.sql ${LEADER_ADDR}
###rm /tmp/init.sql
}

#
# Get current container's "number" and name.
NODE_INDEX=`curl -s 'http://rancher-metadata/2015-12-19/self/container/service_index'`
NODE_NAME=`curl -s 'http://rancher-metadata/2015-12-19/self/container/name'`

#
# Override node name.
ACTORDB_NODE="node${NODE_INDEX}@${NODE_NAME}.rancher.internal"

#
# Run server config with overridden ACTORDB_NODE.
. /docker-config.sh

#
# Start local node.
/docker-run.sh &

#
# Give it a few seconds to get itself together.
sleep 10
log "info" "Server started."

#
# On start up we need to know whether we're the first or not.
LEADER_NAME=`curl -s 'http://rancher-metadata/2015-12-19/self/service/containers/0/name'`
LEADER_ADDR="${LEADER_NAME}.rancher.internal"
log "info" "Leader name is ${LEADER_NAME}."

if [ "${NODE_NAME}" = "${LEADER_NAME}" ]
then
	log "info" "I'm the lead container."
	initdb
else
	log "info" "I'm not the lead container, giving leader 10 seconds before joining cluster..."
	sleep 10
	updatedb
fi

unset ACTORDB_ADMIN_USER ACTORDB_ADMIN_PASSWORD ACTORDB_GROUP ACTORDB_SCALE ACTORDB_THRIFT_PORT ACTORDB_MYSQL_PORT VOLUME_DRIVER HOST_LABEL

wait

log "warn" "Background actordb process finished, shutting down node."