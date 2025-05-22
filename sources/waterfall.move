module waterfall03::waterfall03;

use std::string::String;
use sui::event;
use sui::vec_set::{Self, VecSet};

//------------------------------------------------ Error Code ------------------------------------------------//
// const EAlreadyInitialized: u64 = 0;

//------------------------------------------------ Data Structure ------------------------------------------------//
public struct Event has key {
    id: UID,
    name: String,
    date: String,
    // GPS location for the event
    location: String,
    description: String,
    host_address: address,
    host_name: String,
    participants: VecSet<address>, //nft_address
}

public struct AdminCap has key {
    id: UID,
}

public struct Events has key {
    id: UID,
    events: VecSet<ID>,
}

public struct Attendance has key {
    id: UID,
    event_id: ID,
    event_name: String,
    name: String,
    description: String,
    x_handle: String,
    tg_handle: String,
    friends: VecSet<address>,
}

//------------------------------------------------ Events ------------------------------------------------//
public struct CheckedIn has copy, drop {
    name: String,
    user: address,
    nft_addr: address,
}

public struct FriendAdded has copy, drop {
    user: address,
    user_nft_addr: address,
    friend_nft_addr: address,
}

public struct EventCreated has copy, drop {
    event_id: ID,
    event_name: String,
}

//------------------------------------------------ Init ------------------------------------------------//

// Give the contract deployer the admin capability
fun init(ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    let events = Events {
        id: object::new(ctx),
        events: vec_set::empty(),
    };
    transfer::transfer(admin_cap, ctx.sender());
    transfer::transfer(events, ctx.sender());
}

//------------------------------------------------ Entry Functions ------------------------------------------------//
public entry fun create_event(
    _cap: &AdminCap,
    events: &mut Events,
    event_name: String,
    date: String,
    location: String,
    description: String,
    host_name: String,
    ctx: &mut TxContext,
): String {
    let sender = ctx.sender();
    let event_id = object::new(ctx);
    let event_id_string = object::uid_to_inner(&event_id);
    let event = Event {
        id: event_id,
        name: event_name,
        date,
        location,
        description,
        host_address: sender,
        host_name: host_name,
        participants: vec_set::empty(),
    };

    events.add_event(event_id_string);

    transfer::share_object(event);

    event::emit(EventCreated {
        event_id: event_id_string,
        event_name,
    });

    event_name
}

public entry fun sign_in(
    event: &mut Event,
    name: String,
    description: String,
    x_handle: String,
    tg_handle: String,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    let id = object::new(ctx);
    let nft_addr = object::uid_to_address(&id);
    let nft = Attendance {
        id,
        event_id: event.id.to_inner(),
        event_name: event.name,
        name,
        description,
        x_handle,
        tg_handle,
        friends: vec_set::empty(),
    };
    transfer::transfer(nft, sender);
    event.participants.insert(nft_addr);

    event::emit(CheckedIn {
        name,
        user: sender,
        nft_addr,
    });
}

public entry fun add_friend(
    event: &Event,
    attendance: &mut Attendance,
    friend_nft_addr: address,
    ctx: &mut TxContext,
) {
    assert!(event.participants.contains(&friend_nft_addr));
    attendance.friends.insert(friend_nft_addr);
    event::emit(FriendAdded {
        user: ctx.sender(),
        user_nft_addr: object::uid_to_address(&attendance.id),
        friend_nft_addr,
    });
}

//------------------------------------------------ Internal Helper Functions ------------------------------------------------//
fun add_event(events: &mut Events, event_id: ID) {
    events.events.insert(event_id);
}

//------------------------------------------------ Test Functions ------------------------------------------------//

#[test]
fun test_create_event() {
    use sui::test_scenario;
    use waterfall03::waterfall03;
    let event_host = @0xFACE;

    // Deploy contract
    let mut scenario = test_scenario::begin(event_host);
    {
        waterfall03::init(scenario.ctx());
    };

    // Event host creates an event
    scenario.next_tx(event_host);
    let admin_cap = scenario.take_from_sender<waterfall03::AdminCap>();
    let mut events = scenario.take_from_sender<waterfall03::Events>();
    let event_name = waterfall03::create_event(
        &admin_cap,
        &mut events,
        b"Test Event".to_string(),
        b"2025-05-20".to_string(),
        b"test".to_string(),
        b"test".to_string(),
        b"test".to_string(),
        scenario.ctx(),
    );
    assert!(event_name == b"Test Event".to_string());

    // Clean up
    scenario.return_to_sender(admin_cap);
    scenario.return_to_sender(events);
    scenario.end();
}

#[test]
fun test_sign_in() {
    use sui::test_scenario;
    use waterfall03::waterfall03;
    let event_host = @0xFACE;
    let attendee = @0xBEEF;

    // Deploy contract
    let mut scenario = test_scenario::begin(event_host);
    {
        waterfall03::init(scenario.ctx());
    };

    // Event host creates an event
    scenario.next_tx(event_host);
    let admin_cap = scenario.take_from_sender<waterfall03::AdminCap>();
    let mut events = scenario.take_from_sender<waterfall03::Events>();
    let _event_name = waterfall03::create_event(
        &admin_cap,
        &mut events,
        b"Test Event".to_string(),
        b"2025-05-20".to_string(),
        b"test".to_string(),
        b"test".to_string(),
        b"test".to_string(),
        scenario.ctx(),
    );
    scenario.return_to_sender(admin_cap);
    scenario.return_to_sender(events);

    // Attendee signs in to the event
    scenario.next_tx(attendee);
    let mut event = scenario.take_shared<waterfall03::Event>();
    waterfall03::sign_in(
        &mut event,
        b"Test Attendee".to_string(),
        b"test description".to_string(),
        b"test x handle".to_string(),
        b"test tg handle".to_string(),
        scenario.ctx(),
    );

    // Check if the attendee received his NFT
    scenario.next_tx(attendee);
    let attendance = scenario.take_from_sender<waterfall03::Attendance>();
    assert!(attendance.name == b"Test Attendee".to_string());

    // Clean up
    scenario.return_to_sender(attendance);
    test_scenario::return_shared(event);
    scenario.end();
}

#[test]
fun test_add_friend() {
    use sui::test_scenario;
    use waterfall03::waterfall03;
    let event_host = @0xFACE;
    let attendee = @0xBEEF;
    let friend_addr = @0xCAFE;

    // Deploy contract
    let mut scenario = test_scenario::begin(event_host);
    {
        waterfall03::init(scenario.ctx());
    };

    // Event host creates an event
    scenario.next_tx(event_host);
    let admin_cap = scenario.take_from_sender<waterfall03::AdminCap>();
    let mut events = scenario.take_from_sender<waterfall03::Events>();
    let _event_name = waterfall03::create_event(
        &admin_cap,
        &mut events,
        b"Test Event".to_string(),
        b"2025-05-20".to_string(),
        b"test".to_string(),
        b"test".to_string(),
        b"test".to_string(),
        scenario.ctx(),
    );
    scenario.return_to_sender(admin_cap);
    scenario.return_to_sender(events);
    // Attendee signs in to the event
    scenario.next_tx(attendee);
    let mut event = scenario.take_shared<waterfall03::Event>();
    waterfall03::sign_in(
        &mut event,
        b"Test Attendee".to_string(),
        b"test description".to_string(),
        b"test x handle".to_string(),
        b"test tg handle".to_string(),
        scenario.ctx(),
    );
    test_scenario::return_shared(event);

    // Attendee friend sign in
    scenario.next_tx(friend_addr);
    let mut event = scenario.take_shared<waterfall03::Event>();
    waterfall03::sign_in(
        &mut event,
        b"Friend".to_string(),
        b"friend description".to_string(),
        b"friend x handle".to_string(),
        b"friend tg handle".to_string(),
        scenario.ctx(),
    );
    test_scenario::return_shared(event);

    // Get friend's nft id
    scenario.next_tx(friend_addr);
    let friend_nft = scenario.take_from_sender<waterfall03::Attendance>();
    let friend_nft_addr = object::uid_to_address(&friend_nft.id);
    scenario.return_to_sender(friend_nft);

    // Attendee add friend
    scenario.next_tx(attendee);
    let mut attendance = scenario.take_from_sender<waterfall03::Attendance>();
    let event = scenario.take_shared<waterfall03::Event>();
    waterfall03::add_friend(
        &event,
        &mut attendance,
        friend_nft_addr,
        scenario.ctx(),
    );
    test_scenario::return_shared(event);

    // Check if the friend is added to the attendee's friends
    assert!(attendance.friends.contains(&friend_nft_addr));

    // Clean up
    scenario.return_to_sender(attendance);
    scenario.end();
}
