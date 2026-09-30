//go:build android || smoke

package mobilebridge

import (
	"encoding/json"
	"errors"
	"fmt"

	"github.com/shopspring/decimal"
	"gorm.io/gorm"

	"moneef/internal/models"
	txndto "moneef/internal/transactions/dto"
	txnsvc "moneef/internal/transactions/service"
)

// ListTransactionsRequest mirrors the HTTP handler's query params plus
// explicit pagination — no *http.Request is available in the gomobile shim.
type ListTransactionsRequest struct {
	Type         string `json:"type"`
	CategoryID   uint   `json:"category_id"`
	CategoryName string `json:"category_name"`
	DateFrom     string `json:"date_from"`
	DateTo       string `json:"date_to"`
	Search       string `json:"search"`
	Sort         string `json:"sort"`
	Page         int    `json:"page"`
	PerPage      int    `json:"per_page"`
	AccountID    uint   `json:"account_id"`
}

// PaginatedTransactions is the in-process equivalent of
// pagination.PaginatedResult[models.Transaction] without the next/previous
// URL strings (which are HTTP-only).
type PaginatedTransactions struct {
	Count       int64                `json:"count"`
	TotalPages  int                  `json:"total_pages"`
	CurrentPage int                  `json:"current_page"`
	PerPage     int                  `json:"per_page"`
	Results     []models.Transaction `json:"results"`
}

const (
	defaultPage    = 1
	defaultPerPage = 20
	maxPerPage     = 100
)

func CreateTransaction(payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	var req txndto.TransactionRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	if err := req.Validate(); err != nil {
		return nil, err
	}
	cats := make(map[uint]decimal.Decimal, len(req.TransactionCategories))
	for _, c := range req.TransactionCategories {
		cats[c.CategoryId] = c.Amount
	}
	if err := txnsvc.HandleTransactionCreation(txndto.TransactionCreationParams{
		ProfileID:             pid,
		Name:                  req.TransactionName,
		Type:                  req.TransactionType,
		Date:                  req.Date,
		CurrencyCode:          req.CurrencyCode,
		Icon:                  req.Icon,
		Color:                 req.Color,
		MerchantName:          req.MerchantName,
		Notes:                 req.Notes,
		CategoriesTransaction: cats,
		AccountID:             req.AccountID,
		IsRecurrent:           req.IsRecurrent,
		Frequency:             req.RecurrentFreq,
		AmountPaidPreviously:  req.RecurrentPaidPreviously,
		TotalAmountToPay:      req.RecurrentTotalAmount,
		EndDate:               req.RecurrentEndDate,
		HasEndDate:            req.RecurrentHasEndDate,
		IsActive:              req.IsActiveRecurrent,
	}); err != nil {
		return nil, err
	}
	if req.IsRecurrent != nil && *req.IsRecurrent {
		bookDueRecurrences() // a start date in the past has payments due now
	}
	return []byte(`{"message":"transaction created"}`), nil
}

func ListTransactions(payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	var req ListTransactionsRequest
	if len(payload) > 0 {
		if err := json.Unmarshal(payload, &req); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
		}
	}
	page := req.Page
	if page < 1 {
		page = defaultPage
	}
	perPage := req.PerPage
	if perPage < 1 {
		perPage = defaultPerPage
	}
	if perPage > maxPerPage {
		perPage = maxPerPage
	}

	query := txnsvc.ListTransactions(pid, req.Type, req.CategoryID, req.DateFrom, req.DateTo, req.Search, req.CategoryName, req.Sort)
	if req.AccountID > 0 {
		query = query.Where("transactions.account_id = ?", req.AccountID)
	}

	var count int64
	if err := query.Session(&gorm.Session{}).Count(&count).Error; err != nil {
		return nil, fmt.Errorf("count transactions: %w", err)
	}

	offset := (page - 1) * perPage
	var results []models.Transaction
	if err := query.Offset(offset).Limit(perPage).Find(&results).Error; err != nil {
		return nil, fmt.Errorf("list transactions: %w", err)
	}
	if results == nil {
		results = []models.Transaction{}
	}

	totalPages := 0
	if perPage > 0 {
		totalPages = int((count + int64(perPage) - 1) / int64(perPage))
	}
	resp := PaginatedTransactions{
		Count:       count,
		TotalPages:  totalPages,
		CurrentPage: page,
		PerPage:     perPage,
		Results:     results,
	}
	return json.Marshal(resp)
}

func GetTransaction(id int64) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	if id <= 0 {
		return nil, fmt.Errorf("mobile.GetTransaction: id must be > 0")
	}
	txn, err := txnsvc.GetTransaction(uint(id), pid)
	if err != nil {
		return nil, err
	}
	return json.Marshal(txn)
}

func UpdateTransaction(id int64, payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	if id <= 0 {
		return nil, fmt.Errorf("mobile.UpdateTransaction: id must be > 0")
	}
	var req txndto.TransactionUpdateRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	if err := req.Validate(); err != nil {
		return nil, err
	}
	cats := make(map[uint]decimal.Decimal, len(req.TransactionCategories))
	for _, c := range req.TransactionCategories {
		cats[c.CategoryId] = c.Amount
	}
	if err := txnsvc.UpdateTransaction(uint(id), pid, req, cats); err != nil {
		return nil, err
	}
	return []byte(`{"message":"transaction updated"}`), nil
}

func DeleteTransaction(id int64) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	if id <= 0 {
		return fmt.Errorf("mobile.DeleteTransaction: id must be > 0")
	}
	if err := txnsvc.DeleteTransaction(uint(id), pid); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fmt.Errorf("transaction not found")
		}
		return err
	}
	return nil
}

func ListRecurrences() ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	list, err := txnsvc.ListRecurrences(pid)
	if err != nil {
		return nil, err
	}
	if list == nil {
		list = []models.RecurrenceTemplate{}
	}
	return json.Marshal(list)
}

func RecurrenceTimeline() ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	timeline, err := txnsvc.GetRecurrenceTimeline(pid)
	if err != nil {
		return nil, err
	}
	if timeline == nil {
		return []byte("[]"), nil
	}
	return json.Marshal(timeline)
}

func DeleteRecurrence(id int64) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	if id <= 0 {
		return fmt.Errorf("mobile.DeleteRecurrence: id must be > 0")
	}
	return txnsvc.DeleteRecurrence(pid, uint(id))
}
