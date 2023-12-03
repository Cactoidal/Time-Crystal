use gdnative::{prelude::*, core_types::ToVariant};
use ethers::{core::{abi::{struct_def::StructFieldType, AbiEncode, AbiDecode}, types::*, k256::elliptic_curve::consts::U8}, signers::*, providers::*, prelude::SignerMiddleware};
use ethers_contract::{abigen};
use ethers::core::types::transaction::eip2718::TypedTransaction;
use std::{convert::TryFrom, sync::Arc};
use tokio::runtime::{Builder, Runtime};
use tokio::task::LocalSet;
use tokio::macros::support::{Pin, Poll};
use futures::Future;
use serde_json::json;
use hex::*;
use openssl::rand::rand_bytes;
use openssl::rsa::{Rsa, Padding};
use openssl::rsa::RsaRef;
use openssl::symm::{encrypt, Cipher};
use std::str::from_utf8;



thread_local! {
    static EXECUTOR: &'static SharedLocalPool = {
        Box::leak(Box::new(SharedLocalPool::default()))
    };
}

#[derive(Default)]
struct SharedLocalPool {
    local_set: LocalSet,
}

impl futures::task::LocalSpawn for SharedLocalPool {
    fn spawn_local_obj(
        &self,
        future: futures::task::LocalFutureObj<'static, ()>,
    ) -> Result<(), futures::task::SpawnError> {
        self.local_set.spawn_local(future);

        Ok(())
    }
}


fn init(handle: InitHandle) {
    gdnative::tasks::register_runtime(&handle);
    gdnative::tasks::set_executor(EXECUTOR.with(|e| *e));

    handle.add_class::<TimeCrystal>();
}

abigen!(
    TimeCrystalABI,
    "./TimeCrystal.json",
    event_derives(serde::Deserialize, serde::Serialize)
);

abigen!(
    LINKTokenABI,
    "./LINKToken.json",
    event_derives(serde::Deserialize, serde::Serialize)
);

struct NewFuture(Result<(), Box<dyn std::error::Error + 'static>>);

impl ToVariant for NewFuture {
    fn to_variant(&self) -> Variant {todo!()}
}

struct NewStructFieldType(StructFieldType);

impl OwnedToVariant for NewStructFieldType {
    fn owned_to_variant(self) -> Variant {
        todo!()
    }
}

impl Future for NewFuture {
    type Output = NewStructFieldType;
    fn poll(self: Pin<&mut Self>, _: &mut std::task::Context<'_>) -> Poll<<Self as futures::Future>::Output> { todo!() }
}

#[derive(NativeClass, Debug, ToVariant, FromVariant)]
#[inherit(Node)]
struct TimeCrystal;

#[methods]
impl TimeCrystal {
    fn new(_owner: &Node) -> Self {
        TimeCrystal
    }

#[method]
fn get_address(key: PoolArray<u8>) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 
 
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();

let wallet: LocalWallet = prewallet.with_chain_id(Chain::Sepolia);

let address = wallet.address();

let address_string = address.encode_hex();

let key_slice = match address_string.char_indices().nth(*&0 as usize) {
    Some((_pos, _)) => (&address_string[26..]).to_string(),
    None => "".to_string(),
    };

let return_string: GodotString = format!("0x{}", key_slice).into();

return_string

}



//   NEW GAME STUFF  //

#[method]
#[tokio::main]
async fn register_player_key(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, aes_key: PoolArray<u8>, chainlink_contract: GodotString, ui_node: Ref<Spatial>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
         
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);
    
let user_address = wallet.address();
    
let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");
    
let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();

let chainlink_address: Address = chainlink_contract.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet.clone());

let contract = LINKTokenABI::new(chainlink_address.clone(), Arc::new(client.clone()));
//let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));
    
let raw_pem = "-----BEGIN PUBLIC KEY-----
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvOkgKoC7DhwKMQ9b6m2d
        DJSyiCj3oj1kBcm3tgH8fUnX2hlm0ND+cplxeipnUxhXfsMbOEECE1oywiyi8dja
        rvLI8vS0hDV7wEF8tSEyubMfhWULQ5JqlgUI4aKjR2U9nShRN6qQNdEyS9tc74KH
        5MgwoMwo4BbMpQaJPcgulN+kYzx9ipsH17+ErXzLGodhSwZXiftec/T1qUaJlTYx
        +ue0ZF4EZBfhtviNCzPygokxrlHbEmwmeaa4PJzBc9sWV8chaUarzlYrR+ViD3u+
        4i6tLsMLRHf3DGcQGh/voM3zQPt2Wy/un2IlbM9QSbJfQmBbV5H/CR8fJ/wyjgo6
        dQIDAQAB
-----END PUBLIC KEY-----";
    
let public_rsa_key = Rsa::public_key_from_pem(raw_pem.as_bytes()).unwrap();
    
let aes_vec = &aes_key.to_vec();
    
let aes_keyset = &aes_vec[..];
    
let mut encrypted_player_key = vec![0; public_rsa_key.size() as usize];
    
let encrypted_len = public_rsa_key.public_encrypt(&aes_keyset, &mut encrypted_player_key, Padding::PKCS1_OAEP).unwrap();
    
let base64_player_key = openssl::base64::encode_block(&encrypted_player_key);

let key_bytes = AbiEncode::encode(base64_player_key);

let calldata = contract.transfer_and_call(contract_address, 1.into(), key_bytes.into()).calldata().unwrap();
//let calldata = contract.register_player_key(base64_player_key).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(chainlink_address) 
    .value(0)
    .gas(900000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Spatial> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}


#[method]
#[tokio::main]
async fn get_hand(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, aes_key: PoolArray<u8>, _secrets: GodotString, ui_node: Ref<Spatial>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
         
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);
    
let user_address = wallet.address();
    
let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");
    
let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();
    
let client = SignerMiddleware::new(provider, wallet.clone());
    
let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));
    
let aes_vec = &aes_key.to_vec();
    
let aes_keyset = &aes_vec[..];

let mut secrets_iv = [0; 16];
rand_bytes(&mut secrets_iv).unwrap();

let secrets = _secrets.to_string();

let cipher = Cipher::aes_128_cbc();
let data = secrets.as_bytes();
let ciphertext = encrypt(
    cipher,
    aes_keyset,
    Some(&secrets_iv),
    data).unwrap();

let mut csprng_iv = [0; 16];
rand_bytes(&mut csprng_iv).unwrap();

let base64_secrets = openssl::base64::encode_block(&ciphertext);
let base64_secrets_iv = openssl::base64::encode_block(&secrets_iv);
let base64_csprng_iv = openssl::base64::encode_block(&csprng_iv);

let calldata = contract.get_hand(base64_secrets, base64_secrets_iv, base64_csprng_iv).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(900000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Spatial> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}


#[method]
#[tokio::main]
async fn commit_action(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, _secrets: GodotString, ui_node: Ref<Spatial>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
             
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
        
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);
        
let user_address = wallet.address();
        
let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");
        
let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();
        
let client = SignerMiddleware::new(provider, wallet.clone());
        
let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let secrets: &str = &_secrets.to_string();

let encoded = ethers::abi::AbiEncode::encode(secrets);

let mut sha =  openssl::sha::Sha256::new();

sha.update(&encoded);

let hashed = sha.finish();

let bytes: ethers::types::Bytes = hashed.into();

let calldata = contract.commit_action(bytes).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(900000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();

let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Spatial> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}


#[method]
#[tokio::main]
async fn reveal_action(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, password: GodotString, action: GodotString, ui_node: Ref<Spatial>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
         
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);
    
let user_address = wallet.address();
    
let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");
    
let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();
    
let client = SignerMiddleware::new(provider, wallet.clone());
    
let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.reveal_action(password.to_string(), action.to_string()).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(900000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Spatial> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};

NewFuture(Ok(()))

}



#[method]
#[tokio::main]
async fn declare_victory(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, _secrets: GodotString, ui_node: Ref<Spatial>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
         
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);
    
let user_address = wallet.address();
    
let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");
    
let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();
    
let client = SignerMiddleware::new(provider, wallet.clone());
    
let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.declare_victory(_secrets.to_string()).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(900000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Spatial> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};

NewFuture(Ok(()))

}



#[method]
fn check_queue(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.in_queue(user_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}


#[method]
fn check_in_game(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.in_game(user_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}

#[method]
fn get_player_cards(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.hands(user_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}


#[method]
fn see_actions(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString, player: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let player_address: Address = player.to_string().parse().unwrap();

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.player_actions(player_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}



#[method]
fn has_seeds_remaining(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString, player: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let player_address: Address = player.to_string().parse().unwrap();

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.has_seeds_remaining(player_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}


#[method]
fn crystal_staked(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString, player: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let player_address: Address = player.to_string().parse().unwrap();

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.crystal_staked(player_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}

#[method]
fn token_uri(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString, crystal_id: u64) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.token_uri(crystal_id.into()).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}

#[method]
fn get_opponent(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address: Address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.current_opponent(user_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}

#[method]
fn get_hash_monster(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString, _player: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let player: Address = _player.to_string().parse().unwrap();

let calldata = contract.get_hash_monster(player).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}

#[method]
fn check_commit(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString, player: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let player_address: Address = player.to_string().parse().unwrap();

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.check_commit(player_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}


#[method]
fn test_win(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.test_win().calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}





#[method]
fn decode_hex_string (message: GodotString) -> GodotString {
    let raw_hex: String = message.to_string();
    let decoded: String = ethers::abi::AbiDecode::decode_hex(raw_hex).unwrap();
    let return_string: GodotString = decoded.into();
    return_string
}

#[method]
fn decode_bool (message: GodotString) -> GodotString {
    let raw_hex: String = message.to_string();
    let decoded: bool = ethers::abi::AbiDecode::decode_hex(raw_hex).unwrap();
    let return_string: GodotString = format!("{:?}", decoded).into();
    return_string
}

#[method]
fn decode_address (message: GodotString) -> GodotString {
    let raw_hex: String = message.to_string();
    let decoded: Address = ethers::abi::AbiDecode::decode_hex(raw_hex).unwrap();
    let return_string: GodotString = format!("{:?}", decoded).into();
    return_string
}

#[method]
fn decode_bytes (message: GodotString) -> GodotString {
    let raw_hex: String = message.to_string();
    let decoded: Bytes = ethers::abi::AbiDecode::decode_hex(raw_hex).unwrap();
    let return_string: GodotString = format!("{:?}", decoded).into();
    return_string
}

#[method]
fn decode_u256 (message: GodotString) -> GodotString {
    let raw_hex: String = message.to_string();
    let decoded: U256 = ethers::abi::AbiDecode::decode_hex(raw_hex).unwrap();
    let return_string: GodotString = format!("{:?}", decoded).into();
    return_string
}



#[method]
fn decode_u256_array (message: GodotString) -> GodotString {
    let raw_hex: String = message.to_string();
    let decoded: Vec<U256> = ethers::abi::AbiDecode::decode_hex(raw_hex).unwrap();
    let return_string: GodotString = format!("{:?}", decoded).into();
    return_string
}


#[method]
fn decode_u256_array_from_bytes (message: GodotString) -> GodotString {
    let raw_hex: String = message.to_string();
    //let bytes: Bytes = ethers::abi::AbiDecode::decode_hex(raw_hex).unwrap();
    let decoded_bytes: [U256; 5] = ethers::abi::AbiDecode::decode_hex(raw_hex).unwrap();
    godot_print!("{:?}", decoded_bytes);
    let return_string: GodotString = format!("{:?}", decoded_bytes).into();
    return_string
}



}



godot_init!(init);

