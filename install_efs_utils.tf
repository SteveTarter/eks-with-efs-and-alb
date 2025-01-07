resource "kubernetes_daemonset" "install_efs_utils" {
  metadata {
    name      = "install-efs-utils"
    namespace = "kube-system"
    labels = {
      name = "install-efs-utils"
    }
  }

  spec {
    selector {
      match_labels = {
        name = "install-efs-utils"
      }
    }

    template {
      metadata {
        labels = {
          name = "install-efs-utils"
        }
      }

      spec {
        container {
          name  = "install-efs-utils"
          image = "amazonlinux:2023"

          command = [
            "/bin/bash",
            "-c",
            <<-EOT
              dnf install -y amazon-efs-utils && dnf clean all
              while true; do sleep 3600; done
            EOT
          ]

          security_context {
            privileged = true
          }

          volume_mount {
            name       = "host-root"
            mount_path = "/host"
          }
        }

        host_network = true
        host_pid     = true

        toleration {
          operator = "Exists"
        }

        volume {
          name = "host-root"

          host_path {
            path = "/"
          }
        }
      }
    }
  }
}

