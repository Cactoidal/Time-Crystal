//args[0] = RSA-encrypted PLAYER AES key;
//args[1] = AES-encrypted PLAYER secret passphrase;
//args[2] = iv used to encrypt the secrets;
//args[3] = seed;
//args[4] = CSPRNG iv;
//args[5] = nonce;

// Eventual potential for custom deck in args[6]

// Instantiate the DON Private RSA key.
// Decrypt the PLAYER AES key, then decrypt the PLAYER secret passphrase and inventory.
// Generate secret randomness using CSPRNG key and draw 5 cards from the default 20 card deck.
// Concatenate the passphrase and cards.
// Hash the string and return hash as bytes.


//https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/importKey
function str2ab(str) {
  const buf = new ArrayBuffer(str.length);
  const bufView = new Uint8Array(buf);
  for (let i = 0, strLen = str.length; i < strLen; i++) {
   bufView[i] = str.charCodeAt(i);
  }
 return buf;
}


// Get the DON Private RSA key.

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



// Get the encrypted PLAYER key and decrypt it.

const binaryPlayerKey = atob(args[0]);
const binaryPlayerKeyBytes = str2ab(binaryPlayerKey);

const playerBuffer = await crypto.subtle.decrypt(
{ name: "RSA-OAEP" },
decryption_key,
binaryPlayerKeyBytes,
);

const playerKey = await crypto.subtle.importKey(
  "raw",
  playerBuffer,
  "AES-CBC",
  true,
  ["encrypt", "decrypt"],
);



// Get the encrypted PLAYER secret and decrypt it with the key and iv.

const binaryPlayerSecrets = atob(args[1]);
const binaryPlayerSecretsBytes= str2ab(binaryPlayerSecrets);

const binaryIv = atob(args[2]);
const binaryIvBytes = str2ab(binaryIv);

const decryptedSecrets = await crypto.subtle.decrypt(
{ name: "AES-CBC", iv: binaryIvBytes },
playerKey,
binaryPlayerSecretsBytes,
);

let decoder = new TextDecoder

let secretPhrase = decoder.decode(decryptedSecrets)

// Check the length
if (secretPhrase.length != 20) {
// Return deliberate error
return Functions.encodeUint256("error")
}


// Import the CSPRNG key from DON

var csprngArray = secrets.csprngKey.split(",")

for (let i = 0; i < 16; i++) {
  csprngArray[i] = parseInt(csprngArray[i])
}

const rawcsprngKey = Uint8Array.from(csprngArray)

const csprngKey = await crypto.subtle.importKey(
  "raw",
  rawcsprngKey.buffer,
  "AES-CTR",
  true,
  ["encrypt", "decrypt"],
);


// Generate secret randomness and draw 5 deck cards + default Attack card.

var seed = args[3]
// from user-supplied Counter
let base64Counter = args[4]
// from nonceCounter
const iv = parseInt(args[5])

const binaryCounter = atob(base64Counter);
const counter = str2ab(binaryCounter);
const length = 32;

// In the future, will be replaced with a custom deck imported from the contract
var deckArray = ["10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25","26","27","29","30"]
var deckLength = 20;

var returnString = secretPhrase


// Draw the 5 cards
for (var k = 0; k < 5; k++) {

// Generate raw pseudorandom bytes
const encrypted = await crypto.subtle.encrypt(
  {name: "AES-CTR", iv, counter, length},
  csprngKey,
  new TextEncoder().encode(seed),
);

// Convert pseudorandom bytes into integer
let number_array = new Uint8Array(encrypted)
let secret_value = 0;
for (var i = number_array.length - 1; i >= 0; i--) {
  secret_value = (secret_value) + number_array[i];
}
// Use integer as next seed
seed = secret_value

// Draw card and add it to string
let picked = secret_value % deckLength
returnString += deckArray[picked]
deckArray.splice(picked, 1)
deckLength -= 1
}



// Get default Attack card.
let attack = 99

let result = returnString + attack.toString()

//Get SHA256 Hash and return to contract.
let hash = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(result)))

return hash
