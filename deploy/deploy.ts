import { Address, Deployer } from "../web3webdeploy/types";
import {
  TasksDeployment,
  deploy as tasksDeploy,
} from "../lib/openrd-foundry/deploy/deploy";
import { deploy as openmeshAdminDeploy } from "../lib/openmesh-admin/deploy/deploy";
import { deploy as ensReverseRegistrarDeploy } from "../lib/ens-reverse-registrar/deploy/deploy";

export interface RFPsDeploymentSettings {
  tasksDeployment: TasksDeployment;
  admin?: Address;
  ensReverseRegistrar?: Address;
}

export interface RFPsDeployment {
  RFPs: Address;
}

export async function deploy(
  deployer: Deployer,
  settings?: RFPsDeploymentSettings
): Promise<RFPsDeployment> {
  deployer.startContext("lib/openmesh-admin");
  const admin = settings?.admin ?? (await openmeshAdminDeploy(deployer)).admin;
  deployer.finishContext();
  deployer.startContext("lib/ens-reverse-registrar");
  const ensReverseRegistrar =
    settings?.ensReverseRegistrar ??
    (await ensReverseRegistrarDeploy(deployer)).reverseRegistrar;
  deployer.finishContext();
  deployer.startContext("lib/openrd-foundry");
  const taskDeployment =
    settings?.tasksDeployment ??
    (await tasksDeploy(deployer, { admin, ensReverseRegistrar }));
  deployer.finishContext();

  const RFPs = await deployer.deploy({
    id: "RFPs",
    contract: "RFPs",
    args: [taskDeployment.tasks, admin, ensReverseRegistrar],
  });
  return {
    RFPs: RFPs,
  };
}
