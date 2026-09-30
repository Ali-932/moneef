package models

import (
	"moneef/pkg/types"
	"time"
)

// Account is a named place money lives (Cash, Bank, Savings). Any currency can be in it.
type Account struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	CreatedAt time.Time `json:"created_at"`
	ProfileID uint      `gorm:"not null;index" json:"profile_id"`
	Name      string    `gorm:"type:varchar(255);not null" json:"name"`
}

// Transfer moves money between accounts, or changes currency inside one.
// No FromAccountID means money from outside: a "set balance" adjustment,
// whose ToAmount may be negative.
type Transfer struct {
	ID            uint         `gorm:"primaryKey" json:"id"`
	CreatedAt     time.Time    `json:"created_at"`
	ProfileID     uint         `gorm:"not null;index" json:"profile_id"`
	Date          time.Time    `gorm:"not null" json:"date"`
	FromAccountID *uint        `gorm:"index" json:"from_account_id,omitempty"`
	FromCurrency  string       `gorm:"type:char(3)" json:"from_currency,omitempty"`
	FromAmount    *types.Money `gorm:"type:decimal(19,4)" json:"from_amount,omitempty"`
	ToAccountID   uint         `gorm:"not null;index" json:"to_account_id"`
	ToCurrency    string       `gorm:"type:char(3);not null" json:"to_currency"`
	ToAmount      *types.Money `gorm:"type:decimal(19,4);not null" json:"to_amount"`
}
