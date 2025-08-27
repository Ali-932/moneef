package models

import (
	"gorm.io/gorm"
	"moneef/pkg/types"
	"time"
)

type Currency struct {
	Code   string `gorm:"primaryKey;type:char(3)"` // USD, EUR, etc.
	Name   string `gorm:"type:varchar(100)"`       // US Dollar, Euro
	Symbol string `gorm:"type:varchar(10)"`        // $, €, £
}

type Transaction struct {
	gorm.Model
	ProfileID            uint                `gorm:"not null;index"`
	Name                 string              `gorm:"type:varchar(255);not null"`
	Type                 string              `gorm:"type:varchar(255);not null;check:type IN ('income', 'expense')"`
	Date                 time.Time           `gorm:"not null"`
	Amount               *types.Money        `gorm:"type:decimal(19,4);not null"`
	CurrencyCode         string              `gorm:"type:char(3);not null;index"`
	Currency             *Currency           `gorm:"foreignKey:CurrencyCode;references:Code"`
	Icon                 string              `gorm:"type:varchar(10);"`
	Color                string              `gorm:"type:varchar(255);"`
	MerchantName         *string             `gorm:"type:varchar(255);"`
	Notes                *string             `gorm:"type:varchar(255);"`
	Category             []*Category         `gorm:"many2many:category_transaction;"`
	RecurrenceTemplateID *uint               `gorm:"index"`
	RecurrenceTemplate   *RecurrenceTemplate `gorm:"foreignKey:RecurrenceTemplateID"`
}

type RecurrenceTemplate struct {
	gorm.Model
	ProfileID            uint         `gorm:"not null;index"`
	Name                 string       `gorm:"type:varchar(255);not null"`
	Type                 string       `gorm:"type:varchar(255);not null;check:type IN ('income', 'expense')"`
	Amount               *types.Money `gorm:"type:decimal(19,4);not null"`
	CurrencyCode         string       `gorm:"type:char(3);not null;index"`
	Currency             *Currency    `gorm:"foreignKey:CurrencyCode;references:Code"`
	Icon                 string       `gorm:"type:varchar(10);"`
	Color                string       `gorm:"type:varchar(255);"`
	MerchantName         *string      `gorm:"type:varchar(255);"`
	Notes                *string      `gorm:"type:varchar(255);"`
	Frequency            string       `gorm:"type:varchar(255);not null;check:frequency IN ('daily', 'weekly', 'bi-weekly', 'monthly', 'yearly')"`
	NextDate             time.Time    `gorm:"not null"`
	NextPaymentAmount    *types.Money `gorm:"type:decimal(19,4);not null"`
	AmountPaidPreviously *types.Money `gorm:"type:decimal(19,4);not null;default:0"`
	AmountLeftToPay      *types.Money `gorm:"type:decimal(19,4)"`
	TotalAmountToPay     *types.Money `gorm:"type:decimal(19,4)"`
	EndDate              *time.Time
	StartDate            *time.Time
	HasEndDate           bool          `gorm:"default:false"`
	IsActive             bool          `gorm:"default:true"`
	Transactions         []Transaction `gorm:"foreignKey:RecurrenceTemplateID"`
}
