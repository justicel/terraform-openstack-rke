#cloud-config
runcmd:
- if ! [ -f /opt/fixvdb ]; then wipefs --all --force /dev/vdb; fi
- touch /opt/fixvdb
rancher:
  console: alpine
  docker:
    engine: docker-${docker_version}
  sysctl:
    vm.max_map_count: 262144
  resize_device: /dev/vda
