using System;
using System.Diagnostics;
using TigerBeetle;

public static class Program
{
    public static void Main()
    {
        using var client = new Client(0, new string[] { "127.0.0.1:3000" });

        const int SAMPLES = 1_000_000;
        const int BATCH_SIZE = 8191;
        
        var stopWatch = new Stopwatch();

        // Repeat the same test 10 times and pick the best execution
        for (int tries = 0; tries < 10; tries += 1) {

            long timeTotalMs = 0;
            long timeBatchMaxMs = 0;

            for (int i = 0; i < SAMPLES; i += BATCH_SIZE) {

                var batch = new Transfer[BATCH_SIZE];

                for (int j = 0; (j < BATCH_SIZE) && (i + j < SAMPLES); j++) {
                    batch[j].Id = 0;
                    batch[j].CreditAccountId = 0;
                    batch[j].DebitAccountId = 0;
                    batch[j].Code = 1;
                    batch[j].Ledger = 1;
                    batch[j].Amount = 10;
                }

                stopWatch.Restart();

                var transfersErrors = client.CreateTransfers(batch);
                stopWatch.Stop();
                
                timeTotalMs += stopWatch.ElapsedMilliseconds;
                if (stopWatch.ElapsedMilliseconds > timeBatchMaxMs) {
                    timeBatchMaxMs = stopWatch.ElapsedMilliseconds;
                }

                // Since we are using invalid IDs,
                // it is expected to all transfers to be rejected.
                if (transfersErrors.Length != batch.Length) {
                    Console.WriteLine("Unexpected result {0}", i);
                    return;
                }
            }

            Console.WriteLine($"Total time: {timeTotalMs} ms");
            Console.WriteLine($"Max time per batch: {timeBatchMaxMs} ms");
            Console.WriteLine($"Transfers per second: {SAMPLES * 1000 / timeTotalMs}\n");
        }
    }
}