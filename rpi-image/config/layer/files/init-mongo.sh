#!/bin/bash
# init-mongo.sh
# Initializes the UniFi MongoDB database with RBAC authentication.
# This script is mounted into the MongoDB container at
# /docker-entrypoint-initdb.d/init-mongo.sh and runs only on first start.
#
# Variables are read from the .env file at container start via Docker Compose.

mongosh -u "${MONGO_INITDB_ROOT_USERNAME}" -p "${MONGO_INITDB_ROOT_PASSWORD}" \
  --authenticationDatabase admin \
  --eval "
    db = db.getSiblingDB('${MONGO_DBNAME}');
    db.createUser({
      user: '${MONGO_USER}',
      pwd:  '${MONGO_PASS}',
      roles: [{ role: 'dbOwner', db: '${MONGO_DBNAME}' }]
    });

    db = db.getSiblingDB('${MONGO_DBNAME}_stat');
    db.createUser({
      user: '${MONGO_USER}',
      pwd:  '${MONGO_PASS}',
      roles: [{ role: 'dbOwner', db: '${MONGO_DBNAME}_stat' }]
    });
  "
