
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
const binaryPlayerKey = atob(args[0]);
  // convert from a binary string to an ArrayBuffer
  const binaryPlayerKeyBytes = str2ab(binaryPlayerKey);

//  console.log(binaryDerEncryptBytes)

const decBuffer = await crypto.subtle.decrypt(
  { name: "RSA-OAEP" },
  decryption_key,
  binaryPlayerKeyBytes,
);


const playerKey = await crypto.subtle.importKey(
  "raw",
  decBuffer,
  "AES-CBC",
  true,
  ["encrypt", "decrypt"],
);


const binaryIv = atob(args[1]);
  // convert from a binary string to an ArrayBuffer
  const binaryIvBytes = str2ab(binaryIv);

  const binaryMessage = atob(args[2]);
  // convert from a binary string to an ArrayBuffer
  const binaryMessageBytes= str2ab(binaryMessage);



const decodedMessage = await crypto.subtle.decrypt(
  { name: "AES-CBC", iv: binaryIvBytes },
  playerKey,
  binaryMessageBytes,
);


return decodedMessage
