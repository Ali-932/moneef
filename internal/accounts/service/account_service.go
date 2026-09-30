// Package service keeps where money lives: named accounts, transfers between
// them, and balances. Transfers never touch income/expense totals.
package service

import (
	"errors"
	"strings"
	"time"

	"github.com/shopspring/decimal"
	"gorm.io/gorm"

	"moneef/internal/accounts/dto"
	"moneef/internal/accounts/repository"
	"moneef/internal/config"
	"moneef/internal/db"
	"moneef/internal/models"
	"moneef/pkg/types"
	"moneef/pkg/utils"
)

var (
	ErrNameRequired      = errors.New("account name is required")
	ErrAccountInUse      = errors.New("this account still has activity")
	ErrCurrencyRequired  = errors.New("currency is required")
	ErrAmountNotPositive = errors.New("transfer amounts must be greater than 0")
	ErrSameAccount       = errors.New("pick a different account or currency")
)

// Resolve checks accountID belongs to the profile, or returns the profile's
// default account when accountID is nil.
func Resolve(tx *gorm.DB, profileID uint, accountID *uint) (uint, error) {
	if accountID == nil {
		return defaultAccountID(tx, profileID)
	}
	exists, err := repository.AccountExists(tx, *accountID, profileID)
	if err != nil {
		return 0, err
	}
	if !exists {
		return 0, gorm.ErrRecordNotFound
	}
	return *accountID, nil
}

// defaultAccountID returns the profile's first account. On first use it creates
// "Main"; account-less transactions and recurring payments move into it.
func defaultAccountID(tx *gorm.DB, profileID uint) (uint, error) {
	account, err := repository.FirstAccount(tx, profileID)
	if err != nil {
		return 0, err
	}
	if account.ID == 0 {
		account = models.Account{ProfileID: profileID, Name: "Main"}
		if err := repository.CreateAccount(tx, &account); err != nil {
			return 0, err
		}
	}
	return account.ID, repository.AssignAccountless(tx, profileID, account.ID)
}

func ListAccounts(profileID uint, baseCurrency string) ([]dto.AccountSummary, error) {
	if _, err := defaultAccountID(db.DB, profileID); err != nil {
		return nil, err
	}
	accounts, err := repository.ListAccounts(profileID)
	if err != nil {
		return nil, err
	}
	balances, err := repository.Balances(profileID)
	if err != nil {
		return nil, err
	}
	summaries := make([]dto.AccountSummary, len(accounts))
	for i, account := range accounts {
		summaries[i] = dto.AccountSummary{Account: account, Balances: []dto.Balance{}}
		total, ok := decimal.Zero, true
		for _, b := range balances {
			if b.AccountID != account.ID {
				continue
			}
			summaries[i].Balances = append(summaries[i].Balances, b)
			converted, err := utils.ConvertAmount(db.DB, decimal.Decimal(b.Amount), b.Currency, baseCurrency)
			ok = ok && err == nil
			total = total.Add(converted)
		}
		if ok {
			approx := types.Money(total.Round(config.AmountRounding))
			summaries[i].ApproxTotal = &approx
		}
	}
	return summaries, nil
}

func CreateAccount(profileID uint, req dto.AccountRequest) (*models.Account, error) {
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return nil, ErrNameRequired
	}
	account := &models.Account{ProfileID: profileID, Name: name}
	if err := repository.CreateAccount(db.DB, account); err != nil {
		return nil, err
	}
	return account, nil
}

func RenameAccount(id uint, profileID uint, req dto.AccountRequest) error {
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return ErrNameRequired
	}
	return repository.RenameAccount(id, profileID, name)
}

// DeleteAccount removes an account nothing uses yet (foreign keys are off, so check here).
func DeleteAccount(id uint, profileID uint) error {
	used, err := repository.CountAccountActivity(id)
	if err != nil {
		return err
	}
	if used > 0 {
		return ErrAccountInUse
	}
	return repository.DeleteAccount(id, profileID)
}

func CreateTransfer(profileID uint, req dto.TransferRequest) (*models.Transfer, error) {
	if req.ToCurrency == "" {
		req.ToCurrency = req.FromCurrency
	}
	if req.ToAmount.IsZero() {
		req.ToAmount = req.FromAmount
	}
	if len(req.FromCurrency) != 3 || len(req.ToCurrency) != 3 {
		return nil, ErrCurrencyRequired
	}
	if !req.FromAmount.IsPositive() || !req.ToAmount.IsPositive() {
		return nil, ErrAmountNotPositive
	}
	if req.FromAccountID == req.ToAccountID && req.FromCurrency == req.ToCurrency {
		return nil, ErrSameAccount
	}
	for _, id := range []uint{req.FromAccountID, req.ToAccountID} {
		if _, err := Resolve(db.DB, profileID, &id); err != nil {
			return nil, err
		}
	}
	if req.Date.IsZero() {
		req.Date = time.Now().UTC()
	}
	from, to := types.Money(req.FromAmount), types.Money(req.ToAmount)
	transfer := &models.Transfer{
		ProfileID: profileID, Date: req.Date,
		FromAccountID: &req.FromAccountID, FromCurrency: req.FromCurrency, FromAmount: &from,
		ToAccountID: req.ToAccountID, ToCurrency: req.ToCurrency, ToAmount: &to,
	}
	if err := repository.CreateTransfer(transfer); err != nil {
		return nil, err
	}
	return transfer, nil
}

// SetBalance records the gap between the app's balance and the real one as
// money from outside, so the account shows req.Amount from now on.
func SetBalance(profileID uint, req dto.SetBalanceRequest) error {
	if _, err := Resolve(db.DB, profileID, &req.AccountID); err != nil {
		return err
	}
	if len(req.Currency) != 3 {
		return ErrCurrencyRequired
	}
	balances, err := repository.Balances(profileID)
	if err != nil {
		return err
	}
	diff := req.Amount
	for _, b := range balances {
		if b.AccountID == req.AccountID && b.Currency == req.Currency {
			diff = req.Amount.Sub(decimal.Decimal(b.Amount))
		}
	}
	if diff.IsZero() {
		return nil
	}
	amount := types.Money(diff)
	return repository.CreateTransfer(&models.Transfer{
		ProfileID: profileID, Date: time.Now().UTC(),
		ToAccountID: req.AccountID, ToCurrency: req.Currency, ToAmount: &amount,
	})
}

func ListTransfers(profileID uint, accountID uint) ([]models.Transfer, error) {
	return repository.ListTransfers(profileID, accountID)
}

func DeleteTransfer(id uint, profileID uint) error {
	return repository.DeleteTransfer(id, profileID)
}
