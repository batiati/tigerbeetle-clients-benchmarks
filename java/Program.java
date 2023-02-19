import com.tigerbeetle.*;

public class Bench {

    public static void main(String[] args) {
        try (var client = new Client(0, new String[] {"127.0.0.1:3000"})) {

            final int SAMPLES = 1_000_000;
            final int BATCH_SIZE = 8191;

            // Repeat the same test 10 times and pick the best execution
            for (int tries = 0; tries < 10; tries += 1) {

                long timeTotalMs = 0;
                long timeBatchMaxMs = 0;

                for (int i = 0; i < SAMPLES; i += BATCH_SIZE) {

                    var batch = new TransferBatch(BATCH_SIZE);

                    for (int j = 0; (j < BATCH_SIZE) && (i + j < SAMPLES); j++) {

                        batch.add();
                        batch.setId(0, 0);
                        batch.setCreditAccountId(0, 0);
                        batch.setDebitAccountId(0, 0);
                        batch.setCode((short) 1);
                        batch.setLedger(1);
                        batch.setAmount(10);
                    }

                    var now = System.currentTimeMillis();

                    var transfersErrors = client.createTransfers(batch);
                    var elapsed = System.currentTimeMillis() - now;
                    timeTotalMs += elapsed;
                    if (elapsed > timeBatchMaxMs) {
                        timeBatchMaxMs = elapsed;
                    }

                    // Since we are using invalid IDs,
                    // it is expected to all transfers to be rejected.
                    if (transfersErrors.getLength() != batch.getLength()) {
                        System.err.printf("Unexpected result %d\n", i);
                        return;
                    }
                }

                System.out.printf("Total time: %d ms\n", timeTotalMs);
                System.out.printf("Max time per batch: %d ms\n", timeBatchMaxMs);
                System.out.printf("Transfers per second: %d\n\n", SAMPLES * 1000 / timeTotalMs);
            }

        } catch (Exception e) {
            System.out.println(e);
            e.printStackTrace();
        }
    }
}