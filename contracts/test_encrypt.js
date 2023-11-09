
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
        hash: "SHA-1",
      },
    true,
    ["decrypt"],
  );

  // encrypted message (key) from godot
const binaryDerEncrypt = atob(args[3]);
  // convert from a binary string to an ArrayBuffer
  const binaryDerEncryptBytes = str2ab(binaryDerEncrypt);

  console.log(binaryDerEncryptBytes)

const decBuffer = await crypto.subtle.decrypt(
  { name: "RSA-OAEP" },
  decryption_key,
  binaryDerEncryptBytes,
);

console.log(decBuffer)

const playerKey = await crypto.subtle.importKey(
  "raw",
  decBuffer,
  "AES-CBC",
  true,
  ["encrypt", "decrypt"],
);

console.log(playerKey)

let decoder = new TextDecoder
let message = decoder.decode(decBuffer)
console.log(message)

return Functions.encodeString(message)
