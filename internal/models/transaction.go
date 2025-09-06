package models

import (
	"gorm.io/gorm"
	"moneef/pkg/types"
	"time"
)

type Transaction struct {
	gorm.Model
	ProfileID            uint                  `gorm:"not null;index"`
	Name                 string                `gorm:"type:varchar(255);not null"`
	Type                 string                `gorm:"type:varchar(255);not null;check:type IN ('income', 'expense')"`
	Date                 time.Time             `gorm:"not null"`
	CurrencyCode         string                `gorm:"type:char(3);not null;index"`
	Currency             *Currency             `gorm:"foreignKey:CurrencyCode;references:Code"`
	Icon                 string                `gorm:"type:varchar(10);"`
	Color                string                `gorm:"type:varchar(255);"`
	MerchantName         *string               `gorm:"type:varchar(255);"`
	Notes                *string               `gorm:"type:varchar(255);"`
	TransactionCategory  []TransactionCategory `gorm:"foreignKey:TransactionID"`
	RecurrenceTemplateID *uint                 `gorm:"index"`
	RecurrenceTemplate   *RecurrenceTemplate   `gorm:"foreignKey:RecurrenceTemplateID"`
}
type TransactionCategory struct {
	gorm.Model
	TransactionID uint         `gorm:"not null"`
	CategoryID    uint         `gorm:"not null;"`
	Category      Category     `gorm:"foreignKey:CategoryID;references:ID;constraint:OnDelete:CASCADE"`
	Amount        *types.Money `gorm:"type:decimal(10,2);not null"`

	Transaction Transaction `gorm:"foreignKey:TransactionID;references:ID;constraint:OnDelete:CASCADE"`
}

type RecurrenceTemplate struct {
	gorm.Model
	ProfileID            uint                         `gorm:"not null;index"`
	Name                 string                       `gorm:"type:varchar(255);not null"`
	Type                 string                       `gorm:"type:varchar(255);not null;check:type IN ('income', 'expense')"`
	CurrencyCode         string                       `gorm:"type:char(3);not null;index"`
	Currency             *Currency                    `gorm:"foreignKey:CurrencyCode;references:Code"`
	Icon                 string                       `gorm:"type:varchar(10);"`
	Color                string                       `gorm:"type:varchar(255);"`
	MerchantName         *string                      `gorm:"type:varchar(255);"`
	Notes                *string                      `gorm:"type:varchar(255);"`
	TransactionCategory  []RecurrenceTemplateCategory `gorm:"foreignKey:RecurrenceTemplateID"`
	Frequency            string                       `gorm:"type:varchar(255);not null;check:frequency IN ('daily', 'weekly', 'bi-weekly', 'monthly', 'yearly')"`
	NextDate             time.Time                    `gorm:"not null"`
	NextPaymentAmount    *types.Money                 `gorm:"type:decimal(19,4);not null"`
	AmountPaidPreviously *types.Money                 `gorm:"type:decimal(19,4);not null;default:0"`
	AmountLeftToPay      *types.Money                 `gorm:"type:decimal(19,4)"`
	TotalAmountToPay     *types.Money                 `gorm:"type:decimal(19,4)"`
	EndDate              *time.Time
	StartDate            *time.Time
	HasEndDate           bool          `gorm:"default:false"`
	IsActive             bool          `gorm:"default:true"`
	Transactions         []Transaction `gorm:"foreignKey:RecurrenceTemplateID"`
}

type RecurrenceTemplateCategory struct {
	gorm.Model
	RecurrenceTemplateID uint               `gorm:"not null"`
	CategoryID           uint               `gorm:"not null;"`
	Category             Category           `gorm:"foreignKey:CategoryID;;constraint:OnDelete:CASCADE"`
	Amount               *types.Money       `gorm:"type:decimal(10,2);not null"`
	RecurrenceTemplate   RecurrenceTemplate `gorm:"foreignKey:RecurrenceTemplateID;references:ID;constraint:OnDelete:CASCADE"`
}
