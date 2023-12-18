#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <tb_client.h>

// Synchronization context between the callback and the main thread.
typedef struct completion_context {
  void *reply;
  int size;
  pthread_mutex_t lock;
  pthread_cond_t cv;

} completion_context_t;

// Completion function, called by tb_client no notify that a request as
// completed.
void on_completion(uintptr_t context, tb_client_t client, tb_packet_t *packet,
                   const uint8_t *data, uint32_t size) {

  // The user_data gives context to a request:
  completion_context_t *ctx = (completion_context_t *)packet->user_data;

  // Signaling the main thread we received the reply:
  pthread_mutex_lock(&ctx->lock);
  ctx->size = size;
  ctx->reply = (void *)data;
  pthread_cond_signal(&ctx->cv);
  pthread_mutex_unlock(&ctx->lock);
}

// For benchmarking purposes.
long long get_time_ms(void) {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return (((long long)tv.tv_sec) * 1000) + (tv.tv_usec / 1000);
}

int main(int argc, char **argv) {
  tb_client_t client;
  tb_packet_t *packet;
  const char *address = "127.0.0.1:3000";
  TB_STATUS status = tb_client_init(
      &client,         // Output client.
      0,               // Cluster ID.
      address,         // Cluster addresses.
      strlen(address), //
      1,               // MaxConcurrency == 1, this is a single-threaded program
      0,            // No need for a global context.
      &on_completion   // Completion callback.
  );

  if (status != TB_STATUS_SUCCESS) {
    printf("Failed to initialize tb_client\n");
    exit(-1);
  }

  // Initializing the mutex and condvar
  completion_context_t ctx;

  if (pthread_mutex_init(&ctx.lock, NULL) != 0) {
    printf("Failed to initialize mutex\n");
    exit(-1);
  }

  if (pthread_cond_init(&ctx.cv, NULL)) {
    printf("Failed to initialize condition\n");
    exit(-1);
  }

  pthread_mutex_lock(&ctx.lock);

  const int SAMPLES = 1000000;
  const int BATCH_SIZE = 8190;

  // Repeat the same test 10 times and pick the best execution
  for (int tries = 0; tries < 10; tries++) {

    long max_latency_ms = 0;
    long total_time_ms = 0;

    for (int i = 0; i < SAMPLES; i += BATCH_SIZE) {

      tb_transfer_t batch[BATCH_SIZE];
      memset(&batch, 0, BATCH_SIZE);

      for (int j = 0; (j < BATCH_SIZE) && (i + j < SAMPLES); j++) {
        batch[j].id = 0;
        batch[j].debit_account_id = 0;
        batch[j].credit_account_id = 0;
        batch[j].code = 1;
        batch[j].ledger = 1;
        batch[j].amount = 10;
      }

      // Acquiring a packet for this request:
      if (tb_client_acquire_packet(client, &packet) != TB_PACKET_ACQUIRE_OK) {
        printf("Too many concurrent packets\n");
        exit(-1);
      }

      packet->operation =
          TB_OPERATION_CREATE_TRANSFERS; // The operation to be performed.
      packet->data = &batch;             // The data to be sent.
      packet->data_size = BATCH_SIZE * sizeof(tb_transfer_t);
      packet->user_data = &ctx;      // User-defined context.
      packet->status = TB_PACKET_OK; // Will be set when the reply arrives.

      long long now = get_time_ms();

      tb_client_submit(client, packet);
      pthread_cond_wait(&ctx.cv, &ctx.lock);

      long elapsed_ms = get_time_ms() - now;

      if (elapsed_ms > max_latency_ms)
        max_latency_ms = elapsed_ms;
      total_time_ms += elapsed_ms;

      if (packet->status != TB_PACKET_OK) {
        // Checking if the request failed:
        printf("Error calling create_transfers (ret=%d)\n", packet->status);
        exit(-1);
      }

      // Releasing the packet, so it can be used in a next request.
      tb_client_release_packet(client, packet);

      // Since we are using invalid IDs,
      // it is expected to all transfers to be rejected.
      tb_create_transfers_result_t *results =
          (tb_create_transfers_result_t *)ctx.reply;
      int results_len = ctx.size / sizeof(tb_create_transfers_result_t);
      if (results_len != BATCH_SIZE) {
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