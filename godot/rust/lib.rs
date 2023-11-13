use gdnative::{prelude::*, core_types::ToVariant};
use ethers::{core::{abi::{struct_def::StructFieldType, AbiEncode, AbiDecode}, types::*}, signers::*, providers::*, prelude::SignerMiddleware};
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

#[method]
fn test_encrypt() -> GodotString {
    let mut key = [0; 16];
    rand_bytes(&mut key).unwrap();
    //godot_print!("{:?}", buf);
    //let hex_key = hex::encode(key);

    let raw_pem = "-----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvOkgKoC7DhwKMQ9b6m2d
    DJSyiCj3oj1kBcm3tgH8fUnX2hlm0ND+cplxeipnUxhXfsMbOEECE1oywiyi8dja
    rvLI8vS0hDV7wEF8tSEyubMfhWULQ5JqlgUI4aKjR2U9nShRN6qQNdEyS9tc74KH
    5MgwoMwo4BbMpQaJPcgulN+kYzx9ipsH17+ErXzLGodhSwZXiftec/T1qUaJlTYx
    +ue0ZF4EZBfhtviNCzPygokxrlHbEmwmeaa4PJzBc9sWV8chaUarzlYrR+ViD3u+
    4i6tLsMLRHf3DGcQGh/voM3zQPt2Wy/un2IlbM9QSbJfQmBbV5H/CR8fJ/wyjgo6
    dQIDAQAB
-----END PUBLIC KEY-----";

    let public_key = Rsa::public_key_from_pem(raw_pem.as_bytes()).unwrap();

    //let data = b"foobar";
    //let data = hex_key.as_bytes();
    godot_print!("{:?}", "before");
    //godot_print!("{:?}", data);
    let mut buf = vec![0; public_key.size() as usize];
    godot_print!("{:?}", buf);
    let encrypted_len = public_key.public_encrypt(&key, &mut buf, Padding::PKCS1_OAEP).unwrap();
    godot_print!("{:?}", "after");
    godot_print!("{:?}", buf);
    let return_string = openssl::base64::encode_block(&buf);
    //let return_string = format!("{:?}", buf);
    return_string.into()
}

#[method]
fn test_rsa() -> GodotString {
    let rsa = Rsa::generate(2048).unwrap();
    let data = b"foobar";
    let mut buf = vec![0; rsa.size() as usize];
    let encrypted_len = rsa.public_encrypt(data, &mut buf, Padding::PKCS1).unwrap();
    //"buf" is filled with the encrypted bytes
    godot_print!("{:?}", "message");
    godot_print!("{:?}", buf);
    godot_print!("{:?}", "private key");
    godot_print!("{:?}", RsaRef::private_key_to_der(&rsa));
    //godot_print!("{:?}", RsaRef::public_key_to_pem(&rsa));
    let return_string: GodotString = format!{"{:?}", RsaRef::private_key_to_der(&rsa)}.into();
    return_string
}


#[method]
#[tokio::main]
async fn initialize_session(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, ui_node: Ref<Control>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
     
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();

let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet.clone());

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

//temporary
let seed = 340282366920930463 + _count;

let mut iv = [0; 16];
rand_bytes(&mut iv).unwrap();

let calldata = contract.initialize_session(seed.into(), iv).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(200000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Control> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}



#[method]
#[tokio::main]
async fn examine_secret(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, ui_node: Ref<Control>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
     
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();

let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet.clone());

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));


let calldata = contract.examine_secret().calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(200000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Control> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}



#[method]
fn check_secret(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.returned_secret(user_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}






#[method]
#[tokio::main]
async fn register_player_key(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, aes_key: PoolArray<u8>, ui_node: Ref<Control>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
     
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();

let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet.clone());

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

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

let calldata = contract.register_player_key(base64_player_key).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(500000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Control> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}




#[method]
#[tokio::main]
async fn send_don_message(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, aes_key: PoolArray<u8>, _message: GodotString, ui_node: Ref<Control>) -> NewFuture {

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

let mut iv = [0; 16];
rand_bytes(&mut iv).unwrap();

let message = _message.to_string();

let cipher = Cipher::aes_128_cbc();
let data = message.as_bytes();
let ciphertext = encrypt(
    cipher,
    aes_keyset,
    Some(&iv),
    data).unwrap();


let base64_iv = openssl::base64::encode_block(&iv);
let base64_ciphertext = openssl::base64::encode_block(&ciphertext);

let calldata = contract.send_don_message(base64_ciphertext, base64_iv).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(500000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Control> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}



#[method]
fn check_returned_message(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.decrypted_message(user_address).calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}



//   NEW GAME STUFF  //


#[method]
#[tokio::main]
async fn register_opponent_deck(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, aes_key: PoolArray<u8>, _deck: GodotString, ui_node: Ref<Control>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
     
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();

let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet.clone());

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

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

let mut iv = [0; 16];
rand_bytes(&mut iv).unwrap();

let deck = _deck.to_string();

let cipher = Cipher::aes_128_cbc();
let data = deck.as_bytes();
let ciphertext = encrypt(
    cipher,
    aes_keyset,
    Some(&iv),
    data).unwrap();

let base64_iv = openssl::base64::encode_block(&iv);
let base64_deck = openssl::base64::encode_block(&ciphertext);

let calldata = contract.register_opponent_deck(base64_player_key, base64_deck, base64_iv).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(500000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Control> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}






#[method]
#[tokio::main]
async fn start_game(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, ui_node: Ref<Control>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
     
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();

let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet.clone());

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

//temporary
let seed = 340282366920930463 + _count;

let mut iv = [0; 16];
rand_bytes(&mut iv).unwrap();

let base64_iv = openssl::base64::encode_block(&iv);

let calldata = contract.start_game(seed.into(), base64_iv).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(200000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Control> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}

#[method]
#[tokio::main]
async fn progress_game(key: PoolArray<u8>, chain_id: u64, time_crystal_contract: GodotString, rpc: GodotString, _gas_fee: u64, _count: u64, card_index: u8, ui_node: Ref<Control>) -> NewFuture {

let vec = &key.to_vec();

let keyset = &vec[..]; 
     
let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();

let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let user_address = wallet.address();

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_contract.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet.clone());

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));


let calldata = contract.progress_game(card_index).calldata().unwrap();

let tx = Eip1559TransactionRequest::new()
    .from(user_address)
    .to(contract_address) 
    .value(0)
    .gas(200000)
    .max_fee_per_gas(_gas_fee)
    .max_priority_fee_per_gas(_gas_fee)
    .chain_id(chain_id)
    .nonce(_count)
    .data(calldata);

let typed_tx: TypedTransaction = TypedTransaction::Eip1559(tx.clone());

let signature = wallet.sign_transaction(&typed_tx).await.unwrap();
let signed_data = TypedTransaction::rlp_signed(&typed_tx, &signature);

let node: TRef<Control> = unsafe { ui_node.assume_safe() };

unsafe {
    node.call("set_signed_data", &[hex::encode(signed_data).to_variant()])
};


NewFuture(Ok(()))

}




#[method]
fn get_player_cards(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.get_player_cards().calldata().unwrap();

let return_string: GodotString = calldata.to_string().into();

return_string

}


#[method]
fn get_opponent_cards(key: PoolArray<u8>, chain_id: u64, time_crystal_address: GodotString, rpc: GodotString) -> GodotString {

let vec = &key.to_vec();

let keyset = &vec[..]; 

let prewallet : LocalWallet = LocalWallet::from_bytes(&keyset).unwrap();
    
let wallet: LocalWallet = prewallet.with_chain_id(chain_id);

let provider = Provider::<Http>::try_from(rpc.to_string()).expect("could not instantiate HTTP Provider");

let contract_address: Address = time_crystal_address.to_string().parse().unwrap();

let client = SignerMiddleware::new(provider, wallet);

let contract = TimeCrystalABI::new(contract_address.clone(), Arc::new(client.clone()));

let calldata = contract.get_opponent_cards().calldata().unwrap();

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
fn decode_array (message: GodotString) -> GodotString {
    let raw_hex: String = message.to_string();
    let decoded: Vec<String> = ethers::abi::AbiDecode::decode_hex(raw_hex).unwrap();
    let return_string: GodotString = format!("{:?}", decoded).into();
    return_string
}



}



godot_init!(init);

