import { Address, Deployer } from "../web3webdeploy/types";
import {
  TasksDeployment,
  deploy as tasksDeploy,
} from "../lib/openrd-foundry/deploy/deploy";
import { RFPsDeploymentSettingsInternal, deployRFPs } from "./RFPs";

export interface RFPsDeploymentSettings {
  tasksDeployment: TasksDeployment;
  rfpsDeploymentSettings: Omit<RFPsDeploymentSettingsInternal, "tasks">;
}

export interface RFPsDeployment {
  RFPs: Address;
}

export async function deploy(
  deployer: Deployer,
  settings?: RFPsDeploymentSettings
): Promise<RFPsDeployment> {
  deployer.startContext("lib/openrd-foundry");
  const taskDeployment =
    settings?.tasksDeployment ?? (await tasksDeploy(deployer));
  deployer.finishContext();

  const RFPs = await deployRFPs(deployer, {
    ...(settings?.rfpsDeploymentSettings ?? {}),
    tasks: taskDeployment.tasks,
  });

  return {
    RFPs: RFPs,
  };
}
