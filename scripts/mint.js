/**
 * @const {string}
 * @noinline
 */
export const OLD_TCKO_ADDR = "0xB97Bf95b4F3110285727b70da5a7465bFD2098Ca";

/** @const {!Object<string, number>} */
const Balances = {
  "0x57074c1956d7ef1cda0a8ca26e22c861e30cd733": 4000000,
  "0xcf7fea15b049ab04ffd03c86f353729c8519d72e": 4000000,
  "0x523c8c26e20bbff5f100221c2c4f99e755681731": 1600000,
  "0xd2f98777949a73867f4e5bd3b5cdb90030056383": 1600000,
  "0x1273ed0a8527bc5c6c7f99977fee362ee398190f": 1200000,
  "0x302fec0096bd60e2ea983f18e61afa36627e5538": 1200000,
  "0x52fbe88018537027b6fe4be2249fad2a7a2d2b4a": 800000,
  "0x9b5541ab008f30afa9b047a868ca5e11fa4e6752": 800000,
  "0x9c48199d8d3d8ee6ef4716b0cb7d99148788712e": 800000,
  "0xccc00bc7e6983b1901825888a7bb3bda3b051b12": 800000,
  "0x3480d7de36a3d92ee0cc8685f0f3fea2ade86a9b": 400000,
  "0x3dd308d8a7035d414bd2ec934a83564f814675fa": 400000,
  "0x530a8eeb07d81ec4837f6e2c405357defd7cb1ba": 400000,
  "0x8ede4e8ed0899c14b73b496308af81a40573f721": 400000,
  "0xf2c51ec9c66d67f437f37e0513601bea9c79df2c": 240000,
  "0x7c82fd5db15da5598625f0fc3f7e2077b4fd0eeb": 160000,
  "0xbf63042d4731273765a7654858afae1b3121d025": 160000,
  "0xc885abc244164fb7c1c4c81cbaf2a60a52336bd5": 160000,
  "0x270d986a3c6018b5ec48fdf7eb23e24a3816632e": 80000,
  "0xbcc3ffbf42d91faa52c2622b6e31c3ff3b714d5b": 16000
}

/**
 * @param {string} nodeUrl
 * @return {!Promise<boolean>}
 */
const validateWithNode = (nodeUrl) => {
  const requests = Object.keys(Balances).map((address, index) => ({
    "jsonrpc": "2.0",
    "id": index + 1,
    "method": "eth_call",
    "params": [{
      "data": "0x70a08231000000000000000000000000" + address.slice(2),
      "to": OLD_TCKO_ADDR
    }, "latest"]
  }));
  return fetch(nodeUrl, {
    method: "POST",
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(requests)
  }).then((res) => res.json())
    .then((res) => res.map((elem) => 4 * parseInt(elem.result.slice(-16), 16)))
    .then((remoteBalances) => {
      /** @const {!Array<number>} */
      const localBalances = Object.values(Balances).map((x) => 1_000_000 * x);
      for (let i = 0; i < localBalances.length; ++i)
        if (localBalances[i] != remoteBalances[i]) return false;
      return true;
    })
}

validateWithNode("https://api.avax.network/ext/bc/C/rpc").then(console.log);
