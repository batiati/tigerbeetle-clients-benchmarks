@nogc nothrow:
extern (C):
__gshared:

import core.stdc.config : c_long, c_ulong;
import core.sys.posix.pthread;
import core.sys.posix.sys.time;
import core.stdc.stdio : printf;
import core.stdc.string;
import core.stdc.stdlib;
import modules.tb_client;

// Synchronization context between the callback and the main thread.
struct completion_context_t
{
    void* reply;
    int size;
    pthread_mutex_t lock;
    pthread_cond_t cv;
}

// Completion function, called by tb_client no notify that a request as
// completed.
void on_completion(uintptr_t context, tb_client_t client, tb_packet_t* packet, const(
        ubyte)* data, uint size)
{

    // The user_data gives context to a request:
    completion_context_t* ctx = cast(completion_context_t*) packet.user_data;

    // Signaling the main thread we received the reply:
    pthread_mutex_lock(&ctx.lock);
    ctx.size = size;
    ctx.reply = cast(void*) data;
    pthread_cond_signal(&ctx.cv);
    pthread_mutex_unlock(&ctx.lock);
}

// For benchmarking purposes.
long get_time_ms()
{
    timeval tv = void;
    gettimeofday(&tv, null);
    return ((cast(long) tv.tv_sec) * 1000) + (tv.tv_usec / 1000);
}

void main()
{
    tb_client_t client = void;
    tb_packet_t* packet = void;
    string address = "127.0.0.1:3000";
    TB_STATUS status = tb_client_init(
        &client,                    // Output client.
        cast(tb_uint128_t) 0,       // Cluster ID.
        address.ptr,                // Cluster addresses.
        cast(uint) address.length,  //
        1,                          // MaxConcurrency == 1, this is a single-threaded program
        0,                          // No need for a global context.
        &on_completion              // Completion callback.
        
    );

    if (status != TB_STATUS_SUCCESS)
    {
        printf("Failed to initialize tb_client\n");
        exit(-1);
    }

    // Initializing the mutex and condvar
    completion_context_t ctx = void;

    if (pthread_mutex_init(&ctx.lock, null) != 0)
    {
        printf("Failed to initialize mutex\n");
        exit(-1);
    }

    if (pthread_cond_init(&ctx.cv, null))
    {
        printf("Failed to initialize condition\n");
        exit(-1);
    }

    pthread_mutex_lock(&ctx.lock);

    const(int) SAMPLES = 10_00_000;
    const(int) BATCH_SIZE = 8190;

    // Repeat the same test 10 times and pick the best execution
    for (int tries = 0; tries < 10; tries++)
    {

        c_long max_latency_ms = 0;
        c_long total_time_ms = 0;

        for (int i = 0; i < SAMPLES; i += BATCH_SIZE)
        {

            tb_transfer_t[BATCH_SIZE] batch = void;
            memset(&batch, 0, BATCH_SIZE);

            for (int j = 0; (j < BATCH_SIZE) && (i + j < SAMPLES); j++)
            {
                batch[j].id = cast(tb_uint128_t) 0;
                batch[j].debit_account_id = cast(tb_uint128_t) 0;
                batch[j].credit_account_id = cast(tb_uint128_t) 0;
                batch[j].code = 1;
                batch[j].ledger = 1;
                batch[j].amount = cast(tb_uint128_t) 10;
            }

            // Acquiring a packet for this request:
            if (tb_client_acquire_packet(client, &packet) != TB_PACKET_ACQUIRE_OK)
            {
                printf("Too many concurrent packets\n");
                exit(-1);
            }

            packet.operation =
                TB_OPERATION_CREATE_TRANSFERS; // The operation to be performed.
            packet.data = &batch; // The data to be sent.
            packet.data_size = BATCH_SIZE * tb_transfer_t.sizeof;
            packet.user_data = &ctx; // User-defined context.
            packet.status = TB_PACKET_OK; // Will be set when the reply arrives.

            long now = get_time_ms();

            tb_client_submit(client, packet);
            pthread_cond_wait(&ctx.cv, &ctx.lock);

            c_long elapsed_ms = get_time_ms() - now;

            if (elapsed_ms > max_latency_ms)
                max_latency_ms = elapsed_ms;
            total_time_ms += elapsed_ms;

            if (packet.status != TB_PACKET_OK)
            {
                // Checking if the request failed:
                printf("Error calling create_transfers (ret=%d)\n", packet.status);
                exit(-1);
            }

            // Releasing the packet, so it can be used in a next request.
            tb_client_release_packet(client, packet);

            // Since we are using invalid IDs,
            // it is expected to all transfers to be rejected.
            tb_create_transfers_result_t* results = cast(tb_create_transfers_result_t*) ctx.reply;
            auto results_len = ctx.size / tb_create_transfers_result_t.sizeof;
            if (results_len != BATCH_SIZE)
            {
                printf("Unexpected result %d\n", i);
                exit(-1);
            }
        }

        printf("Total time: %ld ms\n", total_time_ms);
        printf("Max time per batch: %ld ms\n", max_latency_ms);
        printf("Transfers per second: %ld\n", SAMPLES * 1000 / total_time_ms);
        printf("\n");
    }

    // Cleanup
    pthread_mutex_unlock(&ctx.lock);
    pthread_cond_destroy(&ctx.cv);
    pthread_mutex_destroy(&ctx.lock);
    tb_client_deinit(client);
}
