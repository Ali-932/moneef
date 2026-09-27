//go:build android || smoke

package mobile

import (
	"archive/zip"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"moneef/internal/config"
)

const backupLimit = 256 << 20

type backupManifest struct {
	Format           string `json:"format"`
	Version          int    `json:"version"`
	CreatedAt        string `json:"created_at"`
	ProfileID        int64  `json:"profile_id"`
	TransactionCount int64  `json:"transaction_count"`
	SHA256           string `json:"database_sha256"`
}

// ActiveProfileID also recovers the selection embedded in a restored database.
// Android serializes all exported calls on one worker, including backups.
func ActiveProfileID() int64 {
	stateMu.RLock()
	defer stateMu.RUnlock()
	return profileID
}

// CreateBackup exports a consistent live SQLite snapshot, including WAL writes.
// The caller publishes the archive to shared storage only after this succeeds.
func CreateBackup(path string) (result []byte, err error) {
	id, err := getProfileID()
	if err != nil {
		return nil, err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), "snapshot-*.sqlite")
	if err != nil {
		return nil, err
	}
	snapshot := tmp.Name()
	tmp.Close()
	defer removeSQLite(snapshot)
	if err = dbHandle.Exec("VACUUM INTO ?", snapshot).Error; err != nil {
		return nil, err
	}
	stat, err := os.Stat(snapshot)
	if err != nil {
		return nil, err
	}
	if stat.Size() > backupLimit {
		return nil, errors.New("database exceeds the 256 MB backup limit")
	}
	file, err := os.Open(snapshot)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	h := sha256.New()
	if _, err = io.Copy(h, file); err != nil {
		return nil, err
	}
	if _, err = file.Seek(0, 0); err != nil {
		return nil, err
	}
	m := backupManifest{Format: "moneef-local-backup", Version: 1, CreatedAt: time.Now().UTC().Format(time.RFC3339Nano), ProfileID: int64(id), SHA256: hex.EncodeToString(h.Sum(nil))}
	if err = dbHandle.Raw("SELECT count(*) FROM transactions WHERE profile_id = ?", id).Scan(&m.TransactionCount).Error; err != nil {
		return nil, err
	}
	result, err = json.Marshal(m)
	if err != nil {
		return nil, err
	}
	out, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return nil, err
	}
	defer func() {
		out.Close()
		if err != nil {
			os.Remove(path)
		}
	}()
	w := zip.NewWriter(out)
	entry, err := w.Create("manifest.json")
	if err != nil {
		return nil, err
	}
	if _, err = entry.Write(result); err != nil {
		return nil, err
	}
	entry, err = w.Create("database.sqlite")
	if err != nil {
		return nil, err
	}
	if _, err = io.Copy(entry, file); err != nil {
		return nil, err
	}
	if err = w.Close(); err != nil {
		return nil, err
	}
	if err = out.Sync(); err != nil {
		return nil, err
	}
	return result, nil
}

// RestoreBackup validates the entire archive before touching the current data.
// A durable rollback file makes interrupted replacements recoverable at Init.
func RestoreBackup(path string) ([]byte, error) {
	if err := requireInit(); err != nil {
		return nil, err
	}
	live := config.GetConfig().DBPath
	candidate, m, err := validateBackup(path, filepath.Dir(live))
	if err != nil {
		return nil, fmt.Errorf("Cannot restore backup: %w", err)
	}
	defer removeSQLite(candidate)
	oldID := ActiveProfileID()
	if err = Shutdown(); err != nil {
		return nil, err
	}
	rollback := live + ".restore-rollback"
	if err = os.Rename(live, rollback); err != nil {
		_ = Init(live, oldID)
		return nil, err
	}
	if err = syncDirectory(live); err != nil {
		_ = recoverInterruptedRestore(live)
		_ = Init(live, oldID)
		return nil, err
	}
	// Closing SQLite checkpoints its WAL; do not let old sidecars follow the
	// replacement database, even when a previous process exited unexpectedly.
	os.Remove(live + "-wal")
	os.Remove(live + "-shm")
	if err = os.Rename(candidate, live); err == nil {
		err = syncDirectory(live)
	}
	if err == nil {
		// Skip crash recovery for this deliberate, in-process trial open.
		err = initDatabase(live, m.ProfileID)
	}
	if err != nil {
		_ = Shutdown()
		if recovery := recoverInterruptedRestore(live); recovery != nil {
			return nil, fmt.Errorf("restore failed: %v; recovery failed: %w", err, recovery)
		}
		if reopen := Init(live, oldID); reopen != nil {
			return nil, fmt.Errorf("restore failed: %v; reopen failed: %w", err, reopen)
		}
		return nil, err
	}
	if err = os.Remove(rollback); err != nil {
		return nil, err
	}
	if err = syncDirectory(live); err != nil {
		return nil, err
	}
	return json.Marshal(m)
}

func validateBackup(path, dir string) (candidate string, m backupManifest, err error) {
	z, err := zip.OpenReader(path)
	if err != nil {
		return "", m, errors.New("this file is not a Moneef backup")
	}
	defer z.Close()
	if len(z.File) != 2 || z.File[0].Name != "manifest.json" || z.File[1].Name != "database.sqlite" {
		return "", m, errors.New("unexpected backup contents")
	}
	manifest, err := z.File[0].Open()
	if err != nil {
		return "", m, err
	}
	defer manifest.Close()
	data, err := io.ReadAll(io.LimitReader(manifest, 16<<10))
	if err != nil {
		return "", m, err
	}
	if err = json.Unmarshal(data, &m); err != nil {
		return "", m, err
	}
	if m.Format != "moneef-local-backup" || m.Version != 1 || m.ProfileID <= 0 {
		return "", m, errors.New("unsupported backup version or profile")
	}
	if _, err = time.Parse(time.RFC3339Nano, m.CreatedAt); err != nil {
		return "", m, errors.New("invalid backup date")
	}
	if z.File[1].UncompressedSize64 > backupLimit {
		return "", m, errors.New("backup exceeds 256 MB")
	}
	source, err := z.File[1].Open()
	if err != nil {
		return "", m, err
	}
	defer source.Close()
	tmp, err := os.CreateTemp(dir, "restore-*.sqlite")
	if err != nil {
		return "", m, err
	}
	candidate = tmp.Name()
	defer func() {
		tmp.Close()
		if err != nil {
			removeSQLite(candidate)
		}
	}()
	h := sha256.New()
	n, err := io.Copy(io.MultiWriter(tmp, h), io.LimitReader(source, backupLimit+1))
	if err != nil {
		return candidate, m, err
	}
	if n > backupLimit || hex.EncodeToString(h.Sum(nil)) != m.SHA256 {
		return candidate, m, errors.New("backup is incomplete or damaged")
	}
	if err = tmp.Close(); err != nil {
		return candidate, m, err
	}
	conn, err := sql.Open("sqlite", candidate)
	if err != nil {
		return candidate, m, err
	}
	defer conn.Close()
	conn.SetMaxOpenConns(1)
	var integrity string
	if err = conn.QueryRow("PRAGMA integrity_check").Scan(&integrity); err != nil {
		return candidate, m, err
	}
	if integrity != "ok" {
		return candidate, m, errors.New("database integrity check failed")
	}
	var count int64
	if err = conn.QueryRow("SELECT count(*) FROM profiles p JOIN users u ON p.user_id = u.id JOIN user_settings s ON s.user_id = u.id WHERE p.id = ?", m.ProfileID).Scan(&count); err != nil {
		return candidate, m, err
	}
	if count != 1 {
		return candidate, m, errors.New("backup profile or settings are missing")
	}
	if err = conn.QueryRow("SELECT count(*) FROM transactions WHERE profile_id = ?", m.ProfileID).Scan(&count); err != nil {
		return candidate, m, err
	}
	if count != m.TransactionCount {
		return candidate, m, errors.New("transaction count does not match backup")
	}
	// Persist the profile in the database itself. A process death after commit
	// but before Flutter saves its preferences must not select a fresh profile.
	if _, err = conn.Exec("CREATE TABLE IF NOT EXISTS moneef_backup_profile (id INTEGER PRIMARY KEY CHECK(id=1), profile_id INTEGER NOT NULL)"); err != nil {
		return candidate, m, err
	}
	if _, err = conn.Exec("INSERT OR REPLACE INTO moneef_backup_profile VALUES (1, ?)", m.ProfileID); err != nil {
		return candidate, m, err
	}
	if err = conn.Close(); err != nil {
		return candidate, m, err
	}
	f, err := os.OpenFile(candidate, os.O_RDWR, 0600)
	if err != nil {
		return candidate, m, err
	}
	err = f.Sync()
	f.Close()
	return candidate, m, err
}

func removeSQLite(path string) {
	for _, suffix := range []string{"", "-wal", "-shm", "-journal"} {
		_ = os.Remove(path + suffix)
	}
}

func syncDirectory(path string) error {
	d, err := os.Open(filepath.Dir(path))
	if err != nil {
		return err
	}
	defer d.Close()
	return d.Sync()
}

func recoverInterruptedRestore(path string) error {
	rollback := path + ".restore-rollback"
	if _, err := os.Stat(rollback); errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil {
		return err
	}
	removeSQLite(path)
	if err := os.Rename(rollback, path); err != nil {
		return err
	}
	return syncDirectory(path)
}
