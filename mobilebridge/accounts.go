//go:build android || smoke

package mobilebridge

import (
	"encoding/json"
	"fmt"

	accdto "moneef/internal/accounts/dto"
	accsvc "moneef/internal/accounts/service"
	usersvc "moneef/internal/users/service"
)

// ListAccounts returns every account with its per-currency balances.
func ListAccounts() ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	uid, err := resolveUserID(pid)
	if err != nil {
		return nil, err
	}
	settings, err := usersvc.GetSettings(uid)
	if err != nil {
		return nil, err
	}
	list, err := accsvc.ListAccounts(pid, settings.CurrencyCode)
	if err != nil {
		return nil, err
	}
	return json.Marshal(list)
}

func CreateAccount(payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	var req accdto.AccountRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	acc, err := accsvc.CreateAccount(pid, req)
	if err != nil {
		return nil, err
	}
	return json.Marshal(acc)
}

func UpdateAccount(id int64, payload []byte) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	var req accdto.AccountRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	return accsvc.RenameAccount(uint(id), pid, req)
}

func DeleteAccount(id int64) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	return accsvc.DeleteAccount(uint(id), pid)
}

func ListTransfers(accountID int64) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	list, err := accsvc.ListTransfers(pid, uint(accountID))
	if err != nil {
		return nil, err
	}
	return json.Marshal(list)
}

func CreateTransfer(payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	var req accdto.TransferRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	t, err := accsvc.CreateTransfer(pid, req)
	if err != nil {
		return nil, err
	}
	return json.Marshal(t)
}

func DeleteTransfer(id int64) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	return accsvc.DeleteTransfer(uint(id), pid)
}

func SetBalance(payload []byte) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	var req accdto.SetBalanceRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	return accsvc.SetBalance(pid, req)
}
