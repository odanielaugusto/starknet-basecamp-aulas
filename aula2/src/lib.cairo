use starknet::ContractAddress;

#[starknet::interface]
pub trait IHelloWorld<TContractState> {

    fn register_user(ref self: TContractState, id: felt252);
    fn unregister_user(ref self: TContractState, user: ContractAddress);
    fn change_user_id(ref self: TContractState, id: felt252);


    //get
    fn is_user_registered(self: @TContractState, user: ContractAddress) -> bool;
    fn get_user_id(self: @TContractState, user: ContractAddress) -> felt252;
    fn get_users_count(self: @TContractState) -> u64;
}

#[starknet::contract]
mod HelloWorld {
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use core::starknet::{ContractAddress, get_caller_address};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        ids: Map<ContractAddress, felt252>,
        users_registered: Map<ContractAddress, bool>,

        users_count: u64,

        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event{
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        UserRegistered: UserRegistered,
        UserUnregistered: UserUnregistered,
        UserIdChanged: UserIdChanged,

    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct UserRegistered {
        pub user: ContractAddress,
        pub id: felt252,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct UserUnregistered {
        pub user: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct UserIdChanged {
        pub user: ContractAddress,
        pub id: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl HelloWorldImpl of super::IHelloWorld<ContractState> {

        fn register_user(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            self.users_registered.entry(caller).write(true);
            self.ids.entry(caller).write(id);
            self.users_count.write(self.users_count.read() + 1);

            self.emit(UserRegistered {
                user: caller,
                id: id,
            });

        }

        fn unregister_user(ref self: ContractState, user: ContractAddress) {
            let caller = get_caller_address();
            let owner = self.ownable.owner();

            assert(caller == user || caller == owner, 'Unauthorized');
            let is_registered = self.users_registered.entry(user).read();

            assert(is_registered, 'User not registered');

            assert(self.users_count.read() > 0, 'No users registered');

            self.users_count.write(self.users_count.read() - 1);

            self.users_registered.entry(user).write(false);

            self.emit(UserUnregistered {
                user: user,
            });
        }

        fn change_user_id(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            let registered = self.users_registered.entry(caller).read();

            assert(registered, 'User not registered');

            self.ids.entry(caller).write(id);

            self.emit(UserIdChanged {
                user: caller,
                id: id,
            });
        }

        fn get_users_count(self: @ContractState) -> u64 {
            self.users_count.read()
        }

        fn is_user_registered(self: @ContractState, user: ContractAddress) -> bool {
            self.users_registered.entry(user).read()
        }

        fn get_user_id(self: @ContractState, user: ContractAddress) -> felt252 {
            self.ids.entry(user).read()
        }


    }
}
