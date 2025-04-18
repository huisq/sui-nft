module deployer::nft{

    use std::string::{Self, String};
    use sui::vec_set::{Self, VecSet};
    use std::address;
    use sui::clock::{Self, Clock};
    use sui::event;

    //------------------------------------------------ Error Code ------------------------------------------------//
    const EAlreadyInitialized: u64 = 0;

    //------------------------------------------------ Struct ------------------------------------------------//
    public struct EventState has key{
        id: UID,
        name: String,
        participants: VecSet<address>, //nft_address
        create_at: u64,
    }

    public struct AdminCap has key, store{
        id: UID,
    }

    public struct Attendance has key{
        id: UID,
        name: String,
        description: String,
        x_handle: String,
        tg_handle: String,
        friends: VecSet<address>,
        check_in_at: u64,
    }

    //------------------------------------------------ Struct ------------------------------------------------//
    public struct CheckedIn has copy, drop{
        name: String,
        user: address,
        nft_add: address,
        check_in_at: u64,
    }

    public struct FriendAdded has copy, drop{
        user: address,
        user_nft_add: address,
        friend_nft_add: address,
        added_at: u64,
    }

    //------------------------------------------------ Init ------------------------------------------------//
    fun init(ctx: &mut TxContext) {
        let event = EventState{
            id: object::new(ctx),
            name: string::utf8(b""),
            participants: vec_set::empty(),
            create_at: 0,
        };
        transfer::share_object(event);

        transfer::public_transfer(AdminCap{
            id: object::new(ctx)
        },
        tx_context::sender(ctx));
    }

    public fun initialize(
        _cap: &AdminCap,
        event: &mut EventState,
        name: String,
        clock: &Clock,
    ){
        assert!(event.create_at == 0, EAlreadyInitialized);
        event.name = name;
        event.create_at = clock::timestamp_ms(clock);
    }

    //------------------------------------------------ Entry Functions ------------------------------------------------//
    public entry fun sign_in(
        event: &mut EventState,
        name: String,
        description: String,
        x_handle: String,
        tg_handle: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ){
        let sender = tx_context::sender(ctx);
        let id = object::new(ctx);
        let nft_add = object::uid_to_address(&id);
        let nft = Attendance{
            id,
            name,
            description,
            x_handle,
            tg_handle,
            friends: vec_set::empty(),
            check_in_at: clock::timestamp_ms(clock)
        };
        transfer::transfer(nft, sender);
        vec_set::insert(&mut event.participants, nft_add);

        event::emit(CheckedIn{
            name,
            user: sender,
            nft_add,
            check_in_at: clock::timestamp_ms(clock)
        });
    }

    public entry fun add_friend(
        event: &EventState,
        self: &mut Attendance,
        friend_nft_add: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ){
        assert!(vec_set::contains(&event.participants, &friend_nft_add));
        vec_set::insert(&mut self.friends, friend_nft_add);
        event::emit(FriendAdded{
            user: tx_context::sender(ctx),
            user_nft_add: object::uid_to_address(&self.id),
            friend_nft_add,
            added_at: clock::timestamp_ms(clock)
        });
    }
    
}