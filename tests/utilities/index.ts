import { providers, BigNumber } from "ethers";

export function mineBlock(
  provider: providers.Web3Provider,
  timeIncrease?: number
): Promise<void> {
  return new Promise((resolve) => {
    provider.getBlock("latest").then((block) => {
      provider
        .send("evm_mine", [block.timestamp + (timeIncrease || 0)])
        .then(() => {
          resolve();
        });
    });
  });
}

export function expandTo6Decimals(n: number): BigNumber {
  return expandToXDecimals(n, 6);
}

export function expandTo18Decimals(n: number): BigNumber {
  return expandToXDecimals(n, 18);
}

export const uint256Max: BigNumber = BigNumber.from(
  "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
);

export const zeroAddress: string = "0x0000000000000000000000000000000000000000";

function expandToXDecimals(n: number, x: number): BigNumber {
  return BigNumber.from(n).mul(BigNumber.from(10).pow(x));
}
