//args[0] = registeredOpponents[_player].key;
//args[1] = registeredOpponents[_player].deck;
//args[2] = registeredOpponents[_player].iv;
//args[3] = _inventory;

//decrypts the pending Opponent deck, checks that the inventory actually contains the cards,
//returns 1 for valid, 2 for invalid


//https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/importKey
function str2ab(str) {
    const buf = new ArrayBuffer(str.length);
    const bufView = new Uint8Array(buf);
    for (let i = 0, strLen = str.length; i < strLen; i++) {
     bufView[i] = str.charCodeAt(i);
    }
   return buf;
  }

  const binaryDONRSAString = atob(secrets.privateRSA);
  // convert from a binary string to an ArrayBuffer
  const binaryDONRSAKey = str2ab(binaryDONRSAString);

const decryption_key = await crypto.subtle.importKey(
    "pkcs8",
   binaryDONRSAKey,
    {
        name: "RSA-OAEP",
        //not secure!
        hash: "SHA-1",
      },
    true,
    ["decrypt"],
  );


const binaryOpponentKey = atob(args[0]);
  // convert from a binary string to an ArrayBuffer
  const binaryOpponentKeyBytes = str2ab(binaryOpponentKey);


const decBuffer = await crypto.subtle.decrypt(
  { name: "RSA-OAEP" },
  decryption_key,
  binaryOpponentKeyBytes,
);

const opponentKey = await crypto.subtle.importKey(
    "raw",
    decBuffer,
    "AES-CBC",
    true,
    ["encrypt", "decrypt"],
  );
  
  const binaryIv = atob(args[2]);
  // convert from a binary string to an ArrayBuffer
  const binaryIvBytes = str2ab(binaryIv);

  const binaryOpponentDeck = atob(args[1]);
  // convert from a binary string to an ArrayBuffer
  const binaryOpponentDeckBytes= str2ab(binaryOpponentDeck);



const decodedMessage = await crypto.subtle.decrypt(
  { name: "AES-CBC", iv: binaryIvBytes },
  opponentKey,
  binaryOpponentDeckBytes,
);

let decoder = new TextDecoder

let opponentDeck = decoder.decode(decodedMessage)

var opponentDeckArray = []

for (let j = 1; j < 21; j++) {
    opponentDeckArray.push(JSON.parse(opponentDeck)[j.toString()]);
};

var inventoryArray = args[3].split(",")

let valid = true

for (let k = 0; k < 20; k++) {
    if (!inventoryArray.includes(opoonentDeckArray[k])) {
        valid = false
    }
}

if (valid === true) {
return Functions.encodeUint256(1)
}
else {
return Functions.encodeUint256(2)
}
