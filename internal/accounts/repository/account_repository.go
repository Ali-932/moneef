package repository

import (
	"moneef/internal/accounts/dto"
	"moneef/internal/db"
	"moneef/internal/models"

	"gorm.io/gorm"
)

// FirstAccount returns the profile's oldest account, or a zero ID when it has none.
func FirstAccount(tx *gorm.DB, profileID uint) (models.Account, error) {
	var account models.Account
	err := tx.Where("profile_id = ?", profileID).Order("id").Limit(1).Find(&account).Error
	return account, err
}

func CreateAccount(tx *gorm.DB, account *models.Account) error {
	return tx.Create(account).Error
}

// AssignAccountless moves transactions and recurring payments without an account into accountID.
func AssignAccountless(tx *gorm.DB, profileID uint, accountID uint) error {
	for _, model := range []any{&models.Transaction{}, &models.RecurrenceTemplate{}} {
		if err := tx.Model(model).Where("profile_id = ? AND account_id IS NULL", profileID).
			UpdateColumn("account_id", accountID).Error; err != nil {
			return err
		}
	}
	return nil
}

func AccountExists(tx *gorm.DB, id uint, profileID uint) (bool, error) {
	var count int64
	err := tx.Model(&models.Account{}).Where("id = ? AND profile_id = ?", id, profileID).Count(&count).Error
	return count > 0, err
}

func ListAccounts(profileID uint) ([]models.Account, error) {
	var accounts []models.Account
	err := db.DB.Where("profile_id = ?", profileID).Order("id").Find(&accounts).Error
	return accounts, err
}

func RenameAccount(id uint, profileID uint, name string) error {
	result := db.DB.Model(&models.Account{}).Where("id = ? AND profile_id = ?", id, profileID).Update("name", name)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// CountAccountActivity counts transactions, recurring payments and transfers using the account.
func CountAccountActivity(id uint) (int64, error) {
	var count int64
	err := db.DB.Raw(`SELECT
		(SELECT COUNT(*) FROM transactions WHERE account_id = ?) +
		(SELECT COUNT(*) FROM recurrence_templates WHERE account_id = ?) +
		(SELECT COUNT(*) FROM transfers WHERE from_account_id = ? OR to_account_id = ?)`,
		id, id, id, id).Scan(&count).Error
	return count, err
}

func DeleteAccount(id uint, profileID uint) error {
	result := db.DB.Where("id = ? AND profile_id = ?", id, profileID).Delete(&models.Account{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// Balances is income − expenses + transfers in − transfers out, per account and currency.
func Balances(profileID uint) ([]dto.Balance, error) {
	var balances []dto.Balance
	err := db.DB.Raw(`
		SELECT account_id, currency, SUM(amount) AS amount FROM (
			SELECT t.account_id, t.currency_code AS currency,
				CASE WHEN t.type = 'income' THEN tc.amount ELSE -tc.amount END AS amount
			FROM transactions t JOIN transaction_categories tc ON tc.transaction_id = t.id
			WHERE t.profile_id = ?
			UNION ALL
			SELECT to_account_id, to_currency, to_amount FROM transfers WHERE profile_id = ?
			UNION ALL
			SELECT from_account_id, from_currency, -from_amount FROM transfers
			WHERE profile_id = ? AND from_account_id IS NOT NULL
		) GROUP BY account_id, currency ORDER BY currency`,
		profileID, profileID, profileID).Scan(&balances).Error
	return balances, err
}

func CreateTransfer(transfer *models.Transfer) error {
	return db.DB.Create(transfer).Error
}

// ListTransfers returns the account's 20 latest transfers, newest first.
func ListTransfers(profileID uint, accountID uint) ([]models.Transfer, error) {
	transfers := []models.Transfer{}
	err := db.DB.Where("profile_id = ? AND (from_account_id = ? OR to_account_id = ?)", profileID, accountID, accountID).
		Order("date DESC, id DESC").Limit(20).Find(&transfers).Error
	return transfers, err
}

func DeleteTransfer(id uint, profileID uint) error {
	result := db.DB.Where("id = ? AND profile_id = ?", id, profileID).Delete(&models.Transfer{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
