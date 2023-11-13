//args[0] = seed;
//args[1] = iv;
//args[2] = nonce;
//args[3] = playerDeck, a JSON;

// use CSPRNG key to randomize deck and draw 3 cards. return the 3 cards on chain

// Import the deck

var deckArray = []

for (let j = 1; j < 11; j++) {
    deckArray.push(JSON.parse(args[3])[j.toString()]);
}

var deckLength = deckArray.length;

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

// placeholder for VRF seed
const plainText = args[0]

// from user-supplied Counter
let base64Counter = args[1]

// from nonceCounter
const iv = parseInt(args[2])

//https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/importKey
function str2ab(str) {
    const buf = new ArrayBuffer(str.length);
    const bufView = new Uint8Array(buf);
    for (let i = 0, strLen = str.length; i < strLen; i++) {
     bufView[i] = str.charCodeAt(i);
    }
   return buf;
  }

  const binaryCounter = atob(base64Counter);
  // convert from a binary string to an ArrayBuffer
  const counter = str2ab(binaryCounter);

const length = 32;

// Generate raw pseudorandom bytes
const encrypted = await crypto.subtle.encrypt(
    {name: "AES-CTR", iv, counter, length},
    csprngKey,
    new TextEncoder().encode(plainText),
  );

// Convert pseudorandom bytes into integer
// https://stackoverflow.com/questions/62441655/how-do-i-convert-bytes-to-integers-in-javascript
let number_array = new Uint8Array(encrypted)
let secret_value = 0;
for (var i = number_array.length - 1; i >= 0; i--) {
    secret_value = (secret_value * 256) + number_array[i];
}

// Generate output
// Create a better randomness regeneration later
var playerHandArray = []
for (var k = 0; k < 3; k++) {
    let picked = secret_value % deckLength
    playerHandArray.push(deckArray[picked])
    deckArray.splice(picked, 1)
    deckLength -= 1
}

let result = (playerHandArray[0] + playerHandArray[1] + playerHandArray[2])
//let return_string = playerHandArray[0].concat(",")
//return_string = return_string.concat(playerHandArray[1])
//return_string = return_string.concat(",")
//return_string = return_string.concat(playerHandArray[2])

return Functions.encodeString(result)
