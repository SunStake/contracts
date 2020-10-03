import { BigNumber } from "ethers";

export function expandTo6Decimals(n: number): BigNumber {
  return expandToXDecimals(n, 6);
}

export function expandTo18Decimals(n: number): BigNumber {
  return expandToXDecimals(n, 18);
}

export const uint256Max: BigNumber = BigNumber.from(
  "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
);

function expandToXDecimals(n: number, x: number): BigNumber {
  return BigNumber.from(n).mul(BigNumber.from(10).pow(x));
}
