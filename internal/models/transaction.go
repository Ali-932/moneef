package models

import (
	"goMangaObserver/pkg/types"
	"gorm.io/gorm"
	"time"
)

type Transaction struct {
	gorm.Model
	ProfileID           uint         `gorm:"not null;index"`
	Name                string       `gorm:"type:varchar(255);not null"`
	Date                time.Time    `gorm:"not null"`
	Amount              *types.Money `gorm:"not null"`
	Currency            string       `gorm:"not null; type:varchar(10);"`
	Icon                string       `gorm:"type:varchar(10);"`
	Color               string       `gorm:"type:varchar(255);"`
	MerchantName        *string      `gorm:"type:varchar(255);"`
	Notes               *string      `gorm:"type:varchar(255);"`
	IsRecurrent         *bool
	RecurrentFreq       *string `gorm:"type:varchar(255);"`
	RecurrentType       *string `gorm:"type:varchar(255);"`
	IsActiveRecurrent   *bool
	RecurrentAmountPaid *types.Money
	RecurrentStartDate  *time.Time
	RecurrentHasEndDate *bool
	RecurrentEndDate    *time.Time
	CategoryID          *uint
}
