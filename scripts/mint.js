/** @const {string} */
const OLD_TCKO_ADDR = "0xB97Bf95b4F3110285727b70da5a7465bFD2098Ca";

/** @const {string} */
const TCKO_ADDR = "0xcCc01Ec0E6Fb38Cce8b313c3c8dbfe66efD01cCc";

/** @const {!Object<string, number>} */
const DAO_MEMBERS_1 = {
  "0x57074c1956d7ef1cda0a8ca26e22c861e30cd733": 4_000_000,
  "0xcf7fea15b049ab04ffd03c86f353729c8519d72e": 4_000_000,
  "0x523c8c26e20bbff5f100221c2c4f99e755681731": 1_600_000,
  "0xd2f98777949a73867f4e5bd3b5cdb90030056383": 1_600_000,
  "0x1273ed0a8527bc5c6c7f99977fee362ee398190f": 1_200_000,
  "0x302fec0096bd60e2ea983f18e61afa36627e5538": 1_200_000,
  "0x52fbe88018537027b6fe4be2249fad2a7a2d2b4a": 800_000,
  "0x9b5541ab008f30afa9b047a868ca5e11fa4e6752": 800_000,
  "0x9c48199d8d3d8ee6ef4716b0cb7d99148788712e": 800_000,
  "0xccc00bc7e6983b1901825888a7bb3bda3b051b12": 800_000,
};
/** @const {!Object<string, number>} */
const DAO_MEMBERS_2 = {
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
  "0xa41f9ad9fd440c2e297dd89f36240716d832bbdb": 100_000,
  "0x9c6502b0837353097562e5ffc815ac7d44a729ea": 100_000,
  "0x7d211ecf4dd431d68d800497c8902474af0412b7": 100_000,
  "0x11547533ce4613dd9ae040af7bc89a7cbf0d04f0": 100_000,
  "0xc807b02baccf6b128ad3ee5fab8c4ee5f10cb750": 100_000,
};

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

/**
 * @param {string} nodeUrl
 * @return {!Promise<boolean>}
 */
const validateWithNode = (nodeUrl) => {
  /** @const {!Object<string, number>} */
  const daoMembers = Object.assign({}, DAO_MEMBERS_1, DAO_MEMBERS_2);
  /** @const {!Array<!jsonrpc.Request>} */
  const requests = Object.keys(daoMembers).map((address, index) =>
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
      const localBalances = Object.values(daoMembers).map((x) => 1_000_000 * x);
      for (let i = 0; i < localBalances.length; ++i)
        if (localBalances[i] != remoteBalances[i]) return false;
      return true;
    })
}

/**
 * @param {number|!bigint}
 * @return {string}
 */
const uint96 = (num) => num.toString(16).padStart(24, "0");

/**
 * @param {string} calldata without the "0x" prefix.
 */
const printCalldata = (calldata) => {
  console.log("Selector:", calldata.slice(0, 8));
  for (let pos = 8, idx = 1; pos < calldata.length; ++idx, pos += 64)
    console.log(
      "Param " + idx.toString().padStart(2, " ") + ":",
      calldata.slice(pos, pos + 64)
    );
}

/**
 * @param {!Object<string, number>} balances
 * @return {!Promise<void>}
 */
const mintBulk = (balances) => {
  const n = Object.keys(balances).length;
  if (n < 5 || n > 10) return Promise.reject("bulkMint() needs 5 to 10 addresses");

  const calldata = "678c5a9d" + Object.entries(balances)
    .map((item) => uint96(1_000_000 * item[1]) + item[0].slice(2))
    .reduce((a, b) => a + b) + "0".repeat((10 - n) * 64);

  printCalldata(calldata);
  return Promise.resolve();
}

assertEq(
  Object.keys(DAO_MEMBERS_1).length + Object.keys(DAO_MEMBERS_2).length,
  20
);
validateWithNode("https://api.avax.network/ext/bc/C/rpc")
  .then(() => mintBulk(DAO_MEMBERS_1))
  .then(() => mintBulk(DAO_MEMBERS_2));
