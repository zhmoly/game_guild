import { ethers } from 'hardhat'
import { GMON, GNRG, GMON_Z1, GMONC, GMONEC, GMONC_Z1, GLANDC } from '../settings.json'
import { GameFactory__factory } from '../typechain-types';
import { GameFactory } from '../typechain-types/GameFactory'
import * as fs from 'fs';

async function main() {
  let accounts = await ethers.getSigners();
  const factoryContract = (await ethers.getContractFactory("GameFactory", accounts[0])) as GameFactory__factory;
  const gameFactory = (await factoryContract.deploy(GMON, GNRG, GMON_Z1, GMONC, GMONEC, GMONC_Z1, GLANDC)) as GameFactory;
  await gameFactory.deployed();

  const gameFactoryAddress = gameFactory.address;
  console.log(gameFactoryAddress);
  if (gameFactory.address) {
    const settingPath = 'settings.json';
    const data = fs.readFileSync(settingPath);
    let settings = JSON.parse(data.toString());
    settings['GMON_FACTORY'] = gameFactoryAddress;
    fs.writeFileSync(settingPath, JSON.stringify(settings, null, '\t'));
  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });