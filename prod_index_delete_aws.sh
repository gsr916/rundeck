#!/bin/bash
# ES index remove script using Elastic Curator 3.x
host=es-applogs.pd-jiocloud.com
days=7

echo -e Y |python /var/lib/rundeck/scripts/processOldESIndicesForDeletion.py $host $days
