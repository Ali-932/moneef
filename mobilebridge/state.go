//go:build android || smoke

package mobilebridge

import (
	"sync"

	"gorm.io/gorm"
)

var (
	stateMu     sync.RWMutex
	initialized bool
	profileID   int64
	dbHandle    *gorm.DB
)

func setInitialized(db *gorm.DB) {
	stateMu.Lock()
	defer stateMu.Unlock()
	initialized = true
	dbHandle = db
}

func clearInitialized() {
	stateMu.Lock()
	defer stateMu.Unlock()
	initialized = false
	dbHandle = nil
	profileID = 0
}

func requireInit() error {
	stateMu.RLock()
	defer stateMu.RUnlock()
	if !initialized {
		return ErrNotInitialized
	}
	return nil
}

func setProfileIDLocked(id int64) {
	stateMu.Lock()
	defer stateMu.Unlock()
	profileID = id
}

func getProfileID() (uint, error) {
	stateMu.RLock()
	defer stateMu.RUnlock()
	if !initialized {
		return 0, ErrNotInitialized
	}
	if profileID <= 0 {
		return 0, ErrProfileNotSet
	}
	return uint(profileID), nil
}
