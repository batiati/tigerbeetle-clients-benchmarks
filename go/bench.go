package main

import (
	"fmt"
	"log"
	"time"

	tb "github.com/tigerbeetle/tigerbeetle-go"
	tb_types "github.com/tigerbeetle/tigerbeetle-go/pkg/types"
)

func uint128(value string) tb_types.Uint128 {
	x, err := tb_types.HexStringToUint128(value)
	if err != nil {
		panic(err)
	}
	return x
}

func main() {
	client, err := tb.NewClient(tb_types.ToUint128(0), []string{"3000"}, 1)
	if err != nil {
		log.Printf("Error creating client: %s", err)
		return
	}
	defer client.Close()

	SAMPLES := 1_000_000
	BATCH_SIZE := 8190

	// Repeat the same test 10 times and pick the best execution
	for tries := 0; tries < 10; tries += 1 {

		time_total_ms := int64(0)
		time_batch_max_ms := int64(0)
		batch := make([]tb_types.Transfer, BATCH_SIZE)
		for i := 0; i < SAMPLES; i += BATCH_SIZE {
			for j := 0; (j < BATCH_SIZE) && (i+j < SAMPLES); j++ {
				batch[j] = tb_types.Transfer{
					ID:              uint128("0"),
					DebitAccountID:  uint128("0"),
					CreditAccountID: uint128("0"),
					Ledger:          1,
					Code:            1,
					Amount:          tb_types.ToUint128(10),
				}
			}

			start := time.Now()
			res, err := client.CreateTransfers(batch)
			if err != nil {
				fmt.Printf("Error creating transfer batch %d: %s\n", i, err)
				return
			}

			elapsed := time.Since(start).Milliseconds()
			time_total_ms += elapsed
			if elapsed > time_batch_max_ms {
				time_batch_max_ms = elapsed
			}

			// Since we are using invalid IDs,
			// it is expected to all transfers to be rejected.
			if len(res) != len(batch) {
				fmt.Printf("Unexpected result %d\n", i)
				return
			}
		}

		fmt.Printf("Total time: %d ms\n", time_total_ms)
		fmt.Printf("Max time per batch: %d ms\n", time_batch_max_ms)
		fmt.Printf("Transfers per second: %d\n\n", int64(SAMPLES*1000)/time_total_ms)
	}
}
