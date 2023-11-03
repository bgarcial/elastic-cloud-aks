# module "hello-world" {
#   source = "./modules/hello-world-app"
#   # Pass any necessary variables from the root module to the child module.

#   # when using modules in Terraform, the resources within those modules inherently 
#   # depend on the variables passed to them. If a module uses an output from another 
#   # module as a variable input, it creates an implicit dependency.
#   cluster_id = module.aks.cluster_id # implicit dependency
# }