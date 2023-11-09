## Day 1
Fall has arrived, and with it, another Chainlink hackathon.  Very excited to get started.  I'll be making a brand new game using these [GodotRust-Ethers-rs](https://github.com/Cactoidal/GodotRustEthers-rs) tools.

In the interim I've [fixed the laggy transaction problem](https://github.com/Cactoidal/GodotEthersV2), which means games can now freely poll an RPC node and submit transactions without briefly freezing.  So the UX should be much improved.

I have many ideas I'd like to try, although I'm not quite sure yet how they'll come together into a game.  My goal for the hackathon is to make a _fun_ game, which uses Chainlink Functions in some capacity, and potentially other services.  Bots are really the primary obstacle to making sustainable web3 games, so it would be nice to experiment with some anti-bot features as well.

To start with, I want to try some ideas involving secret-handling.  Specifically, I want to use Chainlink Functions to produce secret random values, and I want to create a key-exchange mechanism that will allow players to send and receive secrets from the Functions oracle.

### Secret Random Values

Let's imagine a game where there is a secret set of coordinates, and the player receives a hint about the correct location every time they make a guess.  Or a card game, with a deck of fairly drawn cards, and the deck must be referred to whenever the player draws a new card, or whenever the oracle itself draws and reveals cards.

In both of these cases, randomness is generated in a single event, the randomness is temporarily kept secret, and is referred to later whenever the player makes decisions.

Chainlink VRF is excellent for producing cryptographically secure random values.  And for many applications it already performs just fine out of the box.

But there is one problem, one I'm hoping to solve: Chainlink VRF values are public as soon as they hit the chain.  So while they are random, that randomness is visible to everyone.  Which is part of the goal - they are _verifiably_ random.  Is there a way this property could be preserved, while still maintaining secrecy?

I think this can be done using Chainlink Functions.  I've done some research on various cryptographic primitives, and taking the limitations of Chainlink Functions into account, my plan is to generate secret, random values as follows: 

1) Upload two AES keys to the DON gateway.  These will be the "inner keys" used to generate randomness and "save" that randomness on-chain.

2) Use VRF to generate a seed value.  This seed is public, but it will not be used directly to create the randomness.

3) Pass the seed to Chainlink Functions.  One AES key will be used as a cryptographically-secure pseudorandom number generator (CSPRNG), and will transform the seed.  The transformed seed will pass through a secondary PRNG easily implemented in javascript (such as Xorshift), to get some kind of pseudorandom output. The second AES key will then encrypt this output, and put the encrypted bytes on-chain.

4) Later, when the randomness needs to be checked, the encrypted bytes will be sent back to Functions, which will decrypt them, check them, and return some kind of effect back on-chain.

When generating randomness, consensus is a big problem for the Functions DON.  If every node just uses Math.random(), they'll all generate different values.  By using a shared, secret AES key as the initial CSPRNG key, and passing the same seed to every node, I can guarantee that they'll all end up with the same pseudorandom values, while preventing on-chain observers from predicting what that pseudorandomness will be.

Anyway, I suspect there will be problems in implementation (for example, to be secure, AES keys also need new initialization vectors every time they encrypt something), but my goal is to get this working first.  Let's get started.

___

While working, I realized that at least for this application, I don't actually need to encrypt the secret output and put it back on-chain.  Because the seed is public, the DON can simply reconstruct the entire secret whenever necessary.  This means the "saved secret" can be considerably larger than I originally thought, I only need to use one "inner key", and I don't need to expose any ciphertext whatsoever.

Furthermore, I shouldn't need to use a secondary PRNG function like Xorshift, because I can convert the pseudorandom bytes produced by the CSPRNG key into an integer, and just operate on the integer directly.
