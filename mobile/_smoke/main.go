//go:build smoke

// Smoke driver for the mobile package. Runs the real shim against a temp
// SQLite file on the host (Linux/macOS), exercising Init → Setup →
// CreateTransaction → ListTransactions → GetTransaction → Dashboard. This is
// the closest substitute for "load .aar in spike Android app and call it"
// when no Android device is available — it does not test JNI marshaling, but
// it does verify the exact JSON contract every Flutter call will see.
//
// Run with:
//
//	go run -tags=smoke ./mobile/_smoke/
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"moneef/mobile"
)

func main() {
	tmpDir, err := os.MkdirTemp("", "moneef-smoke-*")
	must(err)
	defer os.RemoveAll(tmpDir)
	dbPath := filepath.Join(tmpDir, "smoke.sqlite")

	log.Printf("smoke: dbPath=%s", dbPath)

	must(mobile.Init(dbPath, 0))
	defer mobile.Shutdown()

	setupPayload := mustJSON(map[string]any{
		"first_name":    "Smoke",
		"last_name":     "Tester",
		"currency_code": "USD",
		"language":      "en",
	})
	setupResp, err := mobile.Setup(setupPayload)
	must(err)
	log.Printf("smoke: Setup → %s", setupResp)

	var setup struct {
		ProfileID int64 `json:"profile_id"`
	}
	must(json.Unmarshal(setupResp, &setup))
	if setup.ProfileID <= 0 {
		log.Fatalf("smoke: setup did not return a profile_id (got %d)", setup.ProfileID)
	}

	catPayload := mustJSON(map[string]any{
		"name":  "Coffee",
		"type":  "expense",
		"icon":  "mdi:coffee",
		"color": "#7B3F00",
	})
	catResp, err := mobile.CreateCategory(catPayload)
	must(err)
	log.Printf("smoke: CreateCategory → %s", catResp)

	var category struct {
		ID uint `json:"id"`
	}
	must(json.Unmarshal(catResp, &category))

	txnPayload := mustJSON(map[string]any{
		"transaction_name": "Morning latte",
		"currency_code":    "USD",
		"transaction_type": "expense",
		"date":             time.Now().UTC().Format(time.RFC3339),
		"icon":             "mdi:coffee",
		"color":            "#7B3F00",
		"transaction_categories": []map[string]any{
			{"category_id": category.ID, "amount": "4.50"},
		},
	})
	createResp, err := mobile.CreateTransaction(txnPayload)
	must(err)
	log.Printf("smoke: CreateTransaction → %s", createResp)

	listPayload := mustJSON(map[string]any{
		"page":     1,
		"per_page": 10,
	})
	listResp, err := mobile.ListTransactions(listPayload)
	must(err)
	log.Printf("smoke: ListTransactions → %s", listResp)

	var listed struct {
		Count   int64 `json:"count"`
		Results []struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"results"`
	}
	must(json.Unmarshal(listResp, &listed))
	if listed.Count != 1 {
		log.Fatalf("smoke: expected 1 transaction, got %d", listed.Count)
	}
	if len(listed.Results) != 1 || listed.Results[0].Name != "Morning latte" {
		log.Fatalf("smoke: unexpected list payload: %s", listResp)
	}

	getResp, err := mobile.GetTransaction(listed.Results[0].ID)
	must(err)
	log.Printf("smoke: GetTransaction → %s", getResp)

	dashResp, err := mobile.Dashboard([]byte("{}"))
	must(err)
	log.Printf("smoke: Dashboard → %s", dashResp)

	fmt.Println("smoke: OK")
}

func must(err error) {
	if err != nil {
		log.Fatalf("smoke: %v", err)
	}
}

func mustJSON(v any) []byte {
	b, err := json.Marshal(v)
	must(err)
	return b
}
