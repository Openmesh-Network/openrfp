import { zeroAddress } from "viem";
import { Address, Deployer } from "../web3webdeploy/types";

export interface DeploymentSettings {
  tasks: Address;
}

export interface Deployment {
  RFPs: Address;
}

export async function deploy(
  deployer: Deployer,
  settings?: DeploymentSettings
): Promise<Deployment> {
  const RFPs = await deployer.deploy({
    id: "RFPs",
    contract: "RFPs",
    args: [settings?.tasks ?? zeroAddress],
  });
  return {
    RFPs: RFPs,
  };
}
