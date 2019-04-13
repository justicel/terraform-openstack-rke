#cloud-config
rancher:
  console: alpine
  docker:
    engine: ${docker_version}
  sysctl:
    vm.max_map_count: 262144
  resize_device: /dev/vda
