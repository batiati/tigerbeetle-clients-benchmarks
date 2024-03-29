const std = @import("std");
const panic = std.debug.panic;

const vsr = @import("vsr.zig");
const RingBuffer = vsr.ring_buffer.RingBuffer;
const StateMachine = vsr.state_machine.StateMachineType(Storage, constants.state_machine_config);
const MessageBus = vsr.message_bus.MessageBusClient;
const MessagePool = vsr.message_pool.MessagePool;
const Storage = vsr.storage.Storage;
const tb = vsr.tigerbeetle;
const Client = vsr.Client(StateMachine, MessageBus);
const constants = vsr.constants;
const IO = vsr.io.IO;
const stdx = vsr.stdx;

const Result = struct {
    reply: anyerror![]const u8,
    reply_ms: i64,
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const client_id = std.crypto.random.int(u128);
    const cluster_id: u32 = 0;
    var address = [_]std.net.Address{try std.net.Address.parseIp4("127.0.0.1", 3000)};

    var io = try IO.init(32, 0);
    defer io.deinit();

    var message_pool = try MessagePool.init(allocator, .client);
    defer message_pool.deinit(allocator);

    var client = try Client.init(
        allocator,
        client_id,
        cluster_id,
        @as(u8, @intCast(address.len)),
        &message_pool,
        .{
            .configuration = address[0..],
            .io = &io,
        },
    );
    defer client.deinit(allocator);

    const samples = 1_000_000;
    const batch_size = 8190;

    // Repeat the same test 10 times and pick the best execution
    var tries: u32 = 0;
    while (tries < 10) : (tries += 1) {
        var time_total_ms: i64 = 0;
        var time_batch_max_ms: i64 = 0;

        var i: u32 = 0;
        while (i < samples) : (i += batch_size) {
            var batch: [batch_size]tb.Transfer = undefined;

            var j: u32 = 0;
            while ((j < batch_size) and (i + j < samples)) : (j += 1) {
                batch[j].id = 0;
                batch[j].debit_account_id = 0;
                batch[j].credit_account_id = 0;
                batch[j].user_data_128 = 0;
                batch[j].pending_id = 0;
                batch[j].timeout = 0;
                batch[j].ledger = 2;
                batch[j].code = 1;
                batch[j].flags = .{};
                batch[j].amount = 10;
                batch[j].timestamp = 0;
            }

            const elapsed_ms = try send(
                &io,
                &client,
                &batch,
            );

            time_total_ms += elapsed_ms;
            if (elapsed_ms > time_batch_max_ms) {
                time_batch_max_ms = elapsed_ms;
            }
        }

        try stdout.print("Total time: {} ms\n", .{time_total_ms});
        try stdout.print("Max time per batch: {} ms\n", .{time_batch_max_ms});
        try stdout.print("Transfers per second: {}\n\n", .{@divFloor(samples * 1000, time_total_ms)});
    }
}

fn send(
    io: *IO,
    client: *Client,
    batch_transfers: []tb.Transfer,
) !i64 {
    const message = client.get_message();
    const payload = std.mem.sliceAsBytes(batch_transfers);

    stdx.copy_disjoint(
        .inexact,
        u8,
        message.buffer[@sizeOf(vsr.Header)..],
        payload,
    );

    var result: ?Result = null;
    const start_ms = std.time.milliTimestamp();

    client.request(
        @as(u128, @intCast(@intFromPtr(&result))),
        send_complete,
        .create_transfers,
        message,
        payload.len,
    );

    while (result == null) {
        client.tick();
        try io.run_for_ns(constants.tick_ms * std.time.ns_per_ms);
    }

    const reply = result.?.reply catch |err|
        panic("Client returned error: {}", .{err});

    const create_transfers_results = std.mem.bytesAsSlice(
        tb.CreateTransfersResult,
        reply,
    );

    // Since we are using invalid IDs,
    // it is expected to all transfers to be rejected.
    if (create_transfers_results.len != batch_transfers.len) {
        panic("Unexpected result", .{});
    }

    return result.?.reply_ms - start_ms;
}

fn send_complete(
    user_data: u128,
    operation: StateMachine.Operation,
    reply: []const u8,
) void {
    _ = operation;

    const result_ptr = @as(*?Result, @ptrFromInt(@as(u64, @intCast(user_data))));
    result_ptr.* = Result{
        .reply = reply,
        .reply_ms = std.time.milliTimestamp(),
    };
}
