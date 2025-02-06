include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path   = "${dirname(find_in_parent_folders())}/_envcommon/cluster.hcl"
  expose = true
}

terraform {
  source = "${get_repo_root()}/modules/aws/eks"
}

# ---------------------------------------------------------------------------------------------------------------------
# INPUTS
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  cluster_name = "jorge"

  # key_pair_name = "newkeypair"
}
