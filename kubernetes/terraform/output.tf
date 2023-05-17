output "ingress_cluster_ip" {
    value       = google_compute_address.ingress_cluster_ip.address
    description = "The public IP address of ingress controller"
}
