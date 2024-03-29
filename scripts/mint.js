/** @const {string} */
const OLD_TCKO_ADDR = "0xB97Bf95b4F3110285727b70da5a7465bFD2098Ca";

/** @const {!Object<string, number>} */
const ROUND1_BALANCES = {
  "0x57074c1956d7ef1cda0a8ca26e22c861e30cd733": 4_000_000,
  "0x523c8c26e20bbff5f100221c2c4f99e755681731": 1_600_000,
  "0xd2f98777949a73867f4e5bd3b5cdb90030056383": 1_600_000,
  "0x1273ed0a8527bc5c6c7f99977fee362ee398190f": 1_200_000,
  "0x302fec0096bd60e2ea983f18e61afa36627e5538": 1_200_000,
  "0x52fbe88018537027b6fe4be2249fad2a7a2d2b4a": 800_000,
  "0x9b5541ab008f30afa9b047a868ca5e11fa4e6752": 800_000,
  "0x9c48199d8d3d8ee6ef4716b0cb7d99148788712e": 800_000,
  "0x3480d7de36a3d92ee0cc8685f0f3fea2ade86a9b": 400_000,
  "0x3dd308d8a7035d414bd2ec934a83564f814675fa": 400_000,
  "0x530a8eeb07d81ec4837f6e2c405357defd7cb1ba": 400_000,
  "0x8ede4e8ed0899c14b73b496308af81a40573f721": 400_000,
  "0xf2c51ec9c66d67f437f37e0513601bea9c79df2c": 240_000,
  "0x7c82fd5db15da5598625f0fc3f7e2077b4fd0eeb": 160_000,
  "0xbf63042d4731273765a7654858afae1b3121d025": 160_000,
  "0xc885abc244164fb7c1c4c81cbaf2a60a52336bd5": 160_000,
  "0x270d986a3c6018b5ec48fdf7eb23e24a3816632e": 80_000,
  "0xbcc3ffbf42d91faa52c2622b6e31c3ff3b714d5b": 16_000
};
/** @const {!Object<string, number>} */
const SEED_SIGNERS = {
  "0x299A3490c8De309D855221468167aAD6C44c59E0": 100_000,
  "0x384bF113dcdF3e7084C1AE2Bb97918c3Bf15A6d2": 100_000,
  "0x77c60E68158De0bC70260DFd1201be9445EfFc07": 100_000,
  "0x4F1DBED3c377646c89B4F8864E0b41806f2B79fd": 100_000,
  "0x86f6B34A26705E6a22B8e2EC5ED0cC5aB3f6F828": 100_000,
  "0xc855dB548A6feB1f34AcAE6531c84261008ea55A": 100_000,
  "0xE3581636Df37f1eBfFbdFE22F8719F57c555d4f7": 100_000,
};

/** @const {!Object<string, string>} */
const ADDRESS_CHANGES = {}

/**
 * @param {number|!bigint}
 * @return {string}
 */
const uint48 = (num) => num.toString(16).padStart(12, "0");

/**
 * @template T
 * @param {T} given
 * @param {T} expected
 * @return {boolean}
 */
const assertEq = (given, expected) => {
  if (given != expected) {
    console.log(`assertEq(): Expected ${expected}, given ${given}`)
    process.exit(1);
  }
  return true;
}

/**
 * @param {!Object<string, number>} balances
 * @return {number} sum of the balances
 */
const sumBalances = (balances) => Object.values(balances).reduce((a, b) => a + b);

/** @return {string} */
const generateConstructor = () => {
  /** @const {!Object<string, number>} */
  const toMint = Object.assign({}, ROUND1_BALANCES, SEED_SIGNERS);

  return Object.entries(toMint).map((amountAccount) => {
    const prevAddress = amountAccount[0];
    const address = ADDRESS_CHANGES[prevAddress] || prevAddress;
    return "mint(0x" + uint48(1_000_000 * amountAccount[1])
      + address.slice(2) + ");\n"
  }).reduce((a, b) => a + b);
}

assertEq(sumBalances(ROUND1_BALANCES), 18_416_000);
assertEq(sumBalances(SEED_SIGNERS), 600_000);

console.log(generateConstructor());

/**
 * @param {string} nodeUrl
 * @return {!Promise<boolean>}
 */
const validateWithNode = (nodeUrl) => {
  /** @const {!Array<!jsonrpc.Request>} */
  const requests = Object.keys(ROUND1_BALANCES).map((address, index) =>
    /** @type {!jsonrpc.Request} */({
    "jsonrpc": "2.0",
    "id": index + 1,
    "method": "eth_call",
    "params": [/** @type {!eth.Transaction} */({
      "data": "0x70a08231000000000000000000000000" + address.slice(2),
      "to": OLD_TCKO_ADDR
    }), "latest"]
  }));
  return fetch(nodeUrl, {
    method: "POST",
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(requests)
  }).then((res) => res.json())
    .then((res) => res.map((elem) => 4 * parseInt(elem.result.slice(-12), 16)))
    .then((remoteBalances) => {
      /** @const {!Array<number>} */
      const localBalances = Object.values(ROUND1_BALANCES).map((x) => 1_000_000 * x);
      for (let i = 0; i < localBalances.length; ++i)
        if (localBalances[i] != remoteBalances[i]) return false;
      return true;
    })
}

validateWithNode("https://api.avax.network/ext/bc/C/rpc")
  .then(console.log);
