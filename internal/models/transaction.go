package models

import (
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
	"moneef/pkg/types"
	"time"
)

type Transaction struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
	ProfileID    uint      `gorm:"not null;index" json:"profile_id"`
	Name         string    `gorm:"type:varchar(255);not null" json:"name"`
	Type         string    `gorm:"type:varchar(255);not null;check:type IN ('income', 'expense')" json:"type"`
	Date         time.Time `gorm:"not null" json:"date"`
	CurrencyCode string    `gorm:"type:char(3);not null;index" json:"currency_code"`
	Currency     *Currency `gorm:"foreignKey:CurrencyCode;references:Code" json:"currency,omitempty"`
	Icon         string    `gorm:"type:varchar(255);" json:"icon"`
	Color        string    `gorm:"type:varchar(255);" json:"color"`
	// Empty sources identify legacy rows; automatic values may be refreshed.
	IconSource           string                `gorm:"type:varchar(16);not null;default:''" json:"-"`
	ColorSource          string                `gorm:"type:varchar(16);not null;default:''" json:"-"`
	MerchantName         *string               `gorm:"type:varchar(255);" json:"merchant_name,omitempty"`
	Notes                *string               `gorm:"type:varchar(255);" json:"notes,omitempty"`
	TransactionCategory  []TransactionCategory `gorm:"foreignKey:TransactionID" json:"TransactionCategory"`
	RecurrenceTemplateID *uint                 `gorm:"index" json:"recurrence_template_id,omitempty"`
	RecurrenceTemplate   *RecurrenceTemplate   `gorm:"foreignKey:RecurrenceTemplateID" json:"recurrence_template,omitempty"`
	// UsdRate is units of CurrencyCode per 1 USD, frozen from settings on save.
	// Nil for older rows; totals then use today's rate.
	UsdRate   *decimal.Decimal `gorm:"type:decimal(19,6)" json:"-"`
	AccountID *uint            `gorm:"index" json:"account_id,omitempty"`
}

func (t *Transaction) GetTotal(db *gorm.DB) (*types.Money, error) {
	if len(t.TransactionCategory) == 0 {
		if err := db.Preload("TransactionCategory").First(t, t.ID).Error; err != nil {
			return nil, err
		}
	}

	var total types.Money
	for _, tc := range t.TransactionCategory {
		if tc.Amount != nil {
			total = total.Add(*tc.Amount)
		}
	}

	return &total, nil
}

type TransactionCategory struct {
	ID            uint         `gorm:"primaryKey" json:"id"`
	CreatedAt     time.Time    `json:"created_at"`
	UpdatedAt     time.Time    `json:"updated_at"`
	TransactionID uint         `gorm:"not null;index" json:"transaction_id"`
	CategoryID    uint         `gorm:"not null;" json:"category_id"`
	Category      Category     `gorm:"foreignKey:CategoryID;references:ID;constraint:OnDelete:CASCADE" json:"Category"`
	Amount        *types.Money `gorm:"type:decimal(19,4);not null" json:"amount"`

	Transaction Transaction `gorm:"foreignKey:TransactionID;references:ID;constraint:OnDelete:CASCADE" json:"transaction,omitempty"`
}

type RecurrenceTemplate struct {
	ID                   uint                         `gorm:"primaryKey" json:"id"`
	CreatedAt            time.Time                    `json:"created_at"`
	UpdatedAt            time.Time                    `json:"updated_at"`
	ProfileID            uint                         `gorm:"not null;index" json:"profile_id"`
	Name                 string                       `gorm:"type:varchar(255);not null" json:"name"`
	Type                 string                       `gorm:"type:varchar(255);not null;check:type IN ('income', 'expense')" json:"type"`
	CurrencyCode         string                       `gorm:"type:char(3);not null;index" json:"currency_code"`
	Currency             *Currency                    `gorm:"foreignKey:CurrencyCode;references:Code" json:"currency,omitempty"`
	Icon                 string                       `gorm:"type:varchar(255);" json:"icon"`
	Color                string                       `gorm:"type:varchar(255);" json:"color"`
	MerchantName         *string                      `gorm:"type:varchar(255);" json:"merchant_name,omitempty"`
	Notes                *string                      `gorm:"type:varchar(255);" json:"notes,omitempty"`
	TransactionCategory  []RecurrenceTemplateCategory `gorm:"foreignKey:RecurrenceTemplateID" json:"transaction_category"`
	Frequency            string                       `gorm:"type:varchar(255);not null;check:frequency IN ('daily', 'weekly', 'bi-weekly', 'monthly', 'yearly')" json:"frequency"`
	NextDate             time.Time                    `gorm:"not null" json:"next_date"`
	NextPaymentAmount    *types.Money                 `gorm:"type:decimal(19,4);not null" json:"next_payment_amount"`
	AmountPaidPreviously *types.Money                 `gorm:"type:decimal(19,4);not null;default:0" json:"amount_paid_previously"`
	AmountLeftToPay      *types.Money                 `gorm:"type:decimal(19,4)" json:"amount_left_to_pay,omitempty"`
	TotalAmountToPay     *types.Money                 `gorm:"type:decimal(19,4)" json:"total_amount_to_pay,omitempty"`
	EndDate              *time.Time                   `json:"end_date,omitempty"`
	StartDate            *time.Time                   `json:"start_date,omitempty"`
	HasEndDate           bool                         `gorm:"default:false" json:"has_end_date"`
	IsActive             bool                         `gorm:"default:true" json:"is_active"`
	Transactions         []Transaction                `gorm:"foreignKey:RecurrenceTemplateID" json:"transactions,omitempty"`
	AccountID            *uint                        `gorm:"index" json:"account_id,omitempty"`
}

type RecurrenceTemplateCategory struct {
	ID                   uint               `gorm:"primaryKey" json:"id"`
	CreatedAt            time.Time          `json:"created_at"`
	UpdatedAt            time.Time          `json:"updated_at"`
	RecurrenceTemplateID uint               `gorm:"not null;index" json:"recurrence_template_id"`
	CategoryID           uint               `gorm:"not null;index" json:"category_id"`
	Category             Category           `gorm:"foreignKey:CategoryID;constraint:OnDelete:CASCADE" json:"Category"`
	Amount               *types.Money       `gorm:"type:decimal(19,4);not null" json:"amount"`
	RecurrenceTemplate   RecurrenceTemplate `gorm:"foreignKey:RecurrenceTemplateID;references:ID;constraint:OnDelete:CASCADE" json:"recurrence_template,omitempty"`
}
