//args[0] = playerCards[_action], as in, the card picked from player's hand;
//args[1] = RSA-encrypted OPPONENT AES key;
//args[2] = AES-encrypted OPPONENT deck, a JSON;
//args[3] = iv used to encrypt the deck;
//args[4] = Strings.toString(currentTurn);
//args[5] = seed;
//args[6] = counter;
//args[7] = nonce;
//args[8] = playerDeck;
//args[9] = currentTurn;

//eventually will need "board state" as well

// decrypt the OPPONENT AES key, then the OPPONENT DECK. Randomize deck using CSPRNG, 
// then draw OPPONENT hand.  Using the turn order, draw cards up to the current
// turn order, and return the opponent and player card for the current turn


//https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/importKey
function str2ab(str) {
    const buf = new ArrayBuffer(str.length);
    const bufView = new Uint8Array(buf);
    for (let i = 0, strLen = str.length; i < strLen; i++) {
     bufView[i] = str.charCodeAt(i);
    }
   return buf;
  }

  const binaryDerString = atob(secrets.privateRSA);
  // convert from a binary string to an ArrayBuffer
  const binaryDer = str2ab(binaryDerString);

const decryption_key = await crypto.subtle.importKey(
    "pkcs8",
   binaryDer,
    {
        name: "RSA-OAEP",
        //not secure!
        hash: "SHA-1",
      },
    true,
    ["decrypt"],
  );

  // encrypted message (key) from godot
const binaryOpponentKey = atob(args[1]);
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
  
  const binaryIv = atob(args[3]);
  // convert from a binary string to an ArrayBuffer
  const binaryIvBytes = str2ab(binaryIv);

  const binaryOpponentDeck = atob(args[2]);
  // convert from a binary string to an ArrayBuffer
  const binaryOpponentDeckBytes= str2ab(binaryOpponentDeck);



const decodedMessage = await crypto.subtle.decrypt(
  { name: "AES-CBC", iv: binaryIvBytes },
  playerKey,
  binaryOpponentDeckBytes,
);

let decoder = new TextDecoder

let opponentDeck = decoder.decode(decodedMessage)

var opponentDeckArray = []

for (let j = 1; j < 11; j++) {
    opponentDeckArray.push(JSON.parse(opponentDeck)[j.toString()]);
}

var opponentDeckLength = opponentDeckArray.length;


var playerDeckArray = []

for (let j = 1; j < 11; j++) {
    playerDeckArray.push(JSON.parse(args[8])[j.toString()]);
}

var playerDeckLength = playerDeckArray.length;


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
const plainText = args[5]

// from user-supplied Counter
let base64Counter = args[6]

// from nonceCounter
const iv = parseInt(args[7])

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


var opponentCard;
for (var l = 0; l < args[9]; l++) {
    let picked2 = secret_value % opponentDeckLength
    opponentDeckArray.splice(picked2, 1)
    opponentDeckLength -= 1
    if ( l === args[9] - 1) {
        opponentCard = opponentDeckArray[picked2]
    }
}

var playerCard;
for (var k = 0; k < 3 + args[9]; k++) {
    let picked = secret_value % playerDeckLength
    playerDeckArray.splice(picked, 1)
    playerDeckLength -= 1
    if ( k === 3 + args[9]) {
        playerCard = playerDeckArray[picked]
    }
}

let result = opponentCard + playerCard
  
return Functions.encodeString(result)
