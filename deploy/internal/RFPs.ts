import { Deployer, Address, DeployInfo } from "../../web3webdeploy/types";

export interface DeployRFPsSettings
  extends Omit<DeployInfo, "contract" | "args"> {
  tasks: Address;
}

export async function deployRFPs(
  deployer: Deployer,
  settings: DeployRFPsSettings
) {
  return await deployer.deploy({
    id: "RFPs",
    contract: "RFPs",
    args: [settings.tasks],
    ...settings,
  })
  .then(deployment => deployment.address);
}
