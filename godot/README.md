## Day 1
Fall has arrived, and with it, another Chainlink hackathon.  Very excited to get started.  I'll be making a brand new game using these [GodotRust-Ethers-rs](https://github.com/Cactoidal/GodotRustEthers-rs) tools.

In the interim I've [fixed the laggy transaction problem](https://github.com/Cactoidal/GodotEthersV2), which means games can now freely poll an RPC node and submit transactions without freezing.  So the UX should be much improved.

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

As for the iv problem, maybe there is a more elegant solution, but for now I'll have users supply an array of 16 integers between 0 and 255, and have the contract validate the contents of the array and check whether it has already been used.  This way it's impossible for the same iv to be used twice, and the iv can be easily generated client-side.

With that, the basic idea of on-chain "secret randomness" seems to be working.  What exactly I'll use it for, I'm not quite sure yet, but I think a use will become apparent later.

Here is a diagram of the mechanism, here used for a simple guessing game:


![diagram1](https://github.com/Cactoidal/Time-Crystal/assets/115384394/48b13495-9499-4ea9-a133-fa663d7aab1d)

## Day 2

Before I continue, I feel I should mention a major weakness of the above idea.  While the "inner key" prevents _almost_ everyone from knowing the secret randomness, there is one person who is still able to decipher it: me!

Since I uploaded the key to the DON gateway, I know what it is, and I could use it to gain knowledge of any secret value given its seed and iv.  

Fortunately, I think the solution should be straightforward.  AES keys are just 16 random bytes.  After the contract has been deployed, a special Functions job could ask each node to generate some random bytes and upload them to the DON gateway.  The full key could then be reconstituted later during requests.

I would create this job now, but I don't think the gateway is set up in such a way that it will work.  For now, I will simulate the idea by uploading parts of the inner key, and combining those parts during requests.

### Oracle Key Exchange

Now that I've tried generating secret randomness, I want to look at the problem of key exchange.

In a typical key exchange, two parties swap some public information and use this info to individually generate the same shared secret.  That shared secret can then be used to encrypt and decrypt sensitive material that only those parties can now share.

Secrets can already be shared with Chainlink Functions using this technique.  The DON's public key is available on-chain, with which a user can generate an ephemeral secret key.  The user encrypts their secrets with this key, and gives it to the DON along with their own public key, which allows the DON to access the secrets when performing requests.

This is easy enough to use as a developer, but a bit harder for users.  The DON gateway, for example, requires the user to subscribe and provide a LINK balance before they can upload secrets.  This protects the gateway from spam.

There is also the "remote secret", which can be uploaded anywhere, and the DON just needs a URL to access it.  This is more flexible, but it forces reliance on a third party to host the secret.

Key exchange could perhaps happen entirely on-chain, but there are some problems.  Not only would the Functions DON need to generate a new keypair every time someone wants to do an exchange, it would need to post the public key on-chain every time, which in most cases will be much larger than the current 32 byte return limit.

The DON would also need to "remember" the keypair long enough to generate the shared secret with the user, and perform the exchange of the sensitive material.

I think these are obstacles that can be overcome (or obviated by some other method of secret-exchange), but for now, I will get around this problem by simply using an RSA keypair I've uploaded to the DON.

Here's how this will work:

1) the Function DON's public RSA key will be available on-chain, or in the game code.

2) the user will generate an AES key locally, encrypt it with the DON's public RSA key, and post the encrypted AES key on-chain.

3) the DON now has the ability to either decrypt secret messages sent by the user, or encrypt secret messages and send them to the user.

Like the weakness I mentioned above, since I'm the one uploading the RSA key, I could decrypt any passed message.

Ultimately I just want to demonstrate the principle of secret exchange between users and the DON, and how it could be used in games.  The messages in my example will not be especially sensitive, just being game data.  But in the future, this mechanism would need to be replaced by a more secure secret-exchanging method.

___

I've realized it's best to start working in Godot and Rust now, since the triangle of gdscript/Rust <-> Solidity <-> javascript all needs to be interoperable for the game to work.  There's a peculiarity in the RSA key format expected by the deno std library, which I'll need to figure out.  Godot needs to encrypt secrets with the public key, and the Functions DON needs to be able to read it.

It's not quite time to make my first calls to Chainlink Functions from Godot, but soon!

___

It took some wrestling, but I was finally able to load a public RSA key into Rust, encrypt 16 bytes, send the encrypted bytes to javascript, import the private RSA key into javascript, decrypt the bytes, and use them to generate an AES key.  Success!

I want to reiterate that this is a demo, and this kind of system would need an extensive audit to ascertain whether this kind of key exchange can be done in a secure way.  If I have time, I'd like to try experimenting with ECDH instead of RSA.  To a certain extent I'm limited by what the deno std library can do (it would be interesting to try CRYSTALS-Kyber, for instance).  

It seems, strangely, that the openssl rust crate uses the SHA-1 hash for its RSA-OAEP padding.  I only get decryption errors in javascript if I try to use a different hash; only SHA-1 seems to work.  This is not acceptable for a secure application, and it seems odd that this crate still uses it.  Maybe I'm making a mistake, and there's a way to change the hash function that I'm missing.

But in any case, the demo now works, and I can proceed to the next phase: making an interface in Godot.

## Day 3

It may not look like much quite yet:

<img width="875" alt="godot2" src="https://github.com/Cactoidal/Time-Crystal/assets/115384394/2b8dd3dd-d3b7-400f-a9fc-22e4cfd91d2a">

I'm happy to report that I've made my first successful call to Chainlink Functions from Godot.  After registering an encrypted AES key, I can now send an encrypted message to Functions, which will decrypt my AES key, decrypt the message, and return it on-chain.  The most recent returned message is printed in the lower right.  Took me some time to remember to use AbiDecode to handle the response.

I'm also pleased that I've implemented both the secret randomness and the oracle key exchange in relatively short order.  But now it's time to leverage these ideas for a more practical purpose.  This goes hand-in-hand with making a much cooler UI.

### Regarding Games

The secret randomness idea allows the oracle to hide information from the player, which is conducive to a player versus oracle (PvO) game.  But it could also be used in a player versus player (PvP) context, when the randomness affects competing players.

The key exchange allows players to hide information from one another, which is also very useful for PvP.

I could imagine an implementation of Texas Hold 'Em using these ideas.  Players register for a game session, and a seed would be used to secretly generate the deck, then draw the community cards and hole cards.  Thanks to secret randomness, no one would know what the community cards are until the oracle reveals them, and thanks to the key exchange, every player would be able to receive their hole cards secretly, without knowing what any other player has in their hand.

But I'm not a gambler, and I don't want to run a gambling parlor, so while that's a pretty clear example, I want to do something else.

### Time Crystals

<img width="825" alt="picture3" src="https://github.com/Cactoidal/Time-Crystal/assets/115384394/df249c24-5fcf-4be1-8917-fe5200dc94de">

A time crystal is a state of matter where particles oscillate in a repeating pattern, without requiring any energy to continuously change.  A fascinating quantum phenomenon, and the inspiration for my working title.  Perhaps Chainlink Automation could be used somehow to mimic the oscillation of a time crystal.  

Chainlink Functions, VRF, and Automation, used in a game with PvO and PvP elements.  I think I have some ideas.

https://github.com/Cactoidal/Time-Crystal/assets/115384394/01049fbd-33a0-4306-9b04-e8d5f01da0fa

The crystal is an icosphere from Blender, and the animation is a rotation script combined with a shader.  

Here's a tip I learned recently that really helps when trying to learn and work with shaders.  Regular Godot SpatialMaterials are really just shaders, and you can convert any SpatialMaterial into a block of shader code:

<img width="204" alt="tip5" src="https://github.com/Cactoidal/Time-Crystal/assets/115384394/9837ebe1-2c1c-42e7-a57e-6dc7c87da1d3">

Just click on the dropdown menu next to the material preview, and click "Convert to ShaderMaterial".  You can now experiment and see how Godot itself writes the parameters of your SpatialMaterials in shader code. 

## Day 4

The game mechanics are still forming.  What I know for sure is that the game will take place in 3D space, with freedom of movement between challenges, and the challenges themselves will be interfaces with smart contracts powered by Chainlink services.

Using the work I've done with secrets and key exchange, there are two core mechanics I definitely want to include:

1) The oracle knows the player's "inventory", and whenever a challenge begins, the oracle will assemble a secret, randomized "deck" from this inventory, from which it will fairly draw items/cards.  A random set of these items will make up the player's "hand" during the challenge, and as the challenge progresses, the oracle will play further items/cards from the secret deck.

2) While playing a challenge, you will encounter what are essentially bots (for now I'm calling them "paramecia") that have been "programmed" by other players.  These paramecia will be encrypted, and registered with the Functions DON to ensure they follow a specific format.  If approved, they will be able to attack you while you are doing a challenge.  Each paramecium will have its own decryption key, which will be passed to you whenever you are attacked.

There are a few other considerations I want to keep in mind.  First is the latency problem, where the player will be stuck with considerable downtime if they have to wait for transactions to settle after every single move.  To get around this, my idea is to have two independent states of play (or "boards") during a challenge, between which the player can switch their attention.

I'd also like to make player decisions fairly complex, with multiple inputs requiring careful consideration, to further reduce the impact of transaction times.  Finally, I'd like to design the game such that there should always be a "pending effect" waiting to be revealed, such that once the player submits their move, there is already something ready to happen next.

There will definitely be loot in the game, obtained from successfully clearing a challenge.  Losing to a paramecium means its owner gets the loot instead.  The "loot table" upon which the player rolls will depend on some kind of threshold, either score-based or from some kind of "trick-taking" system with challenges that, if completed, make the player eligible for certain loot.

Every "card" will have a positive or negative effect; when the oracle plays cards, it will choose randomly to play the positive or negative.  Player cards also have this duality, but the player can choose which one they want to use when they play the card.

Why would you want to play a negative card?  Because it will make "scoring" or "trick-taking" easier, at the cost of your "survivability".  So there is a risk-balancing element.  Play safe, with lesser rewards, or carefully manage risk, and win better prizes.

I'm considering an economic element, where players compete to empower their own "nodes".  An empowered node is eligible to potentially earn passive rewards, but it can be attacked by other players.  A successful attack will drain the power from a node, and allow the winning player to empower their own node instead.  It's up to the node-runner to build defenses that will keep their node online.

So, in addition to the "main gameplay" (which is not quite fully formed yet), there will potentially be sub-games for managing your "deck", managing your paramecia, and managing your node.  There could also potentially be "regions", or some kind of map, where players can establish a dominion with their node.

https://github.com/Cactoidal/Time-Crystal/assets/115384394/c6cb3ac5-074f-4da6-80fa-9a7a4ee24b12

The visual component of the game is taking shape.

A quick mock-up of the "main screen", with art generated using Stable Diffusion.  I'll do another pass later once more of the game is built:

https://github.com/Cactoidal/Time-Crystal/assets/115384394/d6a06cc4-207a-4711-85b7-cd2b2d19acec

___

After a lot of thought and discussion with my teammate, I'm leaning toward a "trick-taking" game.  Perhaps I'm using the term incorrectly, but by "trick" I mean a certain configuration of cards, which will score points when constructed in the field of play.

Every time you play a session, there will be two independent game boards, the spaces of the boards will be randomized, as will your hands.  Your objective is to strategically build tricks.  Tricks are built by linking cards together along connected spaces. There will be an interplay between the type of space, the connections between spaces, and the characteristics of cards.

In addition, I'm thinking there will be two tiers of cards, which will be organized into two separate decks.  The "minor" deck is used to bulld tricks on the board, while the "major" deck will contain cards with global effects or powerful abilities.  "Major" cards will be played randomly by the oracle, in either the positive or negative position.  

The exception will be the "lead card", which is a "major" card chosen by the player before the game begins, and which is played on turn 0.  There will be some strategy in building a "minor deck" that riffs on the effect of whichever "lead card" you've chosen.

Finally, once the procedural game has concluded, the session will proceed into a final phase: fighting a randomly selected Paramecium.  Paramecia will be built according to certain rules, where the Paramecium-builder defines a custom board configuration and specifies certain target tricks.

It's up to the player to construct these tricks during the Paramecium round, or face defeat.  So while building tricks during the procedural game, the player needs to manage their resources to be ready for whatever Paramecium they might face. 

Nodes will probably work similarly, where the defending player will define certain boards and tricks as a final defense gating access to their Node.  The difference is that Node players can have multiple layers of defense, increasing the difficulty (and cost) of an attack against their Node.

I should mention here the economics of the game.  Since so many actions cost LINK, the game contracts need to be self-sufficient.  Therefore, whenever a player wants to start a game session, they will first spend some fixed amount of LINK to cover the costs.

And loot.  Both Paramecium and Node parts can drop from winning games, and can be used to construct stronger Paramecia or better defenses.

The [Rainbow Shader by Exuin](https://godotshaders.com/shader/moving-rainbow-gradient/) below was obtained from [Godot Shaders](https://godotshaders.com):

https://github.com/Cactoidal/Time-Crystal/assets/115384394/e42689b9-18ff-4532-94d6-2b21a03d3b2d

Let's build the game world.

## Day 5

After materializing into a level, the player will seek terminals to "hack", initiating the trick-taking game.  Winning will grant access to vaults containing loot, or paths leading to "inner terminals" guarding better rewards.

https://github.com/Cactoidal/Time-Crystal/assets/115384394/4af0aaea-f6ad-4f40-9f63-909df5b6fe7c

I suppose floating tiles in space aren't really suggestive of terrestrial things like "caves" and "craters".  I'll revisit the level design later - or perhaps rename the regions.

In any case, it's not much of a vault if it can be opened with a simple click. It's time to draft what our game's board will look like. 

___

https://github.com/Cactoidal/Time-Crystal/assets/115384394/dbf2fd74-3515-44f6-a779-a0d4a3080a37

Game mechanics are still under development.  I'm wondering if, rather than generic PvO "trick-taking challenges" that contain PvP elements at the end, I should instead refocus the game to be strictly adversarial.  As in, you have a "deck", your opponent has a "deck", and you're both trying to clobber each other.

If you've played any kind of battle card game, you're familiar with the idea of building resources each turn and strategically deploying different types of cards to try and beat your opponent.  A big problem with PvP on the blockchain is the time delay between actions.  But what if your opponent, instead of being physically present, was instead a secret block of code?

Here's the new idea.  An OPPONENT (vaguely based on the Paramecium or Node mentioned above) consists of a constructed deck and some programmed logic.  There will be a basic logic template, and this can be built upon with per-turn logic, global logic, and conditional logic (i.e. player has card x of type y on the field, so OPPONENT plays card z if card z is in hand, with target x).

This OPPONENT deck is registered by putting an RSA-encrypted AES key on-chain, along with the AES-encrypted deck+logic and the iv.  That OPPONENT can now be attacked by any player.  During play, the oracle will decrypt the OPPONENT deck, validate its contents, randomly shuffle its deck and draw secret cards, and compute the OPPONENT's action each turn based on the programmed logic.

At no point is the full state of the OPPONENT deck ever public on-chain, and the only information conveyed publicly is the card the OPPONENT plays each turn, as determined by the oracle.  Given enough sessions, someone could figure out what the deck composition is, and get an idea for the logic, but the person managing the deck can always rewrite it and reupload it later.

This way, we can have a secret encrypted state on-chain that is used to generate unpredictable gameplay, thanks to Chainlink Functions.

My first task is to make the deck mechanism work.  For now, all cards will just be strings that have no other effect, and the game logic will just be "play a card each turn."  I'll build a system for registering an OPPONENT deck, then a simple framework for games.

At this stage, the oracle's job will be just to randomly order both the OPPONENT deck and the PLAYER deck, deal the hands, and play cards from the OPPONENT hand in response to my plays.  It will need to track which cards have been played, and the current state of the board each turn.



