import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { Create2Factory } from '../src/Create2Factory'
import { ethers } from 'hardhat'
// deploy the contracts TokenPayMaster MasterPayMaster and AltChainPayMaster
const connextGoerli = "0xFCa08024A6D4bCc87275b1E4A1E22B71fAD7f649"
const entryPointstackup = "0x0576a174D229E3cFA37253523E645A78A0C91B57"
const address0 = ethers.constants.AddressZero;
async function deploy(name: string, args: any[]) {
  const factory = await ethers.getContractFactory(name);
  const contract = await factory.deploy(...args);
  await contract.deployed();
  console.log(name, contract.address);
  return contract;
}
async function main() {
  const signer = (await ethers.getSigners())[0];
  // const entrypoint = await deploy("EntryPoint", []);

  console.log("signer", signer.address);
  const bond = await deploy("TokenPayMaster", [address0,entryPointstackup,connextGoerli]);
  // bond.createBond(signer.address,{value: ethers.utils.parseEther("0.05")});


  
//   const altltchains = await deploy("ChainPayMaster", []);
}
main()