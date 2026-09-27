//go:build android || smoke

package mobile

import (
	"fmt"
	"os"

	"gorm.io/gorm"

	"moneef/internal/config"
	"moneef/internal/currencies"
	"moneef/internal/db"
	"moneef/internal/iconlookup"
	"moneef/internal/transactions/engine"
)

// Init opens the SQLite database at dbPath, runs migrations, seeds missing
// icon keywords, refreshes automatic icons, and stores the active profile id.
// profileID may be 0 when
// called from a first-run flow where Setup will return a freshly-minted id;
// in that case the caller must invoke SetProfileID once Setup has returned.
//
// Init is idempotent only in the sense that calling it twice without
// Shutdown returns ErrAlreadyInited — re-binding to a different database
// path is intentionally forbidden in-process.
func Init(dbPath string, profileIDArg int64) error {
	if err := requireInit(); err == nil {
		return ErrAlreadyInited
	}
	if err := recoverInterruptedRestore(dbPath); err != nil {
		return err
	}
	return initDatabase(dbPath, profileIDArg)
}

func initDatabase(dbPath string, profileIDArg int64) error {
	stateMu.RLock()
	already := initialized
	stateMu.RUnlock()
	if already {
		return ErrAlreadyInited
	}

	if dbPath == "" {
		return fmt.Errorf("mobile.Init: dbPath must not be empty")
	}

	// config.GetConfig is a sync.Once singleton; seed db_path through env so
	// the first call inside db.Connect picks up the dbPath the Flutter side
	// passed in.
	if err := os.Setenv("db_path", dbPath); err != nil {
		return fmt.Errorf("mobile.Init: cannot set db_path env: %w", err)
	}
	cfg := config.GetConfig()
	if cfg.DBPath != dbPath {
		return fmt.Errorf("mobile.Init: config was already initialized with a different db path (%q != %q); restart the process to switch databases", cfg.DBPath, dbPath)
	}

	database, err := db.Connect()
	if err != nil {
		return fmt.Errorf("mobile.Init: db connect: %w", err)
	}
	// Failed migrations must release the candidate before rollback replaces it.
	succeeded := false
	defer func() {
		if !succeeded {
			if conn, e := database.DB(); e == nil {
				_ = conn.Close()
			}
		}
	}()
	if err := db.MigrateModels(database); err != nil {
		return fmt.Errorf("mobile.Init: migrate: %w", err)
	}
	if err := database.Transaction(func(tx *gorm.DB) error {
		seededIcons, err := iconlookup.SeedDefaults(tx)
		if err != nil {
			return fmt.Errorf("seed merchant icons: %w", err)
		}
		if err := iconlookup.LoadCache(tx); err != nil {
			return fmt.Errorf("icon cache: %w", err)
		}
		// Classify legacy fallback icons before refreshing built-in categories.
		// New dictionary entries can also improve previously automatic icons.
		return engine.RefreshStoredTransactionIcons(tx, seededIcons > 0)
	}); err != nil {
		return fmt.Errorf("mobile.Init: prepare icons: %w", err)
	}
	if err := seedDefaultCategories(database); err != nil {
		return fmt.Errorf("mobile.Init: seed default categories: %w", err)
	}
	if err := currencies.SeedCurrencies(database); err != nil {
		return fmt.Errorf("mobile.Init: seed currencies: %w", err)
	}

	if database.Migrator().HasTable("moneef_backup_profile") {
		var restoredID int64
		if err := database.Raw("SELECT profile_id FROM moneef_backup_profile WHERE id = 1").Scan(&restoredID).Error; err != nil {
			return err
		}
		if restoredID > 0 {
			profileIDArg = restoredID
		}
	}
	setInitialized(database)
	succeeded = true
	if profileIDArg > 0 {
		setProfileIDLocked(profileIDArg)
	}
	return nil
}

// SetProfileID updates the active profile id without re-opening the database.
// Returns ErrNotInitialized if Init has not been called.
func SetProfileID(id int64) error {
	if err := requireInit(); err != nil {
		return err
	}
	if id <= 0 {
		return fmt.Errorf("mobile.SetProfileID: id must be > 0, got %d", id)
	}
	if err := dbHandle.Exec("CREATE TABLE IF NOT EXISTS moneef_backup_profile (id INTEGER PRIMARY KEY CHECK(id=1), profile_id INTEGER NOT NULL)").Error; err != nil {
		return err
	}
	if err := dbHandle.Exec("INSERT OR REPLACE INTO moneef_backup_profile VALUES (1, ?)", id).Error; err != nil {
		return err
	}
	setProfileIDLocked(id)
	return nil
}

// Shutdown closes the underlying *sql.DB connection and clears the active
// profile id. Safe to call before exit; calling without Init is a no-op.
func Shutdown() error {
	stateMu.RLock()
	wasInit := initialized
	cur := dbHandle
	stateMu.RUnlock()
	if !wasInit || cur == nil {
		return nil
	}
	sqlDB, err := cur.DB()
	if err != nil {
		clearInitialized()
		return fmt.Errorf("mobile.Shutdown: get *sql.DB: %w", err)
	}
	if err := sqlDB.Close(); err != nil {
		clearInitialized()
		return fmt.Errorf("mobile.Shutdown: close: %w", err)
	}
	clearInitialized()
	return nil
}
