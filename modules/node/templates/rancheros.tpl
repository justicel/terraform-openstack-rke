#cloud-config
rancher:
  console: ubuntu
  docker:
    engine: docker-${docker_version}
  sysctl:
    vm.max_map_count: 262144
  resize_device: /dev/vda
