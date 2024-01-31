import { Address, Deployer } from "../web3webdeploy/types";
import {
  TasksDeployment,
  deploy as tasksDeploy,
} from "../lib/openrd-foundry/deploy/deploy";

export interface RFPsDeploymentSettings {
  tasksDeployment: TasksDeployment;
}

export interface RFPsDeployment {
  RFPs: Address;
}

export async function deploy(
  deployer: Deployer,
  settings?: RFPsDeploymentSettings
): Promise<RFPsDeployment> {
  const taskDeployment =
    settings?.tasksDeployment ?? (await tasksDeploy(deployer));

  const RFPs = await deployer.deploy({
    id: "RFPs",
    contract: "RFPs",
    args: [taskDeployment.tasks],
  });
  return {
    RFPs: RFPs,
  };
}
