#!/bin/bash
host=$(hostname -s)
echo -n "$host.vm.memory.used:$(awk '/^Mem/ {print $2}' <(free -m))|c" | nc -w 1 -u {{ graphite_host }} {{ graphite_port }}
echo -n "$host.vm.memory.available:$(awk '/^Mem/ {print $3}' <(free -m))|c" | nc -w 1 -u {{ graphite_host }} {{ graphite_port }}
# get all running docker container names
containers=$(sudo docker ps | awk '{if(NR>1) print $NF}')

# loop through all containers
for container in $containers
do
  echo "Container: $container"
  size=($(sudo docker exec $container /bin/sh -c "df | grep -vE '^Filesystem|shm|boot' | awk '{ print +\$2 }'"))
  used=($(sudo docker exec $container /bin/sh -c "df | grep -vE '^Filesystem|shm|boot' | awk '{ print +\$3 }'"))
  available=($(sudo docker exec $container /bin/sh -c "df | grep -vE '^Filesystem|shm|boot' | awk '{ print +\$4 }'"))
  percentages=($(sudo docker exec $container /bin/sh -c "df | grep -vE '^Filesystem|shm|boot' | awk '{ print +\$5 }'"))
  mounts=($(sudo docker exec $container /bin/sh -c "df | grep -vE '^Filesystem|shm|boot' | awk '{ print \$6 }'"))
  stats=$(docker stats $container --no-stream)
  docker_cpu_usage=$(echo $stats | awk '{ print $16 }')
  docker_mem_usage=$(echo $stats | awk '{ print $17 }')
  docker_mem_limit=$(echo $stats | awk '{ print $19 }')

  echo -n "$host.docker.$container.cpu_usage:$docker_cpu_usage|c" | sed 's/%//'  | nc -w 1 -u {{ graphite_host }} {{ graphite_port }}
  echo -n "$host.docker.$container.mem_usage:$docker_mem_usage|c" | nc -w 1 -u {{ graphite_host }} {{ graphite_port }}
  echo -n "$host.docker.$container.mem_limit:$docker_mem_limit|c" | nc -w 1 -u {{ graphite_host }} {{ graphite_port }}

  for index in ${!mounts[*]}; do
     #echo "Mount ${mounts[index]}: Used: ${used[index]} Percent: ${percentages[index]}%"
     echo -n "$host.docker.$container.volume.${mounts[index]}.disk_size:${size[index]}|c" | nc -w 1 -u {{ graphite_host }} {{ graphite_port }}
     echo -n "$host.docker.$container.volume.${mounts[index]}.disk_used:${used[index]}|c" | nc -w 1 -u {{ graphite_host }} {{ graphite_port }}
     echo -n "$host.docker.$container.volume.${mounts[index]}.disk_available:${available[index]}|c" | nc -w 1 -u {{ graphite_host }} {{ graphite_port }}
  done
done
