package services

import (
	"github.com/shopspring/decimal"
	"moneef/internal/models"
	"moneef/internal/repository"
	"moneef/pkg/types"
	"time"
)

func HandelTransactionCreation(
	profileId uint,
	transactionName string,
	amount decimal.Decimal,
	currencyCode string,
	transactionType string,
	date time.Time,
	icon string,
	color string,
	merchantName *string,
	notes *string,
	categoryIDs []uint,
	isRecurrent *bool,
	recurrentFreq *string,
	recurrentType *string,
	isActiveRecurrent *bool,
	recurrentAmountPaid *decimal.Decimal,
	recurrentStartDate *time.Time,
	recurrentHasEndDate *bool,
	recurrentEndDate *time.Time,

) error {
	if err := CreateTransaction(
		profileId,
		transactionName,
		amount,
		currencyCode,
		transactionType,
		date,
		icon,
		color,
		merchantName,
		notes,
		categoryIDs,
	); err != nil {
		return err
	}
	return nil
}

func CreateTransaction(
	profileID uint,
	transactionName string,
	amount decimal.Decimal,
	currencyCode string,
	transactionType string,
	date time.Time,
	icon string,
	color string,
	merchantName *string,
	notes *string,
	categoryIDs []uint,
) error {
	// Load categories to attach to the transaction
	categories, err := repository.GetCategoriesByIDs(categoryIDs)
	if err != nil {
		return err
	}

	amt := types.Money(amount)
	trx := &models.Transaction{
		ProfileID:    profileID,
		Name:         transactionName,
		Type:         transactionType,
		Date:         date,
		Amount:       &amt,
		CurrencyCode: currencyCode,
		Icon:         icon,
		Color:        color,
		MerchantName: merchantName,
		Notes:        notes,
		Category:     categories,
	}
	return repository.CreateTransaction(trx)
}
