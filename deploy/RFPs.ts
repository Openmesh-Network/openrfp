import { Deployer } from "../../web3webdeploy/types";
import { Address, DeployInfo } from "../web3webdeploy/types";

export interface RFPsDeploymentSettingsInternal
  extends Omit<DeployInfo, "contract" | "args"> {
  tasks: Address;
}

export async function deployRFPs(
  deployer: Deployer,
  settings: RFPsDeploymentSettingsInternal
) {
  return await deployer.deploy({
    id: "RFPs",
    contract: "RFPs",
    args: [settings.tasks],
    ...settings,
  });
}
