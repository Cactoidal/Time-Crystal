// can I use AES-CBC instead?

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

// placeholder for ivCounter
const iv = 1;

// placeholder for counterCounter
// a single digit shift will change the output
// just need to get 16 bytes somehow
let counter = Uint8Array.from([
    228, 133,  40, 200, 195,
    163,  63,  15, 179, 253,
    192,  76, 145,  89,  64,
    104
  ])

// placeholder for length
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
let output = secret_value % 10+1
console.log(output)

// Examine output and return clue
var message = "blank"
switch(output) {
    case 1: message = "hello"
    break
    case 2: message = "why"
    break
    case 3: message = "yes"
    break
    case 4: message = "success"
    break
    case 5: message = "undoubtedly"
    break
    case 6: message = "resplendent"
    break
    case 7: message = "a lot of messages"
    break
    case 8: message = "we did it"
    break
    case 9: message = "hurray"
    break
    case 10: message = "finale"
    break
}
console.log(message)

return Functions.encodeString(message)
