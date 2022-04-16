import { Interface } from "ethers/lib/utils";

export const getSelectors = (
  iface: Interface,
  options?: { include?: string[]; exclude?: string[] }
) => {
  const selector = Object.keys(iface.functions).map((functionName) => {
    if (options?.include && options.include.includes(functionName)) {
      return iface.getSighash(functionName);
    } else if (options?.exclude && !options.exclude.includes(functionName)) {
      return iface.getSighash(functionName);
    }
    return iface.getSighash(functionName);
  });
  return selector;
};
