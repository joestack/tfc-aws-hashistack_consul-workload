# A Consul workload based on a Consul service platform provided by tfc-aws-hashistack (HashiStack)

After you have deployed a Consul service platform via tfc-aws-hashistack, this repo provides a Consul workload that registers its nodes and services at it for further handing.

It's based on two layered deployments to be aligned with a segregation of duty mindset. The lifecycle of a platform is different to the lifecycle of any workload that consumes a platform service. Maintaining a deployment with its own Terraform statefile makes this easylie possible.

To avoid to cut and paste any information (cluster address, acl token, VPC, ..) across both deployments, I use programmatic access to these values via terraform_remote_state.



---

## Content of the repository

| File | Description |
| - | :- |
| scripts/base.sh | basic userdata script to be rendered |
| scripts/client.sh | consul userdata script to be rendered |
| README.md | This README |
| main.tf | Provider related configurations and workload instances|
| variables.tf | Variables to customize the workload |
| outputs.tf | Outputs and post build-time information |

---

## Variable Argument Reference

| Key | Description | Default |
| - | :- | :- |
| remote_state_org" | (required) The name of the Terraform Organization that contains the Consul platform (tfc-aws-hashistack) | TFC_Org |
| remote_state_l1 | (required) The name of the Workspace that contains the Consul platform | tfc-aws-hashistack |
| node_count | (optional) Amount of workload instances | 3 |
| pub_key | (required) Name of the public part of the SSH key (already existing in your AWD region) | joestack |



