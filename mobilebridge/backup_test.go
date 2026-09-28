//go:build smoke

package mobilebridge

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestBackupRoundTripAndRecovery(t *testing.T) {
	dir := t.TempDir()
	live := filepath.Join(dir, "live.sqlite")
	must := func(err error) {
		t.Helper()
		if err != nil {
			t.Fatal(err)
		}
	}
	must(Init(live, 0))
	t.Cleanup(func() { _ = Shutdown() })
	_, err := Setup([]byte(`{"first_name":"Before","last_name":"Backup","currency_code":"USD","language":"en"}`))
	must(err)
	// A non-default profile proves restore never assumes profile 1.
	must(dbHandle.Exec("UPDATE profiles SET id = 42").Error)
	must(SetProfileID(42))
	category, err := CreateCategory([]byte(`{"name":"Offline test","type":"expense","icon":"mdi:coffee","color":"#7B3F00"}`))
	must(err)
	var cat struct {
		ID int64 `json:"id"`
	}
	must(json.Unmarshal(category, &cat))
	tx, _ := json.Marshal(map[string]any{
		"transaction_name": "Offline purchase", "currency_code": "USD", "transaction_type": "expense",
		"date":                   time.Now().UTC().Format(time.RFC3339),
		"transaction_categories": []map[string]any{{"category_id": cat.ID, "amount": "640000.75"}},
	})
	_, err = CreateTransaction(tx)
	must(err)
	must(UpdateSettings([]byte(`{"is_dark_mode":true}`)))
	before, err := ListTransactions([]byte(`{}`))
	must(err)
	profile, err := GetProfile()
	must(err)
	settings, err := GetSettings()
	must(err)
	dashboard, err := Dashboard([]byte(`{}`))
	must(err)
	backup := filepath.Join(dir, "good.moneefbackup")
	metadata, err := CreateBackup(backup)
	must(err)
	var info backupManifest
	must(json.Unmarshal(metadata, &info))
	if info.ProfileID != 42 || info.TransactionCount != 1 {
		t.Fatalf("bad manifest: %s", metadata)
	}
	if _, err := CreateBackup(backup); err == nil {
		t.Fatal("overwrote an existing archive")
	}
	_, err = CreateTransaction(tx)
	must(err)
	must(UpdateProfile([]byte(`{"first_name":"Changed","last_name":"Later"}`)))
	must(UpdateSettings([]byte(`{"is_dark_mode":false}`)))
	changed, err := ListTransactions([]byte(`{}`))
	must(err)

	t.Run("invalid archives leave working database intact", func(t *testing.T) {
		for _, mode := range []string{"truncated", "checksum", "version", "profile", "count", "extra-entry"} {
			t.Run(mode, func(t *testing.T) {
				bad := filepath.Join(dir, mode+".zip")
				data, e := os.ReadFile(backup)
				must(e)
				if mode == "truncated" {
					must(os.WriteFile(bad, data[:len(data)/2], 0600))
				} else {
					reader, e := zip.NewReader(bytes.NewReader(data), int64(len(data)))
					must(e)
					out, e := os.Create(bad)
					must(e)
					writer := zip.NewWriter(out)
					for _, f := range reader.File {
						r, e := f.Open()
						must(e)
						body, e := io.ReadAll(r)
						must(e)
						r.Close()
						if f.Name == "manifest.json" {
							var m backupManifest
							must(json.Unmarshal(body, &m))
							switch mode {
							case "checksum":
								m.SHA256 = strings.Repeat("0", 64)
							case "version":
								m.Version = 99
							case "profile":
								m.ProfileID = 999
							case "count":
								m.TransactionCount = 999
							}
							body, e = json.Marshal(m)
							must(e)
						}
						w, e := writer.Create(f.Name)
						must(e)
						_, e = w.Write(body)
						must(e)
					}
					if mode == "extra-entry" {
						_, e = writer.Create("../escape")
						must(e)
					}
					must(writer.Close())
					must(out.Close())
				}
				if _, e := RestoreBackup(bad); e == nil {
					t.Fatal("accepted invalid backup")
				}
				after, e := ListTransactions([]byte(`{}`))
				must(e)
				if !bytes.Equal(after, changed) {
					t.Fatal("invalid restore changed transactions")
				}
				if ActiveProfileID() != 42 {
					t.Fatal("lost active profile on failed restore")
				}
			})
		}
	})

	t.Run("round trip restores data settings and metrics", func(t *testing.T) {
		_, e := RestoreBackup(backup)
		must(e)
		for _, check := range []struct {
			name string
			want []byte
			read func() ([]byte, error)
		}{
			{"transactions", before, func() ([]byte, error) { return ListTransactions([]byte(`{}`)) }},
			{"profile", profile, GetProfile}, {"settings", settings, GetSettings},
			{"dashboard", dashboard, func() ([]byte, error) { return Dashboard([]byte(`{}`)) }},
		} {
			got, e := check.read()
			must(e)
			if !bytes.Equal(got, check.want) {
				t.Errorf("%s changed across restore:\n%s\n%s", check.name, check.want, got)
			}
		}
		must(Shutdown())
		must(Init(live, 0)) // preferences lost on uninstall, or before restore commit
		if ActiveProfileID() != 42 {
			t.Fatal("restored profile not recovered without preferences")
		}
	})

	t.Run("interrupted replacement rolls back on boot", func(t *testing.T) {
		must(Shutdown())
		must(os.Rename(live, live+".restore-rollback"))
		must(os.WriteFile(live, []byte("partial replacement"), 0600))
		must(Init(live, 0))
		after, e := ListTransactions([]byte(`{}`))
		must(e)
		if !bytes.Equal(after, before) {
			t.Fatal("interrupted restore lost original data")
		}
		if _, e := os.Stat(live + ".restore-rollback"); !os.IsNotExist(e) {
			t.Fatal("rollback not completed")
		}
	})
	t.Run("snapshot can be restored into an empty fresh install", func(t *testing.T) {
		must(Shutdown())
		removeSQLite(live)
		must(Init(live, 0))
		_, e := RestoreBackup(backup)
		must(e)
		got, e := ListTransactions([]byte(`{}`))
		must(e)
		if !bytes.Equal(got, before) || ActiveProfileID() != 42 {
			t.Fatal("fresh install restore lost data or profile")
		}
	})
}
