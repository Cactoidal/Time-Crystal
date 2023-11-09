use gdnative::{prelude::*, core_types::ToVariant};
use ethers::{core::{abi::{struct_def::StructFieldType, AbiEncode}, types::*}, signers::*, providers::*, prelude::SignerMiddleware};
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
fn test_bytes() {
    let mut buf = [0; 16];
    rand_bytes(&mut buf).unwrap();
    godot_print!("{:?}", buf);
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

let mut buf = [0; 16];
rand_bytes(&mut buf).unwrap();
godot_print!("{:?}", buf);

let ethers_iv = buf.map(U256::from);

let calldata = contract.initialize_session(seed.into(), ethers_iv).calldata().unwrap();

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



}



godot_init!(init);

